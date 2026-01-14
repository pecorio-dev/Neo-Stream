# Exemple d'implémentation complète - Reprise de Lecteur avec Google Drive

## 1. Mise à jour de main.dart

Vous devez ajouter Riverpod à votre application. Voici comment modifier `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/initialization/app_initializer.dart';
import 'presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser tous les services
  await initializeAppWithSync();
  
  runApp(
    const ProviderScope(
      child: NeoStreamApp(),
    ),
  );
}

class NeoStreamApp extends StatefulWidget {
  const NeoStreamApp({Key? key}) : super(key: key);

  @override
  State<NeoStreamApp> createState() => _NeoStreamAppState();
}

class _NeoStreamAppState extends State<NeoStreamApp> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // L'initialisation est déjà faite dans main()
    // Vous pouvez ajouter d'autres initialisations ici si nécessaire
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeoStream',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }

  @override
  void dispose() {
    AppInitializer.cleanup();
    super.dispose();
  }
}
```

## 2. Intégration dans une page de détails de film

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/movie.dart';
import '../../presentation/screens/resume_watch_section.dart';
import '../../presentation/screens/player/enhanced_video_player_screen.dart';
import '../../presentation/widgets/sync_status_indicator.dart';

class MovieDetailsScreenIntegrated extends ConsumerStatefulWidget {
  final Movie movie;

  const MovieDetailsScreenIntegrated({
    Key? key,
    required this.movie,
  }) : super(key: key);

  @override
  ConsumerState<MovieDetailsScreenIntegrated> createState() =>
      _MovieDetailsScreenIntegratedState();
}

class _MovieDetailsScreenIntegratedState
    extends ConsumerState<MovieDetailsScreenIntegrated> {
  late StreamInfo _streamInfo;

  @override
  void initState() {
    super.initState();
    _loadStreamInfo();
  }

  Future<void> _loadStreamInfo() async {
    // Charger les informations de streaming du film
    // Cette logique est spécifique à votre application
  }

  void _playMovie({Duration? startPosition}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedVideoPlayerScreen.forMovie(
          streamInfo: _streamInfo,
          movieId: widget.movie.id,
          startPosition: startPosition,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.movie.title),
        actions: [
          // Indicateur de synchronisation dans l'app bar
          Padding(
            padding: const EdgeInsets.all(8),
            child: SyncStatusIndicator(
              showLabel: false,
              size: 24,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image du film
            Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(widget.movie.posterUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Informations du film
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.movie.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.movie.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            // SECTION DE REPRISE DE LECTURE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ResumeWatchSection(
                contentId: widget.movie.id,
                contentType: 'movie',
                title: widget.movie.title,
                duration: Duration(seconds: widget.movie.durationSeconds),
                onResumePressed: () {
                  // La reprise se fera automatiquement dans le player
                  _playMovie();
                },
                onRestartPressed: () {
                  // Commencer depuis le début
                  _playMovie(startPosition: Duration.zero);
                },
              ),
            ),

            const SizedBox(height: 16),

            // Bouton de lecture principal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _playMovie,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Regarder maintenant'),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
```

## 3. Intégration dans le Video Player

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/watch_progress_auto_save_service.dart';
import '../../data/services/sync/auto_sync_service.dart';
import '../../data/services/sync/google_drive_service.dart';
import '../../core/services/watch_progress_service.dart';
import '../../presentation/providers/google_auth_provider.dart';
import '../../presentation/providers/google_drive_provider.dart';
import '../../presentation/providers/auto_sync_provider.dart';

class EnhancedVideoPlayerScreenIntegrated extends ConsumerStatefulWidget {
  final StreamInfo streamInfo;
  final String? movieId;
  final String? seriesId;
  final int? seasonNumber;
  final int? episodeNumber;
  final Duration? startPosition;

  const EnhancedVideoPlayerScreenIntegrated({
    Key? key,
    required this.streamInfo,
    this.movieId,
    this.seriesId,
    this.seasonNumber,
    this.episodeNumber,
    this.startPosition,
  }) : super(key: key);

  @override
  ConsumerState<EnhancedVideoPlayerScreenIntegrated> createState() =>
      _EnhancedVideoPlayerScreenIntegratedState();
}

class _EnhancedVideoPlayerScreenIntegratedState
    extends ConsumerState<EnhancedVideoPlayerScreenIntegrated> {
  VideoPlayerController? _controller;
  late WatchProgressAutoSaveService _autoSaveService;
  late AutoSyncService _syncService;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _setupSyncServices();
  }

  Future<void> _setupSyncServices() async {
    try {
      // Récupérer les services depuis les providers
      final driveService = GoogleDriveService(
        authService: ref.read(googleAuthServiceProvider),
      );

      _syncService = AutoSyncService(
        driveService: driveService,
      );
      await _syncService.initialize();

      // Créer le service d'auto-sauvegarde
      _autoSaveService = WatchProgressAutoSaveService(
        autoSyncService: _syncService,
      );

      // Démarrer l'auto-sauvegarde
      if (_controller != null) {
        _autoSaveService.startAutoSave(
          contentId: widget.movieId ?? widget.seriesId ?? 'unknown',
          contentType: widget.movieId != null ? 'movie' : 'series',
          title: widget.streamInfo.title,
          totalDuration: _controller!.value.duration,
          seasonNumber: widget.seasonNumber,
          episodeNumber: widget.episodeNumber,
          episodeTitle: widget.streamInfo.title,
          getCurrentPosition: () => _controller?.value.position ?? Duration.zero,
        );
      }
    } catch (e) {
      print('Error setting up sync services: $e');
    }
  }

  Future<void> _initializePlayer() async {
    try {
      _controller = VideoPlayerController.network(widget.streamInfo.url)
        ..addListener(() {
          setState(() {
            _currentPosition = _controller!.value.position;
          });
        })
        ..initialize().then((_) {
          // Charger la position sauvegardée
          _loadSavedPosition();
          setState(() {});
        });
    } catch (e) {
      print('Error initializing player: $e');
    }
  }

  Future<void> _loadSavedPosition() async {
    try {
      final contentId = widget.movieId ?? widget.seriesId ?? 'unknown';
      final contentType = widget.movieId != null ? 'movie' : 'series';

      final progress = await WatchProgressService.getProgress(
        contentId,
        contentType: contentType,
        seasonNumber: widget.seasonNumber,
        episodeNumber: widget.episodeNumber,
      );

      if (progress != null && progress.progressPercentage < 0.95) {
        final startPos = widget.startPosition ?? 
            Duration(seconds: progress.resumePosition);
        await _controller?.seekTo(startPos);
      } else if (widget.startPosition != null) {
        await _controller?.seekTo(widget.startPosition!);
      }

      setState(() {});
    } catch (e) {
      print('Error loading saved position: $e');
    }
  }

  @override
  void dispose() {
    // Sauvegarder la progression finale et synchroniser
    if (_controller != null) {
      _autoSaveService.saveOnExit(
        contentId: widget.movieId ?? widget.seriesId ?? 'unknown',
        contentType: widget.movieId != null ? 'movie' : 'series',
        title: widget.streamInfo.title,
        position: _currentPosition,
        duration: _controller!.value.duration,
        seasonNumber: widget.seasonNumber,
        episodeNumber: widget.episodeNumber,
        episodeTitle: widget.streamInfo.title,
      );

      _autoSaveService.stopAutoSave();
      _controller!.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller!),
              
              // Contrôles personnalisés
              VideoPlayerControls(
                controller: _controller!,
                onPlayPauseChanged: (isPlaying) {
                  if (isPlaying) {
                    _controller!.play();
                  } else {
                    _controller!.pause();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## 4. Intégration dans une page de détails de série

```dart
class SeriesDetailsScreenIntegrated extends ConsumerWidget {
  final Series series;

  const SeriesDetailsScreenIntegrated({
    Key? key,
    required this.series,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(series.title),
        actions: [
          // Indicateur de synchronisation
          Padding(
            padding: const EdgeInsets.all(8),
            child: SyncStatusIndicator(
              showLabel: false,
              size: 24,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Image de la série
            // ...

            // Section de reprise - dernier épisode regardé
            FutureBuilder<List<WatchProgress>>(
              future: WatchProgressService.getSeriesProgress(series.id),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  final progresses = snapshot.data!;
                  progresses.sort(
                    (a, b) => b.lastWatched.compareTo(a.lastWatched),
                  );
                  final lastProgress = progresses.first;

                  if (lastProgress.progressPercentage < 0.95) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: ResumeWatchSection(
                        contentId: series.id,
                        contentType: 'series',
                        title:
                            'S${lastProgress.seasonNumber}E${lastProgress.episodeNumber}: ${lastProgress.episodeTitle}',
                        duration: Duration(seconds: lastProgress.duration),
                        seasonNumber: lastProgress.seasonNumber,
                        episodeNumber: lastProgress.episodeNumber,
                        onResumePressed: () {
                          // Reprendre l'épisode
                        },
                        onRestartPressed: () {
                          // Recommencer l'épisode
                        },
                      ),
                    );
                  }
                }

                return const SizedBox.shrink();
              },
            ),

            // Liste des saisons et épisodes
            // ...
          ],
        ),
      ),
    );
  }
}
```

## 5. Paramètres de synchronisation

```dart
// Dans settings_screen.dart
ListTile(
  title: const Text('Synchronisation Google Drive'),
  subtitle: const Text('Gérer la synchronisation cloud'),
  trailing: const Icon(Icons.arrow_forward),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => 
            const GoogleDriveSyncSettingsScreen(),
      ),
    );
  },
),
```

## Points clés à retenir

1. **Initialisation**: Appelez `initializeAppWithSync()` dans `main()`
2. **Authentification**: L'utilisateur doit être connecté avec Google
3. **Auto-sauvegarde**: Démarre automatiquement dans le lecteur vidéo
4. **Synchronisation**: Se produit toutes les 5 minutes ou à la fermeture
5. **Fusion**: Les données locales et cloud sont fusionnées intelligemment
6. **UX**: L'indicateur de statut montre l'état de la synchronisation

## Dépannage

- Vérifiez que Google Sign-In est configuré dans Firebase
- Vérifiez les permissions Google Drive dans la console Google Cloud
- Consultez les logs avec `flutter logs`
- Utilisez `AppInitializer.getInitializationStatus()` pour diagnostiquer
