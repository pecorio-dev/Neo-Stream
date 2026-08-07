import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/neo.dart';
import '../config/theme.dart';
import '../services/download_service.dart';

/// Bouton icône de téléchargement réactif (état lu en direct sur le service) :
/// télécharger → en file/extraction → progression % → téléchargé.
class DownloadIconButton extends StatelessWidget {
  final String sourceUrl;
  final Future<void> Function() onStart;
  final double size;

  const DownloadIconButton({
    super.key,
    required this.sourceUrl,
    required this.onStart,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DownloadService.instance,
      builder: (context, _) {
        final service = DownloadService.instance;
        DownloadTask? task;
        for (final t in service.tasks) {
          if (t.sourceUrl == sourceUrl) {
            task = t;
            break;
          }
        }

        final done = task != null &&
            task.status == DownloadStatus.completed &&
            task.filePath != null;
        final active = task != null && task.status.isActive;

        return Tooltip(
          message: done
              ? 'Téléchargé (hors-ligne)'
              : active
                  ? 'Téléchargement en cours…'
                  : 'Télécharger (hors-ligne)',
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: done || active
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onStart();
                  },
            onLongPress: active
                ? () {
                    HapticFeedback.mediumImpact();
                    service.cancel(task!.id);
                  }
                : (done
                    ? () {
                        HapticFeedback.mediumImpact();
                        service.remove(task!.id);
                      }
                    : null),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: active
                  ? SizedBox(
                      width: size * 0.72,
                      height: size * 0.72,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: task!.progress,
                            strokeWidth: 2.2,
                            color: Neo.accentColor(context),
                          ),
                          Icon(
                            Icons.close_rounded,
                            size: size * 0.42,
                            color: Neo.textTertiary(context),
                          ),
                        ],
                      ),
                    )
                  : Icon(
                      done
                          ? Icons.download_done_rounded
                          : Icons.download_rounded,
                      size: size,
                      color: done
                          ? NeoTheme.successGreen
                          : Neo.textSecondary(context),
                    ),
            ),
          ),
        );
      },
    );
  }
}
