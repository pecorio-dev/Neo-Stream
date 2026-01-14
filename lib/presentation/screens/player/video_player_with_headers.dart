import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/stream_info.dart';

class VideoPlayerWithHeaders extends StatefulWidget {
  final StreamInfo streamInfo;
  final String title;
  final Duration? startPosition;

  const VideoPlayerWithHeaders({
    Key? key,
    required this.streamInfo,
    required this.title,
    this.startPosition,
  }) : super(key: key);

  @override
  State<VideoPlayerWithHeaders> createState() => _VideoPlayerWithHeadersState();
}

class _VideoPlayerWithHeadersState extends State<VideoPlayerWithHeaders> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    WakelockPlus.enable();
  }

  Future<void> _initializePlayer() async {
    try {
      print('🎬═══════════════════════════════════════════');
      print('🎬 VIDEO PLAYER INITIALIZATION');
      print('🎬═══════════════════════════════════════════');
      print('🎬 URL: ${widget.streamInfo.url}');
      print('🎬 Title: ${widget.streamInfo.title}');
      print('🎬 Quality: ${widget.streamInfo.quality}');
      print('🎬 Extension: ${widget.streamInfo.fileExtension}');

      // Obtenir les headers complets
      final headers = widget.streamInfo.getCompleteHeaders();
      print('🎬 Headers: ${headers.length} total');
      headers.forEach((k, v) {
        if (k.toLowerCase() == 'cookie') {
          print('🎬 ✅ Cookie présent');
        } else if (k.toLowerCase() == 'user-agent') {
          print('🎬 ✅ User-Agent: ${v.substring(0, 50)}...');
        }
      });

      // Créer le contrôleur vidéo avec headers
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.streamInfo.url),
        httpHeaders: headers,
      );

      print('🎬 Initialisation du contrôleur...');
      await _controller.initialize();

      print('🎬 ✅ Lecteur vidéo initialisé');
      print('🎬 Durée: ${_controller.value.duration}');

      // Seek si position fournie
      if (widget.startPosition != null && widget.startPosition != Duration.zero) {
        print('🎬 Seeking à ${widget.startPosition}');
        await _controller.seekTo(widget.startPosition!);
      }

      // Auto-play
      await _controller.play();

      setState(() {
        _isInitialized = true;
        _isPlaying = true;
      });

      // Écouter les changements
      _controller.addListener(_onPlayerStateChanged);
    } catch (e) {
      print('🎬 ❌ ERREUR INITIALISATION: $e');
      setState(() {
        _errorMessage = 'Erreur: $e';
      });
    }
  }

  void _onPlayerStateChanged() {
    if (!mounted) return;
    setState(() {
      _isPlaying = _controller.value.isPlaying;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerStateChanged);
    _controller.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: _errorMessage != null
            ? _buildErrorWidget()
            : !_isInitialized
                ? const CircularProgressIndicator()
                : _buildVideoPlayer(),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 16),
        Text(
          _errorMessage ?? 'Erreur',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          if (!_isPlaying)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 64,
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildProgressBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        VideoProgressIndicator(
          _controller,
          allowScrubbing: true,
          colors: VideoProgressColors(
            playedColor: AppColors.neonBlue,
            backgroundColor: Colors.grey[700]!,
            bufferedColor: Colors.grey[600]!,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text(
                _formatDuration(_controller.value.position),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const Spacer(),
              Text(
                _formatDuration(_controller.value.duration),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$minutes:$seconds';
  }
}
