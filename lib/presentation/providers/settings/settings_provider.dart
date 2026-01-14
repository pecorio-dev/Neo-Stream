import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/repositories/settings_repository.dart';

export '../../../data/models/app_settings.dart' show Language, ThemeMode;

final settingsProvider = ChangeNotifierProvider((ref) => SettingsProvider());

enum SettingsLoadingState {
  initial,
  loading,
  loaded,
  saving,
  error,
}

class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _repository = SettingsRepository();

  // État
  SettingsLoadingState _loadingState = SettingsLoadingState.initial;
  AppSettings _settings = const AppSettings();
  String _errorMessage = '';

  // Getters
  SettingsLoadingState get loadingState => _loadingState;
  AppSettings get settings => _settings;
  String get errorMessage => _errorMessage;

  bool get isLoading => _loadingState == SettingsLoadingState.loading;
  bool get isSaving => _loadingState == SettingsLoadingState.saving;
  bool get hasError => _loadingState == SettingsLoadingState.error;

  // Paramètres individuels
  bool get autoPlay => _settings.autoPlay;
  bool get skipIntro => _settings.skipIntro;
  double get playbackSpeed => _settings.playbackSpeed;
  bool get enableHardwareAcceleration => _settings.enableHardwareAcceleration;
  bool get enableNotifications => _settings.enableNotifications;
  Language get language => _settings.language;
  ThemeMode get themeMode => _settings.themeMode;
  bool get enableAnimations => _settings.enableAnimations;
  bool get enableHapticFeedback => _settings.enableHapticFeedback;
  double get uiScale => _settings.uiScale;
  bool get showAdultContent => _settings.showAdultContent;
  bool get enableImageCache => _settings.enableImageCache;
  int get maxCacheSize => _settings.maxCacheSize;
  int get requestTimeout => _settings.requestTimeout;

  List<String> get preferredGenres => _settings.preferredGenres;
  List<String> get blockedGenres => _settings.blockedGenres;

  // Unsaved changes
  bool _hasUnsavedChanges = false;
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  /// Charge les paramètres depuis le repository
  Future<void> loadSettings() async {
    _loadingState = SettingsLoadingState.loading;
    notifyListeners();

    try {
      _settings = await _repository.getSettings();
      _loadingState = SettingsLoadingState.loaded;
      _hasUnsavedChanges = false;
    } catch (e) {
      _errorMessage = e.toString();
      _loadingState = SettingsLoadingState.error;
    }

    notifyListeners();
  }

  /// Sauvegarde les paramètres
  Future<bool> saveSettings() async {
    _loadingState = SettingsLoadingState.saving;
    notifyListeners();

    try {
      await _repository.saveSettings(_settings);
      _loadingState = SettingsLoadingState.loaded;
      _hasUnsavedChanges = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _loadingState = SettingsLoadingState.error;
      notifyListeners();
      return false;
    }
  }

  /// Met à jour l'auto-play
  void setAutoPlay(bool value) {
    if (_settings.autoPlay != value) {
      _settings = _settings.copyWith(autoPlay: value);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Met à jour l'accélération matérielle
  void setEnableHardwareAcceleration(bool value) {
    if (_settings.enableHardwareAcceleration != value) {
      _settings = _settings.copyWith(enableHardwareAcceleration: value);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Met à jour les notifications
  void setEnableNotifications(bool value) {
    if (_settings.enableNotifications != value) {
      _settings = _settings.copyWith(enableNotifications: value);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Met à jour la langue
  void setLanguage(Language value) {
    if (_settings.language != value) {
      _settings = _settings.copyWith(language: value);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Met à jour skip intro
  void setSkipIntro(bool value) {
    if (_settings.skipIntro != value) {
      _settings = _settings.copyWith(skipIntro: value);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Met à jour la vitesse de lecture
  void setPlaybackSpeed(double value) {
    if (_settings.playbackSpeed != value) {
      _settings = _settings.copyWith(playbackSpeed: value);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Met à jour les animations
  void setEnableAnimations(bool value) {
    if (_settings.enableAnimations != value) {
      _settings = _settings.copyWith(enableAnimations: value);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Met à jour haptic feedback
  void setEnableHapticFeedback(bool value) {
    if (_settings.enableHapticFeedback != value) {
      _settings = _settings.copyWith(enableHapticFeedback: value);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Met à jour l'échelle UI
  void setUiScale(double value) {
    if (_settings.uiScale != value) {
      _settings = _settings.copyWith(uiScale: value);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Met à jour contenu adulte
  void setShowAdultContent(bool value) {
    if (_settings.showAdultContent != value) {
      _settings = _settings.copyWith(showAdultContent: value);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Met à jour cache image
  void setEnableImageCache(bool value) {
    if (_settings.enableImageCache != value) {
      _settings = _settings.copyWith(enableImageCache: value);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Met à jour la taille max du cache
  void setMaxCacheSize(int value) {
    if (_settings.maxCacheSize != value) {
      _settings = _settings.copyWith(maxCacheSize: value);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Met à jour timeout requêtes
  void setRequestTimeout(int value) {
    if (_settings.requestTimeout != value) {
      _settings = _settings.copyWith(requestTimeout: value);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Met à jour le mode de thème
  void setThemeMode(ThemeMode value) {
    if (_settings.themeMode != value) {
      _settings = _settings.copyWith(themeMode: value);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  void setPreferredGenres(List<String> genres) {
    _settings = _settings.copyWith(preferredGenres: genres);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void setBlockedGenres(List<String> genres) {
    _settings = _settings.copyWith(blockedGenres: genres);
    _hasUnsavedChanges = true;
    notifyListeners();
  }



  /// Réinitialise les paramètres
  Future<bool> resetSettings() async {
    _loadingState = SettingsLoadingState.saving;
    notifyListeners();

    try {
      _settings = const AppSettings();
      await _repository.saveSettings(_settings);
      _loadingState = SettingsLoadingState.loaded;
      _hasUnsavedChanges = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _loadingState = SettingsLoadingState.error;
      notifyListeners();
      return false;
    }
  }



  /// Importe les paramètres depuis une Map
  Future<bool> importSettingsFromMap(Map<String, dynamic> data) async {
    _loadingState = SettingsLoadingState.saving;
    notifyListeners();

    try {
      _settings = AppSettings.fromJson(data);
      await _repository.saveSettings(_settings);
      _loadingState = SettingsLoadingState.loaded;
      _hasUnsavedChanges = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _loadingState = SettingsLoadingState.error;
      notifyListeners();
      return false;
    }
  }

  /// Exporte les paramètres
  Future<String?> exportSettings() async {
    try {
      return jsonEncode(_settings.toJson());
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    }
  }

  /// Vide le cache
  Future<bool> clearCache() async {
    try {
      // Implémentation du vidage du cache
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  /// Efface toutes les données
  Future<bool> clearAllData() async {
    try {
      _settings = const AppSettings();
      await _repository.saveSettings(_settings);
      _hasUnsavedChanges = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  /// Réessaye le chargement
  Future<void> retry() async {
    await loadSettings();
  }
}
