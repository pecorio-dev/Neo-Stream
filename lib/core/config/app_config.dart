/// Configuration globale de l'application NEO STREAM
class AppConfig {
  // Informations de l'application
  static const String appName = 'NEO STREAM';
  static const String appVersion = '1.0.0';
  static const String appBuild = '2025';
  static const String appDescription = 'Application de streaming cyberpunk';

  // API Configuration
  static const String apiBaseUrl = 'http://node.zenix.sg:25825';
  static const int apiTimeoutMs = 15000;
  static const int apiRetryCount = 3;

  // Cache Configuration
  static const Duration cacheTimeout = Duration(minutes: 5);
  static const int maxCacheSize = 100;
  static const int maxImageCacheSize = 50;
  static const int maxImageCacheSizeBytes = 10 * 1024 * 1024; // 10MB

  // Performance Configuration
  static const int lowMemoryThreshold = 100; // MB
  static const int criticalMemoryThreshold = 50; // MB
  static const Duration memoryMonitorInterval = Duration(seconds: 30);

  // UI Configuration
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 600);
  static const Duration shortAnimationDuration = Duration(milliseconds: 150);

  // Grid Configuration
  static const int gridCrossAxisCount = 2;
  static const double gridChildAspectRatio = 0.65;
  static const double gridCrossAxisSpacing = 12;
  static const double gridMainAxisSpacing = 16;

  // Pagination
  static const int defaultPageSize = 50;
  static const int maxPageSize = 100;

  // Search Configuration
  static const int maxRecentSearches = 10;
  static const Duration searchDebounceDelay = Duration(milliseconds: 500);

  // Video Player Configuration
  static const List<String> supportedVideoFormats = [
    'mp4', 'm3u8', 'mpd', 'avi', 'mkv', 'webm'
  ];

  static const List<String> preferredServers = [
    'UQLOAD',
    'STREAMTAPE',
    'DOODSTREAM',
    'MIXDROP',
  ];

  // Storage Keys
  static const String favoritesKey = 'favorites';
  static const String recentSearchesKey = 'recent_searches';
  static const String settingsKey = 'app_settings';
  static const String cacheKey = 'app_cache';

  // Feature Flags
  static const bool enableAnimations = true;
  static const bool enableMemoryOptimization = true;
  static const bool enableCaching = true;
  static const bool enableAnalytics = false;
  static const bool enableCrashReporting = false;

  // Debug Configuration
  static const bool isDebugMode = true;
  static const bool enableApiLogging = true;
  static const bool enablePerformanceLogging = true;

  // Network Configuration
  static const Map<String, String> defaultHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'User-Agent': 'NEO-STREAM/1.0.0 (Flutter)',
  };

  // Error Messages
  static const String networkErrorMessage = 'Erreur de connexion réseau';
  static const String serverErrorMessage = 'Erreur du serveur';
  static const String unknownErrorMessage = 'Une erreur inconnue s\'est produite';
  static const String noContentMessage = 'Aucun contenu disponible';
  static const String loadingMessage = 'Chargement en cours...';

  // Success Messages
  static const String favoriteAddedMessage = 'Ajouté aux favoris';
  static const String favoriteRemovedMessage = 'Retiré des favoris';
  static const String cacheCleared = 'Cache effacé avec succès';

  // Validation
  static const int minSearchLength = 2;
  static const int maxSearchLength = 100;

  // URLs
  static const String supportUrl = 'https://neostream.support';
  static const String privacyPolicyUrl = 'https://neostream.com/privacy';
  static const String termsOfServiceUrl = 'https://neostream.com/terms';

  // Social Media
  static const String githubUrl = 'https://github.com/neostream';
  static const String twitterUrl = 'https://twitter.com/neostream';
  static const String discordUrl = 'https://discord.gg/neostream';

  // Development
  static const bool isDevelopment = true;
  static const bool isProduction = false;
  static const bool enableTestMode = false;
}
