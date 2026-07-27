import '../widgets/universal_video_player.dart';
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
  bool _loadInFlight = false;
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
      final filtered = _selectedCategory == null
          ? List<FstvChannel>.of(flat)
          : grouped[_selectedCategory] ?? const <FstvChannel>[];

      _loadAttempts = 0;
      setState(() {
        _channelsByCategory = grouped;
        _categories = grouped.keys.toList();
        _flat = flat;
        _filtered = filtered;
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
        pageBuilder: (_1, _2, _3) => _LivePlayerScreen(channel: channel),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_1, anim, _2, child) {
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
                  onPressed: _loading ? null : () => _load(forceRefresh: true),
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
        separatorBuilder: (_1, _2) => const SizedBox(width: 10),
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
    if (_loading && _flat.isEmpty) return _buildLoading();
    if (_premiumRequired) return _buildPremiumWall();
    if (_error != null && _flat.isEmpty) return _buildError();
    if (_filtered.isEmpty && _flat.isEmpty) return _buildEmpty();
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
      itemBuilder: (_1, _2) => NeoGlassCard(
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
        return RepaintBoundary(
          child: _ChannelCard(
            key: ValueKey(ch.slug),
            channel: ch,
            onTap: () => _play(ch),
            isLeftEdge: isLeftEdge,
          ),
        );
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
    super.key,
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
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onTap();
            return KeyEventResult.handled;
          }

          if (isTV) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft && !widget.isLeftEdge) {
              return KeyEventResult.ignored;
            }
            if ([LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowRight].contains(event.logicalKey)) {
              return KeyEventResult.ignored;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft && widget.isLeftEdge) {
              return KeyEventResult.ignored;
            }
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
              child: NeoGlassCard(
                padding: const EdgeInsets.all(14),
                accent: ch.categoryColor,
                elevation: (isTV ? isFocused : (_hovered || isFocused)) ? 4 : 0,
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
                            borderRadius: BorderRadius.circular(Neo.radiusMd),
                            border: Border.all(
                              color: ch.categoryColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(ch.categoryIcon, color: ch.categoryColor, size: 22),
                        ),
                        const Spacer(),
                        AnimatedScale(
                          scale: (_hovered || isFocused) ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: ch.categoryColor.withValues(alpha: (_hovered || isFocused) ? 1 : 0.6),
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      ch.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                                color: Neo.successGreen.withValues(alpha: 0.6),
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
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
  UniversalPlayerController? _universalController;
  bool _loading = true;
  String? _error;
  bool _showControls = true;
  Timer? _hideTimer;

  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 8;
  bool _isReconnecting = false;
  Timer? _reconnectTimer;

  List<String> _streamUrls = const [];
  int _sourceIndex = 0;
  int _openGeneration = 0;

  StreamSubscription<String>? _errorSub;

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
    _openStream();
  }

  Future<void> _openStream() async {
    _reconnectTimer?.cancel();
    _openGeneration++;
    _isReconnecting = false;
    setState(() {
      _loading = true;
      _error = null;
      _reconnectAttempts = 0;
    });
    _streamUrls = const [];
    _sourceIndex = 0;
    await _openStreamInternal(refreshSources: true);
  }

  Future<void> _openStreamInternal({required bool refreshSources}) async {
    try {
      if (refreshSources || _streamUrls.isEmpty) {
        _streamUrls = await _proxy.streamUrlsFor(widget.channel.slug);
        _sourceIndex = 0;
      }
      await _openCurrentSource();
    } catch (e) {
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

  Future<void> _openCurrentSource() async {
    if (_streamUrls.isEmpty || _sourceIndex >= _streamUrls.length) {
      _attemptReconnect(reason: 'aucune source disponible');
      return;
    }

    final generation = ++_openGeneration;
    final url = _streamUrls[_sourceIndex];
    final headers = _proxy.playerHeaders();

    try {
      _universalController?.dispose();
      _universalController = UniversalPlayerController(url: url, headers: headers);

      _errorSub?.cancel();
      _errorSub = _universalController!.errorStream.listen((err) {
        if (!mounted || generation != _openGeneration) return;
        _attemptReconnect(reason: 'erreur flux: $err');
      });

      await _universalController!.initialize();

      if (mounted && generation == _openGeneration) {
        setState(() {
          _loading = false;
          _error = null;
          _isReconnecting = false;
        });
      }
    } catch (e) {
      if (mounted && generation == _openGeneration) {
        _attemptReconnect(reason: 'ouverture impossible: $e');
      }
    }
  }

  void _attemptReconnect({required String reason}) {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (mounted) {
        setState(() {
          _loading = false;
          _isReconnecting = false;
          _error = 'Impossible de charger le flux en direct.';
        });
      }
      return;
    }

    _reconnectAttempts++;
    if (mounted) {
      setState(() {
        _isReconnecting = true;
      });
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: 2 * _reconnectAttempts), () {
      if (!mounted) return;
      _sourceIndex = (_sourceIndex + 1) % (_streamUrls.isNotEmpty ? _streamUrls.length : 1);
      _openStreamInternal(refreshSources: _sourceIndex == 0);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _reconnectTimer?.cancel();
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
          _toggleControls();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.arrowDown) {
          if (!_showControls) {
            setState(() => _showControls = true);
          }
          _scheduleHide();
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
              if (_universalController != null)
                UniversalVideoView(controller: _universalController!),
              if (_loading && !_isReconnecting) _buildLoading(),
              if (_error != null && !_isReconnecting) _buildError(),
              if (_isReconnecting) _buildReconnectingBadge(),
              if (_showControls && _error == null && !_isReconnecting) _buildControlsOverlay(),
            ],
          ),
        ),
      ),
    );
  }

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
