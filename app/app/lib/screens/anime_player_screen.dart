import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';

import '../config/theme.dart';
import '../config/neo.dart';
import '../models/anime.dart';
import '../services/anime_extractor.dart';
import '../services/api_service.dart';
import '../services/player_prefs.dart';

class AnimePlayerScreen extends StatefulWidget {
  final Anime anime;
  final int seasonNumber;
  final AnimeEpisode episode;
  final List<Map<String, String>> sources;

  AnimePlayerScreen({
    super.key,
    required this.anime,
    required this.seasonNumber,
    required this.episode,
    required this.sources,
  });

  @override
  State<AnimePlayerScreen> createState() => _AnimePlayerScreenState();
}

class _AnimePlayerScreenState extends State<AnimePlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  final ApiService _api = ApiService();
  Timer? _progressTimer;
  Timer? _controlsTimer;
  bool _showControls = true;

  bool _isExtracting = true;
  String? _errorMessage;
  String? _extractorUsed;
  int _currentSourceIndex = 0;
  bool _recoveringFromError = false;

  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<bool>? _playingSub;

  int _playbackRetryCount = 0;
  static const int _maxPlaybackRetries = 3;
  Duration? _resumePosition;

  // Incrémente à chaque extraction pour ignorer une réponse devenue obsolète
  // après un changement de source ou la fermeture du lecteur.
  int _extractionGeneration = 0;

  // Gestion des erreurs réseau temporaires
  bool _isWaitingForNetwork = false;
  Timer? _networkRetryTimer;

  /// Clé stable pour le cache local de progression (anime/saison/épisode).
  String get _progressKey =>
      'anime_${widget.anime.id}_${widget.seasonNumber}_${widget.episode.episodeNumber}';

  Map<String, String>? get _selectedSource =>
      widget.sources.isEmpty ? null : widget.sources[_currentSourceIndex];

  bool get _selectedSourceIsSibnet {
    final source = _selectedSource;
    if (source == null) return false;
    final player = (source['player'] ?? '').toLowerCase();
    final url = (source['url'] ?? '').toLowerCase();
    return player.contains('sibnet') || url.contains('sibnet');
  }

  String get _selectedSourceLabel {
    final source = _selectedSource;
    if (source == null) return 'Source inconnue';
    final player = source['player']?.trim();
    if (player != null && player.isNotEmpty) return player;
    return Uri.tryParse(source['url'] ?? '')?.host ?? 'Source inconnue';
  }

  /// Seek robuste : attend que la durée du flux soit connue avant de seek,
  /// sinon media_kit ignore le seek (cause du « retour au début »).
  Future<void> _seekWhenReady(Duration target) async {
    if (target.inSeconds <= 0) return;
    if (_player.state.duration.inSeconds > 0) {
      await _player.seek(target);
      return;
    }
    try {
      await _player.stream.duration
          .firstWhere((d) => d.inSeconds > 0)
          .timeout(Duration(seconds: 25));
    } catch (_) {}
    if (!mounted) return;
    final dur = _player.state.duration;
    final clamped = (dur.inSeconds > 0 && target > dur) ? dur : target;
    await _player.seek(clamped);
  }

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
        androidAttachSurfaceAfterVideoParameters: true,
      ),
    );

    // Sibnet coupe parfois son CDN après quelques minutes. Préférer une autre
    // source quand elle existe, sans empêcher l'utilisateur de choisir Sibnet.
    final nonSibnetIndex = widget.sources.indexWhere((source) {
      final player = (source['player'] ?? '').toLowerCase();
      final url = (source['url'] ?? '').toLowerCase();
      return !player.contains('sibnet') && !url.contains('sibnet');
    });
    if (nonSibnetIndex >= 0) _currentSourceIndex = nonSibnetIndex;

    WakelockPlus.enable();
    if (!NeoTheme.isDesktopPlatform) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    _errorSub = _player.stream.error.listen((error) {
      if (!mounted || _recoveringFromError) return;
      _recoveringFromError = true;

      final errorStr = error.toString().toLowerCase();
      final isNetworkError = errorStr.contains('network') ||
                             errorStr.contains('timeout') ||
                             errorStr.contains('connection') ||
                             errorStr.contains('unreachable');

      // Erreur réseau temporaire : pause + attente sans réextraction
      if (isNetworkError && _playbackRetryCount < _maxPlaybackRetries) {
        _playbackRetryCount++;
        final pos = _player.state.position;
        if (pos.inSeconds > 0) _resumePosition = pos;

        setState(() {
          _isWaitingForNetwork = true;
        });

        _player.pause();

        // Retry automatique après délai croissant (3s, 6s, 9s...)
        final retryDelay = Duration(seconds: 3 * _playbackRetryCount);
        _networkRetryTimer?.cancel();
        _networkRetryTimer = Timer(retryDelay, () {
          if (!mounted) return;
          setState(() {
            _isWaitingForNetwork = false;
          });
          if (_resumePosition != null && _resumePosition!.inSeconds > 0) {
            _player.play();
            _seekWhenReady(_resumePosition!);
          } else {
            _player.play();
          }
          _recoveringFromError = false;
        });
        return;
      }

      // Erreur non-réseau ou max retries atteint
      if (_playbackRetryCount < _maxPlaybackRetries) {
        _playbackRetryCount++;
        final pos = _player.state.position;
        if (pos.inSeconds > 0) _resumePosition = pos;

        // Source stable (Sibnet, Sendvid) : pas de re-extraction,
        // on retente la lecture a la meme position.
        if (_selectedSourceIsSibnet || _isStableExtractor(_extractorUsed)) {
          Future.delayed(Duration(seconds: 2), () {
            if (!mounted) return;
            if (_resumePosition != null && _resumePosition!.inSeconds > 0) {
              _player.play();
              _seekWhenReady(_resumePosition!);
            } else {
              _player.play();
            }
            _recoveringFromError = false;
          });
        } else {
          // Une nouvelle extraction est réservée à une vraie erreur de lecture.
          // Elle n'est jamais déclenchée par une minuterie pendant le visionnage.
          Future.delayed(Duration(seconds: 1), () {
            if (mounted) {
              _recoveringFromError = false;
              _extractVideo();
            }
          });
        }
      } else if (_errorMessage == null) {
        _recoveringFromError = false;
        setState(() {
          _errorMessage = 'Erreur de lecture: $error';
          _isExtracting = false;
        });
      }
    });

    _completedSub = _player.stream.completed.listen((completed) {
      if (completed) _saveProgressSync();
    });

    _playingSub = _player.stream.playing.listen((playing) {
      if (playing) _recoveringFromError = false;
    });

    _extractVideo();
  }

  @override
  void dispose() {
    _saveProgressSync();
    _progressTimer?.cancel();
    _controlsTimer?.cancel();
    _extractionGeneration++;
    _networkRetryTimer?.cancel();
    _errorSub?.cancel();
    _completedSub?.cancel();
    _playingSub?.cancel();
    WakelockPlus.disable();
    if (!NeoTheme.isDesktopPlatform) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _extractVideo() async {
    if (!mounted) return;
    final generation = ++_extractionGeneration;
    setState(() {
      _isExtracting = true;
      _errorMessage = null;
    });

    try {
      Map<String, dynamic> result = {'success': false};
      int startIndex = _currentSourceIndex;
      int totalSources = widget.sources.length;

      // Parcourir toutes les sources disponibles en fallback automatique
      for (int i = 0; i < totalSources; i++) {
        int targetIndex = (startIndex + i) % totalSources;
        final source = widget.sources[targetIndex];
        final sourceUrl = source['url'];

        if (sourceUrl == null || sourceUrl.isEmpty) continue;

        // Tenter l'extraction client-side
        result = await AnimeExtractor.extract(sourceUrl);

        // Si échec client-side, tenter l'extraction serveur
        if (result['success'] != true) {
          try {
            final serverResult = await _api.extractVideoUrlServer(sourceUrl);
            if (serverResult['success'] == true) {
              result = serverResult;
            }
          } catch (_) {}
        }

        if (result['success'] == true) {
          _currentSourceIndex = targetIndex;
          break;
        }
      }

      if (!mounted || generation != _extractionGeneration) return;

      if (result['success'] == true) {
        final videoUrl = result['video_url'] as String;
        final extractor = result['extractor'] as String?;

        setState(() {
          _extractorUsed = extractor;
          _isExtracting = false;
        });

        await _loadVideo(videoUrl, extractor, generation);
      } else {
        setState(() {
        _errorMessage = "Aucun lien trouvé sur l'ensemble des ${widget.sources.length} sources.";
        _isExtracting = false;
      });
    } catch (e) {
      if (!mounted || generation != _extractionGeneration) return;
      setState(() {
        _errorMessage = "Erreur lors de l'extraction: $e";
        _isExtracting = false;
      });
    }
  }

  Future<void> _loadVideo(
    String videoUrl,
    String? extractor,
    int generation,
  ) async {
    if (!mounted || generation != _extractionGeneration) return;
    final headers = _getHeadersForExtractor(extractor, videoUrl);
    final media = Media(videoUrl, httpHeaders: headers);

    await _player.open(media, play: true);
    if (!mounted || generation != _extractionGeneration) return;
    _playbackRetryCount = 0;
    
    // Ensure video track selected to prevent black screen / audio-only
    try {
      final tracks = _player.state.tracks;
      if (tracks.video.isNotEmpty) {
        await _player.setVideoTrack(tracks.video.first);
      } else {
        await _player.setVideoTrack(VideoTrack.auto());
      }
    } catch (_) {}

    if (_resumePosition != null && _resumePosition!.inSeconds > 0) {
      _player.play();
      await _seekWhenReady(_resumePosition!);
      _resumePosition = null;
    } else {
      await _restoreProgress();
    }
    _startProgressTimer();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(Duration(seconds: 15), (_) {
      _saveProgress();
    });
  }

  void _saveProgressSync() {
    final position = _player.state.position.inSeconds.toDouble();
    final duration = _player.state.duration.inSeconds.toDouble();
    if (position <= 0) return;
    PlayerPrefs.saveLocalProgress(
      _progressKey,
      position: position,
      duration: duration,
    );
    if (duration <= 0) return;
    try {
      _api.saveAnimeProgress(
        animeId: widget.anime.id,
        seasonNumber: widget.seasonNumber,
        episodeNumber: widget.episode.episodeNumber,
        currentTime: position,
        totalDuration: duration,
      );
    } catch (_) {}
  }

  Future<void> _saveProgress() async {
    final position = _player.state.position.inSeconds.toDouble();
    final duration = _player.state.duration.inSeconds.toDouble();

    if (position <= 0) {
      return;
    }
    await PlayerPrefs.saveLocalProgress(
      _progressKey,
      position: position,
      duration: duration,
    );

    if (duration <= 0) {
      return;
    }

    try {
      await _api.saveAnimeProgress(
        animeId: widget.anime.id,
        seasonNumber: widget.seasonNumber,
        episodeNumber: widget.episode.episodeNumber,
        currentTime: position,
        totalDuration: duration,
      );
    } catch (e) {
      // Ignorer les erreurs de sauvegarde
    }
  }

  Future<void> _restoreProgress() async {
    if (!mounted) return;

    var bestTime = 0.0;

    // 1) Reprise immédiate depuis le cache local.
    try {
      final local = await PlayerPrefs.loadLocalProgress(_progressKey);
      if (local != null) {
        final localPct =
            local.duration > 0 ? (local.position / local.duration) * 100 : 0;
        if (localPct < 95 && local.position > 10 && mounted) {
          bestTime = local.position;
        }
      }
    } catch (_) {}

    // 2) Réconciliation API (timeout court).
    try {
      final progress = await _api
          .getAnimeProgress(
            animeId: widget.anime.id,
            seasonNumber: widget.seasonNumber,
            episodeNumber: widget.episode.episodeNumber,
          )
          .timeout(Duration(seconds: 3));

      if (progress != null && mounted) {
        final currentTime = (progress['current_time'] as num?)?.toDouble() ?? 0;
        final progressPercent = double.tryParse(progress['progress_percent']?.toString() ?? '0') ?? 0;

        if (progressPercent < 95 &&
            currentTime > 10 &&
            currentTime > bestTime + 10) {
          bestTime = currentTime;
        }
      }
    } catch (_) {}

    if (!mounted) return;

    // S'il y a une position de reprise significative (> 10 secondes)
    if (bestTime > 10) {
      final targetDuration = Duration(seconds: bestTime.toInt());
      bool shouldResume = false;

      if (mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierColor: Color(0xB3000000),
          builder: (dialogCtx) => _ResumeDialog(
            position: targetDuration,
            onResume: () {
              shouldResume = true;
              Navigator.pop(dialogCtx);
            },
            onRestart: () {
              shouldResume = false;
              Navigator.pop(dialogCtx);
            },
          ),
        );
      }

      if (!mounted) return;

      if (shouldResume) {
        final seekTarget = Duration(
          seconds: (bestTime - 3).clamp(0, double.maxFinite).toInt(),
        );
        await _seekWhenReady(seekTarget);
      } else {
        }
    }

    if (mounted) {
      _player.play();
    }
  }

  /// Retourne les headers HTTP appropriés selon l'extracteur
  Map<String, String> _getHeadersForExtractor(String? extractor, String videoUrl) {
    final headers = <String, String>{
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': '*/*',
      'Accept-Language': 'fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7',
      'Connection': 'keep-alive',
    };

    // Headers spécifiques selon l'extracteur
    switch (extractor) {
      case 'sibnet':
      case 'sibnet_html':
        headers['Referer'] = 'https://video.sibnet.ru/';
        headers['Origin'] = 'https://video.sibnet.ru';
        break;
        
      case 'sendvid':
        headers['Referer'] = 'https://sendvid.com/';
        headers['Origin'] = 'https://sendvid.com';
        break;
        
      case 'vidmoly':
      case 'vidmoly_html':
      case 'vidmoly_api':
        headers['Referer'] = 'https://vidmoly.to/';
        headers['Origin'] = 'https://vidmoly.to';
        break;
        
      case 'oneupload':
        headers['Referer'] = 'https://oneupload.to/';
        break;
        
      case 'movearnpre':
        headers['Referer'] = 'https://movearnpre.com/';
        break;
        
      default:
        // Headers génériques pour anime
        headers['Referer'] = 'https://anime-sama.to/';
    }

    // Pour les vidéos HLS (.m3u8), ajouter des headers spécifiques
    if (videoUrl.contains('.m3u8')) {
      headers['Accept'] = 'application/vnd.apple.mpegurl, application/x-mpegurl, */*';
    }

    return headers;
  }

  /// Detecte si l'extracteur utilise des URLs stables (pas d'expiration CDN).
  /// Pour ces sources, on ne re-extrait jamais : on retente la lecture directement.
  bool _isStableExtractor(String? extractor) {
    if (extractor == null) return false;
    const stableExtractors = ['sibnet', 'sibnet_html', 'sendvid'];
    return stableExtractors.contains(extractor.toLowerCase());
  }

  Future<void> _showSourcePicker() async {
    if (widget.sources.isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101018),
        title: const Text(
          'Choisir un lecteur',
          style: TextStyle(color: Colors.white),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: MediaQuery.of(context).size.height * .65,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.sources.length,
            itemBuilder: (_, index) {
              final source = widget.sources[index];
              final player = source['player']?.trim();
              final label = player == null || player.isEmpty
                  ? Uri.tryParse(source['url'] ?? '')?.host ??
                      'Source ${index + 1}'
                  : player;
              return ListTile(
                leading: Icon(
                  index == _currentSourceIndex
                      ? Icons.check_circle_rounded
                      : Icons.play_circle_outline_rounded,
                  color: index == _currentSourceIndex
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white70,
                ),
                title: Text(label, style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  index == _currentSourceIndex ? 'En cours' : 'Changer de source',
                  style: const TextStyle(color: Colors.white60),
                ),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _switchSource(index);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _switchSource(int index) {
    if (index < 0 || index >= widget.sources.length ||
        index == _currentSourceIndex) return;
    final position = _player.state.position;
    _networkRetryTimer?.cancel();
    setState(() {
      _currentSourceIndex = index;
      _resumePosition = position.inSeconds > 0 ? position : null;
      _playbackRetryCount = 0;
      _isWaitingForNetwork = false;
      _recoveringFromError = false;
    });
    _extractVideo();
  }

  KeyEventResult _handleTVKeys(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Back / Escape : quitter le lecteur
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      _saveProgressSync();
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    // Play/Pause : centre de la telecommande ou touche media
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      _player.playOrPause();
      _showControlsBriefly();
      return KeyEventResult.handled;
    }

    // Seek avant (+10s) : D-pad droite ou fast-forward
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaFastForward) {
      final pos = _player.state.position + Duration(seconds: 10);
      final dur = _player.state.duration;
      _player.seek(pos > dur ? dur : pos);
      _showControlsBriefly();
      return KeyEventResult.handled;
    }

    // Seek arriere (-10s) : D-pad gauche ou rewind
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.mediaRewind) {
      final pos = _player.state.position - Duration(seconds: 10);
      _player.seek(pos < Duration.zero ? Duration.zero : pos);
      _showControlsBriefly();
      return KeyEventResult.handled;
    }

    // Volume up : D-pad haut ou touche volume
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.audioVolumeUp) {
      final current = _player.state.volume;
      _player.setVolume((current + 10).clamp(0, 100));
      _showControlsBriefly();
      return KeyEventResult.handled;
    }

    // Volume down : D-pad bas ou touche volume
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.audioVolumeDown) {
      final current = _player.state.volume;
      _player.setVolume((current - 10).clamp(0, 100));
      _showControlsBriefly();
      return KeyEventResult.handled;
    }

    // Mute toggle
    if (key == LogicalKeyboardKey.audioVolumeMute) {
      final current = _player.state.volume;
      _player.setVolume(current > 0 ? 0 : 100);
      _showControlsBriefly();
      return KeyEventResult.handled;
    }

    // Menu / contextMenu : ouvrir les parametres du lecteur
    if (key == LogicalKeyboardKey.contextMenu ||
        key == LogicalKeyboardKey.f10 ||
        key == LogicalKeyboardKey.info) {
      _showSourcePicker();
      return KeyEventResult.handled;
    }

    // Media stop : quitter le lecteur
    if (key == LogicalKeyboardKey.mediaStop) {
      _saveProgressSync();
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleTVKeys,
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isExtracting)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                  SizedBox(height: 24),
                  Text(
                    'Extraction de la vidéo...',
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Essai des différentes sources',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            )
          else if (_errorMessage != null && !_isWaitingForNetwork)
            Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: NeoTheme.errorRed),
                    SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Retour'),
                    ),
                    SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _extractVideo,
                      child: Text('Réessayer (toutes les sources)'),
                    ),
                    if (widget.sources.length > 1) ...[
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _showSourcePicker,
                        icon: const Icon(Icons.tune_rounded),
                        label: Text('Changer de source (${widget.sources.length} disponibles)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else if (_isWaitingForNetwork)
            _buildNetworkWaitingOverlay()
          else
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_showControls) {
                  setState(() => _showControls = false);
                  _controlsTimer?.cancel();
                } else {
                  _showControlsBriefly();
                }
              },
              child: SizedBox.expand(
                child: Video(
                  controller: _controller,
                  controls: NoVideoControls,
                ),
              ),
            ),

          // Top bar overlay
          if (!_isExtracting && _errorMessage == null && !_isWaitingForNetwork)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  duration: Duration(milliseconds: 300),
                  opacity: _showControls ? 1.0 : 0.0,
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 16,
                      right: 16,
                      bottom: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            _saveProgressSync();
                            Navigator.of(context).pop();
                          },
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.anime.title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'S${widget.seasonNumber} E${widget.episode.episodeNumber}',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              if (_extractorUsed != null)
                                Text(
                                  'Source: $_selectedSourceLabel',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        IconButton(
                          tooltip: 'Choisir un lecteur',
                          icon: const Icon(
                            Icons.switch_video_rounded,
                            color: Colors.white,
                          ),
                          onPressed: _showSourcePicker,
                        ),
                        IconButton(
                          tooltip: 'Paramètres du lecteur',
                          icon: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: Neo.glassGradient(context),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                            ),
                            child: Icon(Icons.settings_rounded, color: Colors.white, size: 18),
                          ),
                          onPressed: () => _showPlayerSettings(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Bottom controls
          if (!_isExtracting && _errorMessage == null && !_isWaitingForNetwork)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  duration: Duration(milliseconds: 300),
                  opacity: _showControls ? 1.0 : 0.0,
                  child: _buildAnimeBottomBar(),
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildNetworkWaitingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withValues(alpha: 0.1),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.wifi_off_rounded,
                    size: 40,
                    color: Colors.orange,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Connexion instable détectée',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'Lecture mise en pause automatiquement',
                style: TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'En attente d\'une connexion réseau plus stable...',
                style: TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Colors.orange,
                  strokeWidth: 2,
                ),
              ),
              SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  _networkRetryTimer?.cancel();
                  setState(() {
                    _isWaitingForNetwork = false;
                  });
                  if (_resumePosition != null && _resumePosition!.inSeconds > 0) {
                    _player.play();
                    _seekWhenReady(_resumePosition!);
                  } else {
                    _player.play();
                  }
                },
                icon: Icon(Icons.refresh, size: 18),
                label: Text('Réessayer maintenant'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimeBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.9),
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<Duration>(
            stream: _player.stream.position,
            initialData: _player.state.position,
            builder: (context, positionSnapshot) {
              final position = positionSnapshot.data ?? Duration.zero;
              final duration = _player.state.duration;
              final progress = duration.inMilliseconds > 0
                  ? position.inMilliseconds / duration.inMilliseconds
                  : 0.0;
              return StreamBuilder<Duration>(
                stream: _player.stream.buffer,
                initialData: _player.state.buffer,
                builder: (context, bufferSnapshot) {
                  final buffer = bufferSnapshot.data ?? Duration.zero;
                  final bufferProgress = duration.inMilliseconds > 0
                      ? buffer.inMilliseconds / duration.inMilliseconds
                      : 0.0;
                  return Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            _formatDuration(position),
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: GestureDetector(
                                onTapDown: (details) {
                                  final RenderBox box = context.findRenderObject() as RenderBox;
                                  final frac = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                                  _player.seek(Duration(milliseconds: (duration.inMilliseconds * frac).round()));
                                  _showControlsBriefly();
                                },
                                onHorizontalDragUpdate: (details) {
                                  final RenderBox box = context.findRenderObject() as RenderBox;
                                  final frac = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                                  _player.seek(Duration(milliseconds: (duration.inMilliseconds * frac).round()));
                                  _showControlsBriefly();
                                },
                                child: SizedBox(
                                  height: 44,
                                  child: Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [
                                      // Piste fond
                                      Container(
                                        height: 5,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(3),
                                          color: Colors.white24,
                                        ),
                                      ),
                                      // Buffer
                                      FractionallySizedBox(
                                        widthFactor: bufferProgress.clamp(0.0, 1.0),
                                        child: Container(
                                          height: 5,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(3),
                                            color: Colors.white38,
                                          ),
                                        ),
                                      ),
                                      // Progression
                                      FractionallySizedBox(
                                        widthFactor: progress.clamp(0.0, 1.0),
                                        child: Container(
                                          height: 5,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(3),
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      // Thumb
                                      if (duration.inMilliseconds > 0)
                                        Positioned(
                                          left: progress.clamp(0.0, 1.0) * (MediaQuery.of(context).size.width - 32 - 16 * 2) - 7,
                                          child: Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.replay_10, color: Colors.white, size: 28),
                onPressed: () {
                  final pos = _player.state.position - Duration(seconds: 10);
                  _player.seek(pos < Duration.zero ? Duration.zero : pos);
                  _showControlsBriefly();
                },
              ),
              SizedBox(width: 8),
              StreamBuilder<bool>(
                stream: _player.stream.playing,
                initialData: _player.state.playing,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data ?? false;
                  return IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Colors.white,
                      size: 48,
                    ),
                    onPressed: () {
                      _player.playOrPause();
                      _showControlsBriefly();
                    },
                  );
                },
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.forward_10, color: Colors.white, size: 28),
                onPressed: () {
                  final pos = _player.state.position + Duration(seconds: 10);
                  _player.seek(pos > _player.state.duration ? _player.state.duration : pos);
                  _showControlsBriefly();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showControlsBriefly() {
    setState(() => _showControls = true);
    _controlsTimer?.cancel();
    _controlsTimer = Timer(Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  Future<void> _showPlayerSettings(BuildContext context) async {
    if (NeoTheme.isTV(context)) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => _TVSettingsDialog(player: _player),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Neo.bgOverlay(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _PlayerSettingsSheet(player: _player),
      );
    }
    if (!mounted) return;
  }
}

class _PlayerSettingsSheet extends StatefulWidget {
  final Player? player;
  const _PlayerSettingsSheet({super.key, required this.player});

  @override
  State<_PlayerSettingsSheet> createState() => _PlayerSettingsSheetState();
}

class _PlayerSettingsSheetState extends State<_PlayerSettingsSheet> {
  double _speed = 1.0;

  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  void initState() {
    super.initState();
    _speed = widget.player?.state.rate ?? 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text('Paramètres du lecteur', style: Neo.titleMedium(context)),
          SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.speed_rounded, color: Neo.textSecondary(context), size: 20),
              SizedBox(width: 12),
              Text('Vitesse de lecture',
                  style: Neo.bodyMedium(context).copyWith(color: Neo.textPrimary(context))),
              Spacer(),
              Text('${_speed}x',
                  style: Neo.bodyMedium(context).copyWith(color: Theme.of(context).colorScheme.primary)),
            ],
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _speeds.map((s) {
              final selected = s == _speed;
              return GestureDetector(
                onTap: () {
                  setState(() => _speed = s);
                  widget.player?.setRate(s);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${s}x',
                    style: Neo.labelSmall(context).copyWith(
                      color: selected ? Colors.white : Neo.textSecondary(context),
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TVSettingsDialog extends StatefulWidget {
  final Player? player;
  const _TVSettingsDialog({super.key, required this.player});

  @override
  State<_TVSettingsDialog> createState() => _TVSettingsDialogState();
}

class _TVSettingsDialogState extends State<_TVSettingsDialog> {
  late double _selectedSpeed;
  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  late int _focusedIndex;

  @override
  void initState() {
    super.initState();
    _selectedSpeed = widget.player?.state.rate ?? 1.0;
    _focusedIndex = _speeds.indexOf(_selectedSpeed);
    if (_focusedIndex == -1) _focusedIndex = 3;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Color(0xFF0D1827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 20),
            Text('Vitesse de lecture', style: Neo.titleMedium(context)),
            SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _speeds.length,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemBuilder: (ctx, i) {
                  final speed = _speeds[i];
                  final isCurrent = speed == _selectedSpeed;
                  return Focus(
                    autofocus: i == _focusedIndex,
                    onFocusChange: (has) {
                      if (has) setState(() => _focusedIndex = i);
                    },
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.enter ||
                              event.logicalKey == LogicalKeyboardKey.select ||
                              event.logicalKey == LogicalKeyboardKey.space)) {
                        widget.player?.setRate(speed);
                        Navigator.pop(context);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Builder(
                      builder: (context) {
                        final isFocused = Focus.of(context).hasFocus;
                        return GestureDetector(
                          onTap: () {
                            widget.player?.setRate(speed);
                            Navigator.pop(context);
                          },
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 150),
                            margin: EdgeInsets.symmetric(vertical: 4),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isFocused
                                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                                  : (isCurrent ? Colors.white.withValues(alpha: 0.05) : Colors.transparent),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isFocused
                                    ? Theme.of(context).colorScheme.primary
                                    : (isCurrent ? Colors.white38 : Colors.white.withValues(alpha: 0.08)),
                                width: isFocused ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.speed_rounded,
                                  color: isFocused
                                      ? Theme.of(context).colorScheme.primary
                                      : (isCurrent ? Colors.white : Colors.white70),
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  '${speed}x',
                                  style: Neo.bodyMedium(context).copyWith(
                                    color: isFocused
                                        ? Theme.of(context).colorScheme.primary
                                        : (isCurrent ? Colors.white : Colors.white70),
                                    fontWeight: isCurrent || isFocused ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                Spacer(),
                                if (isCurrent)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: isFocused ? Theme.of(context).colorScheme.primary : Colors.white,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ResumeDialog extends StatelessWidget {
  final Duration position;
  final VoidCallback onResume;
  final VoidCallback onRestart;

  const _ResumeDialog({
    super.key,
    required this.position,
    required this.onResume,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = _formatDuration(position);

    return Dialog(
      backgroundColor: Color(0xFF0F1B2B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(maxWidth: 400),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 36,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Reprendre la lecture ?',
              style: Neo.titleMedium(context).copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Vous avez déjà commencé ce programme. Voulez-vous reprendre la lecture à $formatted ?',
              style: Neo.bodyMedium(context).copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _ResumeButton(
                    label: 'Recommencer',
                    icon: Icons.replay_rounded,
                    onTap: onRestart,
                    isPrimary: false,
                    autofocus: false,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _ResumeButton(
                    label: 'Reprendre',
                    icon: Icons.play_arrow_rounded,
                    onTap: onResume,
                    isPrimary: true,
                    autofocus: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _ResumeButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool autofocus;

  const _ResumeButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isPrimary,
    required this.autofocus,
  });

  @override
  State<_ResumeButton> createState() => _ResumeButtonState();
}

class _ResumeButtonState extends State<_ResumeButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isTV = NeoTheme.isTV(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final baseBgColor = widget.isPrimary
        ? primaryColor
        : Color(0xFF1E2E42);
    final activeBgColor = widget.isPrimary
        ? primaryColor.withValues(alpha: 0.8)
        : Color(0xFF2C3E55);

    final displayColor = _focused ? activeBgColor : baseBgColor;
    final border = _focused && !widget.isPrimary
        ? Border.all(color: primaryColor, width: 2)
        : Border.all(color: Colors.transparent, width: 2);

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? (isTV ? 1.05 : 1.02) : 1.0,
          duration: Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: displayColor,
              borderRadius: BorderRadius.circular(12),
              border: border,
              boxShadow: _focused && widget.isPrimary
                  ? [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
