import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:async';

import '../config/theme.dart';
import '../models/anime.dart';
import '../services/anime_extractor.dart';
import '../services/api_service.dart';

class AnimePlayerScreen extends StatefulWidget {
  final Anime anime;
  final int seasonNumber;
  final AnimeEpisode episode;
  final List<Map<String, String>> sources;

  const AnimePlayerScreen({
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
  String? _videoUrl;
  String? _extractorUsed;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _extractVideo();
    _restoreProgress();
  }

  @override
  void dispose() {
    _saveProgressSync();
    _progressTimer?.cancel();
    _controlsTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _extractVideo() async {
    setState(() {
      _isExtracting = true;
      _errorMessage = null;
    });

    try {
      // Essayer d'extraire depuis les sources disponibles
      final result = await AnimeExtractor.extractFromMultipleSources(
        widget.sources,
      );

      if (result['success'] == true) {
        final videoUrl = result['video_url'] as String;
        final extractor = result['extractor'] as String?;
        
        setState(() {
          _videoUrl = videoUrl;
          _extractorUsed = extractor;
          _isExtracting = false;
        });

        // Charger la vidéo avec les bons headers
        await _loadVideo(videoUrl, extractor);
      } else {
        setState(() {
          _errorMessage = result['error'] as String? ?? 'Extraction échouée';
          _isExtracting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isExtracting = false;
      });
    }
  }

  Future<void> _loadVideo(String videoUrl, String? extractor) async {
    // Préparer les headers HTTP selon l'extracteur
    final headers = _getHeadersForExtractor(extractor, videoUrl);
    
    // Créer le Media avec les headers
    final media = Media(
      videoUrl,
      httpHeaders: headers,
    );

    await _player.open(media);
    
    // Démarrer le timer de sauvegarde de progression
    _startProgressTimer();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _saveProgress();
    });
  }

  void _saveProgressSync() {
    final position = _player.state.position.inSeconds.toDouble();
    final duration = _player.state.duration.inSeconds.toDouble();
    if (position <= 0 || duration <= 0) return;
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

    if (position <= 0 || duration <= 0) {
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
    try {
      final progress = await _api.getAnimeProgress(
        animeId: widget.anime.id,
        seasonNumber: widget.seasonNumber,
        episodeNumber: widget.episode.episodeNumber,
      );

      if (progress == null || !mounted) {
        return;
      }

      final currentTime = (progress['current_time'] as num?)?.toDouble() ?? 0;
      final progressPercent = double.tryParse(progress['progress_percent']?.toString() ?? '0') ?? 0;

      // Si la progression est > 90%, on considère que l'épisode est terminé
      if (progressPercent >= 90) {
        return;
      }

      // Si la progression est > 5%, proposer de reprendre
      if (currentTime > 5 && mounted) {
        final resume = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: NeoTheme.bgOverlay,
            title: Text('Reprendre la lecture ?', style: NeoTheme.titleLarge(context)),
            content: Text(
              'Vous avez déjà regardé ${progressPercent.toStringAsFixed(0)}% de cet épisode.',
              style: NeoTheme.bodyMedium(context),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Recommencer'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Reprendre'),
              ),
            ],
          ),
        );

        if (resume == true && mounted) {
          await _player.seek(Duration(seconds: currentTime.toInt()));
        }
      }
    } catch (e) {
      // Ignorer les erreurs de restauration
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isExtracting)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: NeoTheme.primaryRed),
                  const SizedBox(height: 24),
                  Text(
                    'Extraction de la vidéo...',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Essai des différentes sources',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            )
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: NeoTheme.errorRed),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Retour'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _extractVideo,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            )
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
              child: Video(
                controller: _controller,
                controls: NoVideoControls,
              ),
            ),
          
          // Top bar overlay
          if (!_isExtracting && _errorMessage == null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
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
                        const SizedBox(width: 12),
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
                                  'Source: $_extractorUsed',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Bottom controls
          if (!_isExtracting && _errorMessage == null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _showControls ? 1.0 : 0.0,
                  child: _buildAnimeBottomBar(),
                ),
              ),
            ),
        ],
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
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: GestureDetector(
                                onTapDown: (details) {
                                  final RenderBox box = context.findRenderObject() as RenderBox;
                                  final localPos = details.localPosition;
                                  final progressBarWidth = box.size.width - 16 * 2;
                                  final seekFraction = (localPos.dx / progressBarWidth).clamp(0.0, 1.0);
                                  final seekPosition = Duration(milliseconds: (duration.inMilliseconds * seekFraction).round());
                                  _player.seek(seekPosition);
                                  _showControlsBriefly();
                                },
                                child: SizedBox(
                                  height: 24,
                                  child: Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [
                                      Container(
                                        height: 3,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(2),
                                          color: Colors.white24,
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: bufferProgress.clamp(0.0, 1.0),
                                        child: Container(
                                          height: 3,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(2),
                                            color: Colors.white38,
                                          ),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: progress.clamp(0.0, 1.0),
                                        child: Container(
                                          height: 3,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(2),
                                            color: NeoTheme.primaryRed,
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
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white, size: 28),
                onPressed: () {
                  final pos = _player.state.position - const Duration(seconds: 10);
                  _player.seek(pos < Duration.zero ? Duration.zero : pos);
                  _showControlsBriefly();
                },
              ),
              const SizedBox(width: 8),
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
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white, size: 28),
                onPressed: () {
                  final pos = _player.state.position + const Duration(seconds: 10);
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
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }
}
