import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;

/// Contrôleur universel de lecture vidéo :
/// - Utilise **Google ExoPlayer** (`video_player`) sur Android & Android TV (compatibilité 100% ancienne/nouvelle version Android, aucun écran noir).
/// - Utilise **media_kit** (`mpv`) sur Windows Desktop.
class UniversalPlayerController {
  final String url;
  final Map<String, String>? headers;

  vp.VideoPlayerController? _vpController;
  mk.Player? _mkPlayer;
  mkv.VideoController? _mkVideoController;

  bool _isDisposed = false;
  bool _isAndroidOrMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _bufferingController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  Stream<bool> get bufferingStream => _bufferingController.stream;
  Stream<String> get errorStream => _errorController.stream;

  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;

  Duration get currentPosition => _lastPosition;
  Duration get totalDuration => _lastDuration;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;

  UniversalPlayerController({required this.url, this.headers});

  Future<void> initialize() async {
    if (_isAndroidOrMobile) {
      await _initializeExoPlayer();
    } else {
      await _initializeMediaKit();
    }
  }

  Future<void> _initializeExoPlayer() async {
    try {
      final uri = Uri.parse(url);
      _vpController = vp.VideoPlayerController.networkUrl(
        uri,
        httpHeaders: headers ?? const {},
      );

      _vpController!.addListener(_onExoPlayerStateChanged);
      await _vpController!.initialize();
      await _vpController!.play();
      _isPlaying = true;
      _playingController.add(true);
    } catch (e) {
      _errorController.add("Erreur d'initialisation ExoPlayer: $e");
    }
  }

  void _onExoPlayerStateChanged() {
    if (_isDisposed || _vpController == null) return;
    final val = _vpController!.value;

    if (val.hasError) {
      _errorController.add(val.errorDescription ?? "Erreur de lecture vidéo");
      return;
    }

    if (val.position != _lastPosition) {
      _lastPosition = val.position;
      _positionController.add(val.position);
    }

    if (val.duration != _lastDuration) {
      _lastDuration = val.duration;
      _durationController.add(val.duration);
    }

    if (val.isPlaying != _isPlaying) {
      _isPlaying = val.isPlaying;
      _playingController.add(val.isPlaying);
    }

    if (val.isBuffering != _isBuffering) {
      _isBuffering = val.isBuffering;
      _bufferingController.add(val.isBuffering);
    }
  }

  Future<void> _initializeMediaKit() async {
    try {
      _mkPlayer = mk.Player();
      _mkVideoController = mkv.VideoController(
        _mkPlayer!,
        configuration: const mkv.VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );

      _mkPlayer!.stream.position.listen((pos) {
        if (!_isDisposed) {
          _lastPosition = pos;
          _positionController.add(pos);
        }
      });

      _mkPlayer!.stream.duration.listen((dur) {
        if (!_isDisposed) {
          _lastDuration = dur;
          _durationController.add(dur);
        }
      });

      _mkPlayer!.stream.playing.listen((playing) {
        if (!_isDisposed) {
          _isPlaying = playing;
          _playingController.add(playing);
        }
      });

      _mkPlayer!.stream.buffering.listen((buffering) {
        if (!_isDisposed) {
          _isBuffering = buffering;
          _bufferingController.add(buffering);
        }
      });

      _mkPlayer!.stream.error.listen((err) {
        if (!_isDisposed) {
          _errorController.add(err.toString());
        }
      });

      await _mkPlayer!.open(
        mk.Media(url, httpHeaders: headers),
        play: true,
      );
    } catch (e) {
      _errorController.add("Erreur d'initialisation MediaKit: $e");
    }
  }

  Future<void> play() async {
    if (_vpController != null) {
      await _vpController!.play();
    } else if (_mkPlayer != null) {
      await _mkPlayer!.play();
    }
  }

  Future<void> pause() async {
    if (_vpController != null) {
      await _vpController!.pause();
    } else if (_mkPlayer != null) {
      await _mkPlayer!.pause();
    }
  }

  Future<void> seekTo(Duration position) async {
    if (_vpController != null) {
      await _vpController!.seekTo(position);
    } else if (_mkPlayer != null) {
      await _mkPlayer!.seek(position);
    }
  }

  void dispose() {
    _isDisposed = true;
    _vpController?.removeListener(_onExoPlayerStateChanged);
    _vpController?.dispose();
    _mkPlayer?.dispose();
    _positionController.close();
    _durationController.close();
    _playingController.close();
    _bufferingController.close();
    _errorController.close();
  }
}

/// Widget d'affichage vidéo universel pour TV et Desktop
class UniversalVideoView extends StatelessWidget {
  final UniversalPlayerController controller;

  const UniversalVideoView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller._vpController != null && controller._vpController!.value.isInitialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: controller._vpController!.value.aspectRatio > 0
              ? controller._vpController!.value.aspectRatio
              : 16 / 9,
          child: vp.VideoPlayer(controller._vpController!),
        ),
      );
    }

    if (controller._mkVideoController != null) {
      return mkv.Video(
        controller: controller._mkVideoController!,
        controls: mkv.NoVideoControls,
      );
    }

    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
      ),
    );
  }
}
