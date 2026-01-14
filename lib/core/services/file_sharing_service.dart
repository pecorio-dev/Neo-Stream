import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
// import 'package:file_picker/file_picker.dart'; // Package not available

class FileSharingService {
  static const String _settingsFileName = 'neostream_settings.json';
  
  /// Export settings to a JSON file and share it
  static Future<bool> exportSettings(Map<String, dynamic> settings) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$_settingsFileName');
      
      // Write settings to file
      final jsonString = const JsonEncoder.withIndent('  ').convert(settings);
      await file.writeAsString(jsonString);
      
      // Share the file
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Paramètres NeoStream',
        subject: 'Export des paramètres NeoStream',
      );
      
      return result.status == ShareResultStatus.success;
    } catch (e) {
      debugPrint('Erreur lors de l\'export des paramètres: $e');
      return false;
    }
  }
  
  /// Import settings from a JSON file
  static Future<Map<String, dynamic>?> importSettings() async {
    try {
      // TODO: Implement file picker when package is available
      // For now, return null to indicate feature not available
      debugPrint('Import de paramètres non disponible - package file_picker manquant');
      return null;
    } catch (e) {
      debugPrint('Erreur lors de l\'import des paramètres: $e');
      return null;
    }
  }
  
  /// Export favorites to a JSON file and share it
  static Future<bool> exportFavorites(List<Map<String, dynamic>> favorites) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/neostream_favorites.json');
      
      final data = {
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'favorites': favorites,
      };
      
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      await file.writeAsString(jsonString);
      
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Favoris NeoStream',
        subject: 'Export des favoris NeoStream',
      );
      
      return result.status == ShareResultStatus.success;
    } catch (e) {
      debugPrint('Erreur lors de l\'export des favoris: $e');
      return false;
    }
  }
  
  /// Import favorites from a JSON file
  static Future<List<Map<String, dynamic>>?> importFavorites() async {
    try {
      // TODO: Implement file picker when package is available
      debugPrint('Import de favoris non disponible - package file_picker manquant');
      return null;
    } catch (e) {
      debugPrint('Erreur lors de l\'import des favoris: $e');
      return null;
    }
  }
  
  /// Export watch progress to a JSON file and share it
  static Future<bool> exportWatchProgress(List<Map<String, dynamic>> progress) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/neostream_progress.json');
      
      final data = {
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'watchProgress': progress,
      };
      
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      await file.writeAsString(jsonString);
      
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Progression NeoStream',
        subject: 'Export de la progression NeoStream',
      );
      
      return result.status == ShareResultStatus.success;
    } catch (e) {
      debugPrint('Erreur lors de l\'export de la progression: $e');
      return false;
    }
  }
  
  /// Import watch progress from a JSON file
  static Future<List<Map<String, dynamic>>?> importWatchProgress() async {
    try {
      // TODO: Implement file picker when package is available
      debugPrint('Import de progression non disponible - package file_picker manquant');
      return null;
    } catch (e) {
      debugPrint('Erreur lors de l\'import de la progression: $e');
      return null;
    }
  }
  
  /// Validate the structure of imported settings
  static bool _validateSettingsStructure(Map<String, dynamic> settings) {
    // Check for required fields
    final requiredFields = [
      'theme_mode',
      'language',
      'auto_play',
      'skip_intro',
      'playback_speed',
      'enable_animations',
      'enable_haptic_feedback',
      'enable_hardware_acceleration',
      'enable_image_cache',
      'max_cache_size',
      'enable_notifications',
      'enable_debug_mode',
      'api_endpoint',
      'request_timeout',
      'ui_scale',
    ];
    
    for (final field in requiredFields) {
      if (!settings.containsKey(field)) {
        debugPrint('Champ manquant dans les paramètres: $field');
        return false;
      }
    }
    
    return true;
  }
  
  /// Get the size of a file in a human-readable format
  static String getFileSize(File file) {
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  /// Create a backup of all app data
  static Future<bool> createFullBackup({
    required Map<String, dynamic> settings,
    required List<Map<String, dynamic>> favorites,
    required List<Map<String, dynamic>> watchProgress,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/neostream_backup.json');
      
      final backup = {
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'appVersion': '1.0.0',
        'data': {
          'settings': settings,
          'favorites': favorites,
          'watchProgress': watchProgress,
        },
      };
      
      final jsonString = const JsonEncoder.withIndent('  ').convert(backup);
      await file.writeAsString(jsonString);
      
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Sauvegarde complète NeoStream',
        subject: 'Sauvegarde complète NeoStream',
      );
      
      return result.status == ShareResultStatus.success;
    } catch (e) {
      debugPrint('Erreur lors de la création de la sauvegarde: $e');
      return false;
    }
  }
  
  /// Restore from a full backup
  static Future<Map<String, dynamic>?> restoreFullBackup() async {
    try {
      // TODO: Implement file picker when package is available
      debugPrint('Restauration non disponible - package file_picker manquant');
      return null;
    } catch (e) {
      debugPrint('Erreur lors de la restauration: $e');
      return null;
    }
  }
}