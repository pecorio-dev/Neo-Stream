import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../data/models/watch_progress.dart';
import '../../../core/services/watch_progress_service.dart';

class EnhancedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final Map<String, String> headers;
  final ValueChanged<Duration>? onProgressUpdate;
  final String? title;
  final String? contentId; // For watch progress tracking
  final String? contentType; // 'movie' or 'series'

  const EnhancedVideoPlayer({
    required this.videoUrl,
    required this.headers,
    this.onProgressUpdate,
    this.title,
    this.contentId,
    this.contentType,
    Key? key,
  }) : super(key: key);

  @override
  State<EnhancedVideoPlayer> createState() => _EnhancedVideoPlayerState();
}

class _EnhancedVideoPlayerState extends State<EnhancedVideoPlayer> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _duration = Duration.zero;
  
  // Brightness and volume
  double _brightness = 0.5;
  double _volume = 0.5;
  
  // Gesture tracking
  DateTime? _lastDoubleTapLeft;
  DateTime? _lastDoubleTapRight;
  bool _isGesturing = false; // Prevent excessive rebuilds
  
  // Auto-save
  Timer? _autoSaveTimer;
  static const int _autoSaveDuration = 10; // Save every 10 seconds

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _initializeBrightness();
    // Start auto-save after first frame to avoid layout issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoSave();
    });
  }

  void _startAutoSave() {
    if (mounted && _controller.value.isInitialized) {
      // Save progress every 10 seconds in background (without setState)
      _autoSaveTimer = Timer.periodic(Duration(seconds: _autoSaveDuration), (_) {
        // Use Future to prevent blocking the UI thread
        Future.microtask(() => _saveProgress());
      });
    }
  }

  Future<void> _saveProgress() async {
    if (widget.contentId == null) return;

    try {
      await WatchProgressService.saveProgress(
        contentId: widget.contentId!,
        contentType: widget.contentType ?? 'movie',
        title: widget.title ?? 'Unknown',
        position: _currentPosition,
        duration: _duration,
      );
      print('💾 Progress saved: ${_formatDuration(_currentPosition)} / ${_formatDuration(_duration)}');
    } catch (e) {
      print('❌ Error saving progress: $e');
    }
  }

  Future<void> _initializeBrightness() async {
    // Initialize brightness (default to 0.5)
    setState(() => _brightness = 0.5);
  }

  void _initializePlayer() {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      httpHeaders: widget.headers,
    );

    _controller.addListener(() {
      if (mounted) {
        setState(() {
          _isPlaying = _controller.value.isPlaying;
          _currentPosition = _controller.value.position;
          _duration = _controller.value.duration;
        });
        
        widget.onProgressUpdate?.call(_currentPosition);
      }
    });

    _controller.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((e) {
      print('❌ Erreur init player: $e');
    });

    _controller.play();
  }

  Future<void> _setBrightness(double value) async {
    // Update brightness display (actual system brightness would require platform channel)
    setState(() => _brightness = value.clamp(0.0, 1.0));
  }

  void _setVolume(double value) {
    setState(() => _volume = value.clamp(0.0, 1.0));
    _controller.setVolume(_volume);
  }

  void _skipSeconds(int seconds) {
    final newPosition = _currentPosition + Duration(seconds: seconds);
    if (newPosition.inSeconds >= 0 && newPosition <= _duration) {
      _controller.seekTo(newPosition);
    }
  }

  void _handleLeftSwipe(DragUpdateDetails details) {
    // Luminosité: glisse vers le haut = augmente
    final dy = details.delta.dy;
    final brightnessChange = -dy / 200; // 200px = full brightness change
    final newBrightness = (_brightness + brightnessChange).clamp(0.0, 1.0);
    _setBrightness(newBrightness);
  }

  void _handleRightSwipe(DragUpdateDetails details) {
    // Volume: glisse vers le haut = augmente
    final dy = details.delta.dy;
    final volumeChange = -dy / 200;
    final newVolume = (_volume + volumeChange).clamp(0.0, 1.0);
    _setVolume(newVolume);
  }

  void _handleDoubleTapLeft() {
    final now = DateTime.now();
    if (_lastDoubleTapLeft != null &&
        now.difference(_lastDoubleTapLeft!).inMilliseconds < 500) {
      _skipSeconds(-30); // Reculer 30s
      _lastDoubleTapLeft = null;
    } else {
      _lastDoubleTapLeft = now;
    }
  }

  void _handleDoubleTapRight() {
    final now = DateTime.now();
    if (_lastDoubleTapRight != null &&
        now.difference(_lastDoubleTapRight!).inMilliseconds < 500) {
      _skipSeconds(30); // Avancer 30s
      _lastDoubleTapRight = null;
    } else {
      _lastDoubleTapRight = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _showControls = !_showControls);
      },
      onHorizontalDragStart: (details) {
        _isGesturing = true;
      },
      onHorizontalDragUpdate: (details) {
        final isLeftSide = details.globalPosition.dx < MediaQuery.of(context).size.width / 2;
        if (isLeftSide) {
          _handleLeftSwipe(details);
        } else {
          _handleRightSwipe(details);
        }
      },
      onHorizontalDragEnd: (_) {
        _isGesturing = false;
      },
      onDoubleTapDown: (details) {
        final isLeftSide = details.globalPosition.dx < MediaQuery.of(context).size.width / 2;
        if (isLeftSide) {
          _handleDoubleTapLeft();
        } else {
          _handleDoubleTapRight();
        }
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Video player
            Center(
              child: _controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),

            // Controls overlay
            if (_showControls)
              _buildControlsOverlay(),

            // Brightness/Volume indicators
            _buildIndicators(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Column(
      children: [
        // Top bar
        Container(
          color: Colors.black.withOpacity(0.4),
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
              if (widget.title != null)
                Expanded(
                  child: Text(
                    widget.title!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        
        // Spacer
        const Expanded(child: SizedBox()),
        
        // Center play/pause
        IconButton(
          icon: Icon(
            _isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 48,
          ),
          onPressed: () {
            if (_isPlaying) {
              _controller.pause();
            } else {
              _controller.play();
            }
          },
        ),
        
        // Spacer
        const Expanded(child: SizedBox()),
        
        // Progress bar + Bottom controls
        Container(
          color: Colors.black.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                ),
                child: Slider(
                  value: _currentPosition.inSeconds.toDouble(),
                  max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1,
                  activeColor: Colors.red,
                  inactiveColor: Colors.grey,
                  onChanged: (value) {
                    _controller.seekTo(Duration(seconds: value.toInt()));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_currentPosition),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10, color: Colors.white, size: 20),
                    onPressed: () => _skipSeconds(-10),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_10, color: Colors.white, size: 20),
                    onPressed: () => _skipSeconds(10),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIndicators() {
    if (!_isGesturing) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Icon(Icons.brightness_6, color: Colors.white),
                Text(
                  '${(_brightness * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            Column(
              children: [
                const Icon(Icons.volume_up, color: Colors.white),
                Text(
                  '${(_volume * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$minutes:$seconds';
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _saveProgress(); // Final save on exit
    _controller.dispose();
    super.dispose();
  }
}
