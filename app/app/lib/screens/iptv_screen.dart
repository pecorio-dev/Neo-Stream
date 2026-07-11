import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config/theme.dart';
import '../config/neo.dart';
import '../models/fstv_channel.dart';
import '../services/fstv_proxy_service.dart';
import '../widgets/neo_glass_card.dart';
import '../widgets/satisfying_animations.dart';
import 'payment_wall_screen.dart';

/// Écran TV en direct — chaînes servies par le proxy FSTV (iptv.mine.bz).
///
/// Source unique : FSTV (chaînes premium FR). Authentification automatique via
/// le compte Neo Stream (premium requis). UI glassmorphisme claire par défaut.
class IptvScreen extends StatefulWidget {
  const IptvScreen({super.key});

  @override
  State<IptvScreen> createState() => _IptvScreenState();
}

class _IptvScreenState extends State<IptvScreen> {
  final _proxy = FstvProxyService.instance;
  final _scrollCtrl = ScrollController();

  Map<String, List<FstvChannel>> _channelsByCategory = {};
  List<FstvChannel> _flat = [];
  List<FstvChannel> _filtered = [];

  bool _loading = true;
  String? _error;
  bool _premiumRequired = false;
  int _loadAttempts = 0;
  static const int _maxLoadAttempts = 3;

  String? _selectedCategory; // null = toutes
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silentRetry = false}) async {
    if (!silentRetry) {
      setState(() {
        _loading = true;
        _error = null;
        _premiumRequired = false;
      });
    }
    try {
      await _proxy.ensureAuthenticated();
      final grouped = await _proxy.getChannels(forceRefresh: true);
      if (!mounted) return;
      final flat = grouped.values.expand((l) => l).toList(growable: false);
      // Succès : reset du compteur.
      _loadAttempts = 0;
      setState(() {
        _channelsByCategory = grouped;
        _categories = grouped.keys.toList();
        _flat = flat;
        _loading = false;
        _error = null;
      });
      _applyFilters();
    } on FstvPremiumRequiredException catch (e) {
      if (!mounted) return;
      setState(() {
        _premiumRequired = true;
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Retry silencieux : on ne montre l'erreur qu'après plusieurs essais.
      _loadAttempts++;
      if (_loadAttempts < _maxLoadAttempts) {
        debugPrint('🔁 IPTV chargement échec (essai $_loadAttempts/$_maxLoadAttempts) — retry silencieux');
        // On garde l'état précédent (chargement) sans afficher d'erreur.
        await Future.delayed(Duration(seconds: 2 * _loadAttempts));
        if (mounted) _load(silentRetry: true);
        return;
      }
      setState(() {
        _error = FstvProxyService.humanize(e);
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    var result = _selectedCategory == null
        ? List<FstvChannel>.of(_flat)
        : _channelsByCategory[_selectedCategory] ?? const <FstvChannel>[];

    setState(() => _filtered = result);
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
  }

  void _play(FstvChannel channel) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => _LivePlayerScreen(channel: channel),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, anim, _, child) {
          final curve =
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(opacity: curve, child: child);
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isTV = NeoTheme.isTV(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: !isTV,
        child: FocusScope(
          onKeyEvent: isTV ? (node, event) {
            // Gérer flèche gauche uniquement si aucun enfant ne la consomme
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              // Laisser l'événement descendre aux enfants d'abord
              // S'ils ne le gèrent pas, on ignore (la navbar va le capturer)
              return KeyEventResult.ignored;
            }
            return KeyEventResult.ignored;
          } : null,
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
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: Neo.heroGradient,
                  borderRadius: BorderRadius.circular(Neo.radiusMd),
                  boxShadow: [
                    BoxShadow(
                      color: Neo.primaryRed.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.live_tv_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TV en Direct',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      _loading ? 'Chargement…' : '${_flat.length} chaînes premium',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                    ),
                  ],
                ),
              ),
              if (!_premiumRequired && !_loading)
                IconButton(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Actualiser',
                ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildCategoryBar() {
    final chips = <Widget>[
      _categoryChip(
          label: 'Toutes',
          selected: _selectedCategory == null,
          isFirst: true,
          onTap: () {
            _selectedCategory = null;
            _applyFilters();
          }),
    ];
    for (final cat in _categories) {
      chips.add(_categoryChip(
        label: cat,
        selected: _selectedCategory == cat,
        isFirst: false,
        onTap: () {
          _selectedCategory = cat;
          _applyFilters();
        },
      ));
    }
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _categoryChip({
    required String label,
    required bool selected,
    required bool isFirst,
    required VoidCallback onTap,
  }) {
    final isTV = NeoTheme.isTV(context);
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Enter/OK : activer
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            onTap();
            return KeyEventResult.handled;
          }

          // Flèche gauche sur le premier item : laisser remonter vers navbar
          if (isTV && event.logicalKey == LogicalKeyboardKey.arrowLeft && isFirst) {
            return KeyEventResult.ignored; // Laisse remonter
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (ctx) {
          final isFocused = Focus.of(ctx).hasFocus;
          final highlight = selected || isFocused;
          return GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: highlight
                    ? Neo.primaryRed.withValues(alpha: 0.14)
                    : Neo.bgElevated(context),
                borderRadius: BorderRadius.circular(Neo.radiusFull),
                border: Border.all(
                  color: highlight
                      ? Neo.primaryRed.withValues(alpha: 0.6)
                      : Neo.borderLight(context),
                  width: isFocused ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: highlight
                        ? Neo.primaryRed
                        : Neo.textSecondary(context),
                    fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
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
    if (_loading) return _buildLoading();
    if (_premiumRequired) return _buildPremiumWall();
    if (_error != null) return _buildError();
    if (_filtered.isEmpty) return _buildEmpty();
    return _buildGrid();
  }

  Widget _buildLoading() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.4,
      ),
      itemCount: 6,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, _) => NeoGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Neo.bgElevated(context),
                borderRadius: BorderRadius.circular(Neo.radiusMd),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 12,
              width: 120,
              decoration: BoxDecoration(
                color: Neo.bgElevated(context),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 10,
              width: 70,
              decoration: BoxDecoration(
                color: Neo.borderLight(context),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
      ),
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
                  size: 56,
                  color: Neo.errorRed.withValues(alpha: 0.8)),
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
                  _loadAttempts = 0;
                  _load();
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
                      color:
                          Neo.prestigeGold.withValues(alpha: 0.4),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: NeoGlassCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tv_off_rounded,
                  size: 52, color: Neo.textTertiary(context)),
              const SizedBox(height: 14),
              Text('Aucune chaîne',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Aucune chaîne dans cette catégorie.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final width = MediaQuery.of(context).size.width;
    final crossCount =
        width >= 1200 ? 6 : (width >= 900 ? 5 : (width >= 600 ? 4 : 2));
    return GridView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.95,
      ),
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final ch = _filtered[index];
        final isLeftEdge = index % crossCount == 0; // Première colonne
        return _ChannelCard(
          channel: ch,
          onTap: () => _play(ch),
          isLeftEdge: isLeftEdge,
        ).staggeredFade(index: index);
      },
    );
  }
}

// ── Carte de chaîne ────────────────────────────────────────────────────────

class _ChannelCard extends StatefulWidget {
  final FstvChannel channel;
  final VoidCallback onTap;
  final bool isLeftEdge;

  const _ChannelCard({
    required this.channel,
    required this.onTap,
    required this.isLeftEdge,
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
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Enter/OK : activer
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onTap();
            return KeyEventResult.handled;
          }

          // Flèche gauche : bloquer si pas au bord gauche (empêche d'aller à la navbar)
          if (isTV && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (!widget.isLeftEdge) {
              // Pas au bord : laisser la navigation normale
              return KeyEventResult.ignored;
            }
            // Au bord gauche : laisser remonter vers navbar
            return KeyEventResult.ignored;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (ctx) {
          final isFocused = Focus.of(ctx).hasFocus;
          return MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedScale(
                scale: (_hovered || isFocused) ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: NeoGlassCard(
                  padding: const EdgeInsets.all(14),
                  accent: ch.categoryColor,
                  elevation: (_hovered || isFocused) ? 4 : 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  ch.categoryColor.withValues(alpha: 0.18),
                                  ch.categoryColor.withValues(alpha: 0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                  Neo.radiusMd),
                              border: Border.all(
                                color: ch.categoryColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(ch.categoryIcon,
                                color: ch.categoryColor, size: 22),
                          ),
                          const Spacer(),
                          AnimatedScale(
                            scale: (_hovered || isFocused) ? 1.15 : 1.0,
                            duration: const Duration(milliseconds: 180),
                            child: Icon(
                                Icons.play_circle_fill_rounded,
                                color: ch.categoryColor.withValues(
                                    alpha: (_hovered || isFocused) ? 1 : 0.6),
                                size: 28),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        ch.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Neo.successGreen,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Neo.successGreen
                                      .withValues(alpha: 0.6),
                                  blurRadius: 6,
                                ),
                              ],
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
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
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

// ── Lecteur ────────────────────────────────────────────────────────────────

class _LivePlayerScreen extends StatefulWidget {
  final FstvChannel channel;

  const _LivePlayerScreen({required this.channel});

  @override
  State<_LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends State<_LivePlayerScreen> {
  final _proxy = FstvProxyService.instance;
  late final Player _player;
  late final VideoController _controller;
  bool _loading = true;
  String? _error;
  bool _showControls = true;
  Timer? _hideTimer;

  // ── Reconnexion silencieuse ──────────────────────────────────────────
  // On garde le flux visible pendant les retries : media_kit garde la
  // dernière frame affichée. On ne montre qu'un petit indicateur discret.
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 8;
  bool _isReconnecting = false;
  Timer? _reconnectTimer;
  Timer? _bufferingWatchdog;

  String? _lastStreamUrl; // pour re-open sans re-fetch
  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;

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

  Future<void> _configureMpvForLiveStream() async {
    final nativePlayer = _player.platform;
    if (nativePlayer is NativePlayer) {
      await nativePlayer.setProperty('cache', 'yes');
      await nativePlayer.setProperty('cache-secs', '10');
      await nativePlayer.setProperty('demuxer-max-bytes', '64MiB');
      await nativePlayer.setProperty('demuxer-max-back-bytes', '32MiB');
      await nativePlayer.setProperty('demuxer-readahead-secs', '8');
      await nativePlayer.setProperty('network-timeout', '20');
      await nativePlayer.setProperty('stream-buffer-size', '4MiB');
      await nativePlayer.setProperty('hls-bitrate', 'max');
      await nativePlayer.setProperty('cache-pause-initial', 'yes');
      await nativePlayer.setProperty('cache-pause-wait', '3');
      await nativePlayer.setProperty('hr-seek', 'no');
      await nativePlayer.setProperty('video-sync', 'display-resample');
      await nativePlayer.setProperty('interpolation', 'yes');
      await nativePlayer.setProperty('tscale', 'mitchell');
    }
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _player = Player(
      configuration: PlayerConfiguration(
        bufferSize: 64 * 1024 * 1024,
      ),
    );
    _controller = VideoController(_player);
    _configureMpvForLiveStream();

    _errorSub = _player.stream.error.listen((e) {
      if (!mounted) return;
      _onStreamError(e);
    });

    _playingSub = _player.stream.playing.listen((playing) {
      if (mounted && playing) _onPlaybackResumed();
    });

    // Détection du stall (buffering prolongé = source probablement perdue).
    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      if (buffering) {
        _startBufferingWatchdog();
      } else {
        _bufferingWatchdog?.cancel();
      }
    });

    _openStream();
  }

  /// Démarre un watchdog : si le buffering dure > 20s, on considère que le
  /// flux est mort et on lance une reconnexion silencieuse.
  void _startBufferingWatchdog() {
    _bufferingWatchdog?.cancel();
    _bufferingWatchdog = Timer(const Duration(seconds: 20), () {
      if (!mounted) return;
      if (!_isReconnecting) {
        debugPrint('⏳ IPTV stall détecté (buffering > 20s) — reconnexion');
        _attemptReconnect(reason: 'stall');
      }
    });
  }

  /// Gestion d'une erreur du lecteur.
  /// Toutes les erreurs sont traitées comme transitoires tant qu'on n'a pas
  /// épuisé les tentatives de reconnexion — pas d'affichage d'erreur prématuré.
  void _onStreamError(String e) {
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _attemptReconnect(reason: 'error: $e');
    } else {
      setState(() {
        _loading = false;
        _isReconnecting = false;
        _error = e;
      });
    }
  }

  /// Tente une reconnexion silencieuse. Le flux reste affiché (dernière frame).
  /// On re-open l'URL pour forcer un re-fetch complet.
  void _attemptReconnect({String? reason}) {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      // Épuisement des tentatives : montrer l'erreur.
      debugPrint('❌ IPTV reconnexion abandonnée après $_maxReconnectAttempts essais');
      _bufferingWatchdog?.cancel();
      setState(() {
        _loading = false;
        _isReconnecting = false;
        _error = reason ?? 'Flux interrompu';
      });
      return;
    }

    _reconnectAttempts++;
    _bufferingWatchdog?.cancel();

    // Délai exponentiel avec plafond : 1.5s, 3s, 6s, ... max 15s.
    final delaySeconds = (1.5 * _reconnectAttempts).clamp(1.5, 15.0);
    debugPrint('🔁 IPTV reconnexion $_reconnectAttempts/$_maxReconnectAttempts '
        'dans ${delaySeconds.toStringAsFixed(1)}s ($reason)');

    setState(() {
      _isReconnecting = true;
      // On garde _loading = false pour ne pas masquer la vidéo avec le spinner.
    });

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: (delaySeconds * 1000).round()), () {
      if (!mounted) return;
      _reopenStream();
    });
  }

  /// Re-open le flux en gardant l'URL déjà résolue (évite un re-fetch inutile).
  Future<void> _reopenStream() async {
    try {
      if (_lastStreamUrl != null) {
        await _player.open(
          Media(_lastStreamUrl!, httpHeaders: _proxy.playerHeaders()),
          play: true,
        );
      } else {
        await _openStreamInternal();
      }
    } catch (e) {
      // Échec du re-open : on relance le cycle de reconnexion.
      if (mounted) _attemptReconnect(reason: 'reopen failed: $e');
    }
  }

  /// La lecture a (re)démarré avec succès : on remet les compteurs à zéro.
  void _onPlaybackResumed() {
    _bufferingWatchdog?.cancel();
    setState(() {
      _loading = false;
      _error = null;
      _isReconnecting = false;
      // IMPORTANT : reset du compteur — chaque nouvelle lecture repart de 0.
      _reconnectAttempts = 0;
    });
    _scheduleHide();
  }

  Future<void> _openStream() async {
    setState(() {
      _loading = true;
      _error = null;
      _reconnectAttempts = 0;
    });
    await _openStreamInternal();
  }

  Future<void> _openStreamInternal() async {
    try {
      final url = await _proxy.streamUrlFor(widget.channel.slug);
      _lastStreamUrl = url;
      await _player.open(
        Media(url, httpHeaders: _proxy.playerHeaders()),
        play: true,
      );
    } catch (e) {
      // Erreur à l'ouverture : tenter une reconnexion silencieuse avant
      // d'afficher l'erreur fatale.
      if (_reconnectAttempts < _maxReconnectAttempts) {
        _attemptReconnect(reason: 'open failed: $e');
      } else if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Chaîne indisponible. Réessayez.';
        });
      }
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _reconnectTimer?.cancel();
    _bufferingWatchdog?.cancel();
    _errorSub?.cancel();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _player.dispose();
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
        return KeyEventResult.ignored;
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Video(controller: _controller, controls: NoVideoControls),
            // Spinner de chargement initial uniquement (pas pendant reconnexion).
            if (_loading && !_isReconnecting) _buildLoading(),
            // Erreur fatale uniquement (reconnexion épuisée).
            if (_error != null && !_isReconnecting) _buildError(),
            // Indicateur de reconnexion discret (ne masque pas la vidéo).
            if (_isReconnecting) _buildReconnectingBadge(),
            if (_showControls && _error == null && !_isReconnecting) _buildControlsOverlay(),
          ],
        ),
      ),
    ),
    );
  }

  /// Petit badge discret en haut à droite pendant la reconnexion.
  /// La vidéo reste visible (dernière frame gelée), l'utilisateur voit juste
  /// que l'app travaille en arrière-plan.
  Widget _buildReconnectingBadge() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                color: Colors.orange,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Reconnexion…',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary, strokeWidth: 2.5),
            ),
            const SizedBox(height: 16),
            Text(
              _reconnectAttempts > 0
                  ? 'Reconnexion $_reconnectAttempts/$_maxReconnectAttempts…'
                  : 'Connexion à ${widget.channel.name}…',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: NeoTheme.errorRed, size: 52),
              const SizedBox(height: 14),
              const Text('Chaîne indisponible',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(_error ?? '',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  _reconnectAttempts = 0;
                  _openStream();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(NeoTheme.radiusSm),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record,
                      color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('EN DIRECT',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
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
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
