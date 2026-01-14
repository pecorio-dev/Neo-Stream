/// Constantes globales de l'application NEO STREAM
class AppConstants {
  // App Information
  static const String appVersion = '1.0.0';
  static const String appName = 'NeoStream';
  
  // API Configuration - IP directe pour éviter les problèmes DNS
  static const String baseUrl = 'http://node.zenix.sg:25825';
  static const String moviesEndpoint = '/movies';
  static const String searchEndpoint = '/search';
  static const String genresEndpoint = '/genres';
  
  // Routes
  static const String homeRoute = '/';
  static const String moviesRoute = '/movies';
  static const String seriesRoute = '/series';
  static const String searchRoute = '/search';
  static const String profileRoute = '/profile';
  static const String settingsRoute = '/settings';
  static const String movieDetailsRoute = '/movie-details';
  static const String seriesDetailsRoute = '/series-details';
  static const String videoPlayerRoute = '/video-player';
  static const String favoritesRoute = '/favorites';
  static const String splashRoute = '/splash';
  
  // Asset Paths
  static const String imagesPath = 'assets/images/';
  static const String avatarsPath = 'assets/avatars/';
  
  // Image Assets (using Flutter's built-in assets when possible)
  static const String logoImage = '${imagesPath}logo.png';
  
  // Note: Pour les icônes, nous utilisons les icônes Material Design intégrées de Flutter
  // Exemples: Icons.home, Icons.movie, Icons.tv, Icons.search, Icons.person
  // Cela évite d'avoir besoin de fichiers d'assets personnalisés
  
  // Font Families
  static const String primaryFont = 'Orbitron';
  static const String secondaryFont = 'Rajdhani';
  static const String monoFont = 'RobotoMono';
  
  // Dimensions
  static const double borderRadius = 12.0;
  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 8.0;
  static const double inputBorderRadius = 28.0;
  
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;
  
  static const double marginSmall = 8.0;
  static const double marginMedium = 16.0;
  static const double marginLarge = 24.0;
  static const double marginXLarge = 32.0;
  
  // Icon Sizes
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 48.0;
  
  // Font Sizes
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeLarge = 16.0;
  static const double fontSizeXLarge = 18.0;
  static const double fontSizeXXLarge = 20.0;
  static const double fontSizeTitle = 24.0;
  static const double fontSizeHeading = 28.0;
  static const double fontSizeDisplay = 32.0;
  
  // Elevation
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;
  static const double elevationXHigh = 16.0;
  
  // Opacity
  static const double opacityDisabled = 0.38;
  static const double opacityMedium = 0.6;
  static const double opacityHigh = 0.87;
  
  // Animation Curves
  static const String easeInOut = 'easeInOut';
  static const String easeIn = 'easeIn';
  static const String easeOut = 'easeOut';
  static const String bounceIn = 'bounceIn';
  static const String bounceOut = 'bounceOut';
  
  // Quality Labels
  static const String qualityHD = 'HD';
  static const String qualitySD = 'SD';
  static const String quality4K = '4K';
  static const String qualityAuto = 'AUTO';
  
  // Content Types
  static const String typeMovie = 'movie';
  static const String typeSeries = 'series';
  static const String typeEpisode = 'episode';
  
  // Server Types
  static const String serverUqload = 'UQLOAD';
  static const String serverStreamtape = 'STREAMTAPE';
  static const String serverDoodstream = 'DOODSTREAM';
  static const String serverMixdrop = 'MIXDROP';
  
  // Stream Types
  static const String streamTypeHLS = 'hls';
  static const String streamTypeDASH = 'dash';
  static const String streamTypeMP4 = 'mp4';
  static const String streamTypeAuto = 'auto';
  
  // Rating Thresholds
  static const double ratingExcellent = 8.0;
  static const double ratingGood = 7.0;
  static const double ratingAverage = 6.0;
  static const double ratingPoor = 4.0;
  
  // Grid Configuration
  static const int gridColumnsPortrait = 2;
  static const int gridColumnsLandscape = 3;
  static const int gridColumnsTablet = 4;
  
  // Breakpoints
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;
  static const double desktopBreakpoint = 1200.0;
  
  // Cache Configuration
  static const Duration cacheExpiration = Duration(hours: 1);
  static const int maxCacheAge = 3600; // 1 hour in seconds
  static const int maxCacheEntries = 1000;
  
  // Pagination
  static const int moviesPerPage = 20;
  static const int searchResultsPerPage = 15;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
  
  // Debounce Delays
  static const Duration searchDebounce = Duration(milliseconds: 500);
  static const Duration filterDebounce = Duration(milliseconds: 300);
  
  // Network Configuration
  static const int requestTimeout = 30;
  
  // Timeouts
  static const int shortTimeout = 5000; // 5 seconds
  static const int mediumTimeout = 10000; // 10 seconds
  static const int longTimeout = 30000; // 30 seconds
  
  // Retry Configuration
  static const int maxRetries = 3;
  static const int retryDelay = 1000; // 1 second
  
  // Validation Patterns
  static const String emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String urlPattern = r'^https?:\/\/[^\s]+$';
  static const String phonePattern = r'^\+?[1-9]\d{1,14}$';
  
  // Search Configuration
  static const int minSearchLength = 2;
  static const int maxSearchLength = 100;
  static const int searchDebounceMs = 500;
  static const String searchHint = 'Rechercher films, séries, genres...';
  
  // Date Formats
  static const String dateFormatShort = 'dd/MM/yyyy';
  static const String dateFormatLong = 'dd MMMM yyyy';
  static const String dateFormatISO = 'yyyy-MM-dd';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  
  // Localization
  static const String defaultLocale = 'fr_FR';
  static const String fallbackLocale = 'en_US';
  
  // Platform Specific
  static const String androidPackageName = 'com.neostream.app';
  static const String iosAppId = '123456789';
  static const String windowsAppId = 'NeoStream.App';
  
  // External URLs
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=$androidPackageName';
  static const String appStoreUrl = 'https://apps.apple.com/app/id$iosAppId';
  static const String microsoftStoreUrl = 'https://www.microsoft.com/store/apps/$windowsAppId';
  
  // Social Sharing
  static const String shareTextTemplate = 'Découvrez {title} sur NEO STREAM - L\'avenir du streaming est maintenant !';
  static const String shareUrlTemplate = 'https://neostream.app/content/{id}';
  
  // Error Codes
  static const int errorCodeNetwork = 1001;
  static const int errorCodeServer = 1002;
  static const int errorCodeAuth = 1003;
  static const int errorCodeNotFound = 1004;
  static const int errorCodeTimeout = 1005;
  static const int errorCodeUnknown = 9999;
  
  // Success Codes
  static const int successCodeOk = 200;
  static const int successCodeCreated = 201;
  static const int successCodeAccepted = 202;
  static const int successCodeNoContent = 204;
  
  // HTTP Status Codes
  static const int statusBadRequest = 400;
  static const int statusUnauthorized = 401;
  static const int statusForbidden = 403;
  static const int statusNotFound = 404;
  static const int statusInternalServerError = 500;
  static const int statusBadGateway = 502;
  static const int statusServiceUnavailable = 503;
  
  // Feature Flags Keys
  static const String featureAnimations = 'enable_animations';
  static const String featureMemoryOptimization = 'enable_memory_optimization';
  static const String featureCaching = 'enable_caching';
  static const String featureAnalytics = 'enable_analytics';
  static const String featureCrashReporting = 'enable_crash_reporting';
  static const String featureDebugMode = 'enable_debug_mode';
}

class ApiEndpoints {
  static String movies() => '${AppConstants.baseUrl}${AppConstants.moviesEndpoint}';
  static String search({String? query, String? type, bool? consolidated}) {
    final params = <String, String>{};
    if (query != null) params['q'] = query;
    if (type != null) params['type'] = type;
    if (consolidated != null) params['consolidated'] = consolidated.toString();
    
    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    
    return '${AppConstants.baseUrl}${AppConstants.searchEndpoint}?$queryString';
  }
  static String genres() => '${AppConstants.baseUrl}${AppConstants.genresEndpoint}';
}