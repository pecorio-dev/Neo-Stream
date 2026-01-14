import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/watch_progress.dart';

class WatchProgressService {
  static const String _progressKey = 'watch_progress';
  static const String _settingsKey = 'watch_progress_settings';
  
  /// Save watch progress for a content item
  static Future<bool> saveProgress({
    required String contentId,
    required String contentType, // 'movie' or 'series'
    required String title,
    required Duration position,
    required Duration duration,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeTitle,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing progress
      final existingProgress = await getAllProgress();
      
      // Create or update progress entry
      final progressId = _generateProgressId(contentId, contentType, seasonNumber, episodeNumber);
      final progressPercentage = duration.inSeconds > 0 
          ? (position.inSeconds / duration.inSeconds).clamp(0.0, 1.0)
          : 0.0;
      
      final progress = WatchProgress(
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
      
      // Remove existing entry if it exists
      existingProgress.removeWhere((p) => p.id == progressId);
      
      // Add new progress (only if significant progress made)
      if (position.inSeconds > 30 && progressPercentage < 0.95) {
        existingProgress.add(progress);
      }
      
      // Keep only the most recent 100 entries
      existingProgress.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
      if (existingProgress.length > 100) {
        existingProgress.removeRange(100, existingProgress.length);
      }
      
      // Save to SharedPreferences
      final progressJson = existingProgress.map((p) => p.toJson()).toList();
      await prefs.setString(_progressKey, jsonEncode(progressJson));
      
      return true;
    } catch (e) {
      print('Error saving watch progress: $e');
      return false;
    }
  }
  
  /// Get all watch progress entries
  static Future<List<WatchProgress>> getAllProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressJson = prefs.getString(_progressKey);
      
      if (progressJson == null) return [];
      
      final List<dynamic> progressList = jsonDecode(progressJson);
      return progressList
          .map((json) => WatchProgress.fromJson(json))
          .toList();
    } catch (e) {
      print('Error loading watch progress: $e');
      return [];
    }
  }
  
  /// Get progress for a specific content item
  static Future<WatchProgress?> getProgress({
    required String contentId,
    required String contentType,
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    try {
      final allProgress = await getAllProgress();
      final progressId = _generateProgressId(contentId, contentType, seasonNumber, episodeNumber);
      
      return allProgress.firstWhere(
        (progress) => progress.id == progressId,
        orElse: () => throw StateError('Not found'),
      );
    } catch (e) {
      return null;
    }
  }
  
  /// Get recent progress entries (for continue watching)
  static Future<List<WatchProgress>> getRecentProgress({int limit = 10}) async {
    try {
      final allProgress = await getAllProgress();
      allProgress.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
      
      return allProgress.take(limit).toList();
    } catch (e) {
      print('Error loading recent progress: $e');
      return [];
    }
  }
  
  /// Remove progress for a specific content item
  static Future<bool> removeProgress(String progressId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allProgress = await getAllProgress();
      
      allProgress.removeWhere((progress) => progress.id == progressId);
      
      final progressJson = allProgress.map((p) => p.toJson()).toList();
      await prefs.setString(_progressKey, jsonEncode(progressJson));
      
      return true;
    } catch (e) {
      print('Error removing watch progress: $e');
      return false;
    }
  }
  
  /// Clear all watch progress
  static Future<bool> clearAllProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_progressKey);
      return true;
    } catch (e) {
      print('Error clearing watch progress: $e');
      return false;
    }
  }
  
  /// Mark content as completed (watched to the end)
  static Future<bool> markAsCompleted({
    required String contentId,
    required String contentType,
    required String title,
    required Duration duration,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeTitle,
  }) async {
    return await saveProgress(
      contentId: contentId,
      contentType: contentType,
      title: title,
      position: duration,
      duration: duration,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
    );
  }
  
  /// Get watch statistics
  static Future<Map<String, dynamic>> getWatchStats() async {
    try {
      final allProgress = await getAllProgress();
      
      final totalWatchTime = allProgress.fold<Duration>(
        Duration.zero,
        (total, progress) => total + Duration(seconds: progress.position),
      );
      
      final movieCount = allProgress.where((p) => p.contentType == 'movie').length;
      final seriesCount = allProgress.where((p) => p.contentType == 'series').length;
      
      final completedCount = allProgress.where((p) => p.progressPercentage >= 0.95).length;
      
      return {
        'totalItems': allProgress.length,
        'totalWatchTime': totalWatchTime,
        'movieCount': movieCount,
        'seriesCount': seriesCount,
        'completedCount': completedCount,
        'averageProgress': allProgress.isNotEmpty
            ? allProgress.map((p) => p.progressPercentage).reduce((a, b) => a + b) / allProgress.length
            : 0.0,
      };
    } catch (e) {
      print('Error getting watch stats: $e');
      return {};
    }
  }
  
  /// Export watch progress to JSON
  static Future<Map<String, dynamic>?> exportProgress() async {
    try {
      final allProgress = await getAllProgress();
      final stats = await getWatchStats();
      
      return {
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'stats': stats,
        'progress': allProgress.map((p) => p.toJson()).toList(),
      };
    } catch (e) {
      print('Error exporting watch progress: $e');
      return null;
    }
  }
  
  /// Import watch progress from JSON
  static Future<bool> importProgress(Map<String, dynamic> data) async {
    try {
      if (!data.containsKey('progress') || data['progress'] is! List) {
        return false;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final List<dynamic> progressList = data['progress'];
      
      // Validate and convert progress entries
      final validProgress = <WatchProgress>[];
      for (final json in progressList) {
        try {
          final progress = WatchProgress.fromJson(json);
          validProgress.add(progress);
        } catch (e) {
          print('Skipping invalid progress entry: $e');
        }
      }
      
      // Save imported progress
      final progressJson = validProgress.map((p) => p.toJson()).toList();
      await prefs.setString(_progressKey, jsonEncode(progressJson));
      
      return true;
    } catch (e) {
      print('Error importing watch progress: $e');
      return false;
    }
  }
  
  /// Generate a unique progress ID
  static String _generateProgressId(
    String contentId,
    String contentType,
    int? seasonNumber,
    int? episodeNumber,
  ) {
    if (contentType == 'series' && seasonNumber != null && episodeNumber != null) {
      return '${contentId}_s${seasonNumber}_e$episodeNumber';
    }
    return '${contentId}_$contentType';
  }
  
  /// Get progress settings
  static Future<Map<String, dynamic>> getProgressSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);
      
      if (settingsJson == null) {
        return _getDefaultSettings();
      }
      
      return jsonDecode(settingsJson);
    } catch (e) {
      print('Error loading progress settings: $e');
      return _getDefaultSettings();
    }
  }
  
  /// Save progress settings
  static Future<bool> saveProgressSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, jsonEncode(settings));
      return true;
    } catch (e) {
      print('Error saving progress settings: $e');
      return false;
    }
  }
  
  /// Get default progress settings
  static Map<String, dynamic> _getDefaultSettings() {
    return {
      'autoSave': true,
      'saveInterval': 10, // seconds
      'minProgressToSave': 30, // seconds
      'markCompletedAt': 0.95, // 95% progress
      'maxEntries': 100,
      'autoResume': true,
    };
  }
  
  /// Check if content should auto-resume
  static Future<bool> shouldAutoResume(String contentId, String contentType) async {
    try {
      final settings = await getProgressSettings();
      if (!settings['autoResume']) return false;
      
      final progress = await getProgress(
        contentId: contentId,
        contentType: contentType,
      );
      
      if (progress == null) return false;
      
      // Auto-resume if progress is between 5% and 95%
      return progress.progressPercentage > 0.05 && progress.progressPercentage < 0.95;
    } catch (e) {
      return false;
    }
  }

  /// Get all series progress for a given series
  static Future<List<WatchProgress>> getAllSeriesProgress(String seriesId) async {
    try {
      final allProgress = await getAllProgress();
      final seriesProgressions = allProgress
          .where((p) => p.contentId == seriesId && p.isEpisode)
          .toList();
      seriesProgressions.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
      return seriesProgressions;
    } catch (e) {
      print('❌ Error getting all series progress: $e');
      return [];
    }
}
}