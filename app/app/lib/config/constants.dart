/// Neo-Stream API Configuration
class AppConstants {
  AppConstants._();

  // API (slash final pour résolution correcte des chemins relatifs)
  static const String apiBaseUrl = 'https://neo-stream.eu/app/';

  // Proxy IPTV PHP (live_proxy.php) — gère l'auth session + la clé admin WITV.
  // Endpoints : auth.php (login), live_proxy.php (validate, channels, m3u8).
  static const String phpProxyBaseUrl = 'https://neo-stream.eu/api/';

  // Proxy IPTV FSTV (legacy — reverse proxy vers witv_secure_proxy.py:8080).
  static const String fstvProxyBaseUrl = 'https://iptv.mine.bz';

  /// URL d’API pour un chemin relatif, ex. `auth/login` ou `content/search?q=…`.
  static Uri apiUri(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(apiBaseUrl).resolve(p);
  }
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration extractTimeout = Duration(seconds: 30);
  static const String appVersion = '1.2.2';
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

  // ── Mises à jour via GitHub Releases ────────────────────────────────
  // Dépôt source des releases (tags + APK/exe/deb en assets).
  static const String githubOwner = 'pecorio-dev';
  static const String githubRepo = 'Neo-Stream';
  // API publique GitHub. Ajoute ?per_page pour limiter le nombre de releases.
  static Uri get githubReleasesUri => Uri.parse(
        'https://api.github.com/repos/$githubOwner/$githubRepo/releases?per_page=20',
      );
  // Page web des releases (lien de secours / ouverture navigateur).
  static Uri get githubReleasesPageUri => Uri.parse(
        'https://github.com/$githubOwner/$githubRepo/releases',
      );
  // Délai minimal entre deux vérifications automatiques (anti-spam).
  static const Duration autoCheckMinInterval = Duration(hours: 6);

  // Poster
  static const String posterBaseUrl = 'https://neo-stream.eu';
  static const double posterAspectRatio = 2 / 3;
  static const double backdropAspectRatio = 16 / 9;
}
