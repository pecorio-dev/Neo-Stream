import 'package:flutter/material.dart';
import '../../core/services/watch_progress_service.dart';
import '../../data/models/watch_progress.dart';
import 'resume_watch_dialog.dart';

class AutoResumeDetector extends StatefulWidget {
  final String contentId;
  final String contentType; // 'movie' or 'series'
  final String title;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final Widget child;

  const AutoResumeDetector({
    required this.contentId,
    required this.contentType,
    required this.title,
    required this.onResume,
    required this.onRestart,
    required this.child,
    Key? key,
  }) : super(key: key);

  @override
  State<AutoResumeDetector> createState() => _AutoResumeDetectorState();
}

class _AutoResumeDetectorState extends State<AutoResumeDetector> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowResumeDialog();
    });
  }

  Future<void> _checkAndShowResumeDialog() async {
    try {
      final progress = await WatchProgressService.getProgress(
        contentId: widget.contentId,
        contentType: widget.contentType,
      );

      if (progress != null && !progress.isCompleted && progress.resumePosition > 0) {
        // Only show if user hasn't watched less than 5 seconds
        if (progress.resumePosition > 5) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => ResumeWatchDialog(
                progress: progress,
                onResume: widget.onResume,
                onRestart: widget.onRestart,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error checking resume status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
