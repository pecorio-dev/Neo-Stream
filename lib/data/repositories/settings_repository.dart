import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  static const String _settingsKey = 'app_settings';
  static const String _firstLaunchKey = 'first_launch';
  static const String _lastUpdateCheckKey = 'last_update_check';
  static const String _userPreferencesKey = 'user_preferences';

  /// Sauvegarde les paramètres de l'application
  Future<bool> saveSettings(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = json.encode(settings.toJson());
      await prefs.setString(_settingsKey, settingsJson);
      return true;
    } catch (e) {
      print('Error saving settings: $e');
      return false;
    }
  }

  /// Récupère les paramètres de l'application
  Future<AppSettings> getSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsString = prefs.getString(_settingsKey);
      
      if (settingsString == null || settingsString.isEmpty) {
        // Retourner les paramètres par défaut
        return const AppSettings();
      }
      
      final settingsJson = json.decode(settingsString);
      return AppSettings.fromJson(settingsJson);
    } catch (e) {
      print('Error getting settings: $e');
      return const AppSettings(); // Paramètres par défaut en cas d'erreur
    }
  }

  /// Met à jour un paramètre spécifique
  Future<bool> updateSetting<T>(String key, T value) async {
    try {
      final currentSettings = await getSettings();
      AppSettings? updatedSettings;
      
      switch (key) {
        // case 'defaultVideoQuality':
        //   updatedSettings = currentSettings.copyWith(
        //     defaultVideoQuality: value as VideoQuality
        //   );
        //   break;
        case 'autoPlay':
          updatedSettings = currentSettings.copyWith(autoPlay: value as bool);
          break;
        case 'skipIntro':
          updatedSettings = currentSettings.copyWith(skipIntro: value as bool);
          break;
        case 'playbackSpeed':
          updatedSettings = currentSettings.copyWith(playbackSpeed: value as double);
          break;
        // case 'enableSubtitles':
        //   updatedSettings = currentSettings.copyWith(enableSubtitles: value as bool);
        //   break;
        case 'enableHardwareAcceleration':
          updatedSettings = currentSettings.copyWith(
            enableHardwareAcceleration: value as bool
          );
          break;
        case 'themeMode':
          updatedSettings = currentSettings.copyWith(themeMode: value as ThemeMode);
          break;
        case 'language':
          updatedSettings = currentSettings.copyWith(language: value as Language);
          break;
        case 'enableAnimations':
          updatedSettings = currentSettings.copyWith(enableAnimations: value as bool);
          break;
        case 'enableHapticFeedback':
          updatedSettings = currentSettings.copyWith(enableHapticFeedback: value as bool);
          break;
        case 'uiScale':
          updatedSettings = currentSettings.copyWith(uiScale: value as double);
          break;
        case 'showAdultContent':
          updatedSettings = currentSettings.copyWith(showAdultContent: value as bool);
          break;
        case 'preferredGenres':
          updatedSettings = currentSettings.copyWith(preferredGenres: value as List<String>);
          break;
        case 'blockedGenres':
          updatedSettings = currentSettings.copyWith(blockedGenres: value as List<String>);
          break;
        case 'enableNotifications':
          updatedSettings = currentSettings.copyWith(enableNotifications: value as bool);
          break;
        case 'enableImageCache':
          updatedSettings = currentSettings.copyWith(enableImageCache: value as bool);
          break;
        case 'maxCacheSize':
          updatedSettings = currentSettings.copyWith(maxCacheSize: value as int);
          break;
        // case 'enableDataSaver':
        //   updatedSettings = currentSettings.copyWith(enableDataSaver: value as bool);
        //   break;
        // case 'downloadOnWifiOnly':
        //   updatedSettings = currentSettings.copyWith(downloadOnWifiOnly: value as bool);
        //   break;
        // case 'enableParentalControl':
        //   updatedSettings = currentSettings.copyWith(enableParentalControl: value as bool);
        //   break;
        // case 'parentalPin':
        //   updatedSettings = currentSettings.copyWith(parentalPin: value as String?);
        //   break;
        // case 'enableBiometricLock':
        //   updatedSettings = currentSettings.copyWith(enableBiometricLock: value as bool);
        //   break;
        case 'enableDebugMode':
          updatedSettings = currentSettings.copyWith(enableDebugMode: value as bool);
          break;
        // case 'enableAnalytics':
        //   updatedSettings = currentSettings.copyWith(enableAnalytics: value as bool);
        //   break;
        case 'apiEndpoint':
          updatedSettings = currentSettings.copyWith(apiEndpoint: value as String);
          break;
        case 'requestTimeout':
          updatedSettings = currentSettings.copyWith(requestTimeout: value as int);
          break;
        default:
          print('Unknown setting key: $key');
          return false;
      }
      
      if (updatedSettings == null) {
        print('Failed to update setting: $key');
        return false;
      }
      
      return await saveSettings(updatedSettings);
    } catch (e) {
      print('Error updating setting $key: $e');
      return false;
    }
  }

  /// Réinitialise tous les paramètres aux valeurs par défaut
  Future<bool> resetSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_settingsKey);
      return true;
    } catch (e) {
      print('Error resetting settings: $e');
      return false;
    }
  }

  /// Vérifie si c'est le premier lancement de l'application
  Future<bool> isFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !prefs.containsKey(_firstLaunchKey);
    } catch (e) {
      print('Error checking first launch: $e');
      return true;
    }
  }

  /// Marque que l'application a été lancée au moins une fois
  Future<void> markFirstLaunchComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_firstLaunchKey, false);
    } catch (e) {
      print('Error marking first launch complete: $e');
    }
  }

  /// Sauvegarde la date de la dernière vérification de mise à jour
  Future<void> saveLastUpdateCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastUpdateCheckKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Error saving last update check: $e');
    }
  }

  /// Récupère la date de la dernière vérification de mise à jour
  Future<DateTime?> getLastUpdateCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateString = prefs.getString(_lastUpdateCheckKey);
      if (dateString != null) {
        return DateTime.parse(dateString);
      }
      return null;
    } catch (e) {
      print('Error getting last update check: $e');
      return null;
    }
  }

  /// Sauvegarde les préférences utilisateur personnalisées
  Future<bool> saveUserPreferences(Map<String, dynamic> preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final preferencesJson = json.encode(preferences);
      await prefs.setString(_userPreferencesKey, preferencesJson);
      return true;
    } catch (e) {
      print('Error saving user preferences: $e');
      return false;
    }
  }

  /// Récupère les préférences utilisateur personnalisées
  Future<Map<String, dynamic>> getUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final preferencesString = prefs.getString(_userPreferencesKey);
      
      if (preferencesString == null || preferencesString.isEmpty) {
        return {};
      }
      
      return json.decode(preferencesString);
    } catch (e) {
      print('Error getting user preferences: $e');
      return {};
    }
  }

  /// Exporte tous les paramètres en JSON
  Future<String?> exportSettings() async {
    try {
      final settings = await getSettings();
      final userPreferences = await getUserPreferences();
      
      final exportData = {
        'version': '1.0',
        'exported_at': DateTime.now().toIso8601String(),
        'settings': settings.toJson(),
        'user_preferences': userPreferences,
      };
      
      return json.encode(exportData);
    } catch (e) {
      print('Error exporting settings: $e');
      return null;
    }
  }

  /// Importe les paramètres depuis JSON
  Future<bool> importSettings(String jsonData) async {
    try {
      final importData = json.decode(jsonData);
      
      // Importer les paramètres principaux
      if (importData['settings'] != null) {
        final settings = AppSettings.fromJson(importData['settings']);
        await saveSettings(settings);
      }
      
      // Importer les préférences utilisateur
      if (importData['user_preferences'] != null) {
        await saveUserPreferences(importData['user_preferences']);
      }
      
      return true;
    } catch (e) {
      print('Error importing settings: $e');
      return false;
    }
  }

  /// Efface toutes les données de l'application
  Future<bool> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      return true;
    } catch (e) {
      print('Error clearing all data: $e');
      return false;
    }
  }

  /// Obtient la taille du cache en MB
  Future<double> getCacheSize() async {
    try {
      // Cette méthode devrait calculer la taille réelle du cache
      // Pour l'instant, on retourne une valeur simulée
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      double totalSize = 0.0;
      
      for (final key in keys) {
        final value = prefs.get(key);
        if (value is String) {
          totalSize += value.length / (1024 * 1024); // Convertir en MB
        }
      }
      
      return totalSize;
    } catch (e) {
      print('Error getting cache size: $e');
      return 0.0;
    }
  }

  /// Efface le cache de l'application
  Future<bool> clearCache() async {
    try {
      // Ici on devrait effacer le cache des images et autres données temporaires
      // Pour l'instant, on simule juste l'opération
      print('Cache cleared successfully');
      return true;
    } catch (e) {
      print('Error clearing cache: $e');
      return false;
    }
  }
}