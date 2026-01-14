

enum ThemeMode {
  system,
  light,
  dark;

  String get displayName {
    switch (this) {
      case ThemeMode.system:
        return 'Système';
      case ThemeMode.light:
        return 'Clair';
      case ThemeMode.dark:
        return 'Sombre';
    }
  }
}

enum Language {
  system,
  french,
  english;

  String get displayName {
    switch (this) {
      case Language.system:
        return 'Système';
      case Language.french:
        return 'Français';
      case Language.english:
        return 'English';
    }
  }

  String get code {
    switch (this) {
      case Language.system:
        return 'system';
      case Language.french:
        return 'fr';
      case Language.english:
        return 'en';
    }
  }
}

class AppSettings {
  // Paramètres vidéo
  final bool autoPlay;
  final bool skipIntro;
  final double playbackSpeed;
  final bool enableHardwareAcceleration;

  // Paramètres d'interface
  final ThemeMode themeMode;
  final Language language;
  final bool enableAnimations;
  final bool enableHapticFeedback;
  final double uiScale;

  // Paramètres de contenu
  final bool showAdultContent;
  final List<String> preferredGenres;
  final List<String> blockedGenres;
  final bool enableNotifications;

  // Paramètres de cache et données
  final bool enableImageCache;
  final int maxCacheSize; // en MB

  // Paramètres avancés
  final bool enableDebugMode;
  final String apiEndpoint;
  final int requestTimeout;

  const AppSettings({
    // Paramètres vidéo
    this.autoPlay = true,
    this.skipIntro = false,
    this.playbackSpeed = 1.0,
    this.enableHardwareAcceleration = true,

    // Paramètres d'interface
    this.themeMode = ThemeMode.dark,
    this.language = Language.system,
    this.enableAnimations = true,
    this.enableHapticFeedback = true,
    this.uiScale = 1.0,

    // Paramètres de contenu
    this.showAdultContent = false,
    this.preferredGenres = const [],
    this.blockedGenres = const [],
    this.enableNotifications = true,

    // Paramètres de cache et données
    this.enableImageCache = true,
    this.maxCacheSize = 500,

    // Paramètres avancés
    this.enableDebugMode = false,
    this.apiEndpoint = 'http://node.zenix.sg:25825',
    this.requestTimeout = 30,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      // Paramètres vidéo
      autoPlay: json['auto_play'] ?? true,
      skipIntro: json['skip_intro'] ?? false,
      playbackSpeed: (json['playback_speed'] ?? 1.0).toDouble(),
      enableHardwareAcceleration: json['enable_hardware_acceleration'] ?? true,

      // Paramètres d'interface
      themeMode: ThemeMode.values.firstWhere(
        (e) => e.name == json['theme_mode'],
        orElse: () => ThemeMode.dark,
      ),
      language: Language.values.firstWhere(
        (e) => e.name == json['language'],
        orElse: () => Language.system,
      ),
      enableAnimations: json['enable_animations'] ?? true,
      enableHapticFeedback: json['enable_haptic_feedback'] ?? true,
      uiScale: (json['ui_scale'] ?? 1.0).toDouble(),

      // Paramètres de contenu
      showAdultContent: json['show_adult_content'] ?? false,
      preferredGenres: List<String>.from(json['preferred_genres'] ?? []),
      blockedGenres: List<String>.from(json['blocked_genres'] ?? []),
      enableNotifications: json['enable_notifications'] ?? true,

      // Paramètres de cache et données
      enableImageCache: json['enable_image_cache'] ?? true,
      maxCacheSize: json['max_cache_size'] ?? 500,

      // Paramètres avancés
      enableDebugMode: json['enable_debug_mode'] ?? false,
      apiEndpoint: json['api_endpoint'] ?? 'http://node.zenix.sg:25825',
      requestTimeout: json['request_timeout'] ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // Paramètres vidéo
      'auto_play': autoPlay,
      'skip_intro': skipIntro,
      'playback_speed': playbackSpeed,
      'enable_hardware_acceleration': enableHardwareAcceleration,

      // Paramètres d'interface
      'theme_mode': themeMode.name,
      'language': language.name,
      'enable_animations': enableAnimations,
      'enable_haptic_feedback': enableHapticFeedback,
      'ui_scale': uiScale,

      // Paramètres de contenu
      'show_adult_content': showAdultContent,
      'preferred_genres': preferredGenres,
      'blocked_genres': blockedGenres,
      'enable_notifications': enableNotifications,

      // Paramètres de cache et données
      'enable_image_cache': enableImageCache,
      'max_cache_size': maxCacheSize,

      // Paramètres avancés
      'enable_debug_mode': enableDebugMode,
      'api_endpoint': apiEndpoint,
      'request_timeout': requestTimeout,
    };
  }

  AppSettings copyWith({
    bool? autoPlay,
    bool? skipIntro,
    double? playbackSpeed,
    bool? enableHardwareAcceleration,
    ThemeMode? themeMode,
    Language? language,
    bool? enableAnimations,
    bool? enableHapticFeedback,
    double? uiScale,
    bool? showAdultContent,
    List<String>? preferredGenres,
    List<String>? blockedGenres,
    bool? enableNotifications,
    bool? enableImageCache,
    int? maxCacheSize,
    bool? enableDebugMode,
    String? apiEndpoint,
    int? requestTimeout,
  }) {
    return AppSettings(
      autoPlay: autoPlay ?? this.autoPlay,
      skipIntro: skipIntro ?? this.skipIntro,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      enableHardwareAcceleration: enableHardwareAcceleration ?? this.enableHardwareAcceleration,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
      uiScale: uiScale ?? this.uiScale,
      showAdultContent: showAdultContent ?? this.showAdultContent,
      preferredGenres: preferredGenres ?? this.preferredGenres,
      blockedGenres: blockedGenres ?? this.blockedGenres,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      enableImageCache: enableImageCache ?? this.enableImageCache,
      maxCacheSize: maxCacheSize ?? this.maxCacheSize,
      enableDebugMode: enableDebugMode ?? this.enableDebugMode,
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
      requestTimeout: requestTimeout ?? this.requestTimeout,
    );
  }
}
