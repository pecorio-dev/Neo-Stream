import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/content.dart';
import '../services/api_service.dart';
import 'detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final items = await _api.getHistory();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items.where((item) {
          final poster = item['poster']?.toString() ?? '';
          return Content.resolvePosterUrl(poster).isNotEmpty;
        }).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
    }
  }

  int _safeInt(dynamic value, [int fallback = 0]) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _safeDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDuration(dynamic seconds) {
    final value = _safeInt(seconds);
    if (value <= 0) {
      return '0:00';
    }
    final hours = value ~/ 3600;
    final minutes = (value % 3600) ~/ 60;
    final remainder = value % 60;
    if (hours > 0) {
      return '${hours}h${minutes.toString().padLeft(2, '0')}';
    }
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) {
      return 'Recemment';
    }
    try {
      final date = DateTime.parse(raw).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return raw.split(' ').first;
    }
  }

  Future<void> _confirmClearHistory() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF18182A),
              title: Text(
                'Supprimer l historique ?',
                style: NeoTheme.titleLarge(context),
              ),
              content: Text(
                'Toutes les reprises de lecture seront effacees.',
                style: NeoTheme.bodyMedium(context),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    'Annuler',
                    style: NeoTheme.labelLarge(
                      context,
                    ).copyWith(color: NeoTheme.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    'Supprimer',
                    style: NeoTheme.labelLarge(
                      context,
                    ).copyWith(color: NeoTheme.errorRed),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    try {
      await _api.deleteHistory();
      if (!mounted) {
        return;
      }
      setState(() => _items = <Map<String, dynamic>>[]);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Historique supprime'),
          backgroundColor: NeoTheme.primaryRed,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $error'),
          backgroundColor: NeoTheme.errorRed,
        ),
      );
    }
  }

  void _openDetail(int contentId) {
    if (contentId <= 0) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(contentId: contentId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = NeoTheme.screenPadding(context);

    return Scaffold(
      backgroundColor: NeoTheme.bgBase,
      appBar: AppBar(
        backgroundColor: NeoTheme.bgBase,
        title: Text('Historique', style: NeoTheme.headlineMedium(context)),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              onPressed: _confirmClearHistory,
              tooltip: 'Effacer',
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: NeoTheme.errorRed,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: NeoTheme.primaryRed),
            )
          : RefreshIndicator(
              onRefresh: _loadHistory,
              color: NeoTheme.primaryRed,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        padding.left,
                        12,
                        padding.right,
                        18,
                      ),
                      child: _buildSummaryCard(context),
                    ),
                  ),
                  if (_items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(context),
                    )
                  else
                    _buildHistorySliver(context),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16163A), Color(0xFF0A0A18)],
        ),
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(
          color: NeoTheme.primaryRed.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: NeoTheme.shadowLevel2,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: NeoTheme.primaryRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: NeoTheme.primaryRed.withValues(alpha: 0.2), width: 0.5),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: NeoTheme.primaryRed,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reprises recentes', style: NeoTheme.titleLarge(context)),
                const SizedBox(height: 4),
                Text(
                  '${_items.length} contenus suivis sur cet appareil et votre session.',
                  style: NeoTheme.bodySmall(context),
                ),
              ],
            ),
          ),
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: _confirmClearHistory,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: NeoTheme.errorRed,
              ),
              label: Text(
                'Vider',
                style: NeoTheme.labelLarge(
                  context,
                ).copyWith(color: NeoTheme.errorRed),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: NeoTheme.surfaceGradient,
                border: Border.all(
                  color: NeoTheme.bgBorder.withValues(alpha: 0.15),
                ),
              ),
              child: const Icon(
                Icons.history_toggle_off_rounded,
                size: 42,
                color: NeoTheme.textDisabled,
              ),
            ),
            const SizedBox(height: 18),
            Text('Aucun historique', style: NeoTheme.titleLarge(context)),
            const SizedBox(height: 8),
            Text(
              'Vos films et series regardes apparaitront ici.',
              textAlign: TextAlign.center,
              style: NeoTheme.bodyMedium(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySliver(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final padding = NeoTheme.screenPadding(context);

    if (width >= 980) {
      final crossAxisCount = width >= 1400 ? 5 : width >= 1100 ? 4 : width >= 700 ? 3 : 2;
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, 32),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _HistoryGridCard(
              item: _items[index],
              formatDate: _formatDate,
              formatDuration: _formatDuration,
              safeDouble: _safeDouble,
              safeInt: _safeInt,
              onTap: _openDetail,
            ),
            childCount: _items.length,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: NeoTheme.gridSpacing(context),
            mainAxisSpacing: NeoTheme.gridSpacing(context),
            childAspectRatio: width >= 1400 ? 0.88 : width >= 1100 ? 0.85 : 0.82,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, 28),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == _items.length - 1 ? 0 : 12,
            ),
            child: _HistoryListCard(
              item: _items[index],
              formatDate: _formatDate,
              formatDuration: _formatDuration,
              safeDouble: _safeDouble,
              safeInt: _safeInt,
              onTap: _openDetail,
            ),
          );
        }, childCount: _items.length),
      ),
    );
  }
}

class _HistoryListCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(String raw) formatDate;
  final String Function(dynamic seconds) formatDuration;
  final double Function(dynamic value) safeDouble;
  final int Function(dynamic value, [int fallback]) safeInt;
  final void Function(int contentId) onTap;

  const _HistoryListCard({
    required this.item,
    required this.formatDate,
    required this.formatDuration,
    required this.safeDouble,
    required this.safeInt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final contentId = safeInt(item['content_id']);
    final poster = item['poster']?.toString() ?? '';
    final title = item['title']?.toString() ?? 'Inconnu';
    final type = item['content_type']?.toString() ?? 'film';
    final rating = item['rating'];
    final progress = (safeDouble(item['progress_percent']) / 100).clamp(
      0.0,
      1.0,
    );
    final episodeId = item['episode_id']?.toString() ?? '';
    final updatedAt = formatDate(item['updated_at']?.toString() ?? '');

    return InkWell(
      borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
      onTap: () => onTap(contentId),
      child: Container(
        height: NeoTheme.searchCardHeight(context),
        decoration: BoxDecoration(
          gradient: NeoTheme.surfaceGradient,
          borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
          border: Border.all(
            color: NeoTheme.bgBorder.withValues(alpha: 0.15),
            width: 0.5,
          ),
          boxShadow: NeoTheme.shadowLevel1,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(width: 108, child: _Poster(poster: poster)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: NeoTheme.titleMedium(context),
                          ),
                        ),
                        if (rating != null) ...[
                          const SizedBox(width: 10),
                          _RatingPill(value: rating.toString()),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaPill(
                          label: type == 'serie' ? 'Serie' : 'Film',
                          color: type == 'serie'
                              ? NeoTheme.infoCyan
                              : NeoTheme.primaryRed,
                        ),
                        if (episodeId.isNotEmpty)
                          _MetaPill(
                            label: episodeId,
                            color: NeoTheme.purpleAccent,
                          ),
                        _MetaPill(
                          label: updatedAt,
                          color: NeoTheme.textTertiary,
                          subtle: true,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: NeoTheme.bgBorder.withValues(alpha: 0.2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: NeoTheme.primaryRed,
                                  boxShadow: [
                                    BoxShadow(
                                      color: NeoTheme.primaryRed.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      offset: const Offset(0, 0),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${formatDuration(item['current_time'])} / ${formatDuration(item['total_duration'])}',
                          style: NeoTheme.labelMedium(
                            context,
                          ).copyWith(color: NeoTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryGridCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(String raw) formatDate;
  final String Function(dynamic seconds) formatDuration;
  final double Function(dynamic value) safeDouble;
  final int Function(dynamic value, [int fallback]) safeInt;
  final void Function(int contentId) onTap;

  const _HistoryGridCard({
    required this.item,
    required this.formatDate,
    required this.formatDuration,
    required this.safeDouble,
    required this.safeInt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final contentId = safeInt(item['content_id']);
    final poster = item['poster']?.toString() ?? '';
    final title = item['title']?.toString() ?? 'Inconnu';
    final type = item['content_type']?.toString() ?? 'film';
    final rating = item['rating'];
    final progress = (safeDouble(item['progress_percent']) / 100).clamp(
      0.0,
      1.0,
    );
    final episodeId = item['episode_id']?.toString() ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
      onTap: () => onTap(contentId),
      child: Container(
        decoration: BoxDecoration(
          gradient: NeoTheme.surfaceGradient,
          borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
          border: Border.all(
            color: NeoTheme.bgBorder.withValues(alpha: 0.15),
            width: 0.5,
          ),
          boxShadow: NeoTheme.shadowLevel1,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 13,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Poster(poster: poster),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _MetaPill(
                      label: type == 'serie' ? 'Serie' : 'Film',
                      color: type == 'serie'
                          ? NeoTheme.infoCyan
                          : NeoTheme.primaryRed,
                    ),
                  ),
                  if (rating != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _RatingPill(value: rating.toString()),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 10,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NeoTheme.titleMedium(context),
                    ),
                    const SizedBox(height: 8),
                    if (episodeId.isNotEmpty)
                      Text(
                        episodeId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NeoTheme.bodySmall(
                          context,
                        ).copyWith(color: NeoTheme.purpleAccent),
                      ),
                    const Spacer(),
                    Text(
                      formatDate(item['updated_at']?.toString() ?? ''),
                      style: NeoTheme.labelSmall(context),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: NeoTheme.bgBorder.withValues(alpha: 0.2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: NeoTheme.primaryRed,
                            boxShadow: [
                              BoxShadow(
                                color: NeoTheme.primaryRed.withValues(alpha: 0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${formatDuration(item['current_time'])} / ${formatDuration(item['total_duration'])}',
                      style: NeoTheme.labelMedium(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  final String poster;

  const _Poster({required this.poster});

  @override
  Widget build(BuildContext context) {
    if (poster.isEmpty) {
      return Container(
        color: NeoTheme.bgElevated,
        child: const Icon(Icons.movie_rounded, color: NeoTheme.textDisabled),
      );
    }

    return CachedNetworkImage(
      imageUrl: Content.resolvePosterUrl(poster),
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: NeoTheme.bgElevated),
      errorWidget: (_, __, ___) {
        return Container(
          color: NeoTheme.bgElevated,
          child: const Icon(Icons.movie_rounded, color: NeoTheme.textDisabled),
        );
      },
    );
  }
}

class _RatingPill extends StatelessWidget {
  final String value;

  const _RatingPill({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: NeoTheme.prestigeGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NeoTheme.prestigeGold.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_rounded,
            size: 14,
            color: NeoTheme.prestigeGold,
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: NeoTheme.labelMedium(
              context,
            ).copyWith(color: NeoTheme.prestigeGold),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool subtle;

  const _MetaPill({
    required this.label,
    required this.color,
    this.subtle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: subtle ? 0.08 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Text(
        label,
        style: NeoTheme.labelMedium(
          context,
        ).copyWith(color: subtle ? NeoTheme.textSecondary : color),
      ),
    );
  }
}
