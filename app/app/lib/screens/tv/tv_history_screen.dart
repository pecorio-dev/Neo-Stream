import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/tv_config.dart';
import '../../models/content.dart';
import '../../services/api_service.dart';
import '../../widgets/tv_wrapper.dart';
import '../../widgets/tv_focusable_card.dart';
import 'tv_detail_screen.dart';

class TVHistoryScreen extends StatefulWidget {
  final bool embedded;
  const TVHistoryScreen({super.key, this.embedded = false});

  @override
  State<TVHistoryScreen> createState() => _TVHistoryScreenState();
}

class _TVHistoryScreenState extends State<TVHistoryScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  // H7 : vrai état erreur distinct du vide (au lieu du faux "vide").
  bool _hasError = false;
  // H1 : autofocus consommé une seule fois à l'entrée.
  bool _didInitialAutofocus = false;
  // H1/H3 : nœuds pour autofocus entrée (Vider) et restore après Supprimer.
  final FocusNode _clearFocusNode = FocusNode(debugLabel: 'clearHistory');
  final FocusNode _retryFocusNode = FocusNode(debugLabel: 'retryHistory');
  final FocusNode _emptyReloadFocusNode = FocusNode(debugLabel: 'emptyReload');
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _clearFocusNode.dispose();
    _retryFocusNode.dispose();
    _emptyReloadFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final items = await _api.getHistory();
      if (!mounted) return;
      setState(() {
        _items = items.where((item) {
          final poster = item['poster']?.toString() ?? '';
          return Content.resolvePosterUrl(poster).isNotEmpty;
        }).toList();
        _isLoading = false;
        _hasError = false;
        if (_focusedIndex >= _items.length) _focusedIndex = 0;
      });
      _requestInitialFocus();
    } catch (_) {
      if (!mounted) return;
      // H7 : erreur réseau/API -> état erreur, pas état vide.
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (FocusManager.instance.primaryFocus == null) {
          _retryFocusNode.requestFocus();
        }
      });
    }
  }

  /// H1 : autofocus à l'entrée sur Vider (si liste non vide), sinon la
  /// 1re carte s'autofocus via son flag (index 0). Consommé une fois.
  void _requestInitialFocus() {
    if (_didInitialAutofocus) return;
    _didInitialAutofocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (FocusManager.instance.primaryFocus != null) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      if (_items.isNotEmpty) {
        _clearFocusNode.requestFocus();
      }
      // Si vide : le bouton Recharger de l'empty state a autoFocus:true.
      // Si erreur : le bouton Réessayer a autoFocus:true + fallback ci-dessus.
    });
  }

  /// H3 : après Supprimer (vider), restaure le focus sur le bouton
  /// Recharger de l'état vide (Vider ayant disparu, header en fallback
  /// via traversal). Appelé après le clear réussi.
  void _restoreFocusAfterClear() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (FocusManager.instance.primaryFocus == null) {
        _emptyReloadFocusNode.requestFocus();
      }
    });
  }

  int _safeInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _safeDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDuration(dynamic seconds) {
    final value = _safeInt(seconds);
    if (value <= 0) return '0:00';
    final hours = value ~/ 3600;
    final minutes = (value % 3600) ~/ 60;
    final remainder = value % 60;
    if (hours > 0) return '${hours}h${minutes.toString().padLeft(2, '0')}';
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return 'Récemment';
    try {
      final date = DateTime.parse(raw).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return raw.split(' ').first;
    }
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TVTheme.surfaceColor,
        title: const Text('Supprimer historique ?', style: TextStyle(color: TVTheme.textPrimary)),
        content: const Text('Toutes les reprises seront supprimées.', style: TextStyle(color: TVTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteHistory();
                if (!mounted) return;
                setState(() {
                  _items = [];
                  _focusedIndex = 0;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Historique supprimé'), backgroundColor: TVTheme.accentRed),
                );
                // H3 : Vider a disparu -> restore sur Recharger (état vide).
                _restoreFocusAfterClear();
              } catch (_) {}
            },
            style: FilledButton.styleFrom(backgroundColor: TVTheme.errorRed),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator(color: TVTheme.accentRed))
        : _hasError
            ? _buildError()
            : _items.isEmpty
                ? _buildEmptyState()
                : _buildContent();

    if (widget.embedded) {
      return Scaffold(
        backgroundColor: TVTheme.backgroundDark,
        body: Container(
          decoration: TVTheme.screenDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                child: Row(
                  children: [
                    const Text('Historique', style: TextStyle(color: TVTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (_items.isNotEmpty)
                      TVFocusableCard(
                        // H1 : autofocus à l'entrée sur Vider.
                        focusNode: _clearFocusNode,
                        autoFocus: !_didInitialAutofocus,
                        onTap: _confirmClearHistory,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        borderRadius: BorderRadius.circular(8),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline, color: TVTheme.errorRed, size: 18),
                            SizedBox(width: 6),
                            Text('Vider', style: TextStyle(color: TVTheme.errorRed, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return TVWrapper(
      title: 'Historique',
      showBackButton: true,
      onBack: () => Navigator.pop(context),
      actions: [
        if (_items.isNotEmpty)
          TVFocusableCard(
            // H1 : autofocus à l'entrée sur Vider (mode non-embedded).
            // H3 : cible de restore quand la liste est encore non vide.
            focusNode: _clearFocusNode,
            autoFocus: !_didInitialAutofocus,
            onTap: _confirmClearHistory,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            borderRadius: BorderRadius.circular(8),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline, color: TVTheme.errorRed, size: 18),
                SizedBox(width: 6),
                Text('Vider', style: TextStyle(color: TVTheme.errorRed, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
      ],
      child: content,
    );
  }

  /// H7 : état erreur réel avec Réessayer focusable (autofocus).
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 64, color: TVTheme.errorRed),
          const SizedBox(height: 16),
          const Text('Impossible de charger l\'historique',
              style: TextStyle(color: TVTheme.textPrimary, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Vérifiez votre connexion puis réessayez.',
              style: TextStyle(color: TVTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          TVFocusableCard(
            focusNode: _retryFocusNode,
            autoFocus: true,
            onTap: _loadHistory,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, color: Colors.white),
                SizedBox(width: 8),
                Text('Réessayer',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_toggle_off, size: 80, color: TVTheme.textDisabled)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 1200.ms)
              .then()
              .shimmer(duration: 1800.ms, color: TVTheme.accentRed.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('Aucun historique', style: TextStyle(color: TVTheme.textPrimary, fontSize: 22)),
          const SizedBox(height: 8),
          const Text('Vos films et séries regardés apparaîtront ici.', style: TextStyle(color: TVTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 24),
          // H3 : cible de restore après Supprimer (Vider disparu) + évite
          // le focus mort quand l'état vide est affiché à l'entrée.
          TVFocusableCard(
            focusNode: _emptyReloadFocusNode,
            autoFocus: true,
            onTap: _loadHistory,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Recharger',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // H4 (audit) : documenté sans changement risqué — on garde la navigation
    // push simple vers TVDetailScreen et le filtrage poster existant tels
    // quels ; aucun remaniement du grid/focus traversal (risque de régression
    // D-pad supérieur au gain).
    return GridView.builder(
      padding: const EdgeInsets.all(32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.7,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final isFocused = _focusedIndex == index;
        return _HistoryCard(
          item: item,
          isFocused: isFocused,
          // H1 : si Vider indisponible au traversal, la 1re carte prend
          // l'autofocus d'entrée (Vider reste prioritaire car construit avant).
          autoFocus: index == 0 && !_didInitialAutofocus,
          onTap: () {
            setState(() => _focusedIndex = index);
            final contentId = _safeInt(item['content_id']);
            if (contentId > 0) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => TVDetailScreen(contentId: contentId)));
            }
          },
          onFocus: () => setState(() => _focusedIndex = index),
          formatDate: _formatDate,
          formatDuration: _formatDuration,
          safeDouble: _safeDouble,
          safeInt: _safeInt,
        )
            .animate()
            .fadeIn(duration: 300.ms, delay: Duration(milliseconds: (index % 8) * 50))
            .scale(
              begin: const Offset(0.94, 0.94),
              duration: 300.ms,
              curve: Curves.easeOutCubic,
              delay: Duration(milliseconds: (index % 8) * 50),
            );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isFocused;
  final bool autoFocus;
  final VoidCallback onTap;
  final VoidCallback onFocus;
  final String Function(String) formatDate;
  final String Function(dynamic) formatDuration;
  final double Function(dynamic) safeDouble;
  final int Function(dynamic, [int]) safeInt;

  const _HistoryCard({
    required this.item,
    required this.isFocused,
    this.autoFocus = false,
    required this.onTap,
    required this.onFocus,
    required this.formatDate,
    required this.formatDuration,
    required this.safeDouble,
    required this.safeInt,
  });

  @override
  Widget build(BuildContext context) {
    final poster = item['poster']?.toString() ?? '';
    final title = item['title']?.toString() ?? 'Inconnu';
    final type = item['content_type']?.toString() ?? 'film';
    final progress = (safeDouble(item['progress_percent']) / 100).clamp(0.0, 1.0);
    final episodeId = item['episode_id']?.toString() ?? '';
    final currentTime = item['current_time'];
    final totalDuration = item['total_duration'];

    return TVFocusableCard(
      autoFocus: autoFocus,
      onTap: onTap,
      onFocus: onFocus,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: TVTheme.cardColor,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CachedNetworkImage(
                    imageUrl: Content.resolvePosterUrl(poster),
                    fit: BoxFit.cover,
                    errorWidget: (_1, _2, _3) => const Center(child: Icon(Icons.movie, color: TVTheme.textDisabled, size: 40)),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: type == 'serie' ? TVTheme.infoCyan.withValues(alpha: 0.9) : TVTheme.accentRed.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(type == 'serie' ? 'Serie' : 'Film', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (episodeId.isNotEmpty)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                      child: Text(episodeId, style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
                if (progress > 0)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(TVTheme.accentRed),
                      minHeight: 3,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TVTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 10, color: TVTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${formatDuration(currentTime)} / ${formatDuration(totalDuration)}',
                      style: const TextStyle(color: TVTheme.textSecondary, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
