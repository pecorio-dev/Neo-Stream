import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/watch_progress.dart';
import '../../core/services/watch_progress_service.dart';

final watchProgressProvider = ChangeNotifierProvider((ref) => WatchProgressProvider());

class WatchProgressProvider extends ChangeNotifier {
  List<WatchProgress> _progress = [];
  bool _isLoading = false;
  String _errorMessage = '';

  List<WatchProgress> get progress => _progress;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get hasError => _errorMessage.isNotEmpty;

  /// Load all watch progress
  Future<void> loadProgress() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _progress = await WatchProgressService.getAllProgress();
      _isLoading = false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
    }
    
    notifyListeners();
  }

  /// Add or update progress
  Future<void> saveProgress({
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
      await WatchProgressService.saveProgress(
        contentId: contentId,
        contentType: contentType,
        title: title,
        position: position,
        duration: duration,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        episodeTitle: episodeTitle,
      );
      
      // Reload progress after saving
      await loadProgress();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Remove progress by ID
  Future<void> removeProgress(String progressId) async {
    try {
      await WatchProgressService.removeProgress(progressId);
      
      // Remove from local list
      _progress.removeWhere((p) => p.id == progressId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Clear all progress
  Future<void> clearAllProgress() async {
    try {
      await WatchProgressService.clearAllProgress();
      _progress.clear();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Get recent progress (for continue watching)
  Future<List<WatchProgress>> getRecentProgress({int limit = 10}) async {
    try {
      return await WatchProgressService.getRecentProgress(limit: limit);
    } catch (e) {
      return [];
    }
  }

  /// Get progress for specific content
  Future<WatchProgress?> getProgressForContent({
    required String contentId,
    required String contentType,
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    try {
      return await WatchProgressService.getProgress(
        contentId: contentId,
        contentType: contentType,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get watch statistics
  Future<Map<String, dynamic>> getWatchStats() async {
    try {
      return await WatchProgressService.getWatchStats();
    } catch (e) {
      return {};
    }
  }

  /// Initialize the provider
  Future<void> initialize() async {
    await loadProgress();
  }

  /// Get progress for specific content
  Future<WatchProgress?> getProgress({
    required String contentId,
    required String contentType,
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    try {
      return await WatchProgressService.getProgress(
        contentId: contentId,
        contentType: contentType,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get series progress (all episodes)
  Future<List<WatchProgress>> getSeriesProgress(String seriesId) async {
    try {
      final allProgress = await WatchProgressService.getAllProgress();
      return allProgress.where((progress) => 
        progress.contentType == 'series' && 
        progress.contentId == seriesId
      ).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get recent progress for continue watching
  List<WatchProgress> get recentProgress {
    final sortedProgress = List<WatchProgress>.from(_progress);
    sortedProgress.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
    return sortedProgress.take(10).toList();
  }

  /// Check if there are any progress items
  bool get hasProgress => _progress.isNotEmpty;

  /// Get progress count
  int get progressCount => _progress.length;
}