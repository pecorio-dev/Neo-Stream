import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import 'dart:io';

import '../config/theme.dart';
import '../models/anime.dart';
import '../models/content.dart';
import '../services/anime_extractor.dart';
import '../services/api_service.dart';
import '../services/player_prefs.dart';
import '../services/video_extractor.dart';
import '../utils/watch_link_utils.dart';
import '../widgets/universal_video_player.dart';

/// Source vidéo extraite et prête à lire.
class _PreparedStream {
  final String url;
  final Map<String, String>? headers;
  final String label;

  const _PreparedStream({
    required this.url,
    this.headers,
    required this.label,
  });
}

/// Lecteur unique pour Films, Séries et Anime.
///
/// Flux :
///   1. Liens API (watchLinks / players anime)
///   2. Extraction **1 fois par source** → URL directe HLS/MP4 (0 pub)
///   3. Lecture ExoPlayer / media_kit
///   4. Si extract ou lecture KO → source suivante (jamais de retry sur la même)
class PlayerScreen extends StatefulWidget {
  final Content? content;
  final String? videoSourceUrl;
  final List<WatchLink>? candidateServers;
  final String? preferredLanguage;
  final String? episodeId;

  final Anime? anime;
  final int? seasonNumber;
  final AnimeEpisode? episode;
  final List<Map<String, String>>? sources;

  /// Lecture d'un fichier téléchargé (bypass extraction + réseau).
  final String? localFilePath;
  final String? localTitle;
  final String? localSubtitle;

  const PlayerScreen({
    super.key,
    this.content,
    this.videoSourceUrl,
    this.candidateServers,
    this.preferredLanguage,
    this.episodeId,
    this.anime,
    this.seasonNumber,
    this.episode,
    this.sources,
    this.localFilePath,
    this.localTitle,
    this.localSubtitle,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final ApiService _api = ApiService();

  UniversalPlayerController? _playerController;

  bool _isLoading = true;
  String? _errorMessage;
  bool _showControls = true;
  Timer? _controlsTimer;
  Timer? _progressTimer;
  int _playbackRetryCount = 0;
  static const int _maxPlaybackRetries = 1;
  Duration? _resumePosition;
  bool _isWaitingForNetwork = false;
  Timer? _networkRetryTimer;
  bool _recoveringFromError = false;

  int _extractionGeneration = 0;
  String? _extractorUsed;
  int _currentSourceIndex = 0;
  int _vodServerIndex = 0;
  int _totalSources = 0;
  int _desktopSourceIndex = 0;
  List<_PreparedStream> _preparedStreams = [];
  static const int _maxSourcesToExtract = 6;
  String _statusLabel = 'Chargement...';

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<bool>? _playSub;
  StreamSubscription<bool>? _bufSub;
  StreamSubscription<String>? _errSub;
  StreamSubscription<void>? _compSub;

  // ── Épisode suivant (autoplay) ──
  Timer? _autoplayTimer;
  int _autoplaySecondsLeft = 0;
  Episode? _nextEpisode;
  bool _showNextUp = false;

  String _debugInfo = '';
  bool _showDebug = !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    if (!NeoTheme.isDesktopPlatform) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    _startLoading();
    // Restaure la vitesse de lecture mémorisée.
    PlayerPrefs.load().then((prefs) {
      if (mounted && prefs.playbackRate != 1.0) {
        _currentRate = prefs.playbackRate;
        _playerController?.setRate(prefs.playbackRate);
      }
    });
  }

  @override
  void dispose() {
    final pos = _playerController?.currentPosition.inSeconds.toDouble() ?? 0;
    final dur = _playerController?.totalDuration.inSeconds.toDouble() ?? 0;
    if (pos > 0) {
      PlayerPrefs.saveLocalProgress(_progressKey, position: pos, duration: dur);
    }
    _cleanupPlayer();
    _progressTimer?.cancel();
    _controlsTimer?.cancel();
    _networkRetryTimer?.cancel();
    _autoplayTimer?.cancel();
    _sleepTimer?.cancel();
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
    super.dispose();
  }

  String get _progressKey {
    if (widget.localFilePath != null) {
      return 'local_${widget.localFilePath}';
    }
    if (widget.episodeId != null) {
      return '${widget.content?.id ?? ''}_${widget.episodeId}';
    }
    if (widget.episode != null) {
      return 'anime_${widget.anime?.id ?? ''}_${widget.seasonNumber ?? ''}_${widget.episode!.episodeNumber}';
    }
    return '${widget.content?.id ?? ''}';
  }

  Future<void> _startLoading() async {
    _vodServerIndex = 0;
    _currentSourceIndex = 0;
    _desktopSourceIndex = 0;
    _preparedStreams = [];

    if (widget.localFilePath != null) {
      // Fichier téléchargé : lecture directe, pas d'extraction.
      final uri = Uri.file(widget.localFilePath!).toString();
      _preparedStreams = [
        _PreparedStream(
          url: uri,
          label: widget.localTitle ?? 'Fichier local',
        ),
      ];
      _totalSources = 1;
      final generation = ++_extractionGeneration;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      await _playPreparedStreams(generation: generation);
    } else if (widget.anime != null && widget.sources != null) {
      await _prepareAndPlay(isAnime: true);
    } else if (widget.candidateServers != null &&
        widget.candidateServers!.isNotEmpty) {
      await _prepareAndPlay(isAnime: false);
    } else if (widget.videoSourceUrl != null) {
      await _prepareAndPlayDirect(widget.videoSourceUrl!);
    } else {
      setState(() {
        _errorMessage = "Aucune source disponible";
        _isLoading = false;
      });
    }
  }

  /// Prépare toutes les sources (extraction) puis lance la lecture multi-sources.
  Future<void> _prepareAndPlay({required bool isAnime}) async {
    final generation = ++_extractionGeneration;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _statusLabel = 'Préparation des sources...';
      });
    }

    final rawCount = isAnime
        ? AnimeExtractor.sortSources(widget.sources!).length
        : WatchLinkUtils.filterPlayable(widget.candidateServers!).length;

    if (rawCount == 0) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Aucune source lisible disponible';
          _isLoading = false;
        });
      }
      return;
    }

    final prepared = await _extractAllSources(
      isAnime: isAnime,
      generation: generation,
    );
    if (!mounted || generation != _extractionGeneration) return;

    if (prepared.isEmpty) {
      setState(() {
        _errorMessage =
            'Aucune source lisible ($rawCount testée(s)).';
        _isLoading = false;
      });
      return;
    }

    // Anti-troll : écarter les faux flux (clips courts / mini-fichiers)
    if (prepared.length > 1) {
      if (mounted) setState(() => _statusLabel = 'Vérification des sources...');
      final filtered = await _filterTrollStreams(prepared);
      if (!mounted || generation != _extractionGeneration) return;
      _preparedStreams = filtered;
    } else {
      _preparedStreams = prepared;
    }
    _totalSources = _preparedStreams.length;
    await _playPreparedStreams(generation: generation);
  }

  // ─── Détecteur de faux flux « troll » (FStream/FrenchStream & co) ─────
  //
  // Certains agrégateurs servent, au lieu du vrai flux, un clip très court
  // (pub/troll) ou un mini-fichier. Détection sans télécharger le média :
  //   - HLS  : somme des #EXTINF de la media playlist < 120 s  → suspect
  //   - MP4  : HEAD Content-Length < 8 Mo                      → suspect
  // Les sources indéterminées (master playlist, HEAD impossible) sont gardées.
  // Si TOUT est suspect, on conserve la liste initiale (mieux vaut tenter).
  Future<List<_PreparedStream>> _filterTrollStreams(
    List<_PreparedStream> streams,
  ) async {
    final verdicts = await Future.wait(streams.map(_assessStream));
    final kept = <_PreparedStream>[];
    for (var i = 0; i < streams.length; i++) {
      final verdict = verdicts[i];
      if (verdict == false) {
        _addDebug('source troll/fake écartée: ${streams[i].label}');
      } else {
        kept.add(streams[i]);
      }
    }
    if (kept.isEmpty) {
      _addDebug('toutes les sources semblent fausses → liste conservée');
      return streams;
    }
    return kept;
  }

  /// true = source saine, false = troll/fake suspecté, null = indéterminé.
  Future<bool?> _assessStream(_PreparedStream s) async {
    final client = http.Client();
    try {
      final headers = s.headers ?? <String, String>{};
      if (s.url.contains('.m3u8')) {
        final req = http.Request('GET', Uri.parse(s.url))
          ..headers.addAll(headers);
        final resp = await client.send(req).timeout(const Duration(seconds: 8));
        if (resp.statusCode != 200) return null;
        final body = await resp.stream.bytesToString();
        // Master playlist (variantes) → indéterminé
        if (body.contains('#EXT-X-STREAM-INF')) return null;
        if (!body.contains('#EXTINF')) return null;
        var total = 0.0;
        for (final m in RegExp(r'#EXTINF:([\d.]+)').allMatches(body)) {
          total += double.tryParse(m.group(1)!) ?? 0;
        }
        if (total <= 0) return null;
        return total >= 120;
      }

      final req = http.Request('HEAD', Uri.parse(s.url))..headers.addAll(headers);
      final resp = await client.send(req).timeout(const Duration(seconds: 8));
      final len = resp.contentLength ?? 0;
      if (len <= 0) return null;
      return len >= 8 * 1024 * 1024;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// URL directe (sans liste de candidats).
  Future<void> _prepareAndPlayDirect(String url) async {
    final generation = ++_extractionGeneration;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _statusLabel = 'Extraction...';
      });
    }

    final result = await _extractOne(url, isAnime: false);
    if (!mounted || generation != _extractionGeneration) return;

    if (result == null) {
      // Tenter lecture directe si l'URL est déjà un flux
      if (url.contains('.m3u8') || url.contains('.mp4')) {
        _preparedStreams = [
          _PreparedStream(url: url, label: 'Direct'),
        ];
      } else {
        setState(() {
          _errorMessage = 'Impossible d\'extraire la source vidéo';
          _isLoading = false;
        });
        return;
      }
    } else {
      _preparedStreams = [
        _PreparedStream(
          url: result['video_url'] as String,
          headers: result['headers'] as Map<String, String>?,
          label: result['server']?.toString() ?? 'Direct',
        ),
      ];
      _extractorUsed = result['server']?.toString();
    }

    _totalSources = _preparedStreams.length;
    await _playPreparedStreams(generation: generation);
  }

  /// Extrait jusqu'à [_maxSourcesToExtract] sources dans l'ordre de priorité.
  Future<List<_PreparedStream>> _extractAllSources({
    required bool isAnime,
    required int generation,
  }) async {
    final prepared = <_PreparedStream>[];

    if (isAnime) {
      final sources = AnimeExtractor.sortSources(widget.sources!);
      final limit = sources.length.clamp(0, _maxSourcesToExtract);

      for (int i = 0; i < limit; i++) {
        if (!mounted || generation != _extractionGeneration) break;

        final source = sources[i];
        final sourceUrl = source['url'] ?? '';
        final playerName = source['player'] ?? '?';
        final label = '$playerName (${i + 1}/$limit)';

        if (mounted) setState(() => _statusLabel = 'Extraction $label...');
        _addDebug('anime extract ${i + 1}/$limit $playerName');

        final result = await _extractOne(sourceUrl, isAnime: true);
        if (result == null) continue;

        _currentSourceIndex = i;
        prepared.add(_PreparedStream(
          url: result['video_url'] as String,
          headers: result['headers'] as Map<String, String>?,
          label: label,
        ));
        _extractorUsed =
            result['extractor']?.toString() ?? result['server']?.toString();
        _addDebug('extracted OK: $_extractorUsed');
      }
    } else {
      final servers =
          WatchLinkUtils.filterPlayable(widget.candidateServers!);
      final limit = servers.length.clamp(0, _maxSourcesToExtract);

      for (int i = 0; i < limit; i++) {
        if (!mounted || generation != _extractionGeneration) break;

        final link = servers[i];
        final label =
            '${WatchLinkUtils.serverDisplayName(link)} (${i + 1}/$limit)';

        if (mounted) setState(() => _statusLabel = 'Extraction $label...');
        _addDebug('VOD extract ${i + 1}/$limit ${link.serverName}');

        final result = await _extractOne(link.url, isAnime: false);
        if (result == null) continue;

        _vodServerIndex = i;
        prepared.add(_PreparedStream(
          url: result['video_url'] as String,
          headers: result['headers'] as Map<String, String>?,
          label: label,
        ));
        _extractorUsed =
            result['server']?.toString() ?? link.serverName;
        _addDebug('extracted OK: $_extractorUsed');
      }
    }

    return prepared;
  }

  /// Extraction d'une URL avec fallback API serveur.
  Future<Map<String, dynamic>?> _extractOne(
    String sourceUrl, {
    required bool isAnime,
  }) async {
    if (sourceUrl.trim().isEmpty) return null;
    if (isAnime && AnimeExtractor.isUnplayableUrl(sourceUrl)) return null;

    try {
      Map<String, dynamic> result = isAnime
          ? await AnimeExtractor.extract(sourceUrl)
          : await VideoExtractor.extract(sourceUrl);

      if (result['success'] != true) {
        try {
          final serverResult = await _api.extractVideoUrlServer(sourceUrl);
          if (serverResult['success'] == true) result = serverResult;
        } catch (_) {}
      }

      if (result['success'] != true) return null;
      if (result['needs_browser'] == true) return null;

      final videoUrl = result['video_url'] as String?;
      if (videoUrl == null || !videoUrl.startsWith('http')) return null;

      Map<String, String>? headers;
      final rawHeaders = result['headers'];
      if (rawHeaders is Map) {
        headers = rawHeaders.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      if (isAnime) {
        final extractor =
            result['extractor'] as String? ?? result['server'] as String?;
        headers = _getAnimeHeaders(extractor, videoUrl);
      }

      result['headers'] = headers;
      return result;
    } catch (e) {
      _addDebug('extract exception: $e');
      return null;
    }
  }

  /// Lance la lecture avec toutes les sources extraites.
  Future<void> _playPreparedStreams({required int generation}) async {
    if (_preparedStreams.isEmpty || !mounted) return;

    _cleanupPlayer();
    if (_resumePosition == null) await _restoreProgress();
    final resumeMs = _resumePosition?.inMilliseconds ?? 0;

    final urls = _preparedStreams.map((s) => s.url).toList();
    final headersList =
        _preparedStreams.map((s) => s.headers ?? <String, String>{}).toList();

    _addDebug(
      'play ${urls.length} source(s) resume=${resumeMs}ms',
    );

    // Android : toutes les sources en natif (bascule in-Activity)
    if (!kIsWeb && Platform.isAndroid) {
      _playerController = UniversalPlayerController(
        url: urls.first,
        fallbackUrls: urls.skip(1).toList(),
        headers: _preparedStreams.first.headers,
        headersList: headersList,
        isLive: false,
      );

      try {
        await _playerController!.initialize(
          positionMs: resumeMs > 0 ? resumeMs : 0,
        );
        if (!mounted || generation != _extractionGeneration) return;

        final result = _playerController!.lastSurfaceResult;
        final posRaw = result?['position'];
        final posMs = posRaw is int
            ? posRaw
            : (posRaw is num ? posRaw.toInt() : int.tryParse('$posRaw') ?? 0);

        if (posMs > 1000) {
          await PlayerPrefs.saveLocalProgress(
            _progressKey,
            position: posMs / 1000.0,
            duration: 0,
          );
        }

        final hadError =
            result?['hadError'] == true || result?['ok'] == false;
        _addDebug(
          'native done ok=${result?['ok']} err=${result?['error']} pos=${posMs}ms',
        );

        if (hadError) {
          if (mounted) {
            setState(() {
              _errorMessage =
                  'Erreur de lecture: ${result?['error'] ?? 'flux indisponible'}';
              _isLoading = false;
            });
          }
          return;
        }

        // Session terminée sans erreur. Si la vidéo est allée au bout et
        // qu'un épisode suivant existe → NE PAS pop : la carte "épisode
        // suivant" gère la suite (compte à rebours → enchaînement).
        final completed = result?['completed'] == true;
        if (completed && mounted && _findNextEpisode() != null) {
          _startNextUpCountdown();
          return;
        }
      } catch (e) {
        _addDebug('native player error: $e');
        if (mounted) {
          setState(() {
            _errorMessage = 'Erreur de lecture: $e';
            _isLoading = false;
          });
        }
        return;
      }

      if (mounted) Navigator.of(context).pop();
      return;
    }

    // Desktop : bascule séquentielle source par source
    _desktopSourceIndex = 0;
    await _playDesktopPreparedSource(generation: generation);
  }

  /// Desktop : lecture séquentielle des sources préparées.
  Future<void> _playDesktopPreparedSource({required int generation}) async {
    if (_desktopSourceIndex >= _preparedStreams.length) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Aucune source lisible (${_preparedStreams.length} testée(s)).';
          _isLoading = false;
        });
      }
      return;
    }

    final stream = _preparedStreams[_desktopSourceIndex];
    _addDebug(
      'desktop source ${_desktopSourceIndex + 1}/${_preparedStreams.length} '
      '${stream.label}',
    );

    _cleanupPlayer();
    _playerController = UniversalPlayerController(
      url: stream.url,
      headers: stream.headers,
    );
    _subscribeToController();

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      await _playerController!.initialize().timeout(
        const Duration(seconds: 35),
        onTimeout: () =>
            throw TimeoutException('Timeout initialisation vidéo'),
      );
    } catch (e) {
      _addDebug('desktop init fail source $_desktopSourceIndex: $e');
      _desktopSourceIndex++;
      await _playDesktopPreparedSource(generation: generation);
      return;
    }

    if (!mounted || generation != _extractionGeneration) return;

    if (!_playerController!.isInitialized) {
      _desktopSourceIndex++;
      await _playDesktopPreparedSource(generation: generation);
      return;
    }

    if (_resumePosition != null && _resumePosition!.inSeconds > 0) {
      await _seekWhenReady(_resumePosition!);
      _resumePosition = null;
    } else {
      await _restoreProgress();
      if (_resumePosition != null && _resumePosition!.inSeconds > 0) {
        await _seekWhenReady(_resumePosition!);
        _resumePosition = null;
      }
    }

    if (!mounted) return;
    _playbackRetryCount = 0;
    setState(() => _isLoading = false);
    _startProgressTimer();
  }

  /// Après échec mid-playback desktop : bascule vers la source préparée suivante.
  Future<bool> _tryNextSourceAfterPlaybackFail() async {
    final next = _desktopSourceIndex + 1;
    if (next < _preparedStreams.length) {
      _desktopSourceIndex = next;
      _addDebug('playback fail → source préparée $next');
      final generation = _extractionGeneration;
      await _playDesktopPreparedSource(generation: generation);
      return true;
    }
    return false;
  }

  void _subscribeToController() {
    _posSub?.cancel();
    _durSub?.cancel();
    _playSub?.cancel();
    _bufSub?.cancel();
    _errSub?.cancel();
    _compSub?.cancel();

    if (_playerController == null) return;

    _bufSub = _playerController!.bufferingStream.listen((buffering) {
      _addDebug('buffering=$buffering');
    });

    _playSub = _playerController!.playingStream.listen((playing) {
      _addDebug('playing=$playing');
      if (mounted && playing) _recoveringFromError = false;
    });

    _errSub = _playerController!.errorStream.listen((error) {
      _addDebug('error: $error');
      if (!mounted || _recoveringFromError) {
        _addDebug('error ignored (recovering=$_recoveringFromError)');
        return;
      }
      _onPlayerError(error);
    });

    _compSub = _playerController!.completedStream.listen((_) {
      if (!mounted) return;
      _saveProgressSync();
      _startNextUpCountdown();
    });
  }

  // ─── Épisode suivant (autoplay façon Netflix) ───────────────────────

  Episode? _findNextEpisode() {
    final content = widget.content;
    final epId = widget.episodeId;
    if (content == null || !content.isSerie || epId == null) return null;
    final m = RegExp(r'^S(\d+)E(\d+)$').firstMatch(epId);
    if (m == null) return null;
    final s = int.parse(m.group(1)!);
    final e = int.parse(m.group(2)!);
    final seasons = content.seasons;

    bool playable(Episode ep) =>
        WatchLinkUtils.filterPlayable(ep.watchLinks).isNotEmpty;

    // Même saison, épisode +1
    for (final ep in seasons[s] ?? const <Episode>[]) {
      if (ep.episode == e + 1 && playable(ep)) return ep;
    }
    // Sinon premier épisode jouable d'une saison suivante
    final keys = seasons.keys.toList()..sort();
    final idx = keys.indexOf(s);
    for (var k = (idx < 0 ? 0 : idx + 1); k < keys.length; k++) {
      for (final ep in seasons[keys[k]] ?? const <Episode>[]) {
        if (playable(ep)) return ep;
      }
    }
    return null;
  }

  void _startNextUpCountdown() {
    _autoplayTimer?.cancel();
    final next = _findNextEpisode();
    if (next == null) return;
    setState(() {
      _nextEpisode = next;
      _showNextUp = true;
      _autoplaySecondsLeft = 10;
    });
    _autoplayTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _autoplaySecondsLeft--);
      if (_autoplaySecondsLeft <= 0) {
        t.cancel();
        _goToNextEpisode();
      }
    });
  }

  void _cancelAutoplay() {
    _autoplayTimer?.cancel();
    if (mounted) {
      setState(() {
        _showNextUp = false;
        _nextEpisode = null;
      });
    }
  }

  void _goToNextEpisode() {
    final next = _nextEpisode;
    if (next == null) {
      _cancelAutoplay();
      return;
    }
    _autoplayTimer?.cancel();
    final links = WatchLinkUtils.prioritize(
      WatchLinkUtils.filterPlayable(next.watchLinks),
      preferredLanguage: widget.preferredLanguage,
    );
    if (links.isEmpty) {
      _cancelAutoplay();
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          content: widget.content,
          videoSourceUrl: links.first.url,
          candidateServers: links,
          preferredLanguage: widget.preferredLanguage,
          episodeId: 'S${next.season}E${next.episode}',
        ),
      ),
    );
  }

  void _cleanupPlayer() {
    _posSub?.cancel();
    _durSub?.cancel();
    _playSub?.cancel();
    _bufSub?.cancel();
    _errSub?.cancel();
    _compSub?.cancel();
    _playerController?.dispose();
    _playerController = null;
  }

  Future<void> _seekWhenReady(Duration target) async {
    if (target.inSeconds <= 0) return;
    if (_playerController?.totalDuration.inSeconds != null && _playerController!.totalDuration.inSeconds > 0) {
      await _playerController!.seekTo(target);
      return;
    }
    try {
      await _playerController!.durationStream
          .firstWhere((d) => d.inSeconds > 0)
          .timeout(const Duration(seconds: 25));
    } catch (_) {}
    if (!mounted) return;
    final dur = _playerController?.totalDuration ?? Duration.zero;
    final clamped = (dur.inSeconds > 0 && target > dur) ? dur : target;
    await _playerController?.seekTo(clamped);
  }

  void _onPlayerError(String error) {
    _addDebug('_onPlayerError: $error (retry=$_playbackRetryCount)');
    if (_recoveringFromError) return;

    final pos = _playerController?.currentPosition;
    if (pos != null && pos.inSeconds > 0) _resumePosition = pos;

    // Préférer bascule source préparée plutôt que rejouer la même URL.
    final hasMorePrepared =
        _desktopSourceIndex + 1 < _preparedStreams.length;

    if (hasMorePrepared) {
      _recoveringFromError = true;
      _addDebug('mid-playback error → bascule source');
      Future.microtask(() async {
        final switched = await _tryNextSourceAfterPlaybackFail();
        if (!mounted) return;
        _recoveringFromError = false;
        if (!switched && _errorMessage == null) {
          setState(() {
            _errorMessage = 'Erreur de lecture: $error';
            _isLoading = false;
          });
        }
      });
      return;
    }

    // Dernière source : 1 seul retry réseau max, puis erreur.
    if (_playbackRetryCount >= _maxPlaybackRetries) {
      if (_errorMessage == null) {
        setState(() {
          _errorMessage = 'Erreur de lecture: $error';
          _isLoading = false;
        });
      }
      return;
    }

    _recoveringFromError = true;
    _playbackRetryCount++;

    final errLower = error.toLowerCase();
    final isNetwork = errLower.contains('network') ||
        errLower.contains('timeout') ||
        errLower.contains('connection') ||
        errLower.contains('unreachable');

    if (isNetwork) {
      setState(() => _isWaitingForNetwork = true);
      _playerController?.pause();
      _networkRetryTimer?.cancel();
      _networkRetryTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _isWaitingForNetwork = false);
        _safePlayWithSeek();
        _recoveringFromError = false;
      });
    } else {
      // Erreur non-réseau sur dernière source → échec immédiat
      _recoveringFromError = false;
      if (_errorMessage == null) {
        setState(() {
          _errorMessage = 'Erreur de lecture: $error';
          _isLoading = false;
        });
      }
    }
  }

  void _safePlayWithSeek() {
    if (_playerController == null) return;
    if (_playerController!.isInitialized) {
      if (_resumePosition != null && _resumePosition!.inSeconds > 0) {
        _playerController!.play();
        _seekWhenReady(_resumePosition!);
      } else {
        _playerController!.play();
      }
    } else {
      _addDebug('cannot play - controller not initialized');
    }
  }

  Map<String, String> _getAnimeHeaders(String? extractor, String videoUrl) {
    final headers = <String, String>{
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': '*/*',
      'Accept-Language': 'fr-FR,fr;q=0.9',
      'Connection': 'keep-alive',
    };
    switch (extractor) {
      case 'sibnet': case 'sibnet_html':
        headers['Referer'] = 'https://video.sibnet.ru/';
        headers['Origin'] = 'https://video.sibnet.ru';
        break;
      case 'sendvid':
        headers['Referer'] = 'https://sendvid.com/';
        headers['Origin'] = 'https://sendvid.com';
        break;
      case 'vidmoly': case 'vidmoly_html': case 'vidmoly_api':
        headers['Referer'] = 'https://vidmoly.to/';
        headers['Origin'] = 'https://vidmoly.to';
        break;
      case 'oneupload':
        headers['Referer'] = 'https://oneupload.to/';
        break;
      default:
        headers['Referer'] = 'https://anime-sama.to/';
    }
    if (videoUrl.contains('.m3u8')) {
      headers['Accept'] = 'application/vnd.apple.mpegurl, application/x-mpegurl, */*';
    }
    return headers;
  }

  // ─── Progression ─────────────────────────────────────────────────
  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 15), (_) => _saveProgress());
  }

  void _saveProgressSync() {
    final pos = _playerController?.currentPosition.inSeconds.toDouble() ?? 0;
    if (pos <= 0) return;
    final dur = _playerController?.totalDuration.inSeconds.toDouble() ?? 0;
    PlayerPrefs.saveLocalProgress(_progressKey, position: pos, duration: dur);
  }

  Future<void> _saveProgress() async {
    final pos = _playerController?.currentPosition.inSeconds.toDouble() ?? 0;
    if (pos <= 0) return;
    final dur = _playerController?.totalDuration.inSeconds.toDouble() ?? 0;
    await PlayerPrefs.saveLocalProgress(_progressKey, position: pos, duration: dur);
  }

  Future<void> _restoreProgress() async {
    if (!mounted) return;
    try {
      final local = await PlayerPrefs.loadLocalProgress(_progressKey);
      if (local != null && local.position > 10 && local.duration > 0) {
        final pct = (local.position / local.duration) * 100;
        if (pct < 95 && mounted) {
          _resumePosition = Duration(seconds: local.position.toInt());
        }
      }
    } catch (_) {}
  }

  Future<void> _showControlsBriefly() {
    if (!mounted) return Future.value();
    setState(() => _showControls = true);
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showControls = false);
    });
    return Future.value();
  }

  void _addDebug(String msg) {
    debugPrint('[Player] $msg');
    final ts = DateTime.now().toString().substring(11, 23);
    _debugInfo = '$ts $msg\n$_debugInfo';
    final lines = _debugInfo.split('\n');
    if (lines.length > 8) _debugInfo = lines.sublist(0, 8).join('\n');
    if (mounted) setState(() {});
  }

  Widget _buildDebugOverlay() {
    return Positioned(
      top: 80,
      left: 8,
      child: GestureDetector(
        onLongPress: () => setState(() => _showDebug = false),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _debugInfo,
            style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace'),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ─── Touches TV ──────────────────────────────────────────────────
  bool get _useSurfaceView => _playerController?.useSurfaceView ?? false;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_useSurfaceView) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      _saveProgressSync();
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      _playerController?.playOrPause();
      _showControlsBriefly();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.mediaFastForward) {
      final pos = (_playerController?.currentPosition ?? Duration.zero) + const Duration(seconds: 10);
      final dur = _playerController?.totalDuration ?? Duration.zero;
      _playerController?.seekTo(pos > dur ? dur : pos);
      _showControlsBriefly();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.mediaRewind) {
      final pos = (_playerController?.currentPosition ?? Duration.zero) - const Duration(seconds: 10);
      _playerController?.seekTo(pos < Duration.zero ? Duration.zero : pos);
      _showControlsBriefly();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.audioVolumeUp) {
      final vol = (_playerController?.volume ?? 0.5) + 0.1;
      _playerController?.setVolume(vol.clamp(0.0, 1.0));
      _showControlsBriefly();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.audioVolumeDown) {
      final vol = (_playerController?.volume ?? 0.5) - 0.1;
      _playerController?.setVolume(vol.clamp(0.0, 1.0));
      _showControlsBriefly();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.audioVolumeMute) {
      final cur = _playerController?.volume ?? 0.5;
      _playerController?.setVolume(cur > 0 ? 0 : 1.0);
      _showControlsBriefly();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ─── Build ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Android native activity : pendant la lecture l'Activity est par-dessus.
    // Au retour : loading, erreur, ou pop — jamais un écran noir vide.
    if (_useSurfaceView) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            _isLoading
                ? _buildLoading()
                : _errorMessage != null
                    ? _buildError()
                    : const SizedBox.shrink(),
            // Suite à la fermeture du lecteur natif : proposition d'enchaîner
            // sur l'épisode suivant si la vidéo s'est terminée.
            if (_showNextUp) _buildNextUpOverlay(),
          ],
        ),
      );
    }
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (!_isLoading && _errorMessage == null && !_isWaitingForNetwork)
              _buildVideo(),

            if (_isLoading)
              _buildLoading()
            else if (_errorMessage != null && !_isWaitingForNetwork)
              _buildError()
            else if (_isWaitingForNetwork)
              _buildNetworkWaiting(),

            if (!_isLoading && _errorMessage == null && !_isWaitingForNetwork)
              _buildTopBar(),

            if (!_isLoading && _errorMessage == null && !_isWaitingForNetwork)
              _buildBottomBar(),

            if (_showDebug) _buildDebugOverlay(),

            if (_showNextUp) _buildNextUpOverlay(),
          ],
        ),
      ),
    );
  }

  /// Carte « épisode suivant » avec compte à rebours (style Netflix).
  Widget _buildNextUpOverlay() {
    final next = _nextEpisode;
    if (next == null) return const SizedBox.shrink();
    return Positioned(
      right: 24,
      bottom: 96,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF14141F).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 0.5),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Épisode suivant dans $_autoplaySecondsLeft s',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      value: _autoplaySecondsLeft / 10,
                      strokeWidth: 2.5,
                      color: Theme.of(context).colorScheme.primary,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                next.fullLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _goToNextEpisode();
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Lecture'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.primary.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _cancelAutoplay,
                    child: const Text('Annuler',
                        style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            _statusLabel,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: NeoTheme.errorRed),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Retour')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _startLoading, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkWaiting() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.orange),
            const SizedBox(height: 20),
            const Text('Connexion instable', style: TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Lecture mise en pause automatiquement', style: TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () {
                  _networkRetryTimer?.cancel();
                  setState(() => _isWaitingForNetwork = false);
                  _safePlayWithSeek();
                },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réessayer maintenant'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo() {
    if (_playerController == null) {
      return const SizedBox.expand();
    }
    return MouseRegion(
      onHover: (_) {
        if (!_showControls) _showControlsBriefly();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_showControls) {
            setState(() => _showControls = false);
            _controlsTimer?.cancel();
          } else {
            _showControlsBriefly();
          }
        },
        onDoubleTap: () {
          if (!NeoTheme.isDesktopPlatform) return;
          _toggleFullscreen();
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth > 0 ? constraints.maxWidth : 1920,
              height: constraints.maxHeight > 0 ? constraints.maxHeight : 1080,
              child: UniversalVideoView(controller: _playerController!, fit: BoxFit.contain),
            );
          },
        ),
      ),
    );
  }

  void _toggleFullscreen() {
    // Desktop fullscreen via F11 (OS-level) — no window_manager dependency
    _showControlsBriefly();
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: IgnorePointer(
        ignoring: !_showControls,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _showControls ? 1.0 : 0.0,
          child: Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 16, right: 16, bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () { _saveProgressSync(); Navigator.of(context).pop(); },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.anime?.title ?? widget.content?.title ?? 'Lecture',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.anime != null) ...[
                  Text('S${widget.seasonNumber ?? 1} E${widget.episode?.episodeNumber ?? 1}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(width: 16),
                ],
                if (_extractorUsed != null)
                  Text(_extractorUsed!, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: IgnorePointer(
        ignoring: !_showControls,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _showControls ? 1.0 : 0.0,
          child: Container(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(context).padding.bottom + 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.9), Colors.black.withValues(alpha: 0.6), Colors.transparent],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSeekBar(),
                const SizedBox(height: 4),
                _buildControlsRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeekBar() {
    return StreamBuilder<Duration>(
      stream: _playerController?.positionStream,
      initialData: _playerController?.currentPosition ?? Duration.zero,
      builder: (context, posSnap) {
        final pos = posSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: _playerController?.durationStream,
          initialData: _playerController?.totalDuration ?? Duration.zero,
          builder: (context, durSnap) {
            final dur = durSnap.data ?? Duration.zero;
            final progress = dur.inMilliseconds > 0 ? pos.inMilliseconds / dur.inMilliseconds : 0.0;
            return Row(
              children: [
                Text(_formatDuration(pos), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final trackWidth = constraints.maxWidth;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) {
                            final frac = (details.localPosition.dx / trackWidth).clamp(0.0, 1.0);
                            _playerController?.seekTo(Duration(milliseconds: (dur.inMilliseconds * frac).round()));
                            _showControlsBriefly();
                          },
                          onHorizontalDragUpdate: (details) {
                            final frac = (details.localPosition.dx / trackWidth).clamp(0.0, 1.0);
                            _playerController?.seekTo(Duration(milliseconds: (dur.inMilliseconds * frac).round()));
                            _showControlsBriefly();
                          },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: SizedBox(
                              height: 44,
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  Container(height: 5, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: Colors.white24)),
                                  FractionallySizedBox(
                                    widthFactor: progress.clamp(0.0, 1.0),
                                    child: Container(height: 5, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: Theme.of(context).colorScheme.primary)),
                                  ),
                                  if (dur.inMilliseconds > 0)
                                    Positioned(
                                      left: (progress.clamp(0.0, 1.0) * trackWidth - 7).clamp(0.0, (trackWidth - 14).clamp(0.0, double.infinity)),
                                      child: Container(width: 14, height: 14, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Text(_formatDuration(dur), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildControlsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.replay_10, color: Colors.white, size: 28),
          onPressed: () {
            final pos = (_playerController?.currentPosition ?? Duration.zero) - const Duration(seconds: 10);
            _playerController?.seekTo(pos < Duration.zero ? Duration.zero : pos);
            _showControlsBriefly();
          },
        ),
        const SizedBox(width: 8),
        StreamBuilder<bool>(
          stream: _playerController?.playingStream,
          initialData: _playerController?.isPlaying ?? false,
          builder: (context, snap) {
            final playing = snap.data ?? false;
            return IconButton(
              icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white, size: 48),
              onPressed: () { _playerController?.playOrPause(); _showControlsBriefly(); },
            );
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.forward_10, color: Colors.white, size: 28),
          onPressed: () {
            final pos = (_playerController?.currentPosition ?? Duration.zero) + const Duration(seconds: 10);
            final dur = _playerController?.totalDuration ?? Duration.zero;
            _playerController?.seekTo(pos > dur ? dur : pos);
            _showControlsBriefly();
          },
        ),
        // Épisode suivant manuel (séries)
        if (widget.episodeId != null && _findNextEpisode() != null) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Épisode suivant',
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
            onPressed: () {
              _nextEpisode = _findNextEpisode();
              _goToNextEpisode();
            },
          ),
        ],
        const SizedBox(width: 8),
        _buildSourcesButton(),
        const SizedBox(width: 8),
        _buildSpeedButton(),
        const SizedBox(width: 8),
        _buildSleepTimerButton(),
      ],
    );
  }

  /// Sélecteur de source directement dans le lecteur (desktop/Web).
  Widget _buildSourcesButton() {
    if (_preparedStreams.length <= 1) return const SizedBox.shrink();
    return PopupMenuButton<int>(
      tooltip: 'Changer de source',
      color: const Color(0xFF1A1A2E),
      icon: const Icon(Icons.dns_rounded, color: Colors.white, size: 24),
      onSelected: (i) {
        if (i == _desktopSourceIndex) return;
        HapticFeedback.selectionClick();
        final pos = _playerController?.currentPosition;
        if (pos != null && pos.inSeconds > 0) _resumePosition = pos;
        _desktopSourceIndex = i;
        _playDesktopPreparedSource(generation: _extractionGeneration);
        _showControlsBriefly();
      },
      itemBuilder: (context) => [
        for (var i = 0; i < _preparedStreams.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _preparedStreams[i].label,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                if (i == _desktopSourceIndex)
                  const Icon(Icons.check_rounded,
                      color: Colors.white70, size: 16),
              ],
            ),
          ),
      ],
    );
  }

  double _currentRate = 1.0;
  Timer? _sleepTimer;
  String? _sleepLabel;

  Widget _buildSpeedButton() {
    const rates = [1.0, 1.25, 1.5, 2.0, 0.5, 0.75];
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      onPressed: () async {
        final idx = (rates.indexOf(_currentRate) + 1) % rates.length;
        _currentRate = rates[idx < 0 ? 0 : idx];
        HapticFeedback.selectionClick();
        await _playerController?.setRate(_currentRate);
        final prefs = await PlayerPrefs.load();
        prefs.playbackRate = _currentRate;
        await prefs.save();
        if (mounted) setState(() {});
        _showControlsBriefly();
      },
      child: Text(
        '${_currentRate}x',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSleepTimerButton() {
    const options = [0, 15, 30, 45, 60];
    return PopupMenuButton<int>(
      tooltip: 'Minuteur de sommeil',
      color: const Color(0xFF1A1A2E),
      icon: Icon(
        _sleepTimer != null ? Icons.bedtime_rounded : Icons.bedtime_outlined,
        color: _sleepTimer != null ? NeoTheme.warningOrange : Colors.white,
        size: 26,
      ),
      onSelected: (minutes) {
        HapticFeedback.selectionClick();
        _sleepTimer?.cancel();
        _sleepTimer = null;
        if (minutes > 0) {
          _sleepTimer = Timer(Duration(minutes: minutes), () {
            _playerController?.pause();
            if (mounted) {
              setState(() {
                _sleepTimer = null;
                _sleepLabel = null;
                _showControls = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Minuteur : lecture mise en pause')),
              );
            }
          });
          _sleepLabel = '$minutes min';
        } else {
          _sleepLabel = null;
        }
        setState(() {});
        _showControlsBriefly();
      },
      itemBuilder: (context) => [
        for (final m in options)
          PopupMenuItem<int>(
            value: m,
            child: Text(
              minutesLabel(m),
              style: const TextStyle(color: Colors.white),
            ),
          ),
      ],
    );
  }

  String minutesLabel(int m) => m == 0 ? 'Désactivé' : 'Pause dans $m min';
}
