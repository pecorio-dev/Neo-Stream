import 'dart:async';
import '../models/watch_progress.dart';
import 'watch_progress_service.dart';
import 'sync/auto_sync_service.dart';
import 'local_storage/watch_progress_local_service.dart';

class WatchProgressAutoSaveService {
  static const String _tag = 'WatchProgressAutoSaveService';
  static const int _autoSaveIntervalSeconds = 10;
  static const int _minProgressToSave = 30;

  final AutoSyncService? _autoSyncService;
  final WatchProgressLocalService _localService;

  Timer? _autoSaveTimer;
  bool _isAutoSaving = false;

  WatchProgressAutoSaveService({
    AutoSyncService? autoSyncService,
    WatchProgressLocalService? localService,
  })  : _autoSyncService = autoSyncService,
        _localService = localService ?? WatchProgressLocalService();

  bool get isAutoSaving => _isAutoSaving;

  /// Démarre l'auto-sauvegarde pour un contenu
  void startAutoSave({
    required String contentId,
    required String contentType,
    required String title,
    required Duration totalDuration,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeTitle,
    required Duration Function() getCurrentPosition,
  }) {
    print('$_tag: Starting auto-save for $title');

    _autoSaveTimer?.cancel();
    _isAutoSaving = true;

    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: _autoSaveIntervalSeconds),
      (timer) async {
        try {
          final position = getCurrentPosition();

          if (position.inSeconds >= _minProgressToSave) {
            await _saveProgressLocally(
              contentId: contentId,
              contentType: contentType,
              title: title,
              position: position,
              duration: totalDuration,
              seasonNumber: seasonNumber,
              episodeNumber: episodeNumber,
              episodeTitle: episodeTitle,
            );

            // Vérifier si une synchronisation est nécessaire
            if (_autoSyncService != null) {
              await _autoSyncService!.syncIfNeeded();
            }
          }
        } catch (e) {
          print('$_tag: Auto-save error: $e');
        }
      },
    );
  }

  /// Arrête l'auto-sauvegarde
  Future<void> stopAutoSave() async {
    print('$_tag: Stopping auto-save');
    _autoSaveTimer?.cancel();
    _isAutoSaving = false;
  }

  /// Sauvegarde la progression localement
  Future<void> _saveProgressLocally({
    required String contentId,
    required String contentType,
    required String title,
    required Duration position,
    required Duration duration,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeTitle,
  }) async {
    try {
      final watchProgress = WatchProgress(
        contentId: contentId,
        contentType: contentType,
        title: title,
        position: position.inSeconds,
        duration: duration.inSeconds,
        lastWatched: DateTime.now(),
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        episodeTitle: episodeTitle,
      );

      // Sauvegarder dans les services locaux
      await WatchProgressService.saveProgress(watchProgress);
      await _localService.saveProgress(watchProgress);

      print('$_tag: Progress saved locally: ${watchProgress.formattedPosition}/${watchProgress.formattedDuration}');
    } catch (e) {
      print('$_tag: Error saving progress locally: $e');
    }
  }

  /// Sauvegarde final à la fermeture du lecteur
  Future<void> saveOnExit({
    required String contentId,
    required String contentType,
    required String title,
    required Duration position,
    required Duration duration,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeTitle,
  }) async {
    print('$_tag: Saving progress on exit');

    try {
      // Sauvegarder la dernière position
      await _saveProgressLocally(
        contentId: contentId,
        contentType: contentType,
        title: title,
        position: position,
        duration: duration,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        episodeTitle: episodeTitle,
      );

      // Forcer une synchronisation immédiate
      if (_autoSyncService != null) {
        print('$_tag: Triggering sync on exit');
        await _autoSyncService!.forceSyncNow();
      }

      print('$_tag: ✅ Progress saved on exit');
    } catch (e) {
      print('$_tag: Error saving on exit: $e');
    }
  }

  /// Nettoie les ressources
  void dispose() {
    _autoSaveTimer?.cancel();
    print('$_tag: Disposed');
  }
}
