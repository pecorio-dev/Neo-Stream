import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/watch_progress_service.dart';
import '../../data/models/watch_progress.dart';
import '../widgets/sync_status_indicator.dart';

class ResumeWatchSection extends ConsumerWidget {
  final String contentId;
  final String contentType;
  final String title;
  final Duration? duration;
  final int? seasonNumber;
  final int? episodeNumber;
  final VoidCallback onResumePressed;
  final VoidCallback onRestartPressed;

  const ResumeWatchSection({
    Key? key,
    required this.contentId,
    required this.contentType,
    required this.title,
    required this.duration,
    required this.onResumePressed,
    required this.onRestartPressed,
    this.seasonNumber,
    this.episodeNumber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<WatchProgress?>(
      future: WatchProgressService.getProgress(
        contentId: contentId,
        contentType: contentType,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final progress = snapshot.data!;
        final progressPercentage = duration != null
            ? (progress.position / duration!.inSeconds).clamp(0.0, 1.0)
            : 0.0;

        // Ne pas afficher si la lecture est déjà terminée
        if (progressPercentage >= 0.95) {
          return const SizedBox.shrink();
        }

        final formattedPosition = _formatDuration(Duration(seconds: progress.position));
        final formattedRemaining =
            _formatDuration(Duration(seconds: duration!.inSeconds - progress.position));

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue[400]!.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête avec titre et statut sync
              Row(
                children: [
                  const Icon(
                    Icons.bookmark,
                    size: 20,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Continuer à regarder',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SyncStatusIndicator(
                    showLabel: false,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progression
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressPercentage,
                      minHeight: 6,
                      backgroundColor: Colors.grey[700],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue[400]!,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formattedPosition,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[400],
                            ),
                      ),
                      Text(
                        '$formattedRemaining restant',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[400],
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRestartPressed,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Recommencer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onResumePressed,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Continuer'),
                    ),
                  ),
                ],
              ),

              // Info de synchronisation
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_done,
                      size: 16,
                      color: Colors.green[400],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Synchronisé avec Google Drive',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green[400],
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    } else {
      return '${seconds}s';
    }
  }
}
