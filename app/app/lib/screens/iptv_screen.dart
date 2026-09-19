import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _favIds = _favs.ids;
    _favs.addListener(_onFavsChanged);
    _favs.load();
    _resume.addListener(_onResumeChanged);
    _resume.load();
    _load();
    // Pré-chauffe le guide TV en tâche de fond (zéro impact sur le live :
    // ni blocage des chaînes, ni appel au proxy iptv.mine.bz). Quand il
    // arrive, re-trie le spotlight ("en cours d'abord") + affiche les
    // pastilles EPG (un seul setState global, pas un FutureBuilder par carte).
    EpgService.instance.ensureLoaded().then((_) {
      if (!mounted) return;
      setState(_refreshSpotlight);
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
    _favs.removeListener(_onFavsChanged);
    _resume.removeListener(_onResumeChanged);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (_loadInFlight) return;
    _loadInFlight = true;

    if (_flat.isEmpty) {
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
                      color: Neo.primaryRed.withValues(alpha: 0.3),
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
                  Neo.primaryRed.withValues(alpha: 0.45),
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
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            if (!_loading) _load(forceRefresh: true);
            return KeyEventResult.handled;
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
                    ? focusColor.withValues(alpha: 0.18)
                    : Neo.bgElevated(context),
                borderRadius: BorderRadius.circular(Neo.radiusMd),
                border: Border.all(
                  color: tvFocused ? focusColor : Neo.borderLight(context),
                  width: tvFocused ? 3.5 : 1.2,
                ),
                boxShadow: tvFocused
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.9),
                          blurRadius: 6,
                          spreadRadius: 1.5,
                        ),
                        BoxShadow(
                          color: focusColor.withValues(alpha: 0.55),
                          blurRadius: 22,
                          spreadRadius: 3,
                        ),
                      ]
                    : null,
              ),
              child: GestureDetector(
                onTap: _loading ? null : () => _load(forceRefresh: true),
                behavior: HitTestBehavior.opaque,
                child: Tooltip(
                  message: 'Actualiser',
                  child: Center(
                    child: Icon(
                      Icons.refresh_rounded,
                      color:
                          tvFocused ? focusColor : Neo.textSecondary(context),
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
    final chips = <Widget>[
      _categoryChip(
        label: 'Toutes',
        count: _flat.length,
        icon: Icons.apps_rounded,
        selected: _selectedCategory == null && !_favOnly,
        isFirst: true,
        onTap: () {
          _selectedCategory = null;
          _favOnly = false;
          _applyFilters();
        },
      ),
      _categoryChip(
        label: 'Favoris',
        count: _favIds.length,
        icon: Icons.favorite_rounded,
        selected: _favOnly,
        isFirst: false,
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
      chips.add(_categoryChip(
        label: cat,
        count: list?.length ?? 0,
        icon: icon,
        selected: _selectedCategory == cat && !_favOnly,
        isFirst: false,
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
        itemCount: chips.length,
        separatorBuilder: (_1, _2) => const SizedBox(width: 10),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _categoryChip({
    required String label,
    required int count,
    IconData? icon,
    required bool selected,
    required bool isFirst,
    required VoidCallback onTap,
  }) {
    final isTV = NeoTheme.isTV(context);
    return Focus(
      // Premier chip visible : point d'entrée autofocus côté contenu.
      autofocus: isTV && isFirst,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Enter/OK : activer
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
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
          // Flèche haut depuis la barre catégories : traversal normal (remonte).
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
                        ? focusColor.withValues(alpha: 0.22)
                        : highlight
                            ? Neo.primaryRed.withValues(alpha: 0.14)
                            : Neo.bgElevated(context),
                    borderRadius: BorderRadius.circular(Neo.radiusFull),
                    border: Border.all(
                      color: tvFocused
                          ? focusColor
                          : highlight
                              ? Neo.primaryRed.withValues(alpha: 0.6)
                              : Neo.borderLight(context),
                      // Bordure très épaisse sur focus TV : lisible à 3 m.
                      width: tvFocused ? 3.5 : (highlight ? 1.5 : 1),
                    ),
                    boxShadow: tvFocused
                        ? [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.9),
                              blurRadius: 6,
                              spreadRadius: 1.5,
                            ),
                            BoxShadow(
                              color: focusColor.withValues(alpha: 0.55),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                          ]
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
                                  ? focusColor
                                  : highlight
                                      ? Neo.primaryRed
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
                                  ? focusColor
                                  : highlight
                                      ? Neo.primaryRed
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
                                ? focusColor.withValues(alpha: 0.25)
                                : highlight
                                    ? Neo.primaryRed.withValues(alpha: 0.16)
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
                                  ? focusColor
                                  : highlight
                                      ? Neo.primaryRed
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
              childAspectRatio: 0.9,
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
                      color: Neo.primaryRed.withValues(alpha: 0.22),
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
              childAspectRatio: 0.9,
            ),
            itemCount: _filtered.length,
            itemBuilder: (context, index) {
              final ch = _filtered[index];
              final isLeftEdge = index % crossCount == 0; // Première colonne
              return Padding(
                // Marge basse : la pastille EPG déborde de 9 px sous la carte.
                padding: const EdgeInsets.only(bottom: 10),
                child: RepaintBoundary(
                  child: _ChannelCard(
                    key: ValueKey(ch.slug),
                    channel: ch,
                    onTap: () => _showDetails(ch),
                    isLeftEdge: isLeftEdge,
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

/// Carte chaîne factice pour le shimmer (même gabarit que la vraie carte).
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
          const SizedBox(height: 12),
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
  @override
  void initState() {
    super.initState();
    // Le guide arrive en tâche de fond : re-trie "en cours d'abord"
    // dès qu'il est prêt (simple setState, pas de reload réseau ici).
    EpgService.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

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
                  color: Neo.primaryRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Neo.radiusFull),
                ),
                child: Text(
                  '${widget.channels.length}',
                  style: const TextStyle(
                    color: Neo.primaryRed,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: isTV ? 148 : 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            itemCount: widget.channels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final ch = widget.channels[i];
              return _SpotlightCard(
                channel: ch,
                isFirst: i == 0,
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
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback? onLeftEdge;

  const _SpotlightCard({
    required this.channel,
    required this.isFirst,
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
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
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
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (ctx) {
          final isFocused = Focus.of(ctx).hasFocus;
          final tvFocused = isTV && isFocused;
          final focusColor = Neo.accentColor(context);
          final epg = EpgService.instance;
          final nn = epg.getNowAndNext(channel.slug) ??
              epg.getNowAndNext(channel.name);
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
                  boxShadow: tvFocused
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.9),
                            blurRadius: 6,
                            spreadRadius: 1.5,
                          ),
                          BoxShadow(
                            color: focusColor.withValues(alpha: 0.55),
                            blurRadius: 22,
                            spreadRadius: 3,
                          ),
                        ]
                      : null,
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
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Icon(
                                        Icons.favorite_rounded,
                                        color: Neo.primaryRed,
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
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onTap();
            return KeyEventResult.handled;
          }

          // Touche dédiée TV : Menu / Info / touche F / bouton jaune (Y)
          // sur carte focusée => bascule le favori (la carte reste le seul
          // élément focusable, pas de sous-bouton au D-pad).
          if (event.logicalKey == LogicalKeyboardKey.contextMenu ||
              event.logicalKey == LogicalKeyboardKey.info ||
              event.logicalKey == LogicalKeyboardKey.gameButtonY ||
              event.logicalKey == LogicalKeyboardKey.keyF) {
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
            // Gauche interne + haut/bas/droite : traversal normal.
            // Up remonte vers la categoryBar, gauche interne vers carte voisine.
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.arrowDown ||
                event.logicalKey == LogicalKeyboardKey.arrowRight) {
              return KeyEventResult.ignored;
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
          return AnimatedOpacity(
            // Carte non-focusée assombrie sur TV : contraste à 3 m.
            opacity: isTV && !isFocused ? 0.6 : 1.0,
            duration: const Duration(milliseconds: 180),
            child: AnimatedScale(
              scale: tvFocused ? 1.07 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
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
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.9),
                                blurRadius: 6,
                                spreadRadius: 1.5,
                              ),
                              BoxShadow(
                                color: focusColor.withValues(alpha: 0.55),
                                blurRadius: 24,
                                spreadRadius: 3,
                              ),
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
                                      // Pastille lecture survol/focus.
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
                                                color: Colors.white,
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
                                            child: const Icon(
                                              Icons.play_arrow_rounded,
                                              color: Colors.white,
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
                                            ? Neo.primaryRed
                                                .withValues(alpha: 0.16)
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: widget.isFavorite
                                              ? Neo.primaryRed
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
                                            ? Neo.primaryRed
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
                                maxLines: 2,
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
                              // Indicateur nb sources + pastille EN DIRECT.
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
                                  const SizedBox(width: 6),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Neo.successGreen,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6,
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
                  // Pastille "EN COURS : émission" flottante (overlay :
                  // zéro impact sur le layout de la carte).
                  _EpgLivePill(channel: ch),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Pastille EPG "EN COURS : émission" ───────────────────────────────────
// Overlay en bas de carte (ne modifie pas le layout). N'apparaît que quand
// le guide est chargé ET qu'un programme est en cours sur cette chaîne.
// Absente sinon (chaîne inconnue du guide, trou de grille, EPG en panne).
// Lecture mémoire synchrone : AUCUN FutureBuilder par carte (avant : un
// Future ensureLoaded() + rebuild par carte, soit ~N futures et ~2N requêtes
// EPG à chaque build de grille). Le parent (_IptvScreenState) fait un seul
// ensureLoaded() + un setState global quand le guide arrive.
class _EpgLivePill extends StatelessWidget {
  final FstvChannel channel;

  const _EpgLivePill({required this.channel});

  @override
  Widget build(BuildContext context) {
    final epg = EpgService.instance;
    final nn =
        epg.getNowAndNext(channel.slug) ?? epg.getNowAndNext(channel.name);
    if (nn == null) return const SizedBox.shrink();
    return Positioned(
      left: 10,
      right: 10,
      bottom: -9,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Neo.errorRed,
          borderRadius: BorderRadius.circular(Neo.radiusFull),
          border: Border.all(color: Colors.white, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Neo.errorRed.withValues(alpha: 0.5),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                'EN COURS : ${nn.now.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Neo.infoCyan.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Neo.radiusFull),
        border: Border.all(
          color: Neo.infoCyan.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.history_rounded,
            size: 12,
            color: Neo.infoCyan,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Neo.infoCyan,
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
      // memCache dimensionné au rendu ×2 (retina), placeholder = fallback
      // initiale (zéro flash blanc / zéro saut de layout).
      child: logo.isEmpty
          ? _logoFallback(channel, size)
          : CachedNetworkImage(
              imageUrl: logo,
              width: size,
              height: size,
              memCacheWidth: (size * 2).toInt(),
              memCacheHeight: (size * 2).toInt(),
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

  const _ChannelDetailsDialog({
    required this.channel,
    required this.entries,
    required this.onPlayBest,
    required this.onPlaySource,
  });

  @override
  State<_ChannelDetailsDialog> createState() => _ChannelDetailsDialogState();
}

class _ChannelDetailsDialogState extends State<_ChannelDetailsDialog> {
  bool _epgReady = false;

  @override
  void initState() {
    super.initState();
    // Le guide a été pré-chargé à l'ouverture de l'onglet ; ici on
    // s'assure juste qu'il est prêt avant d'afficher la section EPG.
    EpgService.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _epgReady = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTV = NeoTheme.isTV(context);
    final width = MediaQuery.of(context).size.width;
    final dialogWidth = isTV ? 560.0 : (width >= 600 ? 520.0 : width);
    return Focus(
      autofocus: true,
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
            ? const EdgeInsets.symmetric(horizontal: 48, vertical: 48)
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
            maxHeight:
                MediaQuery.of(context).size.height * (isTV ? 0.85 : 0.88),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _ChannelLogo(channel: widget.channel, size: 76),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Fermer',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
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
                  // Section EPG "Maintenant / À suivre" (display-only).
                  _buildEpgSection(),
                  const SizedBox(height: 14),
                  // CTA principal : autofocus D-pad, 1er dans l'ordre.
                  // Sans source, bouton désactivé (jamais d'ouverture du
                  // player vers une erreur certaine) + exclu du focus D-pad.
                  if (widget.entries.isEmpty)
                    const ExcludeFocus(
                      child: _DialogDisabledButton(),
                    )
                  else
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(0),
                      child: _DialogPrimaryButton(
                        autofocus: true,
                        onActivated: widget.onPlayBest,
                        // Phone : "Reprendre le direct" si déjà regardée,
                        // sinon "Lancer le direct" (TV : toujours Lancer).
                        label: !isTV &&
                                IptvResume.instance
                                    .wasWatched(widget.channel.slug)
                            ? 'Reprendre le direct'
                            : 'Lancer le direct',
                      ),
                    ),
                  const SizedBox(height: 12),
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Aucune source disponible pour cette chaîne.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: widget.entries.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final e = widget.entries[i];
                              return FocusTraversalOrder(
                                // Ordre D-pad : après Lancer (0), sources 1..N.
                                order: NumericFocusOrder(i + 1),
                                child: _SourceRow(
                                  index: i,
                                  displayName: e.displayName,
                                  onActivated: () => widget.onPlaySource(e.url),
                                ),
                              );
                            },
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
    final epg = EpgService.instance;
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
    final nn =
        epg.getNowAndNext(channel.slug) ?? epg.getNowAndNext(channel.name);
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
class _DialogPrimaryButton extends StatelessWidget {
  final bool autofocus;
  final VoidCallback onActivated;
  final String label;

  const _DialogPrimaryButton({
    required this.autofocus,
    required this.onActivated,
    this.label = 'Lancer le direct',
  });

  @override
  Widget build(BuildContext context) {
    final isTV = NeoTheme.isTV(context);
    return Focus(
      autofocus: autofocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            onActivated();
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
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.9),
                          blurRadius: 6,
                          spreadRadius: 1.5,
                        ),
                        BoxShadow(
                          color: focusColor.withValues(alpha: 0.55),
                          blurRadius: 22,
                          spreadRadius: 3,
                        ),
                      ]
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

/// Ligne source du popup : nom = label API si non vide, sinon "Source N".
/// Focusable / cliquable au D-pad pour lancer directement cette source.
class _SourceRow extends StatelessWidget {
  final int index;
  final String displayName;
  final VoidCallback onActivated;

  const _SourceRow({
    required this.index,
    required this.displayName,
    required this.onActivated,
  });

  @override
  Widget build(BuildContext context) {
    final isTV = NeoTheme.isTV(context);
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            onActivated();
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
            scale: tvFocused ? 1.03 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: tvFocused
                    ? focusColor.withValues(alpha: 0.18)
                    : Neo.bgElevated(context),
                borderRadius: BorderRadius.circular(Neo.radiusMd),
                border: Border.all(
                  color: tvFocused ? focusColor : Neo.borderLight(context),
                  width: tvFocused ? 3.5 : 1.2,
                ),
                boxShadow: tvFocused
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.9),
                          blurRadius: 6,
                          spreadRadius: 1.5,
                        ),
                        BoxShadow(
                          color: focusColor.withValues(alpha: 0.55),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ]
                    : null,
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
                              ? focusColor.withValues(alpha: 0.25)
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
                                  ? focusColor
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
                                    color: tvFocused ? focusColor : null,
                                  ),
                        ),
                      ),
                      Icon(
                        Icons.play_circle_fill_rounded,
                        color:
                            tvFocused ? focusColor : Neo.textTertiary(context),
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

  StreamSubscription<String>? _errorSub;

  bool get _useNativeAndroid => !kIsWeb && Platform.isAndroid;

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
      // (502 amont transitoires). Probe rapide → sources OK d'abord, les
      // autres gardées ensuite (jamais jetées).
      _streamUrls = await _proxy.rankSources(raw);
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
  void _applyImposedSource() {
    final imposed = widget.initialSourceUrl?.trim();
    if (imposed == null || imposed.isEmpty || _streamUrls.isEmpty) return;
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
      _streamUrls = await _proxy.rankSources(fresh);
      _applyImposedSource();
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
  Future<void> _nextDesktopSource(int generation) async {
    if (!mounted || generation != _openGeneration) return;
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
      '[LivePlayer] desktop source $_desktopSourceIndex/${_streamUrls.length}',
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

    // Erreur player → retry backoff si transitoire (502 amont…), sinon
    // bascule source suivante. Le retry ne s'applique qu'au 1er échec de
    // la source courante (max 2 essais / source).
    _errorSub = _universalController!.errorStream.listen((err) {
      if (!mounted || generation != _openGeneration || _userClosedNative)
        return;
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
      if (!mounted || generation != _openGeneration) return;
      if (_universalController!.isInitialized) {
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
      if (!mounted || generation != _openGeneration) return;
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
        if (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack ||
            event.logicalKey == LogicalKeyboardKey.browserBack) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA) {
          if (_error != null) {
            _openStream();
          } else {
            _toggleControls();
          }
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.arrowDown) {
          if (!_showControls) setState(() => _showControls = true);
          _scheduleHide();
          return KeyEventResult.handled;
        }
        // Bouton jaune (Y) / F / Menu => bascule le favori.
        if (event.logicalKey == LogicalKeyboardKey.gameButtonY ||
            event.logicalKey == LogicalKeyboardKey.keyF ||
            event.logicalKey == LogicalKeyboardKey.contextMenu) {
          _toggleFav();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
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
              ElevatedButton.icon(
                onPressed: _openStream,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Neo.readableOnPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Retour',
                    style: TextStyle(color: Colors.white70)),
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
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
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
            IconButton(
              icon: Icon(
                _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isFav ? Neo.primaryRed : Colors.white70,
              ),
              tooltip: _isFav ? 'Retirer des favoris' : 'Ajouter aux favoris',
              onPressed: _toggleFav,
            ),
          ],
        ),
      ),
    );
  }
}
