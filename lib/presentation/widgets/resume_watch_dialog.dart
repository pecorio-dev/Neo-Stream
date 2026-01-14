import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/watch_progress.dart';

class ResumeWatchDialog extends StatelessWidget {
  final WatchProgress progress;
  final VoidCallback onResume;
  final VoidCallback onRestart;

  const ResumeWatchDialog({
    required this.progress,
    required this.onResume,
    required this.onRestart,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalDuration = Duration(seconds: progress.duration);
    final resumePosition = Duration(seconds: progress.resumePosition);
    final watched = ((progress.resumePosition / progress.duration) * 100).toStringAsFixed(1);

    return AlertDialog(
      backgroundColor: AppColors.cyberBlack,
      title: const Text(
        'Reprendre la lecture',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            progress.title,
            style: const TextStyle(
              color: AppColors.neonBlue,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Vous avez regardé $watched% de ce contenu',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress.resumePosition / progress.duration,
                  backgroundColor: Colors.grey.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonBlue),
                  minHeight: 4,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${resumePosition.inMinutes}m ${(resumePosition.inSeconds % 60).toString().padLeft(2, '0')}s',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Durée totale: ${totalDuration.inMinutes}m ${(totalDuration.inSeconds % 60).toString().padLeft(2, '0')}s',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onRestart();
          },
          child: const Text(
            'Recommencer',
            style: TextStyle(color: AppColors.neonPink),
          ),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            onResume();
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.neonBlue,
          ),
          child: const Text(
            'Reprendre',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
