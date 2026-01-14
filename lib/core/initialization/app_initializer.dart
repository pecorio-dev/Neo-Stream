import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/local_storage/watch_progress_local_service.dart';
// Removed: CpasmieuxImageLoader - not needed for media_kit
import '../../data/repositories/favorites_repository.dart';

class AppInitializer {
  static const String _tag = 'AppInitializer';

  static Future<void> initialize() async {
    try {
      print('$_tag: Starting app initialization...');

      // 0. Initialiser le stockage des favoris
      await _initializeFavoritesStorage();

      // 1. Initialiser la base de données locale
      await _initializeLocalDatabase();

      // 2. Préparer la résolution DNS pour les images
      await _initializeDnsResolution();

      print('$_tag: ✅ App initialization completed');
    } catch (e) {
      print('$_tag: ❌ Initialization error: $e');
      rethrow;
    }
  }

  static Future<void> _initializeFavoritesStorage() async {
    try {
      print('$_tag: Initializing Favorites Storage...');
      await FavoritesRepository.init();
      print('$_tag: ✅ Favorites Storage initialized');
    } catch (e) {
      print('$_tag: ⚠️ Favorites Storage initialization error: $e');
      // Ne pas échouer si le stockage des favoris n'est pas disponible
    }
  }



  static Future<void> _initializeLocalDatabase() async {
    try {
      print('$_tag: Initializing Local Database...');

      final localService = WatchProgressLocalService();
      await localService.database.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print('$_tag: ⚠️ Local Database initialization timed out');
          throw TimeoutException('Database initialization timeout');
        },
      );

      print('$_tag: ✅ Local Database initialized');
    } catch (e) {
      print('$_tag: ❌ Local Database initialization error: $e');
      // Ne pas échouer si la base de données locale n'est pas disponible
    }
  }

  static Future<void> cleanup() async {
    try {
      print('$_tag: Cleaning up resources...');

      final localService = WatchProgressLocalService();
      await localService.close();

      print('$_tag: ✅ Cleanup completed');
    } catch (e) {
      print('$_tag: ⚠️ Cleanup error: $e');
    }
  }

  static Future<Map<String, dynamic>> getInitializationStatus() async {
    try {
      final localService = WatchProgressLocalService();

      return {
        'localDbInitialized': true,
        'localProgressCount': await localService.getProgressCount(),
        'pendingSyncCount': await localService.getPendingSyncCount(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  static Future<void> _initializeDnsResolution() async {
    // DNS resolution for images optimization removed - not needed for media_kit
    print('$_tag: DNS optimization skipped (media_kit ready)');
  }
}

/// Widget pour initialiser l'application avec Riverpod
class AppInitializerWidget extends ConsumerWidget {
  final Widget Function(BuildContext, AsyncSnapshot) builder;

  const AppInitializerWidget({
    Key? key,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<void>(
      future: AppInitializer.initialize(),
      builder: (context, snapshot) {
        return builder(context, snapshot);
      },
    );
  }
}

/// Initialisation complète avec tous les services
Future<void> initializeAppWithSync() async {
  // Initialiser les services de base
  await AppInitializer.initialize();

  // Vous pouvez ajouter des initialisations supplémentaires ici
  // comme la configuration des loggers, analytics, etc.
}
