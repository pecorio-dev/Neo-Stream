import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config/theme.dart';
import '../config/neo.dart';
import '../models/fstv_channel.dart';
import '../services/epg_service.dart';
import '../services/fstv_proxy_service.dart';
import '../services/iptv_favorites.dart';
import '../services/iptv_resume.dart';
import '../widgets/neo_glass_card.dart';
import '../widgets/satisfying_animations.dart';
import '../widgets/universal_video_player.dart';
import 'payment_wall_screen.dart';

/// Halo de focus à contraste garanti (jamais blanc sur blanc) :
/// anneau intérieur net blanc en thème sombre / noir en thème clair
/// (le halo ne se confond donc jamais avec le fond), + lueur de la
/// couleur d'accent. Le contenu (texte/icône) reste géré par l'appelant
/// en fond opaque + couleur lisible ([Neo.readableOn]).
List<BoxShadow> _focusHalo(BuildContext context, Color focusColor) {
  final isLight = Theme.of(context).brightness == Brightness.light;
  return [
    BoxShadow(
      color: (isLight ? Colors.black : Colors.white).withValues(alpha: 0.9),
      blurRadius: 6,
      spreadRadius: 1.5,
    ),
    BoxShadow(
      color: focusColor.withValues(alpha: 0.55),
      blurRadius: 22,
      spreadRadius: 3,
    ),
  ];
}

/// Touche "OK" TV : Enter + variantes gamepad/numpad (B2). Utilisé partout
/// sur l'onglet Direct (refresh, chips, spotlight, cartes, popup, player)
/// pour que la touche OK du gamepad (gameButtonA) et Entrée du pavé
/// numérique ne soient jamais morts.
bool _isTvActivate(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.enter ||
    key == LogicalKeyboardKey.numpadEnter ||
    key == LogicalKeyboardKey.select ||
    key == LogicalKeyboardKey.space ||
    key == LogicalKeyboardKey.gameButtonA;

/// Touche "favori" TV : Menu / Info / Y (gamepad + clavier) / F.
bool _isFavKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.contextMenu ||
    key == LogicalKeyboardKey.info ||
    key == LogicalKeyboardKey.gameButtonY ||
    key == LogicalKeyboardKey.keyY ||
    key == LogicalKeyboardKey.keyF;

/// Navigation directionnelle explicite (B1) : tente le déplacement vers
/// [dir] depuis [node] et consomme l'événement si le focus a bougé, sinon
/// laisse le traversal par défaut s'en charger (filet : navbar, rangées
/// voisines). Évite que Gauche/Droite ne remonte en haut via la politique
/// géométrique [ReadingOrderTraversalPolicy].
KeyEventResult _moveFocus(FocusNode node, TraversalDirection dir) =>
    node.focusInDirection(dir)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;

/// Depuis un handler racine (le [node] attaché n'est PAS le focus courant,
/// cas du player plein écran) : déplace le focus actuel vers [dir], consommé
/// si bougé, sinon filet vers le traversal par défaut.
KeyEventResult _moveFocused(TraversalDirection dir) {
  final focused = FocusManager.instance.primaryFocus;
  if (focused != null && focused.focusInDirection(dir)) {
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

/// Écran TV en direct — chaînes servies par le proxy FSTV (iptv.mine.bz).
///
/// Source unique : FSTV (chaînes premium FR). Authentification automatique via
/// le compte Neo Stream (premium requis). UI glassmorphisme claire par défaut.
class IptvScreen extends StatefulWidget {
  /// Callback TV : appelé quand D-pad gauche est pressé sur un élément
  /// en bord gauche (premier chip catégorie / carte première colonne),
  /// pour remonter le focus à la navbar du TVShell.
  final VoidCallback? onLeftEdge;

  const IptvScreen({super.key, this.onLeftEdge});

  @override
  State<IptvScreen> createState() => _IptvScreenState();
}

class _IptvScreenState extends State<IptvScreen> {
  final _proxy = FstvProxyService.instance;
  final _favs = IptvFavorites.instance;
  final _resume = IptvResume.instance;
  final _scrollCtrl = ScrollController();

  Map<String, List<FstvChannel>> _channelsByCategory = {};
  List<FstvChannel> _flat = [];
  List<FstvChannel> _filtered = [];
  Set<String> _favIds = {};

  bool _loading = true;
  bool _loadInFlight = false;
  String? _error;
  bool _premiumRequired = false;

  String? _selectedCategory; // null = toutes
  bool _favOnly = false; // filtre "Favoris"
  List<String> _categories = [];

  /// Spotlight "À la une" mémoïsé (recalculé après _load, changement de
  /// filtre et arrivée du guide — jamais à chaque build : le calcul fait
  /// ~2 × N requêtes EPG avec normalisations de noms).
  List<FstvChannel> _spotlight = const [];

  /// Travail différé annulable (anti-freeze ouverture d'onglet) :
  /// - [_epgKickTimer] : EPG démarré APRÈS le premier rendu (postFrame +
  ///   ~1.5 s, priorité basse) pour laisser grille + logos se peindre d'abord.
  /// - [_preRankTimer] : pré-rank sources SEULEMENT quand idle (~3 s après
  ///   l'arrivée des chaînes). Annulés dans [dispose] (sortie d'onglet).
  Timer? _epgKickTimer;
  Timer? _preRankTimer;
  bool _epgWarmStarted = false;

  @override
  void initState() {
    super.initState();
    _favIds = _favs.ids;
    _favs.addListener(_onFavsChanged);
    _favs.load();
    _resume.addListener(_onResumeChanged);
    _resume.load();
    _load();
    // Guide TV en DIFFÉRÉ après le premier rendu (anti-freeze) : le download
    // EPG (~6.7 Mo) + parse (~58k programmes) ne doivent jamais concurrencer
    // le premier paint (grille + logos). PostFrame + délai 1.5 s, priorité
    // basse. À son arrivée : un seul setState global (re-tri spotlight +
    // pastilles EPG), jamais un FutureBuilder par carte. Zéro impact live :
    // ni blocage des chaînes, ni appel au proxy iptv.mine.bz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _epgKickTimer?.cancel();
      _epgKickTimer = Timer(
        const Duration(milliseconds: 1500),
        _warmEpgLowPriority,
      );
    });
  }

  /// Démarre le guide TV à priorité basse (hors premier rendu).
  /// Single-flight + cache 12 h côté service : gratuit si déjà chargé.
  /// Gardes mounted : aucun setState pendant le build ni après dispose.
  void _warmEpgLowPriority() async {
    if (!mounted || _epgWarmStarted) return;
    _epgWarmStarted = true;
    // Cède un tour d'event-loop avant le gros travail réseau/parse pour
    // laisser le premier rendu se stabiliser (logos, grille).
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await EpgService.instance.ensureLoaded();
    if (!mounted) return;
    // Re-tri spotlight à priorité idle : le scan (~135 chaînes × requêtes
    // EPG mémoïsées) ne vole pas la frame en cours.
    SchedulerBinding.instance.scheduleTask(() {
      if (!mounted) return;
      setState(_refreshSpotlight);
    }, Priority.idle);
  }

  /// Planifie le pré-rank sources quand idle (~3 s), annulable à la sortie
  /// de l'onglet. Ne démarre jamais pendant le build / le premier rendu.
  void _schedulePreRank() {
    _preRankTimer?.cancel();
    _preRankTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _flat.isEmpty) return;
      _preRankVisible();
    });
  }

  void _onFavsChanged() {
    if (!mounted) return;
    setState(() {
      _favIds = _favs.ids;
      _filtered = _computeFiltered();
      _refreshSpotlight();
    });
  }

  /// Historique "Reprendre" : simple refresh (re-tri spotlight "reprise
  /// d'abord" + pastilles des cartes). Aucun reload réseau.
  void _onResumeChanged() {
    if (!mounted) return;
    setState(_refreshSpotlight);
  }

  @override
  void dispose() {
    _epgKickTimer?.cancel();
    _preRankTimer?.cancel();
    _favs.removeListener(_onFavsChanged);
    _resume.removeListener(_onResumeChanged);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (_loadInFlight) return;
    _loadInFlight = true;

    // _loading vaut déjà true à l'init : pas de setState synchrone depuis
    // initState (setState pendant le premier build = jank + frame perdue).
    if (_flat.isEmpty && !_loading) {
      setState(() {
        _loading = true;
        _error = null;
        _premiumRequired = false;
      });
    }

    try {
      await _proxy.ensureAuthenticated();
      final grouped = await _proxy.getChannels(forceRefresh: forceRefresh);
      if (!mounted) return;

      final flat = grouped.values.expand((l) => l).toList(growable: false);

      setState(() {
        _channelsByCategory = grouped;
        _categories = grouped.keys.toList();
        // La catégorie sélectionnée a pu disparaître côté API (renommage) :
        // retomber sur "Toutes" plutôt qu'une grille vide trompeuse.
        if (_selectedCategory != null &&
            !grouped.containsKey(_selectedCategory)) {
          _selectedCategory = null;
          _favOnly = false;
        }
        _flat = flat;
        _filtered = _computeFilteredFor(flat, grouped);
        _refreshSpotlight();
        _loading = false;
        _error = null;
      });
      // Pré-rank DIFFÉRÉ quand idle (fire-and-forget, ~3 s, annulable) :
      // probe les chaînes visibles (spotlight + ~20 premières, jamais les
      // 135 d'un coup, vagues de 5 côté proxy) pour mémoriser la meilleure
      // source par slug → "Lancer" démarre aussitôt sur la meilleure connue,
      // sans attendre le rank complet. Jamais pendant le premier rendu.
      _schedulePreRank();
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    } on FstvPremiumRequiredException catch (e) {
      if (!mounted) return;
      setState(() {
        _premiumRequired = true;
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = FstvProxyService.humanize(e);
        _loading = false;
      });
    } finally {
      _loadInFlight = false;
    }
  }

  /// Filtre courant (catégorie × favoris) appliqué à [_flat].
  List<FstvChannel> _computeFiltered() =>
      _computeFilteredFor(_flat, _channelsByCategory);

  List<FstvChannel> _computeFilteredFor(
    List<FstvChannel> flat,
    Map<String, List<FstvChannel>> grouped,
  ) {
    Iterable<FstvChannel> result = _selectedCategory == null
        ? flat
        : grouped[_selectedCategory] ?? const <FstvChannel>[];
    if (_favOnly) {
      result = result.where((ch) => _favIds.contains(ch.slug));
    }
    return result.toList(growable: false);
  }

  void _applyFilters() {
    setState(() {
      _filtered = _computeFiltered();
      _refreshSpotlight();
    });
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
  }

  /// Pré-rank des chaînes visibles en tâche de fond (spotlight + premières
  /// de la grille, ≤ 30 au total — jamais tout le catalogue d'un coup).
  /// Fire-and-forget : ne bloque ni n'échoue jamais, remplit juste le cache
  /// "meilleure source par slug" du proxy pour un zapping immédiat.
  void _preRankVisible() {
    if (!mounted || _flat.isEmpty) return;
    final queue = <FstvChannel>[];
    final seen = <String>{};
    void add(FstvChannel ch) {
      if (ch.slug.isEmpty || !seen.add(ch.slug)) return;
      queue.add(ch);
    }

    for (final ch in _spotlight) {
      add(ch);
      if (queue.length >= 30) break;
    }
    for (final ch in _filtered) {
      add(ch);
      if (queue.length >= 30) break;
    }
    if (queue.isEmpty) return;
    unawaited(_proxy.preRankChannels(queue));
  }

  void _play(FstvChannel channel, {String? initialSourceUrl}) {
    HapticFeedback.mediumImpact();
    // Mémorise la reprise AVANT d'ouvrir le lecteur (le direct n'a pas de
    // timeline : "reprendre" = rouvrir la dernière chaîne regardée).
    _resume.touch(channel.slug);
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_1, _2, _3) => _LivePlayerScreen(
          channel: channel,
          initialSourceUrl: initialSourceUrl,
        ),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_1, anim, _2, child) {
          final curve =
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(opacity: curve, child: child);
        },
      ),
    );
  }

  /// Popup détails d'une chaîne : logo, nom, catégorie, nb sources,
  /// bouton "Lancer le direct" (meilleure source rankée) + choix par source.
  /// Chaque ligne affiche le label API quand il est non vide, sinon
  /// "Source N" — uniquement ces deux cas.
  void _showDetails(FstvChannel channel) {
    HapticFeedback.selectionClick();
    final entries = _popupSourcesOf(channel);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => _ChannelDetailsDialog(
        channel: channel,
        entries: entries,
        isFavorite: _favIds.contains(channel.slug),
        onToggleFavorite: () {
          HapticFeedback.selectionClick();
          _favs.toggle(channel.slug);
        },
        // "Lancer le direct" : meilleure source rankée (pas d'imposée).
        onPlayBest: () {
          Navigator.of(dialogCtx).pop();
          _play(channel);
        },
        // Choix explicite : le player démarre sur cette source imposée.
        onPlaySource: (url) {
          Navigator.of(dialogCtx).pop();
          _play(channel, initialSourceUrl: url);
        },
      ),
    );
  }

  /// Sources affichables du popup, dans l'ordre API : [{url, displayName}].
  /// displayName = label API trimé si non vide, sinon "Source N".
  static List<({String url, String displayName})> _popupSourcesOf(
    FstvChannel channel,
  ) {
    final out = <({String url, String displayName})>[];
    for (var i = 0; i < channel.sources.length; i++) {
      final raw = channel.sources[i];
      final url = (raw['url'] as String?)?.trim() ?? '';
      if (url.isEmpty) continue;
      final label = (raw['label'] as String?)?.trim() ?? '';
      out.add((
        url: url,
        displayName: label.isNotEmpty ? label : 'Source ${out.length + 1}',
      ));
    }
    return out;
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isTV = NeoTheme.isTV(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: !isTV,
        // Pas de FocusScope anonyme ici : il cassait le test
        // `enclosingScope == node` du TVShell et piégeait la flèche gauche.
        // Simple FocusTraversalGroup : Up grille -> categoryBar via traversal.
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Column(
            children: [
              _buildHeader(),
              if (!_premiumRequired && !_loading) _buildCategoryBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isTV = NeoTheme.isTV(context);
    final favCount = _favIds.length;
    final subtitle = _loading
        ? 'Chargement des chaînes…'
        : '${_flat.length} chaîne${_flat.length > 1 ? 's' : ''} · '
            '${_categories.length} catégorie${_categories.length > 1 ? 's' : ''} · '
            '$favCount favori${favCount > 1 ? 's' : ''}';
    return Padding(
      padding: EdgeInsets.fromLTRB(20, isTV ? 20 : 16, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: isTV ? 56 : 48,
                height: isTV ? 56 : 48,
                decoration: BoxDecoration(
                  gradient: Neo.heroGradient(context),
                  borderRadius: BorderRadius.circular(Neo.radiusMd),
                  boxShadow: [
                    BoxShadow(
                      color: Neo.accentColor(context).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.live_tv_rounded,
                    color: Neo.onHeroGradient(context),
                    size: isTV ? 30 : 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'TV en Direct',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: isTV ? 26 : null,
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Pastille LIVE premium (masquée pendant le chargement).
                        if (!_loading && !_premiumRequired) const _LiveBadge(),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).hintColor,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              // Horloge locale + bouton refresh. L'horloge est premium sur
              // phone aussi (compacte sous 560 px), pas seulement sur TV.
              const _LiveClock(),
              const SizedBox(width: 10),
              if (!_premiumRequired && !_loading) _buildRefreshButton(),
            ],
          ),
          const SizedBox(height: 10),
          // Filet premium sous le header.
          Container(
            height: 1.2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Neo.accentColor(context).withValues(alpha: 0.45),
                  Neo.borderLight(context).withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bouton refresh du header avec focus TV très visible :
  /// bordure épaisse + halo + scale, pilotés par l'état Focus (D-pad),
  /// pas par le hover tactile.
  Widget _buildRefreshButton() {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (_isTvActivate(event.logicalKey)) {
            if (!_loading) _load(forceRefresh: true);
            return KeyEventResult.handled;
          }
          // Navigation latérale explicite (B1) : Gauche/Droite vers le
          // voisin, Haut/Bas vers la rangée voisine, sinon traversal.
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            return _moveFocus(node, TraversalDirection.left);
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            return _moveFocus(node, TraversalDirection.right);
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            return _moveFocus(node, TraversalDirection.up);
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            return _moveFocus(node, TraversalDirection.down);
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (ctx) {
          final isFocused = Focus.of(ctx).hasFocus;
          final isTV = NeoTheme.isTV(context);
          final tvFocused = isTV && isFocused;
          final focusColor = Neo.accentColor(context);
          // Focus TV : fond opaque + icône lisible (jamais blanc sur blanc).
          final focusFg = Neo.readableOn(focusColor);
          return AnimatedScale(
            scale: tvFocused ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tvFocused
                    ? focusColor
                    : Neo.bgElevated(context),
                borderRadius: BorderRadius.circular(Neo.radiusMd),
                border: Border.all(
                  color: tvFocused ? focusFg : Neo.borderLight(context),
                  width: tvFocused ? 3.5 : 1.2,
                ),
                boxShadow:
                    tvFocused ? _focusHalo(context, focusColor) : null,
              ),
              child: GestureDetector(
                onTap: _loading ? null : () => _load(forceRefresh: true),
                behavior: HitTestBehavior.opaque,
                child: Tooltip(
                  message: 'Actualiser',
                  child: Center(
                    child: Icon(
                      Icons.refresh_rounded,
                      color: tvFocused ? focusFg : Neo.textSecondary(context),
                      size: tvFocused ? 26 : 22,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryBar() {
    final specs = <({String label, int count, IconData icon, bool selected, VoidCallback onTap})>[
      (
        label: 'Toutes',
        count: _flat.length,
        icon: Icons.apps_rounded,
        selected: _selectedCategory == null && !_favOnly,
        onTap: () {
          _selectedCategory = null;
          _favOnly = false;
          _applyFilters();
        },
      ),
      (
        label: 'Favoris',
        count: _favIds.length,
        icon: Icons.favorite_rounded,
        selected: _favOnly,
        onTap: () {
          _favOnly = !_favOnly;
          _applyFilters();
        },
      ),
    ];
    for (final cat in _categories) {
      final list = _channelsByCategory[cat];
      final icon =
          (list != null && list.isNotEmpty) ? list.first.categoryIcon : Icons.tv_rounded;
      final selected = _selectedCategory == cat && !_favOnly;
      specs.add((
        label: cat,
        count: list?.length ?? 0,
        icon: icon,
        selected: selected,
        onTap: () {
          _selectedCategory = cat;
          _favOnly = false;
          _applyFilters();
        },
      ));
    }
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        itemCount: specs.length,
        separatorBuilder: (_1, _2) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s = specs[i];
          return _categoryChip(
            label: s.label,
            count: s.count,
            icon: s.icon,
            selected: s.selected,
            isFirst: i == 0,
            isLast: i == specs.length - 1,
            onTap: s.onTap,
          );
        },
      ),
    );
  }

  Widget _categoryChip({
    required String label,
    required int count,
    IconData? icon,
    required bool selected,
    required bool isFirst,
    bool isLast = false,
    required VoidCallback onTap,
  }) {
    final isTV = NeoTheme.isTV(context);
    return Focus(
      // Premier chip visible : point d'entrée autofocus côté contenu.
      autofocus: isTV && isFirst,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Enter/OK : activer
          if (_isTvActivate(event.logicalKey)) {
            onTap();
            return KeyEventResult.handled;
          }

          // Flèche gauche sur le premier chip : retour navbar (voie principale).
          if (isTV &&
              event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              isFirst) {
            if (widget.onLeftEdge != null) {
              widget.onLeftEdge!();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored; // filet : handler shell
          }
          // Navigation latérale explicite (B1) : Gauche/Droite vers le chip
          // voisin (jamais de remontée en haut via le traversal géométrique).
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            return _moveFocus(node, TraversalDirection.left);
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (isLast) return KeyEventResult.ignored;
            return _moveFocus(node, TraversalDirection.right);
          }
          // Haut/Bas : vers la rangée voisine (header/grille) quand
          // prévisible, sinon traversal.
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            return _moveFocus(node, TraversalDirection.up);
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            return _moveFocus(node, TraversalDirection.down);
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (ctx) {
          // Visuel piloté par l'état Focus (D-pad TV), pas par le hover.
          final isFocused = Focus.of(ctx).hasFocus;
          final tvMode = NeoTheme.isTV(context);
          final tvFocused = tvMode && isFocused;
          final focusColor = Neo.accentColor(context);
          // Accent du thème actif (blanc en sombre, rouge en clair) : jamais
          // de blanc codé en dur, sinon blanc sur blanc en thème clair.
          final accent = Neo.accentColor(context);
          // Focus TV : fond opaque + texte lisible (fond clair + texte sombre
          // en sombre, fond coloré + texte blanc en clair).
          final focusFg = Neo.readableOn(focusColor);
          final highlight = selected || isFocused;
          return AnimatedOpacity(
            // Carte non-focusée assombrie sur TV : contraste à 3 m.
            opacity: tvMode && !isFocused ? 0.62 : 1.0,
            duration: const Duration(milliseconds: 180),
            child: AnimatedScale(
              scale: tvFocused ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: tvFocused
                        ? focusColor
                        : highlight
                            ? accent.withValues(alpha: 0.14)
                            : Neo.bgElevated(context),
                    borderRadius: BorderRadius.circular(Neo.radiusFull),
                    border: Border.all(
                      color: tvFocused
                          ? focusFg
                          : highlight
                              ? accent.withValues(alpha: 0.6)
                              : Neo.borderLight(context),
                      // Bordure très épaisse sur focus TV : lisible à 3 m.
                      width: tvFocused ? 3.5 : (highlight ? 1.5 : 1),
                    ),
                    boxShadow: tvFocused
                        ? _focusHalo(context, focusColor)
                        : null,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              icon,
                              size: tvFocused ? 17 : 15,
                              color: tvFocused
                                  ? focusFg
                                  : highlight
                                      ? accent
                                      : Neo.textSecondary(context),
                            ),
                          ),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tvFocused
                                  ? focusFg
                                  : highlight
                                      ? accent
                                      : Neo.textSecondary(context),
                              fontWeight: (highlight || tvFocused)
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              fontSize: tvFocused ? 14 : 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: tvFocused
                                ? focusFg.withValues(alpha: 0.25)
                                : highlight
                                    ? accent.withValues(alpha: 0.16)
                                    : Theme.of(context)
                                        .hintColor
                                        .withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(Neo.radiusFull),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: tvFocused
                                  ? focusFg
                                  : highlight
                                      ? accent
                                      : Neo.textSecondary(context),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _flat.isEmpty) return _buildLoading();
    if (_premiumRequired) return _buildPremiumWall();
    if (_error != null && _flat.isEmpty) return _buildError();
    if (_filtered.isEmpty) return _buildEmpty();
    return _buildGrid();
  }

  Widget _buildLoading() {
    final width = MediaQuery.of(context).size.width;
    final crossCount = _gridCrossCount(width);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bandeau de chargement : titre + barre animée.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
          child: Row(
            children: [
              const _ShimmerBlock(width: 150, height: 16, radius: 8),
              const Spacer(),
              const _ShimmerBlock(width: 90, height: 14, radius: 7),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount,
              mainAxisSpacing: 18,
              crossAxisSpacing: 16,
              // Même gabarit que les vraies cartes (bloc EPG inclus).
              childAspectRatio: _gridAspect(
                  MediaQuery.of(context).size.width),
            ),
            itemCount: crossCount * 3,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_1, _2) => const _ShimmerChannelCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: NeoGlassCard(
          padding: const EdgeInsets.all(28),
          accent: Neo.errorRed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 56, color: Neo.errorRed.withValues(alpha: 0.8)),
              const SizedBox(height: 16),
              Text('Erreur de chargement',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                _error ?? '',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  _load(forceRefresh: true);
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    ).popIn();
  }

  Widget _buildPremiumWall() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: NeoGlassCard(
          padding: const EdgeInsets.all(32),
          accent: Neo.prestigeGold,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: Neo.premiumGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Neo.prestigeGold.withValues(alpha: 0.4),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              Text('Abonnement requis',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                'La TV en direct est la seule fonctionnalité payante de Neo Stream. '
                'Abonnez-vous pour débloquer toutes les chaînes en HD.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'À partir de 5,83€/mois · Sans engagement',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Neo.prestigeGold,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaymentWallScreen()),
                ),
                icon: const Icon(Icons.live_tv_rounded),
                label: const Text('Voir les offres'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    ).popIn();
  }

  Widget _buildEmpty() {
    final favEmpty = _favOnly && _filtered.isEmpty;
    final icon = favEmpty
        ? Icons.favorite_border_rounded
        : Icons.tv_off_rounded;
    final title = favEmpty
        ? 'Aucun favori pour le moment'
        : 'Aucune chaîne ici';
    final hint = favEmpty
        ? 'Touchez le cœur d\u2019une chaîne — ou faites un appui long — pour la retrouver ici. Sur TV : touche Menu / Info sur la carte.'
        : _selectedCategory == null
            ? 'Les chaînes apparaîtront ici dès qu\u2019elles seront disponibles.'
            : 'Aucune chaîne dans « $_selectedCategory » pour le moment. Essayez une autre catégorie.';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: NeoGlassCard(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: Neo.heroGradient(context),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Neo.accentColor(context).withValues(alpha: 0.22),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: Icon(icon,
                    size: 40, color: Neo.onHeroGradient(context)),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  hint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Neo.textSecondary(context),
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 18),
              // Raccourcis contextuels (jamais bloquants).
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (favEmpty || _selectedCategory != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        _selectedCategory = null;
                        _favOnly = false;
                        _applyFilters();
                      },
                      icon: const Icon(Icons.apps_rounded, size: 18),
                      label: const Text('Voir toutes les chaînes'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _load(forceRefresh: true),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Actualiser'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).popIn();
  }

  /// Nb de colonnes partagé (shimmer + grille) pour une transition douce.
  static int _gridCrossCount(double width) {
    if (width >= 1400) return 6;
    if (width >= 1100) return 5;
    if (width >= 800) return 4;
    if (width >= 560) return 3;
    return 2;
  }

  /// Ratio grille partagé (shimmer + grille) : les cartes portent désormais
  /// le bloc EPG (titre + barre + à suivre) + la pastille reprise, donc plus
  /// hautes que larges. Petit écran (≤ 3 colonnes) : cartes étroites →
  /// ratio bas pour absorber le pire cas (nom + EPG + sources + reprise).
  static double _gridAspect(double width) =>
      _gridCrossCount(width) <= 3 ? 0.62 : 0.72;

  /// Sélection "À la une / En ce moment" : chaînes généralistes d'abord,
  /// programmes EPG en cours en premier. Vide quand un filtre est actif
  /// (catégorie ou favoris) pour ne jamais masquer la grille filtrée.
  /// "Reprendre" en tête : les chaînes déjà regardées (historique local
  /// [IptvResume], plus récent d'abord) remontent devant, à EPG égal.
  /// Coûteux (~2 requêtes EPG / chaîne) → mémoïsé dans [_spotlight],
  /// recalculé via [_refreshSpotlight] (après load, filtre, arrivée EPG,
  /// changement d'historique).
  void _refreshSpotlight() {
    _spotlight = _computeSpotlight();
  }

  /// Tri "reprise d'abord" à EPG égal : stable, sans toucher à l'ordre API
  /// au sein de chaque groupe (reprises récentes → EPG en cours → reste).
  static List<FstvChannel> _resumeFirst(
    List<FstvChannel> withEpg,
    List<FstvChannel> without,
    IptvResume resume,
  ) {
    if (!resume.isLoaded) return [...withEpg, ...without];
    int rankOf(FstvChannel ch) => resume.wasWatched(ch.slug) ? 0 : 1;
    int seenOf(FstvChannel ch) =>
        resume.lastSeen(ch.slug)?.millisecondsSinceEpoch ?? 0;
    int byResume(FstvChannel a, FstvChannel b) {
      final r = rankOf(a).compareTo(rankOf(b));
      if (r != 0) return r;
      // Plus récent d'abord au sein du groupe "reprendre".
      if (rankOf(a) == 0) return seenOf(b).compareTo(seenOf(a));
      return 0; // ordre API conservé sinon (tri stable de Dart).
    }
    final w = List<FstvChannel>.of(withEpg)..sort(byResume);
    final wo = List<FstvChannel>.of(without)..sort(byResume);
    return [...w, ...wo];
  }

  List<FstvChannel> _computeSpotlight() {
    if (_selectedCategory != null || _favOnly || _flat.isEmpty) {
      return const [];
    }
    List<FstvChannel> pool = const [];
    for (final entry in _channelsByCategory.entries) {
      final k = entry.key.toLowerCase();
      if (k.contains('géné') ||
          k.contains('gene') ||
          k.contains('général') ||
          k.contains('general')) {
        pool = entry.value;
        break;
      }
    }
    final base = pool.isEmpty ? _flat : pool;
    final epg = EpgService.instance;
    final withEpg = <FstvChannel>[];
    final without = <FstvChannel>[];
    for (final ch in base) {
      final nn =
          epg.getNowAndNext(ch.slug) ?? epg.getNowAndNext(ch.name);
      if (nn != null) {
        withEpg.add(ch);
      } else {
        without.add(ch);
      }
    }
    // "Reprendre" en tête, à EPG égal (reprises récentes → en cours → reste).
    final ordered = _resumeFirst(withEpg, without, _resume);
    return ordered.take(10).toList(growable: false);
  }

  Widget _buildGrid() {
    final width = MediaQuery.of(context).size.width;
    final crossCount = _gridCrossCount(width);
    final isTVGrid = NeoTheme.isTV(context);
    final spotlight = _spotlight;
    return Column(
      children: [
        if (spotlight.isNotEmpty)
          _SpotlightSection(
            channels: spotlight,
            favIds: _favIds,
            onOpen: _showDetails,
            onLeftEdge: widget.onLeftEdge,
          ),
        Expanded(
          child: GridView.builder(
            controller: _scrollCtrl,
            // Espace libéré pour la barre de navigation flottante.
            padding: EdgeInsets.fromLTRB(
                20, spotlight.isNotEmpty ? 4 : 12, 20,
                NeoTheme.isTV(context) ? 40 : 140),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount,
              mainAxisSpacing: 22,
              crossAxisSpacing: 16,
              // Même gabarit que le shimmer (bloc EPG inclus).
              childAspectRatio: _gridAspect(width),
            ),
            itemCount: _filtered.length,
            itemBuilder: (context, index) {
              final ch = _filtered[index];
              final isLeftEdge = index % crossCount == 0; // Première colonne
              // Dernière colonne OU dernier élément (ligne incomplète) :
              // bord droit visuel, pas de voisin à droite.
              final isRightEdge = (index + 1) % crossCount == 0 ||
                  index == _filtered.length - 1;
              return RepaintBoundary(
                // Slugs dédupliqués côté proxy (fusion des doublons API) :
                // chaque slug n'a qu'une carte → clé stable et unique.
                child: _ChannelCard(
                  key: ValueKey('live_${ch.slug}'),
                  channel: ch,
                  onTap: () => _showDetails(ch),
                  isLeftEdge: isLeftEdge,
                  isRightEdge: isRightEdge,
                  onLeftEdge: widget.onLeftEdge,
                  isFavorite: _favIds.contains(ch.slug),
                  onToggleFavorite: () {
                    HapticFeedback.selectionClick();
                    _favs.toggle(ch.slug);
                  },
                  // Premier élément visible : autofocus (le 1er chip gagne
                  // en pratique car il précède dans l'ordre de traversal).
                  autofocus: isTVGrid && index == 0 && spotlight.isEmpty,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Header premium : badge LIVE, horloge, shimmer, spotlight ──────────────

/// Pastille "EN DIRECT" du header avec point pulsant.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Neo.errorRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Neo.radiusFull),
        border: Border.all(
          color: Neo.errorRed.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(size: 7),
          SizedBox(width: 6),
          Text(
            'EN DIRECT',
            style: TextStyle(
              color: Neo.errorRed,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Point rouge pulsant (badge LIVE, pastilles EPG).
class _PulsingDot extends StatefulWidget {
  final double size;

  const _PulsingDot({this.size = 7});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: 0.45 + 0.55 * _ctrl.value,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: const BoxDecoration(
            color: Neo.errorRed,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Horloge locale du header (HH:mm, refresh toutes les 20 s).
class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hh = _now.hour.toString().padLeft(2, '0');
    final mm = _now.minute.toString().padLeft(2, '0');
    // Compacte sur phone étroit (< 560 px) : même info, moins de padding.
    final compact = MediaQuery.of(context).size.width < 560;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Neo.bgElevated(context),
        borderRadius: BorderRadius.circular(Neo.radiusMd),
        border: Border.all(color: Neo.borderLight(context), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PulsingDot(size: 6),
          const SizedBox(width: 7),
          Text(
            '$hh:$mm',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 13 : null,
                ),
          ),
        ],
      ),
    );
  }
}

/// Bloc shimmer élémentaire (reflet animé, zéro dépendance).
class _ShimmerBlock extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBlock({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  State<_ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<_ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.2 + 2.4 * t, 0),
              end: Alignment(0.2 + 2.4 * t, 0),
              colors: [
                Neo.bgElevated(context),
                Neo.bgElevated(context).withValues(alpha: 0.45),
                Neo.bgElevated(context),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Carte chaîne factice pour le shimmer (même gabarit que la vraie carte :
/// logo + nom + catégorie + bloc EPG + sources).
class _ShimmerChannelCard extends StatelessWidget {
  const _ShimmerChannelCard();

  @override
  Widget build(BuildContext context) {
    return NeoGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Neo.radiusMd),
                ),
              ),
              const Spacer(),
              const _ShimmerBlock(width: 34, height: 34, radius: 17),
            ],
          ),
          const SizedBox(height: 14),
          const _ShimmerBlock(width: 130, height: 13, radius: 6),
          const SizedBox(height: 9),
          const _ShimmerBlock(width: 80, height: 10, radius: 5),
          const SizedBox(height: 8),
          const _ShimmerBlock(width: double.infinity, height: 5, radius: 3),
          const SizedBox(height: 6),
          const _ShimmerBlock(width: 110, height: 10, radius: 5),
          const SizedBox(height: 8),
          const Row(
            children: [
              _ShimmerBlock(width: 74, height: 22, radius: 11),
              SizedBox(width: 8),
              _ShimmerBlock(width: 56, height: 14, radius: 7),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section "À la une / En ce moment" ──────────────────────────────────────
// Rail horizontal simple au-dessus de la grille (visible uniquement sur
// "Toutes", sans filtre). Cartes focusables au D-pad avec le même langage
// visuel que le reste (bordure 3.5 + halo + scale). Gauche sur la 1re carte
// => retour navbar via onLeftEdge. Aucun impact sur le proxy ni le player.

class _SpotlightSection extends StatefulWidget {
  final List<FstvChannel> channels;
  final Set<String> favIds;
  final ValueChanged<FstvChannel> onOpen;
  final VoidCallback? onLeftEdge;

  const _SpotlightSection({
    required this.channels,
    required this.favIds,
    required this.onOpen,
    this.onLeftEdge,
  });

  @override
  State<_SpotlightSection> createState() => _SpotlightSectionState();
}

class _SpotlightSectionState extends State<_SpotlightSection> {
  // Pas de ensureLoaded() ici : le parent (_IptvScreenState) pré-chauffe le
  // guide une seule fois et fait un setState global à son arrivée (qui
  // reconstruit cette section). Un 2e appel ne ferait que doubler le rebuild.
  @override
  Widget build(BuildContext context) {
    final isTV = NeoTheme.isTV(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
          child: Row(
            children: [
              const _PulsingDot(size: 8),
              const SizedBox(width: 8),
              Text(
                'À la une · En ce moment',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: isTV ? 17 : null,
                    ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Neo.accentColor(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Neo.radiusFull),
                ),
                child: Text(
                  '${widget.channels.length}',
                  style: TextStyle(
                    color: Neo.accentColor(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          // +12 px vs avant : laisse la place à la ligne "À suivre".
          height: isTV ? 160 : 152,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            itemCount: widget.channels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final ch = widget.channels[i];
              return _SpotlightCard(
                key: ValueKey('spot_${ch.slug}'),
                channel: ch,
                isFirst: i == 0,
                isLast: i == widget.channels.length - 1,
                isFavorite: widget.favIds.contains(ch.slug),
                onOpen: () => widget.onOpen(ch),
                onLeftEdge: widget.onLeftEdge,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  final FstvChannel channel;
  final bool isFirst;
  final bool isLast;
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback? onLeftEdge;

  const _SpotlightCard({
    super.key,
    required this.channel,
    required this.isFirst,
    this.isLast = false,
    required this.isFavorite,
    required this.onOpen,
    this.onLeftEdge,
  });

  @override
  Widget build(BuildContext context) {
    final isTV = NeoTheme.isTV(context);
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (_isTvActivate(event.logicalKey)) {
            onOpen();
            return KeyEventResult.handled;
          }
          if (isTV &&
              event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              isFirst) {
            if (onLeftEdge != null) {
              onLeftEdge!();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          }
          // Navigation latérale explicite (B1) : Gauche/Droite vers la carte
          // voisine du rail, jamais de remontée en haut.
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            return _moveFocus(node, TraversalDirection.left);
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (isLast) return KeyEventResult.ignored;
            return _moveFocus(node, TraversalDirection.right);
          }
          // Haut/Bas : vers la rangée voisine (catégories/grille) quand
          // prévisible, sinon traversal.
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            return _moveFocus(node, TraversalDirection.up);
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            return _moveFocus(node, TraversalDirection.down);
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (ctx) {
          final isFocused = Focus.of(ctx).hasFocus;
          final tvFocused = isTV && isFocused;
          final focusColor = Neo.accentColor(context);
          // Lecture mémoire synchrone (zéro FutureBuilder par carte).
          final nn = _nowNextOf(channel);
          return AnimatedOpacity(
            opacity: isTV && !isFocused ? 0.62 : 1.0,
            duration: const Duration(milliseconds: 180),
            child: AnimatedScale(
              scale: tvFocused ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: isTV ? 320 : 284,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Neo.radiusLg),
                  border: Border.all(
                    color: tvFocused ? focusColor : Colors.transparent,
                    width: 3.5,
                  ),
                  boxShadow:
                      tvFocused ? _focusHalo(context, focusColor) : null,
                ),
                child: GestureDetector(
                  onTap: onOpen,
                  behavior: HitTestBehavior.opaque,
                  child: NeoGlassCard(
                    padding: const EdgeInsets.all(12),
                    accent: channel.categoryColor,
                    elevation: tvFocused ? 4 : 0,
                    child: Row(
                      children: [
                        _ChannelLogo(
                          channel: channel,
                          size: 64,
                          highlight: isFocused,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      channel.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  if (isFavorite)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Icon(
                                        Icons.favorite_rounded,
                                        color: Neo.accentColor(context),
                                        size: 15,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Reprise phone dans le spotlight : même
                              // pastille que les cartes (TV inchangée).
                              if (!isTV &&
                                  IptvResume.instance
                                      .wasWatched(channel.slug))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: _ResumePill(
                                    seen: IptvResume.instance
                                        .lastSeen(channel.slug),
                                  ),
                                ),
                              if (nn != null) ...[
                                Text(
                                  nn.now.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Neo.textSecondary(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: nn.now
                                        .progressAt(DateTime.now())
                                        .clamp(0.0, 1.0),
                                    minHeight: 4,
                                    backgroundColor: Neo.errorRed
                                        .withValues(alpha: 0.15),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Neo.errorRed),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  nn.now.rangeLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Neo.textTertiary(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                if (nn.next != null)
                                  Text(
                                    'À suivre · ${nn.next!.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Neo.textTertiary(context),
                                          fontWeight: FontWeight.w500,
                                          fontStyle: FontStyle.italic,
                                        ),
                                  ),
                              ] else ...[
                                Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: Neo.successGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'DIRECT',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Neo.successGreen,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6,
                                          ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        channel.category,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: channel.categoryColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: channel.categoryColor
                                .withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: channel.categoryColor,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Carte de chaîne ────────────────────────────────────────────────────────

class _ChannelCard extends StatefulWidget {
  final FstvChannel channel;
  final VoidCallback onTap;
  final bool isLeftEdge;
  final bool isRightEdge;
  final VoidCallback? onLeftEdge;
  final bool autofocus;

  /// État favori (cœur affiché) — persisté via IptvFavorites.
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const _ChannelCard({
    super.key,
    required this.channel,
    required this.onTap,
    required this.isLeftEdge,
    this.isRightEdge = false,
    this.onLeftEdge,
    this.autofocus = false,
    this.isFavorite = false,
    required this.onToggleFavorite,
  });

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;
    final isTV = NeoTheme.isTV(context);
    return Focus(
      autofocus: widget.autofocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (_isTvActivate(event.logicalKey)) {
            widget.onTap();
            return KeyEventResult.handled;
          }

          // Touche dédiée TV : Menu / Info / touche Y (gamepad + clavier) /
          // touche F sur carte focusée => bascule le favori (la carte reste
          // le seul élément focusable, pas de sous-bouton au D-pad).
          if (_isFavKey(event.logicalKey)) {
            widget.onToggleFavorite();
            return KeyEventResult.handled;
          }

          if (isTV) {
            // Bord gauche : retour navbar via callback (voie principale).
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                widget.isLeftEdge) {
              if (widget.onLeftEdge != null) {
                widget.onLeftEdge!();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored; // filet : handler shell
            }
            // Gauche/Droite explicites (B1) : vers la carte voisine, jamais
            // de remontée en haut via le traversal géométrique.
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              return _moveFocus(node, TraversalDirection.left);
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              if (widget.isRightEdge) return KeyEventResult.ignored;
              return _moveFocus(node, TraversalDirection.right);
            }
            // Haut/Bas : vers la carte de la rangée voisine quand prévisible
            // (première ligne → spotlight/catégories), sinon traversal.
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              return _moveFocus(node, TraversalDirection.up);
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              return _moveFocus(node, TraversalDirection.down);
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (ctx) {
          // Visuel piloté par l'état Focus (D-pad TV), pas par le hover :
          // sur TV le hover tactile/desktop est ignoré pour le focus visuel.
          final isFocused = Focus.of(ctx).hasFocus;
          final tvFocused = isTV && isFocused;
          final focusColor = Neo.accentColor(context);
          // Lecture EPG mémoire synchrone (guide pré-chargé par le parent) :
          // aucun FutureBuilder / ensureLoaded par carte.
          final nn = _nowNextOf(ch);
          return AnimatedOpacity(
            // Carte non-focusée assombrie sur TV : contraste à 3 m.
            opacity: isTV && !isFocused ? 0.6 : 1.0,
            duration: const Duration(milliseconds: 180),
            child: AnimatedScale(
              scale: tvFocused ? 1.07 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Neo.radiusLg),
                      // Bordure épaisse conservant sa largeur (transparente au
                      // repos) pour éviter tout saut de layout au focus.
                      border: Border.all(
                        color: tvFocused ? focusColor : Colors.transparent,
                        width: 3.5,
                      ),
                      boxShadow: tvFocused
                          ? [
                              ..._focusHalo(context, focusColor),
                              BoxShadow(
                                color: focusColor.withValues(alpha: 0.25),
                                blurRadius: 56,
                                spreadRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _hovered = true),
                      onExit: (_) => setState(() => _hovered = false),
                      child: GestureDetector(
                        onTap: widget.onTap,
                        // Appui long (mobile + TV) => bascule le favori.
                        onLongPress: widget.onToggleFavorite,
                        child: NeoGlassCard(
                          padding: const EdgeInsets.all(14),
                          accent: ch.categoryColor,
                          elevation:
                              (isTV ? isFocused : (_hovered || isFocused))
                                  ? 4
                                  : 0,
                          // Vraie carte chaîne TV : logo grand, nom, catégorie,
                          // pastille favori, indicateur nb sources.
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Logo grand (72) avec fallback initiale.
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      _ChannelLogo(
                                        channel: ch,
                                        size: 72,
                                        highlight: _hovered || isFocused,
                                      ),
                                      // Pastille lecture survol/focus : icône +
                                      // anneau lisibles sur la couleur de
                                      // catégorie (jamais blanc sur jaune/vert
                                      // clair).
                                      if (_hovered || isFocused)
                                        Positioned(
                                          right: -4,
                                          bottom: -4,
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: ch.categoryColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Neo.readableOn(
                                                    ch.categoryColor),
                                                width: 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: ch.categoryColor
                                                      .withValues(alpha: 0.5),
                                                  blurRadius: 10,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.play_arrow_rounded,
                                              color: Neo.readableOn(
                                                  ch.categoryColor),
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const Spacer(),
                                  // Pastille favori (indicateur, pas de focus
                                  // D-pad : le D-pad ne s'y arrête jamais).
                                  GestureDetector(
                                    onTap: widget.onToggleFavorite,
                                    behavior: HitTestBehavior.opaque,
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: widget.isFavorite
                                            ? focusColor
                                                .withValues(alpha: 0.16)
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: widget.isFavorite
                                              ? focusColor
                                              : Neo.textTertiary(context)
                                                  .withValues(alpha: 0.35),
                                          width: widget.isFavorite ? 1.6 : 1.2,
                                        ),
                                      ),
                                      child: Icon(
                                        widget.isFavorite
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color: widget.isFavorite
                                            ? focusColor
                                            : Neo.textTertiary(context)
                                                .withValues(
                                                    alpha:
                                                        (_hovered || isFocused)
                                                            ? 0.9
                                                            : 0.5),
                                        size: 18,
                                        semanticLabel: widget.isFavorite
                                            ? 'Retirer des favoris'
                                            : 'Ajouter aux favoris',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                ch.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              // Catégorie : pastille couleur + libellé.
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: ch.categoryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      ch.category,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: ch.categoryColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Programme en cours : titre + barre temporelle
                              // (début/fin EPG) + "à suivre" — ou pastille
                              // DIRECT simple sans EPG (voir widget dédié).
                              _ChannelEpgProgress(nowNext: nn),
                              const SizedBox(height: 8),
                              // Indicateur nb sources (les chaînes KO amont,
                              // 0 source, restent listées : le popup gère
                              // l'échec avec un état dédié, jamais caché).
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Neo.bgElevated(context),
                                      borderRadius:
                                          BorderRadius.circular(Neo.radiusFull),
                                      border: Border.all(
                                        color: Neo.borderLight(context),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.dns_rounded,
                                          size: 12,
                                          color: Neo.textSecondary(context),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${ch.sources.length} source${ch.sources.length > 1 ? 's' : ''}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color:
                                                    Neo.textSecondary(context),
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // Reprise phone : pastille "Reprendre · il y a X"
                              // (direct = pas de timeline, juste la récence).
                              // TV inchangée (focus D-pad uniquement).
                              if (!isTV &&
                                  IptvResume.instance.wasWatched(ch.slug))
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: _ResumePill(
                                    seen: IptvResume.instance
                                        .lastSeen(ch.slug),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
            ),
          );
        },
      ),
    );
  }
}

// ── Lecture EPG mémoire partagée (grille + spotlight + cartes) ────────────
// Un seul point d'accès synchrone : slug d'abord, nom en repli (le mapping
// se fait par nom normalisé côté EpgService, avec cache de résolution).
// AUCUN FutureBuilder / ensureLoaded par carte : le parent pré-chauffe le
// guide une fois et rebuild globalement à son arrivée.
EpgNowNext? _nowNextOf(FstvChannel channel) {
  final epg = EpgService.instance;
  return epg.getNowAndNext(channel.slug) ?? epg.getNowAndNext(channel.name);
}

// ── Bloc EPG inline des cartes grille ──────────────────────────────────────
// Affiche où en est le programme : titre en cours + barre de progression
// temporelle (début/fin EPG) + "à suivre" si dispo — le tout sur UNE ligne
// méta (horaires + suivant tronqués, ellipsis) pour tenir dans la carte.
// Sans EPG (chaîne inconnue du guide, trou de grille, guide en panne) :
// pastille DIRECT simple. Display-only, jamais focusable au D-pad.
class _ChannelEpgProgress extends StatelessWidget {
  final EpgNowNext? nowNext;

  const _ChannelEpgProgress({required this.nowNext});

  @override
  Widget build(BuildContext context) {
    final nn = nowNext;
    if (nn == null) {
      return Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Neo.successGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'DIRECT',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Neo.successGreen,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
          ),
        ],
      );
    }
    final meta = nn.next == null
        ? nn.now.rangeLabel
        : '${nn.now.rangeLabel} · À suivre : ${nn.next!.title}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          nn.now.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Neo.textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: nn.now.progressAt(DateTime.now()).clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: Neo.errorRed.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(Neo.errorRed),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Neo.textTertiary(context),
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

// ── Pastille "Reprendre" phone (direct = récence, pas de timeline) ───────
// Affichée uniquement côté phone (isTV == false) quand la chaîne a déjà été
// ouverte (historique local IptvResume). TV inchangée.
class _ResumePill extends StatelessWidget {
  final DateTime? seen;

  const _ResumePill({required this.seen});

  @override
  Widget build(BuildContext context) {
    final label = seen == null
        ? 'Reprendre'
        : 'Reprendre · ${IptvResume.relativeLabel(seen!)}';
    // Bleu assombri en thème clair (le cyan clair est illisible sur fond
    // clair) ; cyan d'origine en thème sombre.
    final pill = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF0369A1)
        : Neo.infoCyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: pill.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Neo.radiusFull),
        border: Border.all(
          color: pill.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_rounded,
            size: 12,
            color: pill,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: pill,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Logo de chaîne (grand, avec fallback initiale) ────────────────────────

class _ChannelLogo extends StatelessWidget {
  final FstvChannel channel;
  final double size;
  final bool highlight;

  const _ChannelLogo({
    required this.channel,
    this.size = 72,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final logo = (channel.logo ?? '').trim();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Neo.radiusMd),
        border: Border.all(
          color: highlight
              ? channel.categoryColor
              : channel.categoryColor.withValues(alpha: 0.3),
          width: highlight ? 2 : 1,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: channel.categoryColor.withValues(alpha: 0.35),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      // Logos cachés mémoire + disque (avant : Image.network → chaque
      // scroll/rebuild retéléchargeait les ~135 logos, jank + data).
      // memCache dimensionné au rendu (retina ×2 max), disque plafonné à
      // 256 px (les logos fstv.rest sont bien plus gros — inutile d'en
      // garder plus pour un affichage 64-76 px) : limite la pression
      // mémoire + le rate-limit amont. useOldImageOnUrlChange évite le
      // flash / re-fetch quand la carte rebuild (scroll, focus TV).
      // GridView.builder ne construit que les cartes visibles (~10-12,
      // jamais les 135 d'un coup) : pas de rafale simultanée. Pas de Key
      // sur ce widget : une clé instable casserait le cache au scroll.
      child: logo.isEmpty
          ? _logoFallback(channel, size)
          : CachedNetworkImage(
              imageUrl: logo,
              width: size,
              height: size,
              memCacheWidth: (size * 2).toInt(),
              memCacheHeight: (size * 2).toInt(),
              maxWidthDiskCache: 256,
              maxHeightDiskCache: 256,
              useOldImageOnUrlChange: true,
              fit: BoxFit.contain,
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (_, __) => _logoFallback(channel, size),
              errorWidget: (_, __, ___) => _logoFallback(channel, size),
            ),
    );
  }

  /// Fallback initiale (logo absent / en chargement / en erreur).
  static Widget _logoFallback(FstvChannel channel, double size) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            channel.categoryColor.withValues(alpha: 0.22),
            channel.categoryColor.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Center(
        child: Text(
          channel.initial,
          style: TextStyle(
            color: channel.categoryColor,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.42,
          ),
        ),
      ),
    );
  }
}

// ── Popup détails d'une chaîne ─────────────────────────────────────────────
// Dialog adaptatif : centré sur TV, bottom-sheet sur mobile. Navigable au
// D-pad : FocusTraversalGroup ordonné (Lancer en autofocus, puis sources),
// Esc / Retour / Back ferme.

class _ChannelDetailsDialog extends StatefulWidget {
  final FstvChannel channel;
  final List<({String url, String displayName})> entries;
  final VoidCallback onPlayBest;
  final ValueChanged<String> onPlaySource;

  /// État favori initial + bascule (B8) : le dialog expose une ligne
  /// "Favori" focusable au D-pad (jamais de popup sans action favori).
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const _ChannelDetailsDialog({
    required this.channel,
    required this.entries,
    required this.onPlayBest,
    required this.onPlaySource,
    this.isFavorite = false,
    required this.onToggleFavorite,
  });

  @override
  State<_ChannelDetailsDialog> createState() => _ChannelDetailsDialogState();
}

class _ChannelDetailsDialogState extends State<_ChannelDetailsDialog> {
  bool _epgReady = false;

  /// Scroll interne de la zone sources (la seule zone scrollable du popup :
  /// l'en-tête + EPG + "Lancer" restent fixes et toujours visibles).
  late final ScrollController _sourcesCtrl = ScrollController();

  /// Ordre D-pad explicite : Lancer (ordre 0), Favori (ordre 1), puis
  /// sources (2..N+1). Nœuds possédés par le dialog (disposés ici) pour une
  /// navigation Up/Down fiable même quand la liste est scrollée.
  final FocusNode _lancerNode = FocusNode(debugLabel: 'details_lancer');
  final FocusNode _favNode = FocusNode(debugLabel: 'details_fav');
  late final List<FocusNode> _sourceNodes = List.generate(
    widget.entries.length,
    (i) => FocusNode(debugLabel: 'details_source_$i'),
  );

  /// Bouton Fermer : ne devient focusable qu'en cas 0 source (B7) — quand
  /// "Lancer" est exclu, le focus va sur Fermer (jamais 0 stop au D-pad).
  /// Nœud possédé par le dialog (disposé ici).
  final FocusNode _closeNode = FocusNode(debugLabel: 'details_close');

  @override
  void dispose() {
    IptvFavorites.instance.removeListener(_onFavsChanged);
    _sourcesCtrl.dispose();
    _lancerNode.dispose();
    _favNode.dispose();
    _closeNode.dispose();
    for (final n in _sourceNodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// Le parent ne rebuild pas le dialog quand les favoris changent (popup
  /// déjà ouvert) : écoute directe pour garder la ligne Favori à jour.
  void _onFavsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    IptvFavorites.instance.addListener(_onFavsChanged);
    // Le guide a été pré-chargé à l'ouverture de l'onglet (single-flight,
    // cache 12 h : cet appel est gratuit quand le guide est déjà là).
    // Court-circuit synchrone : pas de spinner si déjà prêt.
    if (EpgService.instance.isLoaded) {
      _epgReady = true;
      return;
    }
    EpgService.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _epgReady = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTV = NeoTheme.isTV(context);
    final width = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final dialogWidth = isTV ? 560.0 : (width >= 600 ? 520.0 : width);
    // Focus racine NON focusable et hors traversal : il ne fait que
    // intercepter Esc/Retour (bubblé depuis le descendant focusé). Avant,
    // `autofocus: true` ici volait le focus au bouton "Lancer" et rendait
    // les sources inatteignables au D-pad.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack ||
            event.logicalKey == LogicalKeyboardKey.browserBack) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        insetPadding: isTV
            ? const EdgeInsets.symmetric(horizontal: 48, vertical: 24)
            : EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: 12,
                top: MediaQuery.of(context).size.height * 0.12,
              ),
        alignment: isTV ? Alignment.center : Alignment.bottomCenter,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Neo.radiusLg),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogWidth,
            // Jamais plus de 85 % de l'écran TV : le popup ne dépasse plus.
            maxHeight: screenH * (isTV ? 0.85 : 0.88),
          ),
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // En-tête : logo + nom + catégorie + nb sources.
                  // Logo réduit sur TV (64 vs 76) : gagne ~12 px verticaux
                  // pour laisser "Lancer" + 2-3 sources visibles sans scroll.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _ChannelLogo(
                          channel: widget.channel, size: isTV ? 64 : 76),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.channel.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: widget.channel.categoryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    widget.channel.category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: widget.channel.categoryColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.entries.length} source${widget.entries.length > 1 ? 's' : ''} disponible${widget.entries.length > 1 ? 's' : ''}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).hintColor,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      // Croix exclue du traversal D-pad sur TV quand "Lancer"
                      // est présent (Esc/Retour ferme déjà) : évite un arrêt
                      // focus fantôme avant "Lancer". Cas 0 source (B7) :
                      // "Lancer" est exclu → la croix devient focusable
                      // (autofocus, ordre 0) pour ne jamais laisser 0 stop
                      // au D-pad. Tactile/phone inchangé.
                      if (isTV && widget.entries.isNotEmpty)
                        ExcludeFocus(
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Fermer',
                          ),
                        )
                      else if (isTV)
                        FocusTraversalOrder(
                          order: const NumericFocusOrder(0),
                          child: Focus(
                            focusNode: _closeNode,
                            autofocus: true,
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent) {
                                if (_isTvActivate(event.logicalKey)) {
                                  Navigator.of(context).pop();
                                  return KeyEventResult.handled;
                                }
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowDown) {
                                  FocusScope.of(node.context!).nextFocus();
                                  return KeyEventResult.handled;
                                }
                              }
                              return KeyEventResult.ignored;
                            },
                            child: Builder(
                              builder: (ctx) {
                                final focused = Focus.of(ctx).hasFocus;
                                final focusColor =
                                    Neo.accentColor(context);
                                final focusFg =
                                    Neo.readableOn(focusColor);
                                return GestureDetector(
                                  onTap: () =>
                                      Navigator.of(context).pop(),
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: focused
                                          ? focusColor
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: focused
                                            ? focusFg
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                      boxShadow: focused
                                          ? _focusHalo(context, focusColor)
                                          : null,
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: focused
                                          ? focusFg
                                          : Theme.of(context).iconTheme.color,
                                      semanticLabel: 'Fermer',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      else
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Fermer',
                        ),
                    ],
                  ),
                  SizedBox(height: isTV ? 10 : 14),
                  // Reprise phone : rappel "dernière vue il y a X" au-dessus
                  // du CTA (TV inchangée : pas de bandeau).
                  if (!isTV &&
                      IptvResume.instance.wasWatched(widget.channel.slug))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ResumePill(
                        seen: IptvResume.instance
                            .lastSeen(widget.channel.slug),
                      ),
                    ),
                  // Section EPG "Maintenant / À suivre" (display-only,
                  // jamais focusable au D-pad : ExcludeFocus garantit que le
                  // traversal Lancer(0) -> Favori(1) -> sources(2..N+1)
                  // n'est pas pollué).
                  ExcludeFocus(child: _buildEpgSection()),
                  SizedBox(height: isTV ? 10 : 14),
                  // CTA principal : autofocus D-pad, 1er dans l'ordre.
                  // Sans source, bouton désactivé (jamais d'ouverture du
                  // player vers une erreur certaine) + exclu du focus D-pad
                  // (B7 : le focus va alors sur Fermer, ordre 0).
                  if (widget.entries.isEmpty)
                    const ExcludeFocus(
                      child: _DialogDisabledButton(),
                    )
                  else
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(0),
                      child: _DialogPrimaryButton(
                        autofocus: true,
                        focusNode: _lancerNode,
                        onActivated: widget.onPlayBest,
                        onToggleFavorite: widget.onToggleFavorite,
                        // Retour focus depuis la 1re source : remonte la
                        // liste en haut pour que "Lancer" redevienne visible.
                        onFocused: () {
                          if (_sourcesCtrl.hasClients) {
                            _sourcesCtrl.animateTo(
                              0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                        // Phone : "Reprendre le direct" si déjà regardée,
                        // sinon "Lancer le direct" (TV : toujours Lancer).
                        label: !isTV &&
                                IptvResume.instance
                                    .wasWatched(widget.channel.slug)
                            ? 'Reprendre le direct'
                            : 'Lancer le direct',
                      ),
                    ),
                  const SizedBox(height: 10),
                  // Ligne Favori (B8) : focusable au D-pad (ordre 1, entre
                  // "Lancer" et les sources), synchronisée en direct via
                  // l'écoute IptvFavorites (le popup reste ouvert).
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: _DialogFavoriteRow(
                      isFavorite: IptvFavorites.instance
                          .isFavorite(widget.channel.slug),
                      focusNode: _favNode,
                      onToggle: widget.onToggleFavorite,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Choisir une source',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: widget.entries.isEmpty
                        ? Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              // Chaînes KO amont (0 source) : restent listées,
                              // échec expliqué proprement au lieu d'un player
                              // qui s'ouvrirait sur une erreur certaine
                              // (le CTA "Lancer" est désactivé ci-dessus).
                              'Aucune source disponible pour cette chaîne '
                              '(panne amont transitoire possible — '
                              'réessayez plus tard).',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          )
                        : Scrollbar(
                            controller: _sourcesCtrl,
                            thumbVisibility: false,
                            child: SingleChildScrollView(
                              controller: _sourcesCtrl,
                              // Scroll interne contraint par le Flexible :
                              // l'en-tête + "Lancer" restent fixes, seules
                              // les sources défilent. Jamais de dépassement
                              // d'écran (dialog plafonné à 85 % côté parent).
                              padding: const EdgeInsets.only(
                                right: 2,
                                bottom: 4,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0;
                                      i < widget.entries.length;
                                      i++) ...[
                                    FocusTraversalOrder(
                                      // Ordre D-pad : après Lancer (0) et
                                      // Favori (1), sources 2..N+1.
                                      order: NumericFocusOrder(i + 2),
                                      child: _SourceRow(
                                        index: i,
                                        displayName:
                                            widget.entries[i].displayName,
                                        focusNode: _sourceNodes[i],
                                        onActivated: () => widget.onPlaySource(
                                            widget.entries[i].url),
                                        onToggleFavorite:
                                            widget.onToggleFavorite,
                                      ),
                                    ),
                                    if (i < widget.entries.length - 1)
                                      const SizedBox(height: 8),
                                  ],
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Section "Maintenant / À suivre" du guide TV (display-only, jamais
  /// focusable au D-pad). Silencieuse en cas d'échec : le direct reste
  /// utilisable sans le guide.
  Widget _buildEpgSection() {
    final channel = widget.channel;
    if (!_epgReady) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'Chargement du guide…',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
          ),
        ],
      );
    }
    final nn = _nowNextOf(channel);
    if (nn == null) {
      return Text(
        'Guide TV non disponible pour cette chaîne.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).hintColor,
              fontStyle: FontStyle.italic,
            ),
      );
    }
    final at = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 15,
              color: Neo.textSecondary(context),
            ),
            const SizedBox(width: 6),
            Text(
              'Programme TV',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if ((nn.now.category ?? '').isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Neo.bgElevated(context),
                  borderRadius: BorderRadius.circular(Neo.radiusFull),
                  border: Border.all(
                    color: Neo.borderLight(context),
                    width: 1,
                  ),
                ),
                child: Text(
                  nn.now.category!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Neo.textSecondary(context),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        _EpgProgramRow(
          live: true,
          program: nn.now,
          progress: nn.now.progressAt(at),
        ),
        if (nn.next != null) ...[
          const SizedBox(height: 8),
          _EpgProgramRow(live: false, program: nn.next!),
        ],
      ],
    );
  }
}

// ── Ligne programme EPG du popup ───────────────────────────────────────────
// Display-only (pas de focus D-pad) : titre + horaires + barre de progression
// pour le direct en cours, présentation compacte pour le programme suivant.
class _EpgProgramRow extends StatelessWidget {
  final bool live;
  final EpgProgram program;
  final double progress;

  const _EpgProgramRow({
    required this.live,
    required this.program,
    this.progress = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: live
            ? Neo.errorRed.withValues(alpha: 0.08)
            : Neo.bgElevated(context),
        borderRadius: BorderRadius.circular(Neo.radiusMd),
        border: Border.all(
          color: live
              ? Neo.errorRed.withValues(alpha: 0.4)
              : Neo.borderLight(context),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: live ? Neo.errorRed : Neo.textTertiary(context),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                live ? 'EN COURS' : 'À SUIVRE · ${program.rangeLabel}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: live ? Neo.errorRed : Neo.textSecondary(context),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
              ),
              if (live) ...[
                const Spacer(),
                Text(
                  program.rangeLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Neo.textSecondary(context),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Text(
            program.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if ((program.subTitle ?? '').isNotEmpty)
            Text(
              program.subTitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Neo.textSecondary(context),
                  ),
            ),
          if (live) ...[
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: Neo.errorRed.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(Neo.errorRed),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bouton "Lancer le direct" du popup : focus TV très visible.
/// Ordre traversal 0 (côté appelant), autofocus D-pad. Down descend vers la
/// ligne Favori via l'ordre de traversal ; l'activation (OK/Enter/Espace)
/// appelle [onPlayBest] (meilleure source rankée — proxy iptv.mine.bz).
/// Menu / Info / Y / F bascule le favori ([onToggleFavorite], B8).
class _DialogPrimaryButton extends StatelessWidget {
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback onActivated;
  final VoidCallback? onFocused;
  final VoidCallback? onToggleFavorite;
  final String label;

  const _DialogPrimaryButton({
    required this.autofocus,
    required this.onActivated,
    this.focusNode,
    this.onFocused,
    this.onToggleFavorite,
    this.label = 'Lancer le direct',
  });

  @override
  Widget build(BuildContext context) {
    final isTV = NeoTheme.isTV(context);
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      onFocusChange: (hasFocus) {
        if (hasFocus) onFocused?.call();
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (_isTvActivate(event.logicalKey)) {
            onActivated();
            return KeyEventResult.handled;
          }
          // Favori depuis "Lancer" (B8) : Menu / Info / Y / F.
          if (_isFavKey(event.logicalKey)) {
            onToggleFavorite?.call();
            return KeyEventResult.handled;
          }
          // Down D-pad : descend vers la ligne Favori (ordre traversal 1)
          // même si la liste est scrollée (le voisinage directionnel seul
          // pouvait rater la cible dans le scroll interne).
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            FocusScope.of(node.context!).nextFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (ctx) {
          final isFocused = Focus.of(ctx).hasFocus;
          final tvFocused = isTV && isFocused;
          final focusColor = Neo.accentColor(context);
          return AnimatedScale(
            scale: tvFocused ? 1.04 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Neo.radiusMd),
                border: Border.all(
                  color: tvFocused ? focusColor : Colors.transparent,
                  width: 3.5,
                ),
                boxShadow: tvFocused
                    ? _focusHalo(context, focusColor)
                    : null,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onActivated,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(Neo.radiusMd - 3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        color: Neo.readableOnPrimary(context),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: Neo.readableOnPrimary(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bouton "Lancer le direct" désactivé (0 source) : même gabarit, grisé,
/// non focusable au D-pad (ExcludeFocus côté appelant).
class _DialogDisabledButton extends StatelessWidget {
  const _DialogDisabledButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Neo.bgElevated(context),
        borderRadius: BorderRadius.circular(Neo.radiusMd),
        border: Border.all(color: Neo.borderLight(context), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: Neo.textTertiary(context),
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            'Aucune source disponible',
            style: TextStyle(
              color: Neo.textSecondary(context),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne "Favori" du popup (B8) : focusable au D-pad (ordre 1, entre
/// "Lancer" et les sources), même langage visuel que les lignes source.
/// OK/Enter/Espace ou Menu / Info / Y / F bascule le favori ; Up remonte à
/// "Lancer", Down descend vers la 1re source.
class _DialogFavoriteRow extends StatelessWidget {
  final bool isFavorite;
  final FocusNode? focusNode;
  final VoidCallback onToggle;

  const _DialogFavoriteRow({
    required this.isFavorite,
    required this.onToggle,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final isTV = NeoTheme.isTV(context);
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (_isTvActivate(event.logicalKey) ||
              _isFavKey(event.logicalKey)) {
            onToggle();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            FocusScope.of(node.context!).previousFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            FocusScope.of(node.context!).nextFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (ctx) {
          final isFocused = Focus.of(ctx).hasFocus;
          final tvFocused = isTV && isFocused;
          final focusColor = Neo.accentColor(context);
          final focusFg = Neo.readableOn(focusColor);
          return AnimatedScale(
            scale: tvFocused ? 1.03 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: tvFocused ? focusColor : Neo.bgElevated(context),
                borderRadius: BorderRadius.circular(Neo.radiusMd),
                border: Border.all(
                  color: tvFocused ? focusFg : Neo.borderLight(context),
                  width: tvFocused ? 3.5 : 1.2,
                ),
                boxShadow:
                    tvFocused ? _focusHalo(context, focusColor) : null,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: tvFocused
                              ? focusFg.withValues(alpha: 0.25)
                              : focusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Center(
                          child: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: tvFocused
                                ? focusFg
                                : focusColor,
                            size: 17,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isFavorite
                              ? 'Retirer des favoris'
                              : 'Ajouter aux favoris',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: tvFocused
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: tvFocused ? focusFg : null,
                                  ),
                        ),
                      ),
                      Icon(
                        isFavorite
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        color: tvFocused ? focusFg : Neo.textTertiary(context),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Ligne source du popup : nom = label API si non vide, sinon "Source N".
/// Focusable / cliquable au D-pad pour lancer directement cette source
/// ([onPlaySource] côté appelant : le player démarre sur l'URL imposée).
/// Visuel focus fort : bordure 3.5 + halo [_focusHalo], fond opaque +
/// texte [Neo.readableOn] (jamais blanc sur blanc).
class _SourceRow extends StatelessWidget {
  final int index;
  final String displayName;
  final FocusNode? focusNode;
  final VoidCallback onActivated;

  /// Bascule favori (B8) : Menu / Info / Y / F depuis une source focusée.
  final VoidCallback? onToggleFavorite;

  const _SourceRow({
    required this.index,
    required this.displayName,
    required this.onActivated,
    this.focusNode,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final isTV = NeoTheme.isTV(context);
    return Focus(
      focusNode: focusNode,
      onFocusChange: (hasFocus) {
        // Auto-scroll : la ligne focusée au D-pad reste visible dans le
        // scroll interne (avant : le focus descendait hors champ, les
        // sources devenaient inaccessibles/invisibles).
        if (hasFocus) {
          final ctx = focusNode?.context;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              alignment: 0.5,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
            );
          }
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (_isTvActivate(event.logicalKey)) {
            onActivated();
            return KeyEventResult.handled;
          }
          // Favori depuis une source (B8) : Menu / Info / Y / F.
          if (_isFavKey(event.logicalKey)) {
            onToggleFavorite?.call();
            return KeyEventResult.handled;
          }
          // Up depuis la 1re source -> remonte à la ligne Favori (ordre 1)
          // via l'ordre de traversal (fiable même avec le scroll interne).
          // Up/Down entre sources = précédent/suivant de l'ordre 2..N+1.
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            FocusScope.of(node.context!).previousFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            FocusScope.of(node.context!).nextFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (ctx) {
          final isFocused = Focus.of(ctx).hasFocus;
          final tvFocused = isTV && isFocused;
          final focusColor = Neo.accentColor(context);
          // Focus TV : fond opaque + contenu lisible (jamais blanc sur
          // blanc : texte sombre sur accent clair, texte blanc sur accent
          // sombre).
          final focusFg = Neo.readableOn(focusColor);
          return AnimatedScale(
            scale: tvFocused ? 1.03 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: tvFocused ? focusColor : Neo.bgElevated(context),
                borderRadius: BorderRadius.circular(Neo.radiusMd),
                border: Border.all(
                  color: tvFocused ? focusFg : Neo.borderLight(context),
                  width: tvFocused ? 3.5 : 1.2,
                ),
                boxShadow:
                    tvFocused ? _focusHalo(context, focusColor) : null,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(Neo.radiusMd),
                canRequestFocus: false,
                onTap: onActivated,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: tvFocused
                              ? focusFg.withValues(alpha: 0.25)
                              : Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: tvFocused
                                  ? focusFg
                                  : Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: tvFocused
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: tvFocused ? focusFg : null,
                                  ),
                        ),
                      ),
                      Icon(
                        Icons.play_circle_fill_rounded,
                        color: tvFocused ? focusFg : Neo.textTertiary(context),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Lecteur TV en direct ───────────────────────────────────────────────────
//
// Sur Android / Freebox Mini 4K : lance NativeVideoActivity (ExoPlayer HLS).
//   - Toutes les sources passées d'un coup
//   - 1 seule tentative par source (bascule in-Activity, pas d'écran noir)
// Sur Desktop : media_kit, 1 try par source puis bascule Flutter

class _LivePlayerScreen extends StatefulWidget {
  final FstvChannel channel;

  /// Source imposée par le popup détails : le player démarre sur cette URL
  /// (puis bascule sur les suivantes en cas d'échec). Null = meilleure
  /// source rankée (comportement historique).
  final String? initialSourceUrl;

  const _LivePlayerScreen({required this.channel, this.initialSourceUrl});

  @override
  State<_LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends State<_LivePlayerScreen> {
  final _proxy = FstvProxyService.instance;
  final _favs = IptvFavorites.instance;
  bool _isFav = false;
  UniversalPlayerController? _universalController;
  bool _loading = true;
  String? _error;
  bool _showControls = true;
  Timer? _hideTimer;

  /// Desktop only : index source courante (Android bascule en natif).
  int _desktopSourceIndex = 0;

  /// Essais déjà effectués sur la source desktop courante (retry transitoire).
  int _desktopSourceAttempts = 0;

  /// Max 2 essais par source desktop sur erreur transitoire (502 amont…).
  static const int _maxDesktopAttemptsPerSource = 2;
  int _openGeneration = 0;
  bool _userClosedNative = false;
  bool _isSwitching = false;
  bool _didRefreshRetry = false;
  List<String> _streamUrls = const [];

  /// URLs (trimées) déjà prouvées mortes pendant cette session de lecture :
  /// abandonnées via [_nextDesktopSource]. Sert après refresh à ne jamais
  /// rejouer une source KO (dont l'imposée). Vidé à chaque [_openStream].
  final Set<String> _deadSources = <String>{};

  /// Nœuds focus D-pad du player (B10/B11) : overlay Retour/Favori +
  /// erreur Réessayer/Retour. Possédés ici, disposés dans [dispose].
  /// Jamais co-visibles (overlay XOR erreur) : ordres 0/1 réutilisés.
  final FocusNode _backNode = FocusNode(debugLabel: 'live_back');
  final FocusNode _favNode = FocusNode(debugLabel: 'live_fav');
  final FocusNode _retryNode = FocusNode(debugLabel: 'live_retry');
  final FocusNode _errorBackNode = FocusNode(debugLabel: 'live_error_back');

  StreamSubscription<String>? _errorSub;

  bool get _useNativeAndroid => !kIsWeb && Platform.isAndroid;

  /// Overlay haut (Retour/Favori) affiché : même condition que le build.
  bool get _overlayVisible =>
      !_useNativeAndroid && _showControls && _error == null && !_loading;

  /// Anneau de focus TV sur fond noir du player (overlay + erreur) :
  /// bordure blanche épaisse + halo, visible à 3 m.
  static Decoration? _playerFocusRing(bool focused) => focused
      ? BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
                color: Colors.white54, blurRadius: 16, spreadRadius: 2),
          ],
        )
      : null;

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _isFav = _favs.isFavorite(widget.channel.slug);
    _favs.addListener(_onFavsChanged);
    _favs.load();
    _openStream();
  }

  void _onFavsChanged() {
    final v = _favs.isFavorite(widget.channel.slug);
    if (mounted && v != _isFav) setState(() => _isFav = v);
  }

  void _toggleFav() {
    HapticFeedback.selectionClick();
    _favs.toggle(widget.channel.slug);
  }

  Future<void> _openStream() async {
    _openGeneration++;
    _userClosedNative = false;
    _desktopSourceIndex = 0;
    _desktopSourceAttempts = 0;
    _didRefreshRetry = false;
    _deadSources.clear();
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final raw = await _proxy.streamUrlsFor(widget.channel.slug);
      if (raw.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Aucune source disponible pour cette chaîne.';
          });
        }
        return;
      }
      // Mesures terrain : beaucoup de chaînes n'ont qu'1 source OK sur N
      // (502 amont transitoires). Zapping rapide : on joue IMMÉDIATEMENT
      // la meilleure source connue (pré-rank à l'ouverture de l'onglet,
      // sinon ordre API) sans attendre le rank complet. Le rank complet
      // tourne en tâche de fond (mémorise la meilleure pour la prochaine
      // fois) et la bascule inter-sources existante ne s'enclenche qu'en
      // cas d'échec — jamais de switch en cours de lecture réussie.
      // Le choix manuel du popup reste prioritaire (source imposée en tête).
      _streamUrls = _proxy.prioritizeKnown(widget.channel.slug, raw);
      _applyImposedSource();
      if (_streamUrls.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Aucune source disponible pour cette chaîne.';
          });
        }
        return;
      }
      debugPrint(
        '[LivePlayer] ${widget.channel.name}: ${_streamUrls.length} source(s)',
      );
      unawaited(_proxy.rankSources(raw, slug: widget.channel.slug));
      await _playAllSources();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Chaîne indisponible.\n${FstvProxyService.humanize(e)}';
        });
      }
    }
  }

  /// Remonte la source imposée par le popup en tête de [_streamUrls]
  /// (comparaison trimée, doublons purgés). Si introuvable — ex. ids
  /// rafraîchis entre-temps — garde l'ordre ranké (fallback sûr).
  /// L'imposée n'est qu'un point de départ : si elle a déjà été prouvée morte
  /// ([_deadSources], après refresh), on ne la rejoue jamais.
  void _applyImposedSource() {
    final imposed = widget.initialSourceUrl?.trim();
    if (imposed == null || imposed.isEmpty || _streamUrls.isEmpty) return;
    if (_deadSources.contains(imposed)) {
      debugPrint('[LivePlayer] imposed source already proven dead → keep order');
      return;
    }
    final idx = _streamUrls.indexWhere((u) => u.trim() == imposed);
    if (idx <= 0) {
      if (idx == 0) {
        debugPrint('[LivePlayer] imposed source already first');
      } else {
        debugPrint('[LivePlayer] imposed source not found, keep ranked order');
      }
      return;
    }
    final reordered = List<String>.of(_streamUrls);
    reordered.removeAt(idx);
    reordered.insert(0, imposed);
    _streamUrls = List<String>.unmodifiable(reordered);
    debugPrint('[LivePlayer] imposed source → first (${_streamUrls.length})');
  }

  /// Les jetons CDN amont (FSTV) expirent vite et l'amont répond souvent
  /// 502 de façon transitoire : si TOUTES les sources échouent, on force un
  /// rafraîchissement des chaînes (ids neufs) et on rejoue systématiquement
  /// — même à ids identiques, le 502 a pu se résorber entre-temps.
  /// Reprise où on en était : les sources déjà prouvées mortes ([_deadSources],
  /// dont l'imposée si KO) sont exclues des candidates — jamais rejouées — puis
  /// les candidates sont re-rankées (probe, budget ≤ 4 s côté proxy) et la
  /// lecture repart à l'index 0 = 1re source non encore essayée. Le compteur
  /// "k/N" reflète donc toujours la vraie position dans la liste courante.
  Future<bool> _tryRefreshAndReplay(int generation) async {
    if (_didRefreshRetry) return false;
    _didRefreshRetry = true;
    try {
      await _proxy.getChannels(forceRefresh: true);
      final fresh = await _proxy.streamUrlsFor(widget.channel.slug);
      if (!mounted || generation != _openGeneration) return false;
      if (fresh.isEmpty) return false;
      debugPrint(
          '[LivePlayer] refresh → 2e tentative (${fresh.length} sources)');
      // La mémo peut pointer sur d'anciens ids : l'oublier, puis ne garder que
      // les sources non encore essayées (à ids identiques la morte est écartée,
      // à ids neufs tout est rejouable).
      _proxy.dropBestFor(widget.channel.slug);
      final candidates = fresh
          .where((u) => !_deadSources.contains(u.trim()))
          .toList(growable: false);
      if (candidates.isEmpty) {
        debugPrint(
            '[LivePlayer] refresh → toutes les sources connues sont mortes');
        return false;
      }
      // Re-rank des candidates (remémorise la meilleure pour la prochaine
      // fois). Gardé par la génération : un _openStream concurrent annule.
      final ranked =
          await _proxy.rankSources(candidates, slug: widget.channel.slug);
      if (!mounted || generation != _openGeneration) return false;
      _streamUrls = ranked.isNotEmpty
          ? List<String>.unmodifiable(ranked)
          : List<String>.unmodifiable(candidates);
      _desktopSourceIndex = 0;
      _desktopSourceAttempts = 0;
      setState(() {
        _loading = true;
        _error = null;
      });
      await _playAllSources();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _playAllSources() async {
    if (_streamUrls.isEmpty) return;
    final generation = ++_openGeneration;
    final headers = _proxy.playerHeaders();

    try {
      _universalController?.dispose();
      _errorSub?.cancel();

      // ── Android : toutes les sources d'un coup, 1 try chacune en natif ──
      if (_useNativeAndroid) {
        if (mounted) {
          setState(() {
            _loading = true;
            _error = null;
          });
        }

        _universalController = UniversalPlayerController(
          url: _streamUrls.first,
          fallbackUrls: _streamUrls.skip(1).toList(),
          headers: headers,
          isLive: true,
        );

        await _universalController!.initialize();
        if (!mounted || generation != _openGeneration) return;

        final result = _universalController!.lastSurfaceResult;
        final hadError = result?['hadError'] == true || result?['ok'] == false;
        final errMsg = result?['error']?.toString();

        if (!hadError) {
          _userClosedNative = true;
          if (mounted) Navigator.of(context).pop();
          return;
        }

        // Toutes les sources ont déjà été essayées côté natif (1 try chacune)
        debugPrint('[LivePlayer] all native sources failed: $errMsg');
        // 2e chance : les jetons ont peut-être expiré côté amont
        if (await _tryRefreshAndReplay(generation)) return;
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Impossible de charger le flux.\n'
                '${_streamUrls.length} source(s) testée(s).\n'
                '${errMsg ?? ''}';
          });
        }
        return;
      }

      // ── Desktop : 1 try par source, bascule Flutter ───────────────────
      await _playDesktopSource(generation);
    } catch (e) {
      if (mounted && generation == _openGeneration) {
        setState(() {
          _loading = false;
          _error = 'Ouverture impossible: $e';
        });
      }
    }
  }

  /// Erreur transitoire probable côté amont (502/503/… revus en mesures) :
  /// mérite 1 retry avec backoff avant de passer à la source suivante.
  static bool _isTransientLiveError(Object e) {
    if (e is TimeoutException) return true;
    final s = e.toString().toLowerCase();
    return s.contains('502') ||
        s.contains('503') ||
        s.contains('504') ||
        s.contains('429') ||
        s.contains('408') ||
        s.contains('timeout') ||
        s.contains('timed out') ||
        s.contains('socket') ||
        s.contains('connection reset') ||
        s.contains('connection closed') ||
        s.contains('broken pipe') ||
        s.contains('network is unreachable');
  }

  /// Passe à la source suivante (ou rejoue après refresh si tout épuisé).
  /// La source abandonnée est prouvée morte : mémorisée dans [_deadSources]
  /// (URL trimée) pour ne jamais être rejouée après refresh — y compris
  /// l'imposée du popup, qui n'est qu'un point de départ.
  Future<void> _nextDesktopSource(int generation) async {
    if (!mounted || generation != _openGeneration) return;
    if (_desktopSourceIndex >= 0 &&
        _desktopSourceIndex < _streamUrls.length) {
      final dead = _streamUrls[_desktopSourceIndex].trim();
      if (dead.isNotEmpty && _deadSources.add(dead)) {
        debugPrint('[LivePlayer] source proven dead ($dead)');
      }
    }
    _desktopSourceIndex++;
    _desktopSourceAttempts = 0;
    await _playDesktopSource(generation);
  }

  /// Rejoue la même source après backoff (erreurs transitoires uniquement).
  Future<void> _retryDesktopSource(int generation) async {
    if (!mounted || generation != _openGeneration) return;
    _desktopSourceAttempts++;
    debugPrint(
      '[LivePlayer] retry source $_desktopSourceIndex '
      '(essai ${_desktopSourceAttempts + 1}/$_maxDesktopAttemptsPerSource)',
    );
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted || generation != _openGeneration) return;
    await _playDesktopSource(generation);
  }

  Future<void> _playDesktopSource(int generation) async {
    if (_desktopSourceIndex >= _streamUrls.length) {
      // Toutes les sources épuisées : 2e chance avec des jetons frais
      if (generation == _openGeneration &&
          await _tryRefreshAndReplay(generation)) {
        return;
      }
      if (mounted && generation == _openGeneration) {
        setState(() {
          _loading = false;
          _error = 'Impossible de charger le flux.\n'
              '${_streamUrls.length} source(s) testée(s).';
        });
      }
      return;
    }

    final url = _streamUrls[_desktopSourceIndex];
    final headers = _proxy.playerHeaders();
    debugPrint(
      '[LivePlayer] desktop source ${_desktopSourceIndex + 1}/${_streamUrls.length}',
    );

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    _universalController?.dispose();
    _errorSub?.cancel();
    // L'ancienne écoute est annulée ci-dessus : aucune erreur périmée ne peut
    // arriver → ré-armer le garde anti-double-bascule ici. Sans ce reset,
    // après un 1er échec le flag restait à true et toutes les erreurs des
    // sources suivantes étaient ignorées (lecteur bloqué en chargement).
    _isSwitching = false;
    _universalController = UniversalPlayerController(
      url: url,
      headers: headers,
      isLive: true,
    );
    // Capture locale de la tentative : les gardes `identical` ci-dessous
    // garantissent l'exactement-une-fois par source. Sans eux, deux chaînes
    // concurrentes (erreur errorStream + throw d'initialize pour le même
    // échec, ou retry en retard après bascule) pouvaient soit re-basculer
    // depuis un contrôleur périmé (sauts de sources, compteur incohérent),
    // soit déclarer un faux succès sur un contrôleur déjà disposé — l'index
    // restait alors figé et le compteur bloqué sur "1/N".
    final attemptCtrl = _universalController!;

    // Erreur player → retry backoff si transitoire (502 amont…), sinon
    // bascule source suivante. Le retry ne s'applique qu'au 1er échec de
    // la source courante (max 2 essais / source).
    _errorSub = attemptCtrl.errorStream.listen((err) {
      if (!mounted || generation != _openGeneration || _userClosedNative) {
        return;
      }
      // Erreur d'un contrôleur périmé (bascule déjà partie vers la source
      // suivante) : ignorer, sinon double-bascule et sources sautées.
      if (!identical(_universalController, attemptCtrl)) return;
      if (_isSwitching) return;
      debugPrint(
          '[LivePlayer] desktop error on source $_desktopSourceIndex: $err');
      _isSwitching = true;
      if (_desktopSourceAttempts + 1 < _maxDesktopAttemptsPerSource &&
          _isTransientLiveError(err)) {
        _retryDesktopSource(generation);
      } else {
        _nextDesktopSource(generation);
      }
    });

    try {
      // Watchdog : media_kit/mpv peut rester muet (ni erreur ni ready) sur un
      // flux HLS mort → sans timeout le loader tournait indéfiniment.
      // 20 s : compromis zapping / tolérance réseau (le probe préalable a
      // déjà écarté les sources manifestement mortes).
      await _universalController!.initialize().timeout(
            const Duration(seconds: 20),
            onTimeout: () =>
                throw TimeoutException('Timeout initialisation live'),
          );
      // Tentative périmée entre-temps (bascule concurrente déjà partie) :
      // ne rien faire — ni faux succès, ni double-bascule.
      if (!mounted ||
          generation != _openGeneration ||
          !identical(_universalController, attemptCtrl)) {
        return;
      }
      if (attemptCtrl.isInitialized) {
        setState(() {
          _loading = false;
          _error = null;
        });
        _isSwitching = false;
        _desktopSourceAttempts = 0;
        _scheduleHide();
      } else {
        await _nextDesktopSource(generation);
      }
    } catch (e) {
      // Échec d'une tentative périmée (le fallback est déjà parti via
      // errorStream ou une chaîne concurrente) : ignorer pour ne pas
      // sauter une source saine.
      if (!mounted ||
          generation != _openGeneration ||
          !identical(_universalController, attemptCtrl)) {
        return;
      }
      // Timeout d'init = transitoire typique → 1 retry backoff avant abandon.
      if (_desktopSourceAttempts + 1 < _maxDesktopAttemptsPerSource &&
          _isTransientLiveError(e)) {
        await _retryDesktopSource(generation);
      } else {
        await _nextDesktopSource(generation);
      }
    }
  }

  @override
  void dispose() {
    _favs.removeListener(_onFavsChanged);
    _hideTimer?.cancel();
    _errorSub?.cancel();
    _backNode.dispose();
    _favNode.dispose();
    _retryNode.dispose();
    _errorBackNode.dispose();
    _universalController?.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        // Retour : télécommande + bouton B gamepad (touche dédiée, B12).
        if (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack ||
            event.logicalKey == LogicalKeyboardKey.browserBack ||
            event.logicalKey == LogicalKeyboardKey.gameButtonB) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        if (_isTvActivate(event.logicalKey)) {
          // Relais gamepad/numpad (B2/B10/B11) : les boutons overlay/erreur
          // gèrent déjà Enter/Espace en natif, mais ignorent gameButtonA
          // (et parfois numpadEnter) — la racine relaie vers le bouton
          // focusé au lieu d'appliquer l'action racine (toggle/retry).
          if (_backNode.hasFocus) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          if (_favNode.hasFocus) {
            _toggleFav();
            return KeyEventResult.handled;
          }
          if (_retryNode.hasFocus) {
            _openStream();
            return KeyEventResult.handled;
          }
          if (_errorBackNode.hasFocus) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          if (_error != null) {
            _openStream();
          } else {
            _toggleControls();
          }
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.arrowDown) {
          final down =
              event.logicalKey == LogicalKeyboardKey.arrowDown;
          // État erreur (B11) : Up/Down circule entre Réessayer/Retour
          // (les deux atteignables) au lieu de consommer sans déplacer.
          if (_error != null && !_loading) {
            if (down) {
              FocusScope.of(node.context!).nextFocus();
            } else {
              FocusScope.of(node.context!).previousFocus();
            }
            return KeyEventResult.handled;
          }
          // Contrôles visibles (B10) : Up/Down amène le focus sur l'overlay
          // (Retour/Favori) au lieu de le consommer sur la racine.
          if (_overlayVisible) {
            if (_backNode.hasFocus || _favNode.hasFocus) {
              if (down) {
                FocusScope.of(node.context!).nextFocus();
              } else {
                FocusScope.of(node.context!).previousFocus();
              }
            } else {
              _backNode.requestFocus();
            }
            _scheduleHide();
            return KeyEventResult.handled;
          }
          if (!_showControls) setState(() => _showControls = true);
          _scheduleHide();
          return KeyEventResult.handled;
        }
        // Gauche/Droite depuis l'overlay ou l'erreur : navigation explicite
        // entre les boutons (B10/B11), sinon filet.
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowRight) {
          if (_backNode.hasFocus ||
              _favNode.hasFocus ||
              _retryNode.hasFocus ||
              _errorBackNode.hasFocus) {
            return _moveFocused(
              event.logicalKey == LogicalKeyboardKey.arrowLeft
                  ? TraversalDirection.left
                  : TraversalDirection.right,
            );
          }
          return KeyEventResult.ignored;
        }
        // Menu / Info / Y (gamepad + clavier) / F => bascule le favori
        // (touche info ajoutée, B10).
        if (_isFavKey(event.logicalKey)) {
          _toggleFav();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          // Groupe de traversal ordonné (B10) : Retour(0)/Favori(1) en
          // lecture, Réessayer(0)/Retour(1) en erreur (jamais co-visibles).
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!_useNativeAndroid && _universalController != null)
                  UniversalVideoView(controller: _universalController!),
                if (_loading) _buildLoading(),
                if (_error != null && !_loading) _buildError(),
                if (!_useNativeAndroid &&
                    _showControls &&
                    _error == null &&
                    !_loading)
                  _buildControlsOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    final srcInfo = _streamUrls.isNotEmpty
        ? ' · ${_streamUrls.length} source${_streamUrls.length > 1 ? 's' : ''}'
        : '';
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Connexion à ${widget.channel.name}$srcInfo…',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (_useNativeAndroid) ...[
              const SizedBox(height: 8),
              const Text(
                'Lecteur natif · 1 essai par source',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ] else if (_streamUrls.length > 1) ...[
              const SizedBox(height: 8),
              Text(
                'Source ${_desktopSourceIndex + 1}/${_streamUrls.length}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: NeoTheme.errorRed, size: 52),
              const SizedBox(height: 14),
              const Text(
                'Chaîne indisponible',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? '',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Réessayer (ordre 0, autofocus) + Retour (ordre 1) : tous deux
              // focusables et atteignables au D-pad (B11). Up/Down/Left/Right
              // circulent via la racine, OK gamepad/numpad relayé au bouton
              // focusé. Anneau blanc : focus lisible sur fond noir.
              FocusTraversalOrder(
                order: const NumericFocusOrder(0),
                child: ListenableBuilder(
                  listenable: _retryNode,
                  builder: (context, _) => Container(
                    decoration: _playerFocusRing(_retryNode.hasFocus),
                    child: ElevatedButton.icon(
                      focusNode: _retryNode,
                      autofocus: true,
                      onPressed: _openStream,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Réessayer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        foregroundColor: Neo.readableOnPrimary(context),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FocusTraversalOrder(
                order: const NumericFocusOrder(1),
                child: ListenableBuilder(
                  listenable: _errorBackNode,
                  builder: (context, _) => Container(
                    decoration:
                        _playerFocusRing(_errorBackNode.hasFocus),
                    child: TextButton(
                      focusNode: _errorBackNode,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Retour',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          right: 8,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            // Retour (ordre 0) : atteignable au D-pad (B10) — Up/Down depuis
            // la racine amène le focus ici, Gauche/Droite circule vers Favori.
            FocusTraversalOrder(
              order: const NumericFocusOrder(0),
              child: ListenableBuilder(
                listenable: _backNode,
                builder: (context, _) => Container(
                  decoration: _playerFocusRing(_backNode.hasFocus),
                  child: IconButton(
                    focusNode: _backNode,
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    tooltip: 'Retour',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(NeoTheme.radiusSm),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record,
                      color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'EN DIRECT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.channel.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Favori (ordre 1) : atteignable au D-pad (B10), même relais
            // OK gamepad/numpad que Retour via la racine.
            FocusTraversalOrder(
              order: const NumericFocusOrder(1),
              child: ListenableBuilder(
                listenable: _favNode,
                builder: (context, _) => Container(
                  decoration: _playerFocusRing(_favNode.hasFocus),
                  child: IconButton(
                    focusNode: _favNode,
                    icon: Icon(
                      _isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _isFav ? Neo.primaryRed : Colors.white70,
                    ),
                    tooltip: _isFav
                        ? 'Retirer des favoris'
                        : 'Ajouter aux favoris',
                    onPressed: _toggleFav,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
