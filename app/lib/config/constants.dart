/// Neo-Stream API Configuration
class AppConstants {
  AppConstants._();

  // API (slash final pour résolution correcte des chemins relatifs)
  static const String apiBaseUrl = 'https://neo-stream.eu/app/';

  /// URL d’API pour un chemin relatif, ex. `auth/login` ou `content/search?q=…`.
  static Uri apiUri(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(apiBaseUrl).resolve(p);
  }
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration extractTimeout = Duration(seconds: 30);
  static const String appVersion = '1.0.0';
  static const String appClient = 'neo-stream-flutter';
  static const Duration integrityRefreshMargin = Duration(minutes: 10);

  // Cache durations
  static const Duration homeCacheDuration = Duration(minutes: 2);
  static const Duration trendingCacheDuration = Duration(minutes: 10);
  static const Duration genresCacheDuration = Duration(hours: 1);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;

  // Player
  static const Duration seekDuration = Duration(seconds: 10);
  static const Duration controlsFadeDuration = Duration(milliseconds: 300);
  static const Duration controlsHideDelay = Duration(seconds: 4);
  static const Duration progressSaveInterval = Duration(seconds: 15);

  // TV Detection
  static const double tvBreakpoint = 960;
  static const double tabletBreakpoint = 600;

  // Poster
  static const String posterBaseUrl = 'https://neo-stream.eu/app';
  static const double posterAspectRatio = 2 / 3;
  static const double backdropAspectRatio = 16 / 9;
}
