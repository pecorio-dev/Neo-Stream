import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import '../services/player_prefs.dart';
import 'surface_player.dart';

/// Backend de lecture :
/// - **surface** : Android / Android TV → NativeVideoActivity (ExoPlayer SurfaceView)
///   Fiable sur Freebox Mini 4K (évite écran noir TextureView/PlatformView).
/// - **mediaKit** : Windows / Linux / macOS
/// - **videoPlayer** : fallback non-Android (non utilisé en prod mobile ici)
enum PlayerKind { surface, mediaKit, videoPlayer }

PlayerKind _detectPlayer() {
  if (!kIsWeb && Platform.isAndroid) return PlayerKind.surface;
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return PlayerKind.mediaKit;
  }
  return PlayerKind.videoPlayer;
}

final PlayerKind _playerKind = _detectPlayer();

class UniversalPlayerController {
  final String url;
  /// Sources de secours (même flux). Sur Android, bascule native 1-try/source.
  final List<String> fallbackUrls;
  final Map<String, String>? headers;
  /// Headers par source (alignés sur url + fallbackUrls).
  final List<Map<String, String>> headersList;
  final bool isLive;
  final PlayerKind kind = _playerKind;

  SurfacePlayerController? _surfaceCtrl;
  mk.Player? _mkPlayer;
  mkv.VideoController? _mkVideoController;
  List<StreamSubscription>? _mkSubs;

  bool _isDisposed = false;
  bool _surfaceSessionDone = false;
  Map<String, dynamic>? _lastSurfaceResult;

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _bufferingController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _completedController = StreamController<void>.broadcast();

  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  Stream<bool> get bufferingStream => _bufferingController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<void> get completedStream => _completedController.stream;

  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;
  double _volume = 1.0;
  double _rate = 1.0;
  bool _completedFired = false;

  Duration get currentPosition => _lastPosition;
  Duration get totalDuration => _lastDuration;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  double get volume => _volume;
  double get rate => _rate;

  /// Sur Android, le player natif est une Activity externe : "initialisé" tant
  /// que la session n'est pas terminée / pas d'erreur fatale.
  bool get isInitialized {
    if (_isDisposed) return false;
    if (kind == PlayerKind.surface) {
      return _surfaceCtrl != null && !_surfaceSessionDone;
    }
    return _mkPlayer != null;
  }

  /// true = lecture via Activity native (pas de widget vidéo Flutter).
  bool get useNativeActivity => kind == PlayerKind.surface;
  bool get useSurfaceView => useNativeActivity;

  /// Résultat de la dernière session native (position, ok, hadError…).
  Map<String, dynamic>? get lastSurfaceResult => _lastSurfaceResult;

  /// true si l'utilisateur a fermé le player natif (ou erreur).
  bool get nativeSessionFinished => _surfaceSessionDone;

  UniversalPlayerController({
    required this.url,
    this.fallbackUrls = const [],
    this.headers,
    this.headersList = const [],
    this.isLive = false,
  });

  /// Toutes les URLs uniques dans l'ordre (primaire + fallbacks).
  List<String> get allUrls {
    final out = <String>[];
    void add(String u) {
      final t = u.trim();
      if ((t.startsWith('http://') || t.startsWith('https://')) &&
          !out.contains(t)) {
        out.add(t);
      }
    }

    add(url);
    for (final u in fallbackUrls) {
      add(u);
    }
    return out;
  }

  SurfacePlayerController? get surfaceController => _surfaceCtrl;

  Future<void> initialize({int positionMs = 0}) async {
    switch (_playerKind) {
      case PlayerKind.surface:
        await _initSurface(positionMs: positionMs);
      case PlayerKind.mediaKit:
        await _initMediaKit();
      case PlayerKind.videoPlayer:
        await _initVideoPlayer();
    }
  }

  Future<void> _initSurface({int positionMs = 0}) async {
    try {
      final urls = allUrls;
      debugPrint(
        '[UVP] _initSurface live=$isLive sources=${urls.length} '
        'url=${url.length > 80 ? url.substring(0, 80) : url}',
      );
      _surfaceCtrl = SurfacePlayerController();
      _surfaceSessionDone = false;
      final result = await _surfaceCtrl!.initialize(
        url: urls.isNotEmpty ? urls.first : url,
        urls: urls,
        headers: headers,
        headersList: headersList.isNotEmpty ? headersList : null,
        position: positionMs,
        isLive: isLive,
      );
      _lastSurfaceResult = result;
      _surfaceSessionDone = true;

      if (result == null) {
        _errorController.add('Lecteur natif indisponible');
        return;
      }

      final rawPos = result['position'];
      final posMs = rawPos is int
          ? rawPos
          : rawPos is num
              ? rawPos.toInt()
              : int.tryParse('${rawPos}') ?? 0;
      if (posMs > 0) {
        _lastPosition = Duration(milliseconds: posMs);
        _positionController.add(_lastPosition);
      }

      final hadError = result['hadError'] == true || result['ok'] == false;
      final err = result['error']?.toString();
      if (hadError) {
        _errorController.add(err?.isNotEmpty == true ? err! : 'Erreur de lecture native');
      }

      if (result['completed'] == true && !_completedFired) {
        _completedFired = true;
        _completedController.add(null);
      }

      debugPrint('[UVP] surface session done ok=${result['ok']} hadError=$hadError err=$err');
    } catch (e) {
      debugPrint('[UVP] surface init error: $e');
      _surfaceSessionDone = true;
      _errorController.add('SurfacePlayer: $e');
    }
  }

  Future<void> _initMediaKit() async {
    try {
      debugPrint('[UVP] _initMediaKit url=$url');
      final prefs = await PlayerPrefs.load();
      _mkPlayer = mk.Player();
      _mkVideoController = mkv.VideoController(
        _mkPlayer!,
        configuration: mkv.VideoControllerConfiguration(
          enableHardwareAcceleration: prefs.hwdecEnabled,
        ),
      );
      _mkSubs = [
        _mkPlayer!.stream.position.listen((pos) {
          if (!_isDisposed) {
            _lastPosition = pos;
            _positionController.add(pos);
          }
        }),
        _mkPlayer!.stream.duration.listen((dur) {
          if (!_isDisposed) {
            _lastDuration = dur;
            _durationController.add(dur);
          }
        }),
        _mkPlayer!.stream.playing.listen((playing) {
          if (!_isDisposed) {
            _isPlaying = playing;
            _playingController.add(playing);
          }
        }),
        _mkPlayer!.stream.buffering.listen((buffering) {
          if (!_isDisposed) {
            _isBuffering = buffering;
            _bufferingController.add(buffering);
          }
        }),
        _mkPlayer!.stream.error.listen((err) {
          if (!_isDisposed) _errorController.add(err.toString());
        }),
        _mkPlayer!.stream.completed.listen((_) {
          if (!_isDisposed && !_completedFired) {
            _completedFired = true;
            _completedController.add(null);
          }
        }),
      ];
      await _mkPlayer!.open(mk.Media(url, httpHeaders: headers), play: true);
      debugPrint('[UVP] MediaKit opened');
    } catch (e) {
      debugPrint('[UVP] MediaKit error: $e');
      _errorController.add('MediaKit: $e');
    }
  }

  Future<void> _initVideoPlayer() async {
    _errorController.add('video_player non disponible sur cette plateforme');
  }

  Future<void> play() async {
    if (_mkPlayer != null) await _mkPlayer!.play();
  }

  Future<void> pause() async {
    if (_mkPlayer != null) await _mkPlayer!.pause();
  }

  Future<void> playOrPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seekTo(Duration position) async {
    if (_mkPlayer != null) await _mkPlayer!.seek(position);
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    if (_mkPlayer != null) await _mkPlayer!.setVolume(_volume * 100);
  }

  Future<void> setRate(double rate) async {
    _rate = rate.clamp(0.25, 2.0);
    if (_mkPlayer != null) await _mkPlayer!.setRate(_rate);
  }

  void dispose() {
    _isDisposed = true;
    _mkSubs?.forEach((s) => s.cancel());
    _mkSubs = null;
    _surfaceCtrl?.dispose();
    _mkPlayer?.dispose();
    _positionController.close();
    _durationController.close();
    _playingController.close();
    _bufferingController.close();
    _errorController.close();
    _completedController.close();
  }
}

class UniversalVideoView extends StatelessWidget {
  final UniversalPlayerController controller;
  final BoxFit fit;

  const UniversalVideoView({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    // Activity native Android : rien à afficher dans Flutter.
    if (controller.useNativeActivity) {
      return const SizedBox.expand();
    }

    if (controller._mkVideoController != null) {
      return mkv.Video(
        controller: controller._mkVideoController!,
        controls: mkv.NoVideoControls,
        fit: fit,
      );
    }

    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
      ),
    );
  }
}
