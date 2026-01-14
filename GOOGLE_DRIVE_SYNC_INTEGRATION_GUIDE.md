# Guide d'intégration - Synchronisation Google Drive avec Reprise de Lecteur

## Vue d'ensemble

Ce guide décrit comment intégrer le système complet de synchronisation Google Drive avec reprise de lecteur dans votre application NEO-Stream.

## Architecture

### Services créés

1. **GoogleAuthService** (`lib/data/services/google_auth_service.dart`)
   - Gère l'authentification Google Sign-In
   - Obtient et actualise les tokens d'accès
   - Sauvegarde les données d'authentification

2. **GoogleDriveService** (`lib/data/services/sync/google_drive_service.dart`)
   - Upload/télécharge la progression depuis Google Drive
   - Fusionne les données locales et cloud
   - Gère les métadonnées de synchronisation

3. **AutoSyncService** (`lib/data/services/sync/auto_sync_service.dart`)
   - Synchronisation automatique en arrière-plan (tous les 5 minutes)
   - Fusion intelligente des données
   - Gestion des synchronisations en attente

4. **WatchProgressAutoSaveService** (`lib/data/services/watch_progress_auto_save_service.dart`)
   - Auto-sauvegarde locale de la progression (toutes les 10 secondes)
   - Sauvegarde finale à la fermeture du lecteur
   - Déclenche les synchronisations cloud si nécessaire

### Providers Riverpod

- `googleAuthServiceProvider` - Instance du service d'authentification
- `googleAuthStateProvider` - État actuel de l'authentification
- `googleDriveServiceProvider` - Instance du service Google Drive
- `autoSyncServiceProvider` - Instance du service de synchronisation automatique
- `autoSyncStatsProvider` - Statistiques de synchronisation

### Widgets

- `SyncStatusIndicator` - Indicateur visuel du statut de synchronisation
- `ResumeProgressBar` - Barre de progression avec options de reprise
- `ResumeWatchSection` - Section complète pour la reprise de lecture

## Implémentation dans le Video Player

### 1. Intégration basique

```dart
class VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late WatchProgressAutoSaveService _autoSaveService;
  late AutoSyncService _syncService;

  @override
  void initState() {
    super.initState();
    _initializeSyncServices();
  }

  Future<void> _initializeSyncServices() async {
    // Initialiser le service de synchronisation
    _syncService = AutoSyncService(
      driveService: GoogleDriveService(),
    );
    await _syncService.initialize();

    // Initialiser le service d'auto-sauvegarde
    _autoSaveService = WatchProgressAutoSaveService(
      autoSyncService: _syncService,
    );

    // Démarrer l'auto-sauvegarde
    _autoSaveService.startAutoSave(
      contentId: widget.contentId,
      contentType: widget.contentType,
      title: widget.title,
      totalDuration: _videoController.value.duration,
      seasonNumber: widget.seasonNumber,
      episodeNumber: widget.episodeNumber,
      episodeTitle: widget.episodeTitle,
      getCurrentPosition: () => _videoController.value.position,
    );
  }

  @override
  void dispose() {
    // Sauvegarder la position finale et synchroniser
    _autoSaveService.saveOnExit(
      contentId: widget.contentId,
      contentType: widget.contentType,
      title: widget.title,
      position: _videoController.value.position,
      duration: _videoController.value.duration,
      seasonNumber: widget.seasonNumber,
      episodeNumber: widget.episodeNumber,
      episodeTitle: widget.episodeTitle,
    );

    _autoSaveService.stopAutoSave();
    _videoController.dispose();
    super.dispose();
  }
}
```

### 2. Charger la progression sauvegardée

```dart
Future<void> _loadSavedProgress() async {
  final progress = await WatchProgressService.getProgress(
    widget.contentId,
    seasonNumber: widget.seasonNumber,
    episodeNumber: widget.episodeNumber,
  );

  if (progress != null && progress.progressPercentage < 0.95) {
    // Proposer de reprendre
    _showResumeDialog(progress);
  }
}

void _showResumeDialog(WatchProgress progress) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Reprendre la lecture ?'),
      content: Text(
        'Continuer depuis ${progress.formattedPosition} ?'
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _videoController.seekTo(Duration(seconds: progress.resumePosition));
            _videoController.play();
          },
          child: const Text('Continuer'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _videoController.play();
          },
          child: const Text('Recommencer'),
        ),
      ],
    ),
  );
}
```

## Implémentation dans les Pages de Détails

### 1. Afficher la section de reprise

```dart
class MovieDetailsScreen extends StatelessWidget {
  final Movie movie;

  const MovieDetailsScreen({required this.movie});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ... contenu existant ...
            
            // Section de reprise de lecture
            ResumeWatchSection(
              contentId: movie.id,
              contentType: 'movie',
              title: movie.title,
              duration: Duration(seconds: movie.durationSeconds),
              onResumePressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen.forMovie(
                      movieId: movie.id,
                      streamInfo: _streamInfo,
                    ),
                  ),
                );
              },
              onRestartPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen.forMovie(
                      movieId: movie.id,
                      streamInfo: _streamInfo,
                      startPosition: Duration.zero,
                    ),
                  ),
                );
              },
            ),

            // ... reste du contenu ...
          ],
        ),
      ),
    );
  }
}
```

### 2. Ajouter l'indicateur de synchronisation

```dart
class SeriesDetailsScreen extends ConsumerWidget {
  final Series series;

  const SeriesDetailsScreen({required this.series});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(series.title),
        actions: [
          // Indicateur de synchronisation
          Padding(
            padding: const EdgeInsets.all(12),
            child: SyncStatusIndicator(
              showLabel: true,
              size: 20,
            ),
          ),
          // ... autres actions ...
        ],
      ),
      body: ListView(
        children: [
          // ... contenu existant ...
          
          // Section de reprise pour le dernier épisode regardé
          FutureBuilder<WatchProgress?>(
            future: WatchProgressService.getSeriesProgress(series.id),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                final lastProgress = snapshot.data!;
                return ResumeWatchSection(
                  contentId: series.id,
                  contentType: 'series',
                  title: '${lastProgress.title} - S${lastProgress.seasonNumber}E${lastProgress.episodeNumber}',
                  duration: Duration(seconds: lastProgress.duration),
                  seasonNumber: lastProgress.seasonNumber,
                  episodeNumber: lastProgress.episodeNumber,
                  onResumePressed: () {
                    // Reprendre la lecture
                  },
                  onRestartPressed: () {
                    // Recommencer l'épisode
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // ... reste du contenu ...
        ],
      ),
    );
  }
}
```

## Configuration requise

### 1. Variables d'environnement `.env`

```env
GOOGLE_OAUTH_CLIENT_ID=your_client_id.apps.googleusercontent.com
```

### 2. Configuration Android (`android/build.gradle`)

```gradle
google_sign_in: ^6.2.1
googleapis: ^11.4.0
```

### 3. Configuration iOS (iOS/Podfile)

```ruby
pod 'GoogleSignIn'
```

### 4. Permissions AndroidManifest.xml

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

## Flux de synchronisation

```
┌─────────────────────────────────────────────────────────────┐
│                    Lecture d'une vidéo                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
   ┌────▼────┐                  ┌────▼────────┐
   │ 10 sec  │                  │ À la sortie  │
   │  (auto- │                  │   du player  │
   │  save)  │                  │              │
   └────┬────┘                  └────┬─────────┘
        │                            │
        │ Toutes les 5 min          │ Forcer un sync
        │ sync si changements       │
        │                            │
        ├────────────┬───────────────┤
        │            │               │
    ┌───▼────────────▼──────┐   ┌───▼─────────┐
    │  Google Drive Sync    │   │  Local Save │
    │  - Fusionner données  │   │  - Sauver   │
    │  - Upload/Download    │   │  - BDD      │
    └───────────────────────┘   └─────────────┘
```

## Gestion des erreurs

### Erreurs de synchronisation

```dart
try {
  await autoSyncService.syncIfNeeded();
} catch (e) {
  print('Erreur de sync: $e');
  // Afficher un message à l'utilisateur
  // La prochaine tentative aura lieu automatiquement
}
```

### Erreur d'authentification

```dart
final authService = GoogleAuthService();
await authService.initialize();

if (!authService.isSignedIn) {
  // Afficher l'écran de connexion
  await authService.signIn();
}
```

## Tests

### Test des services

```dart
void main() {
  test('GoogleDriveService upload', () async {
    final authService = GoogleAuthService();
    await authService.signIn();
    
    final driveService = GoogleDriveService(authService: authService);
    final success = await driveService.uploadProgress([]);
    
    expect(success, true);
  });

  test('AutoSyncService merge', () async {
    final syncService = AutoSyncService(
      driveService: mockDriveService,
    );
    
    final merged = syncService.mergeProgress(localProgress, cloudProgress);
    expect(merged.length, greaterThan(0));
  });
}
```

## Bonnes pratiques

1. **Synchronisation régulière**: Laisser la synchronisation automatique activée
2. **Gestion des quotas**: Limiter les uploads fréquents (5 minutes minimum)
3. **Fusion intelligente**: Toujours fusionner plutôt que remplacer
4. **Sauvegarde locale**: Conserver les données locales même en cas d'erreur cloud
5. **UX transparente**: Ne pas bloquer l'application pendant la synchronisation

## Dépannage

### La synchronisation ne fonctionne pas

1. Vérifier la connexion internet
2. Vérifier que Google Sign-In est configuré
3. Vérifier les permissions Google Drive
4. Vérifier les logs: `adb logcat | grep GoogleDriveSyncService`

### Les données ne se synchronisent pas

1. Vérifier le token d'accès: `GoogleAuthService().accessToken`
2. Vérifier l'espace disponible sur Google Drive
3. Forcer une synchronisation: `autoSyncService.forceSyncNow()`

### Problèmes de fusion de données

1. Vérifier les timestamps `lastWatched`
2. Vérifier les IDs de contenu sont identiques
3. Consulter les logs de fusion

## Ressources

- [Google Sign-In pour Flutter](https://pub.dev/packages/google_sign_in)
- [Google Drive API](https://developers.google.com/drive/api)
- [Riverpod Documentation](https://riverpod.dev)
- [Flutter Concurrency](https://dart.dev/guides/language/concurrency)

## Support

Pour toute question ou problème, consultez:
- Les logs applicatifs
- Les tests unitaires fournis
- La documentation officielle de Google APIs
