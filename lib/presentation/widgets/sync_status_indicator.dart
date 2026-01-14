import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncStatusIndicator extends ConsumerWidget {
  final bool showLabel;
  final double size;

  const SyncStatusIndicator({
    Key? key,
    this.showLabel = true,
    this.size = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Tooltip(
      message: 'Synchronisation locale',
      child: Icon(
        Icons.cloud_done,
        color: Colors.green,
      ),
    );
  }
}

class ResumeProgressBar extends StatelessWidget {
  final String contentId;
  final String contentType;
  final String title;
  final Duration? savedPosition;
  final Duration totalDuration;
  final VoidCallback onResume;
  final VoidCallback onRestart;

  const ResumeProgressBar({
    Key? key,
    required this.contentId,
    required this.contentType,
    required this.title,
    required this.savedPosition,
    required this.totalDuration,
    required this.onResume,
    required this.onRestart,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (savedPosition == null || savedPosition!.inSeconds == 0) {
      return const SizedBox.shrink();
    }

    final progressPercent = totalDuration.inSeconds > 0
        ? (savedPosition!.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    final isCompleted = progressPercent >= 0.95;
    final formattedTime = _formatDuration(savedPosition!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Continuer à regarder',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressPercent,
              minHeight: 4,
              backgroundColor: Colors.grey[700],
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? Colors.green[400]! : Colors.blue[400]!,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCompleted
                ? 'Lecture terminée'
                : '$formattedTime restant',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[400],
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRestart,
                  child: const Text('Recommencer'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onResume,
                  child: Text(isCompleted ? 'Recommencer' : 'Continuer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final remaining = totalDuration.inSeconds - duration.inSeconds;
    if (remaining <= 0) return 'Terminé';
    
    final hours = remaining ~/ 3600;
    final minutes = (remaining % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m restantes';
    } else {
      return '${minutes}m restantes';
    }
  }
}

class SyncSettingsButton extends ConsumerWidget {
  const SyncSettingsButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Icon(Icons.sync);
  }
}
