import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/neo.dart';
import '../config/theme.dart';
import '../services/download_service.dart';
import '../widgets/neo_glass_card.dart';
import 'player_screen.dart';

/// Écran Téléchargements : file d'attente, progression en direct,
/// lecture hors-ligne des fichiers terminés.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final _downloads = DownloadService.instance;

  @override
  void initState() {
    super.initState();
    _downloads.addListener(_onChanged);
  }

  @override
  void dispose() {
    _downloads.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  String _fmtBytes(int bytes) {
    if (bytes <= 0) return '';
    if (bytes >= 1 << 30) return '${(bytes / (1 << 30)).toStringAsFixed(2)} Go';
    if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(1)} Mo';
    if (bytes >= 1 << 10) return '${(bytes / (1 << 10)).toStringAsFixed(0)} Ko';
    return '$bytes o';
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _downloads.tasks;
    return Scaffold(
      backgroundColor: Neo.bgBase(context),
      appBar: AppBar(
        backgroundColor: Neo.bgBase(context),
        title: Text(
          'Téléchargements',
          style: Neo.headlineMedium(context),
        ),
        actions: [
          if (tasks.any((t) =>
              t.status == DownloadStatus.failed ||
              t.status == DownloadStatus.cancelled))
            IconButton(
              tooltip: 'Effacer les terminés',
              icon: const Icon(Icons.cleaning_services_rounded),
              onPressed: _downloads.clearFinished,
            ),
        ],
      ),
      body: tasks.isEmpty ? _buildEmpty() : _buildList(tasks),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: Neo.surfaceGradient(context),
              border: Border.all(
                color: Neo.bgBorder(context).withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Icon(
              Icons.download_rounded,
              size: 40,
              color: Neo.textDisabled(context),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Aucun téléchargement',
            style: Neo.titleLarge(context),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Les films et épisodes téléchargés depuis les fiches apparaîtront ici — regardables hors-ligne.',
              textAlign: TextAlign.center,
              style: Neo.bodyMedium(context)
                  .copyWith(color: Neo.textTertiary(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<DownloadTask> tasks) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: tasks.length,
      itemBuilder: (context, i) {
        final task = tasks[i];
        return Dismissible(
          key: ValueKey(task.id),
          direction: task.status.isActive
              ? DismissDirection.none
              : DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: NeoTheme.errorRed.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
            ),
            child: const Icon(Icons.delete_rounded, color: NeoTheme.errorRed),
          ),
          onDismissed: (_) {
            HapticFeedback.mediumImpact();
            _downloads.remove(task.id);
          },
          child: _DownloadCard(task: task, fmtBytes: _fmtBytes),
        );
      },
    );
  }
}

class _DownloadCard extends StatelessWidget {
  final DownloadTask task;
  final String Function(int) fmtBytes;

  const _DownloadCard({required this.task, required this.fmtBytes});

  @override
  Widget build(BuildContext context) {
    final downloads = DownloadService.instance;
    final active = task.status.isActive;
    final done = task.status == DownloadStatus.completed;
    final failed = task.status == DownloadStatus.failed;

    final (statusLabel, statusColor) = switch (task.status) {
      DownloadStatus.queued => ('En attente…', Neo.textTertiary(context)),
      DownloadStatus.extracting =>
        ('Préparation du lien…', NeoTheme.infoCyan),
      DownloadStatus.downloading => (
          '${(task.progress * 100).toStringAsFixed(0)} %',
          Theme.of(context).colorScheme.primary
        ),
      DownloadStatus.completed => ('Terminé', NeoTheme.successGreen),
      DownloadStatus.failed => ('Échoué', NeoTheme.errorRed),
      DownloadStatus.cancelled => ('Annulé', NeoTheme.warningOrange),
    };

    final bytesLabel = task.status == DownloadStatus.downloading
        ? task.subtitle.contains('·') // HLS → progression par segment
            ? 'segment ${task.receivedBytes}/${task.totalBytes}'
            : '${fmtBytes(task.receivedBytes)} / ${fmtBytes(task.totalBytes)}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeoGlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(NeoTheme.radiusSm),
                    color: statusColor.withValues(alpha: 0.14),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Icon(
                    done
                        ? Icons.play_circle_fill_rounded
                        : active
                            ? Icons.download_rounded
                            : failed
                                ? Icons.error_outline_rounded
                                : Icons.stop_circle_outlined,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Neo.titleMedium(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Neo.bodySmall(context)
                            .copyWith(color: Neo.textTertiary(context)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  statusLabel,
                  style: Neo.labelMedium(context).copyWith(color: statusColor),
                ),
              ],
            ),
            if (active && task.totalBytes > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: task.progress,
                  minHeight: 4,
                  backgroundColor:
                      Neo.bgOverlay(context).withValues(alpha: 0.4),
                  valueColor: AlwaysStoppedAnimation(statusColor),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bytesLabel,
                      style: Neo.labelSmall(context)
                          .copyWith(color: Neo.textTertiary(context)),
                    ),
                  ),
                  Text(
                    task.qualityLabel,
                    style: Neo.labelSmall(context)
                        .copyWith(color: Neo.textTertiary(context)),
                  ),
                ],
              ),
            ],
            if (failed && task.error != null) ...[
              const SizedBox(height: 8),
              Text(
                task.error!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Neo.bodySmall(context)
                    .copyWith(color: NeoTheme.errorRed.withValues(alpha: 0.85)),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (active)
                  _ChipAction(
                    icon: Icons.close_rounded,
                    label: 'Annuler',
                    color: NeoTheme.warningOrange,
                    onTap: () => downloads.cancel(task.id),
                  ),
                if (failed || task.status == DownloadStatus.cancelled) ...[
                  _ChipAction(
                    icon: Icons.refresh_rounded,
                    label: 'Réessayer',
                    color: NeoTheme.infoCyan,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      downloads.retry(task.id);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                _ChipAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Supprimer',
                  color: NeoTheme.errorRed,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    downloads.remove(task.id);
                  },
                ),
                if (done) ...[
                  const SizedBox(width: 8),
                  _ChipAction(
                    icon: Icons.play_arrow_rounded,
                    label: 'Regarder',
                    color: Theme.of(context).colorScheme.primary,
                    filled: true,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlayerScreen(
                            localFilePath: task.filePath,
                            localTitle: task.title,
                            localSubtitle: task.subtitle,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  const _ChipAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? color.withValues(alpha: 0.9) : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: filled ? Neo.readableOn(color) : color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Neo.labelMedium(context).copyWith(
                  color: filled ? Neo.readableOn(color) : color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
