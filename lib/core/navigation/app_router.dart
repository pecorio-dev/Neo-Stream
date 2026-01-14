import 'package:flutter/material.dart';
import 'navigation_service.dart';
import 'animation_service.dart';
import '../../data/services/platform_service.dart';
import '../../core/tv/tv_navigation_service.dart';
import 'advanced_navigation_service.dart';
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/platform_selection_screen.dart';
import '../../presentation/screens/profile_selection_screen.dart';
import '../../presentation/screens/profile_creation_screen.dart';
import '../../presentation/screens/movies_screen.dart';
import '../../presentation/screens/search_screen.dart';
import '../../presentation/screens/series_screen.dart';
import '../../presentation/screens/favorites/favorites_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/movie_details_screen.dart';
import '../../presentation/screens/series_details_screen.dart';
import '../../presentation/screens/enhanced_series_details_screen.dart';
import '../../presentation/screens/series_compact_details_screen.dart';
import '../../presentation/screens/series_favorites_screen.dart';
// Removed: video_player_screen.dart (replaced by media_kit)
import '../../presentation/screens/player/simple_video_player.dart';
import '../../presentation/screens/player/enhanced_video_player.dart';
import '../../presentation/screens/main_screen.dart';
import '../../data/models/movie.dart';
import '../../data/models/series.dart';
import '../../data/models/series_compact.dart';
import '../../data/models/stream_info.dart';

/// Service centralisé de gestion des routes de l'application
class AppRouter {
  /// Map des routes nommées
  static final Map<String, WidgetBuilder> _routes = {
    '/': (context) => const SplashScreen(),
    '/platform-selection': (context) => const PlatformSelectionScreen(),
    '/profile-selection': (context) => const ProfileSelectionScreen(),
    '/profile-creation': (context) => const ProfileCreationScreen(),
    '/main': (context) => const MainScreen(),
    '/movies': (context) => const MainScreen(),
    '/search': (context) => SearchScreen(),
  };

  /// Générer une route
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
    // ========== DÉTAIL FILM ==========
      case '/movie-detail':
        if (args is Movie) {
          return _buildPageRoute(
            child: MovieDetailsScreen(movie: args),
            isTVMode: PlatformService.isTVMode,
            settings: settings,
          );
        }
        break;

    // ========== DÉTAIL SÉRIE ==========
      case '/series-detail':
        if (args is Series) {
          return _buildPageRoute(
            child: EnhancedSeriesDetailsScreen(series: args),
            isTVMode: PlatformService.isTVMode,
            settings: settings,
          );
        }
        break;

    // ========== DÉTAIL SÉRIE COMPACT ==========
      case '/series-compact-detail':
        if (args is SeriesCompact) {
          return _buildPageRoute(
            child: SeriesCompactDetailsScreen(series: args),
            isTVMode: PlatformService.isTVMode,
            settings: settings,
          );
        }
        break;

    // ========== LECTEUR VIDÉO - ✅ COMPLET ==========
      case '/video-player':
        return _buildVideoPlayerRoute(args, settings);

    // ========== RECHERCHE ==========
      case '/search':
        return _buildPageRoute(
          child: SearchScreen(initialQuery: args as String?),
          isTVMode: PlatformService.isTVMode,
          settings: settings,
        );

    // ========== AUTRES ROUTES ==========
      default:
        if (_routes.containsKey(settings.name)) {
          Widget screen = Builder(
            builder: (BuildContext context) {
              return _routes[settings.name]!(context);
            },
          );
          return _buildPageRoute(
            child: screen,
            isTVMode: PlatformService.isTVMode,
            settings: settings,
          );
        }
    }
    return null;
  }

  /// ✅ CONSTRUCTION DE LA ROUTE LECTEUR VIDÉO - COMPLÈTE
  static Route<dynamic> _buildVideoPlayerRoute(
      dynamic args,
      RouteSettings settings,
      ) {
    try {
      debugPrint('🎬 ========== ROUTE LECTEUR VIDÉO ==========');
      debugPrint('🎬 Arguments type: ${args.runtimeType}');

      if (args == null) {
        debugPrint('🎬 ❌ Arguments manquants');
        return _buildErrorRoute(
          'Arguments manquants pour le lecteur vidéo',
          settings,
        );
      }

      // Cas 1: Arguments sont une Map
      if (args is Map<String, dynamic>) {
        debugPrint('🎬 ✅ Arguments sont une Map');
        return _buildVideoPlayerFromMap(args, settings);
      }

      // Cas 2: Arguments sont un StreamInfo
      if (args is StreamInfo) {
        debugPrint('🎬 ✅ Arguments sont un StreamInfo');
        return _buildPageRoute(
          child: SimpleVideoPlayer(
            videoUrl: args.url,
            headers: args.getCompleteHeaders(),
            title: args.title ?? 'Vidéo',
          ),
          isTVMode: PlatformService.isTVMode,
          settings: settings,
        );
      }

      // Cas par défaut: erreur
      debugPrint('🎬 ❌ Arguments invalides: ${args.runtimeType}');
      return _buildErrorRoute(
        'Arguments invalides pour le lecteur vidéo: ${args.runtimeType}',
        settings,
      );
    } catch (e, stackTrace) {
      debugPrint('🎬 ❌ ERREUR dans _buildVideoPlayerRoute: $e');
      debugPrint('🎬 StackTrace: $stackTrace');
      return _buildErrorRoute(
        'Erreur lors de l\'ouverture du lecteur: $e',
        settings,
      );
    }
  }

  /// ✅ CONSTRUCTION DU LECTEUR VIDÉO À PARTIR D'UNE MAP - COMPLÈTE
  static Route<dynamic> _buildVideoPlayerFromMap(
      Map<String, dynamic> args,
      RouteSettings settings,
      ) {
    try {
      debugPrint('🎬 === DÉBUT CRÉATION LECTEUR DEPUIS MAP ===');
      debugPrint('🎬 Keys disponibles: ${args.keys.toList()}');

      // Extraire ou créer le StreamInfo
      StreamInfo streamInfo;

      if (args.containsKey('streamInfo') && args['streamInfo'] != null) {
        // Si un StreamInfo existe déjà
        debugPrint('🎬 ✅ StreamInfo fourni directement');
        streamInfo = args['streamInfo'] as StreamInfo;

        debugPrint('🎬 Détails StreamInfo:');
        debugPrint('🎬   - URL: ${streamInfo.url}');
        debugPrint('🎬   - Title: ${streamInfo.title}');
        debugPrint('🎬   - Quality: ${streamInfo.quality}');
        debugPrint('🎬   - Headers: ${streamInfo.headers.length} headers');
        debugPrint('🎬   - Referer: ${streamInfo.referer}');
        debugPrint('🎬   - UserAgent: ${streamInfo.userAgent != null ? 'Oui' : 'Non'}');
      } else {
        // Créer un StreamInfo à partir des arguments
        debugPrint('🎬 🔨 Création StreamInfo depuis arguments');

        final url = args['url'] as String? ?? '';
        debugPrint('🎬   - URL fournie: $url');

        if (url.isEmpty) {
          debugPrint('🎬 ❌ URL vide - Impossible de créer le lecteur');
          return _buildErrorRoute(
            'URL vidéo manquante',
            settings,
          );
        }

        streamInfo = StreamInfo(
          url: url,
          title: args['title'] as String? ?? 'Vidéo',
          headers: _parseHeaders(args['headers']),
          quality: args['quality'] as String? ?? 'HD',
          referer: args['referer'] as String?,
          userAgent: args['userAgent'] as String?,
        );

        debugPrint('🎬 ✅ StreamInfo créé');
        debugPrint('🎬   - Title: ${streamInfo.title}');
        debugPrint('🎬   - Quality: ${streamInfo.quality}');
        debugPrint('🎬   - Headers: ${streamInfo.headers.length} headers');
      }

      // ✅ CONVERSION CORRECTE DE startPosition - TOUS LES CAS
      Duration? startPosition;
      if (args.containsKey('startPosition') && args['startPosition'] != null) {
        final startPositionArg = args['startPosition'];
        debugPrint('🎬 📍 Conversion startPosition...');
        debugPrint('🎬   - Type: ${startPositionArg.runtimeType}');
        debugPrint('🎬   - Value: $startPositionArg');

        try {
          // Cas 1: C'est déjà une Duration
          if (startPositionArg is Duration) {
            startPosition = startPositionArg;
            debugPrint('🎬   ✅ Duration directe');
          }
          // Cas 2: C'est un int (millisecondes)
          else if (startPositionArg is int) {
            startPosition = Duration(milliseconds: startPositionArg);
            debugPrint('🎬   ✅ Convertie de int (ms)');
          }
          // Cas 3: C'est un double (secondes ou millisecondes)
          else if (startPositionArg is double) {
            // Si > 1000, probablement en ms, sinon en secondes
            if (startPositionArg > 1000) {
              startPosition = Duration(milliseconds: startPositionArg.toInt());
              debugPrint('🎬   ✅ Convertie de double (ms)');
            } else {
              startPosition = Duration(milliseconds: (startPositionArg * 1000).toInt());
              debugPrint('🎬   ✅ Convertie de double (s)');
            }
          }
          // Cas 4: C'est une String à parser
          else if (startPositionArg is String) {
            try {
              final seconds = int.parse(startPositionArg);
              startPosition = Duration(seconds: seconds);
              debugPrint('🎬   ✅ Convertie de String (s)');
            } catch (e) {
              debugPrint('🎬   ❌ Erreur parsing String: $e');
            }
          } else {
            debugPrint('🎬   ⚠️ Type non reconnu: ${startPositionArg.runtimeType}');
          }
        } catch (e) {
          debugPrint('🎬   ❌ Erreur conversion: $e');
        }

        if (startPosition != null) {
          debugPrint('🎬 ✅ startPosition final: $startPosition');
        } else {
          debugPrint('🎬 ⚠️ startPosition restera null');
        }
      } else {
        debugPrint('🎬 ℹ️ Pas de startPosition fourni');
      }

      // Extraire les autres paramètres optionnels
      final movieTitle = args['movieTitle'] as String?;
      final movieId = args['movieId'] as String?;
      final seriesId = args['seriesId'] as String?;
      final seasonNumber = args['seasonNumber'] as int?;
      final episodeNumber = args['episodeNumber'] as int?;

      debugPrint('🎬 Paramètres optionnels:');
      debugPrint('🎬   - movieTitle: $movieTitle');
      debugPrint('🎬   - movieId: $movieId');
      debugPrint('🎬   - seriesId: $seriesId');
      debugPrint('🎬   - seasonNumber: $seasonNumber');
      debugPrint('🎬   - episodeNumber: $episodeNumber');

      // Créer le lecteur vidéo
      debugPrint('🎬 🎬 Création du SimpleVideoPlayer...');
      
      final videoPlayer = SimpleVideoPlayer(
        videoUrl: streamInfo.url,
        headers: streamInfo.getCompleteHeaders(),
        title: movieTitle ?? seriesId ?? 'Vidéo',
      );

      debugPrint('🎬 ✅ SimpleVideoPlayer créé avec succès');
      debugPrint('🎬 === FIN CRÉATION LECTEUR ===');

      return _buildPageRoute(
        child: videoPlayer,
        isTVMode: PlatformService.isTVMode,
        settings: settings,
      );
    } catch (e, stackTrace) {
      debugPrint('🎬 ❌ ERREUR lors de la création du lecteur: $e');
      debugPrint('🎬 StackTrace: $stackTrace');
      return _buildErrorRoute(
        'Erreur lors de la création du lecteur: $e',
        settings,
      );
    }
  }

  /// Parse les headers depuis les arguments
  static Map<String, String> _parseHeaders(dynamic headers) {
    if (headers == null) {
      debugPrint('🎬 ℹ️ Pas de headers fournis');
      return {};
    }

    debugPrint('🎬 📋 Parsing headers - Type: ${headers.runtimeType}');

    if (headers is Map<String, String>) {
      debugPrint('🎬 ✅ Headers sont Map<String, String>');
      return headers;
    }

    if (headers is Map) {
      try {
        final parsed = headers.cast<String, String>();
        debugPrint('🎬 ✅ Headers castés en Map<String, String>');
        return parsed;
      } catch (e) {
        debugPrint('🎬 ❌ Erreur casting headers: $e');
        return {};
      }
    }

    debugPrint('🎬 ⚠️ Headers type non reconnu: ${headers.runtimeType}');
    return {};
  }

  /// Créer une route avec animation appropriée
  static Route<T> _buildPageRoute<T>({
    required Widget child,
    required bool isTVMode,
    required RouteSettings settings,
  }) {
    return CustomPageRoute<T>(
      child: child,
      isTVMode: isTVMode,
      settings: settings,
    );
  }

  /// Route d'erreur - COMPLÈTE
  static Route<dynamic> _buildErrorRoute(
      String message,
      RouteSettings settings,
      ) {
    debugPrint('🎬 ❌ ROUTE D\'ERREUR: $message');
    return _buildPageRoute(
      child: ErrorScreen(message: message),
      isTVMode: PlatformService.isTVMode,
      settings: settings,
    );
  }

  /// Naviguer vers un écran avec gestion des erreurs
  static Future<void> navigateTo(
      BuildContext context,
      String routeName, {
        Object? arguments,
        String? errorMessage,
      }) {
    debugPrint('🎬 🔀 Navigation vers: $routeName');
    if (arguments != null) {
      debugPrint('🎬   Arguments: ${arguments.runtimeType}');
    }

    return AdvancedNavigationService.navigateToNamedSafely(
      context,
      routeName,
      arguments: arguments,
      errorMessage: errorMessage ?? 'Erreur lors de la navigation vers $routeName',
    );
  }

  /// Naviguer vers un écran avec remplacement
  static Future<void> replaceWith(
      BuildContext context,
      String routeName, {
        Object? arguments,
        String? errorMessage,
      }) {
    try {
      debugPrint('🎬 🔄 Remplacement de route: $routeName');
      return Navigator.of(context).pushReplacementNamed(
        routeName,
        arguments: arguments,
      );
    } catch (e) {
      debugPrint('🎬 ❌ Navigation error: $e');
      if (errorMessage != null && context.mounted) {
        _showErrorDialog(context, errorMessage);
      }
      return Future.value();
    }
  }

  /// Afficher un message d'erreur
  static Future<void> _showErrorDialog(BuildContext context, String message) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Erreur'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Obtenir la map des routes
  static Map<String, WidgetBuilder> get routes => _routes;
}

/// ✅ ÉCRAN D'ERREUR - COMPLET
class ErrorScreen extends StatelessWidget {
  final String message;

  const ErrorScreen({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Erreur'),
        backgroundColor: Colors.red,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Retour'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget pour le splash screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _navigateToPlatformSelection();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
  }

  void _navigateToPlatformSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 2));

      try {
        final isSetupCompleted = await PlatformService.isPlatformSetupCompleted().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            print('⚠️ isPlatformSetupCompleted timed out - assuming not completed');
            return false;
          },
        );

        if (mounted) {
          if (isSetupCompleted) {
            Navigator.pushReplacementNamed(context, '/profile-selection');
          } else {
            Navigator.pushReplacementNamed(context, '/platform-selection');
          }
        }
      } catch (e) {
        print('⚠️ Error checking platform setup: $e - navigating to platform-selection');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/platform-selection');
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPageWrapper(
      isTVMode: PlatformService.isTVMode,
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        body: Center(
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.live_tv,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'NEO STREAM',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Chargement...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
