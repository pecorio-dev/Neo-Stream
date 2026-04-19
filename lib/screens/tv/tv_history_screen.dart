import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/tv_config.dart';
import '../../models/content.dart';
import '../../services/api_service.dart';
import '../../widgets/tv_wrapper.dart';
import '../../widgets/tv_focusable_card.dart';
import '../detail_screen.dart';

class TVHistoryScreen extends StatefulWidget {
  const TVHistoryScreen({super.key});

  @override
  State<TVHistoryScreen> createState() => _TVHistoryScreenState();
}

class _TVHistoryScreenState extends State<TVHistoryScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final items = await _api.getHistory();
      if (!mounted) return;
      setState(() {
        _items = items.where((item) {
          final poster = item['poster']?.toString() ?? '';
          return Content.resolvePosterUrl(poster).isNotEmpty;
        }).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
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
    if (raw.isEmpty) return 'Recemment';
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
        content: const Text('Toutes les reprises seront supprimees.', style: TextStyle(color: TVTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteHistory();
                if (!mounted) return;
                setState(() => _items = []);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Historique supprime'), backgroundColor: TVTheme.accentRed),
                );
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
    return TVWrapper(
      title: 'Historique',
      showBackButton: true,
      onBack: () => Navigator.pop(context),
      actions: [
        if (_items.isNotEmpty)
          GestureDetector(
            onTap: _confirmClearHistory,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: TVTheme.errorRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: TVTheme.errorRed.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline, color: TVTheme.errorRed, size: 18),
                  SizedBox(width: 6),
                  Text('Vider', style: TextStyle(color: TVTheme.errorRed, fontSize: 13)),
                ],
              ),
            ),
          ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: TVTheme.accentRed))
          : _items.isEmpty
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.history_toggle_off, size: 80, color: TVTheme.textDisabled),
          SizedBox(height: 16),
          Text('Aucun historique', style: TextStyle(color: TVTheme.textPrimary, fontSize: 22)),
          SizedBox(height: 8),
          Text('Vos films et series regardes apparaitront ici.', style: TextStyle(color: TVTheme.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildContent() {
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
          onTap: () {
            setState(() => _focusedIndex = index);
            final contentId = _safeInt(item['content_id']);
            if (contentId > 0) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(contentId: contentId)));
            }
          },
          onFocus: () => setState(() => _focusedIndex = index),
          formatDate: _formatDate,
          formatDuration: _formatDuration,
          safeDouble: _safeDouble,
          safeInt: _safeInt,
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isFocused;
  final VoidCallback onTap;
  final VoidCallback onFocus;
  final String Function(String) formatDate;
  final String Function(dynamic) formatDuration;
  final double Function(dynamic) safeDouble;
  final int Function(dynamic, [int]) safeInt;

  const _HistoryCard({
    required this.item,
    required this.isFocused,
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
      autoFocus: false,
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
                    errorWidget: (_, __, ___) => const Center(child: Icon(Icons.movie, color: TVTheme.textDisabled, size: 40)),
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
