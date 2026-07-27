import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config/theme.dart';
import '../config/neo.dart';
import '../models/content.dart';
import '../services/api_service.dart';
import '../services/player_prefs.dart';
import '../services/video_extractor.dart';
import '../utils/watch_link_utils.dart';

class PlayerScreen extends StatefulWidget {
  final Content content;
  final String videoSourceUrl;
  final List<WatchLink> candidateServers;
  final String? preferredLanguage;
  final String? episodeId;

  PlayerScreen({
    super.key,
    required this.content,
    required this.videoSourceUrl,
    required this.candidateServers,
    this.preferredLanguage,
    this.episodeId,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final ApiService _api = ApiService();

  Player? _player;
  VideoController? _videoController;
  bool _isExtracting = true;
  bool _isInitializing = false;
  String? _error;

  Timer? _progressTimer;
  double _lastSavedTime = 0;

  /// Clé stable identifiant ce média (film/épisode) pour le cache local de
  /// progression. Permet de reprendre même si l'API est lente/indisponible.
  String get _progressKey =>
      widget.episodeId != null
          ? '${widget.content.id}_${widget.episodeId}'
          : '${widget.content.id}';

  bool _showControls = true;
  Timer? _controlsTimer;
  final FocusNode _playerFocusNode = FocusNode();

  // Accélération du seek au maintien (gauche/droite télécommande)
  int _seekRepeatCount = 0;
  LogicalKeyboardKey? _seekKey;

  int _currentServerIndex = 0;
  List<WatchLink> _availableServers = <WatchLink>[];
  bool _awaitingInitialSourceSelection = true;
  final List<HeadlessInAppWebView> _activeWebViews = <HeadlessInAppWebView>[];
  int _extractionSessionId = 0;
  int _parallelism = 1;
  String? _lastFailureReason;

  // Retry automatique sur erreur réseau pendant la lecture
  int _playbackRetryCount = 0;
  static const int _maxPlaybackRetries = 3;
  Duration? _resumePosition;

  StreamSubscription<String>? _playerErrorSub;
  StreamSubscription<bool>? _playerCompletedSub;

  // Gestion session CDN — refresh pré-emptif en deux phases

  // Gestion des erreurs réseau temporaires
  bool _isWaitingForNetwork = false;
  Timer? _networkRetryTimer;

  @override
  void initState() {
    super.initState();
    
    WakelockPlus.enable();

    // Only set orientation/UI mode on mobile — TV/desktop don't support it
    if (!NeoTheme.isDesktopPlatform) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    _availableServers = WatchLinkUtils.prioritize(
      widget.candidateServers.isNotEmpty
          ? widget.candidateServers
          : widget.content.watchLinks,
      preferredLanguage: widget.preferredLanguage,
    );
    _parallelism = WatchLinkUtils.recommendedParallelism();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_availableServers.isEmpty) {
        _startExtractionPipeline();
      } else {
        _showInitialSourcePicker();
      }
    });
  }

  Future<void> _showInitialSourcePicker() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (dialogContext) => _ServerDialog(
        servers: _availableServers,
        currentIndex: _currentServerIndex,
        onSelect: (index) {
          Navigator.of(dialogContext).pop();
          if (!mounted) return;
          setState(() {
            _currentServerIndex = index;
            _awaitingInitialSourceSelection = false;
          });
          _startExtractionPipeline(
            startIndex: index,
            allowFallbacks: false,
          );
        },
      ),
    );

    // Le retour système ferme uniquement le lecteur : aucune lecture ne démarre
    // sans que l'utilisateur ait choisi sa source.
    if (mounted && _awaitingInitialSourceSelection) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _saveProgressSync();
    _cancelExtractionSession();
    
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

    _progressTimer?.cancel();
    _controlsTimer?.cancel();
    _networkRetryTimer?.cancel();
    _playerErrorSub?.cancel();
    _playerCompletedSub?.cancel();
    _player?.dispose();
    _playerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _startExtractionPipeline({
    int startIndex = 0,
    bool allowFallbacks = true,
  }) async {
    if (_availableServers.isEmpty || startIndex >= _availableServers.length) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isExtracting = false;
        _isInitializing = false;
        _error =
            _lastFailureReason ??
            'Aucune source lisible n\'a pu être extraite automatiquement.';
      });
      return;
    }

    _cancelExtractionSession();
    final sessionId = ++_extractionSessionId;

    setState(() {
      _isExtracting = true;
      _isInitializing = false;
      _error = null;
      _lastFailureReason = null;
    });

    final result = await _extractFirstSuccessful(
      sessionId: sessionId,
      startIndex: startIndex,
      allowFallbacks: allowFallbacks,
    );

    if (!mounted || sessionId != _extractionSessionId) {
      return;
    }

    if (result == null) {
      setState(() {
        _isExtracting = false;
        _isInitializing = false;
        _error =
            _lastFailureReason ??
            'Aucune source lisible n\'a pu être extraite automatiquement.';
      });
      return;
    }

    _currentServerIndex = result.index;
    _startPlayerAfterExtraction(
      result.videoUrl,
      result.videoType,
      result.source,
      result.headers,
    );
  }

  Future<_ExtractionResult?> _extractFirstSuccessful({
    required int sessionId,
    required int startIndex,
    required bool allowFallbacks,
  }) async {
    final candidateCount = allowFallbacks
        ? _availableServers.length - startIndex
        : 1;
    final queue = Queue<_ServerCandidate>.from(
      List<_ServerCandidate>.generate(candidateCount, (
        offset,
      ) {
        final index = startIndex + offset;
        return _ServerCandidate(index: index, source: _availableServers[index]);
      }),
    );

    final completer = Completer<_ExtractionResult?>();
    var activeWorkers = 0;
    var finished = false;

    void complete(_ExtractionResult? result) {
      if (finished || completer.isCompleted) {
        return;
      }
      finished = true;
      _disposeActiveWebViews();
      completer.complete(result);
    }

    void maybeLaunchNext() {
      while (!finished &&
          activeWorkers < _parallelism &&
          queue.isNotEmpty &&
          sessionId == _extractionSessionId) {
        final candidate = queue.removeFirst();
        activeWorkers++;
        _markCandidateStarted(candidate);

        _extractFromServer(candidate, sessionId)
            .then((result) {
              activeWorkers--;

              if (finished || sessionId != _extractionSessionId) {
                return;
              }

              if (result != null) {
                complete(result);
                return;
              }

              if (queue.isEmpty && activeWorkers == 0) {
                complete(null);
                return;
              }

              maybeLaunchNext();
            })
            .catchError((_) {
              activeWorkers--;
              if (finished || sessionId != _extractionSessionId) {
                return;
              }

              if (queue.isEmpty && activeWorkers == 0) {
                complete(null);
                return;
              }

              maybeLaunchNext();
            });
      }

      if (!finished && queue.isEmpty && activeWorkers == 0) {
        complete(null);
      }
    }

    maybeLaunchNext();
    return completer.future;
  }

  void _markCandidateStarted(_ServerCandidate candidate) {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<_ExtractionResult?> _extractFromServer(
    _ServerCandidate candidate,
    int sessionId,
  ) async {
    // Essayer l'extraction hybride (locale d'abord, puis fallback API PHP)
    try {
      final result = await _api.extractVideoUrl(candidate.source.url);

      if (result['success'] == true && result['video_url'] != null) {
        final videoUrl = result['video_url'] as String;
        final videoType = result['type'] as String? ?? 'mp4';
        final headers = (result['headers'] as Map?)?.cast<String, dynamic>();
        final rawQualities = result['qualities'] as List?;
        final qualities = rawQualities
            ?.map((e) => (e as Map).cast<String, String>())
            .toList();

        return _ExtractionResult(
          index: candidate.index,
          source: candidate.source,
          videoUrl: videoUrl,
          videoType: videoType,
          headers: headers,
          qualities: qualities,
        );
      }
    } catch (_) {}

    // Extraction 100 % locale : si les patterns natifs échouent, on passe au
    // WebView headless (sniffing réseau du vrai flux). Aucun appel API serveur.
    // Fallback vers WebView si tout le reste échoue
    final completer = Completer<_ExtractionResult?>();
    HeadlessInAppWebView? webView;
    Timer? timeout;
    var resolved = false;

    void resolve(_ExtractionResult? result, {String? failureReason}) {
      if (resolved) {
        return;
      }
      resolved = true;
      timeout?.cancel();
      if (failureReason != null && failureReason.trim().isNotEmpty) {
        _lastFailureReason = failureReason;
      }
      if (webView != null) {
        _activeWebViews.remove(webView);
        webView.dispose();
      }
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }

    bool maybeResolveWithPlayableUrl(String? rawUrl) {
      final normalized = _normalizePlayableUrl(rawUrl);
      if (normalized == null) {
        return false;
      }
      resolve(
        _ExtractionResult(
          index: candidate.index,
          source: candidate.source,
          videoUrl: normalized,
          videoType: _inferVideoType(normalized),
        ),
      );
      return true;
    }

    try {
      final sourceUrl = candidate.source.url;

      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(sourceUrl)),
        initialSettings: InAppWebViewSettings(
          useShouldInterceptRequest: true,
          useShouldInterceptFetchRequest: true,
          useShouldInterceptAjaxRequest: true,
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          javaScriptCanOpenWindowsAutomatically: true,
          supportMultipleWindows: false,
          userAgent:
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        ),
        initialUserScripts: UnmodifiableListView<UserScript>([
          UserScript(
            source: '''
              try {
                Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
                delete window.flutter_inappwebview;
              } catch (_) {}
            ''',
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            forMainFrameOnly: false,
          ),
        ]),
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          if (resolved || sessionId != _extractionSessionId) {
            return NavigationActionPolicy.CANCEL;
          }

          final url = navigationAction.request.url.toString();
          if (maybeResolveWithPlayableUrl(url)) {
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
        shouldInterceptRequest: (controller, request) async {
          if (resolved || sessionId != _extractionSessionId) {
            return null;
          }
          maybeResolveWithPlayableUrl(request.url.toString());
          return null;
        },
        shouldInterceptFetchRequest: (controller, request) async {
          if (resolved || sessionId != _extractionSessionId) {
            return null;
          }
          maybeResolveWithPlayableUrl(request.url.toString());
          return null;
        },
        shouldInterceptAjaxRequest: (controller, request) async {
          if (resolved || sessionId != _extractionSessionId) {
            return null;
          }
          maybeResolveWithPlayableUrl(request.url.toString());
          return null;
        },
        onLoadStop: (controller, url) async {
          if (resolved || sessionId != _extractionSessionId) {
            return;
          }

          try {
            await controller.evaluateJavascript(
              source: '''
                document.querySelectorAll(
                  'video, source, button, .play, #play, .vjs-big-play-button, .clappr-play-button, .jw-video, .jw-state-idle, .plyr__control, [class*="play" i], [id*="play" i]'
                ).forEach((element) => {
                  try { element.click(); } catch (_) {}
                });
                try { document.body.click(); } catch (_) {}
              ''',
            );

            await Future.delayed(Duration(milliseconds: 900));
            if (resolved) {
              return;
            }

            final directSrc = _sanitizeJavascriptValue(
              await controller.evaluateJavascript(
                source: '''
                  (() => {
                    const video = document.querySelector('video');
                    if (video && video.src && video.src.startsWith('http') && !video.src.includes('blob:')) {
                      return video.src;
                    }
                    const source = document.querySelector('source');
                    if (source && source.src && source.src.startsWith('http') && !source.src.includes('blob:')) {
                      return source.src;
                    }
                    return null;
                  })();
                ''',
              ),
            );

            if (maybeResolveWithPlayableUrl(directSrc)) {
              return;
            }

            final iframeSrc = _sanitizeJavascriptValue(
              await controller.evaluateJavascript(
                source: '''
                  (() => {
                    const iframe = document.querySelector('iframe');
                    if (iframe && iframe.src && iframe.src.startsWith('http')) {
                      return iframe.src;
                    }
                    return null;
                  })();
                ''',
              ),
            );

            if (iframeSrc != null &&
                iframeSrc.isNotEmpty &&
                !_isIgnoredUrl(iframeSrc)) {
              await controller.loadUrl(
                urlRequest: URLRequest(url: WebUri(iframeSrc)),
              );
              return;
            }

            final html = _sanitizeJavascriptValue(
              await controller.evaluateJavascript(
                source: 'document.documentElement.outerHTML',
              ),
            );

            if (html != null && html.isNotEmpty) {
              final match = RegExp(
                r'''(https?://[^\s"'<>]+\.(m3u8|mp4)[^\s"'<>]*)''',
                caseSensitive: false,
              ).firstMatch(html);
              if (match != null &&
                  maybeResolveWithPlayableUrl(match.group(1))) {
                return;
              }
            }

            await controller.evaluateJavascript(
              source: 'document.body.click();',
            );
          } catch (_) {}
        },
      );

      _activeWebViews.add(webView);
      timeout = Timer(
        _timeoutFor(candidate.source),
        () => resolve(
          null,
          failureReason:
              'Source indisponible, tentative suivante...',
        ),
      );

      await webView.run();
    } catch (_) {
      resolve(
        null,
        failureReason:
            'Source indisponible, tentative suivante...',
      );
    }

    return completer.future;
  }

  Duration _timeoutFor(WatchLink source) {
    final domain = WatchLinkUtils.sourceLabel(source).toLowerCase();
    if (domain.contains('kakaflix') ||
        domain.contains('multiup') ||
        domain.contains('kokoflix')) {
      return Duration(seconds: 18);
    }
    return Duration(seconds: 14);
  }

  String? _normalizePlayableUrl(String? rawUrl) {
    if (rawUrl == null) {
      return null;
    }

    var url = rawUrl.trim();
    if (url.isEmpty || url == 'null' || url == 'undefined') {
      return null;
    }

    if (url.startsWith('//')) {
      url = 'https:$url';
    }

    if (_isIgnoredUrl(url)) {
      return null;
    }

    final lower = url.toLowerCase();
    final looksPlayable =
        lower.contains('.m3u8') ||
        lower.contains('.mp4') ||
        lower.contains('video/mp4') ||
        lower.contains('master.txt');

    if (!looksPlayable) {
      return null;
    }

    return url;
  }

  String? _sanitizeJavascriptValue(dynamic value) {
    if (value == null) {
      return null;
    }

    var raw = value.toString().trim();
    if (raw.isEmpty || raw == 'null' || raw == 'undefined') {
      return null;
    }

    if ((raw.startsWith('"') && raw.endsWith('"')) ||
        (raw.startsWith("'") && raw.endsWith("'"))) {
      raw = raw.substring(1, raw.length - 1);
    }

    return raw
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u002F', '/')
        .replaceAll('&amp;', '&');
  }

  bool _isIgnoredUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('google-analytics') ||
        lower.contains('googlesyndication') ||
        lower.contains('doubleclick') ||
        lower.contains('/ads') ||
        lower.contains('blob:');
  }

  String _inferVideoType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8') || lower.contains('master.txt')) {
      return 'hls';
    }
    return 'mp4';
  }

  void _startPlayerAfterExtraction(
    String url,
    String type,
    WatchLink source,
    Map<String, dynamic>? extractorHeaders,
  ) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isExtracting = false;
      _isInitializing = true;
    });

    _initializePlayer(url, type, source, extractorHeaders);
  }

  Map<String, String> _buildPlaybackHeaders(
    WatchLink source, {
    Map<String, dynamic>? extractorHeaders,
  }) {
    final sourceUri = Uri.tryParse(source.url);
    final referer = sourceUri != null ? '${sourceUri.scheme}://${sourceUri.host}/' : '';
    final headers = <String, String>{
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      'Accept': '*/*',
      'Accept-Language': 'fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7',
      'Accept-Encoding': 'identity',
      'Connection': 'keep-alive',
      'Sec-Fetch-Dest': 'video',
      'Sec-Fetch-Mode': 'no-cors',
      'Sec-Fetch-Site': 'cross-site',
      'Sec-Ch-Ua': '"Not A(Brand";v="8", "Chromium";v="131", "Google Chrome";v="131"',
      'Sec-Ch-Ua-Mobile': '?0',
      'Sec-Ch-Ua-Platform': '"Windows"',
      if (referer.isNotEmpty) 'Referer': referer,
      if (referer.isNotEmpty) 'Origin': referer.substring(0, referer.length - 1),
    };
    extractorHeaders?.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        headers[key] = value.toString();
      }
    });
    return headers;
  }

  Future<void> _initializePlayer(
    String videoUrl,
    String type,
    WatchLink source,
    Map<String, dynamic>? extractorHeaders,
  ) async {
    _playbackRetryCount = 0;

    try {
      _player?.dispose();

      final headers = _buildPlaybackHeaders(
        source,
        extractorHeaders: extractorHeaders,
      );
      // Créer le Player et VideoController
      _player = Player();
      _videoController = VideoController(
        _player!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
          androidAttachSurfaceAfterVideoParameters: true,
        ),
      );

      // Annuler les subscriptions de l'ancien player avant d'en créer de nouvelles
      _playerErrorSub?.cancel();
      _playerCompletedSub?.cancel();

      // Capturer l'instance pour ignorer les événements d'un ancien player
      final thisPlayer = _player!;
      var errorHandled = false;

      _playerErrorSub = thisPlayer.stream.error.listen((error) {
        if (!mounted || errorHandled) return;

        final errorStr = error.toString().toLowerCase();
        final isNetworkError = errorStr.contains('network') ||
                               errorStr.contains('timeout') ||
                               errorStr.contains('connection') ||
                               errorStr.contains('unreachable');
        final isDecodeError = errorStr.contains('decode') || errorStr.contains('video') || errorStr.contains('format');

        // Erreur réseau temporaire : pause + attente sans réextraction
        if (isNetworkError && _playbackRetryCount < _maxPlaybackRetries) {
          errorHandled = true;
          _playbackRetryCount++;
          final pos = thisPlayer.state.position;
          if (pos.inSeconds > 0) _resumePosition = pos;

          setState(() {
            _isWaitingForNetwork = true;
          });

          thisPlayer.pause();

          // Retry automatique après délai croissant (3s, 6s, 9s...)
          final retryDelay = Duration(seconds: 3 * _playbackRetryCount);
          _networkRetryTimer?.cancel();
          _networkRetryTimer = Timer(retryDelay, () {
            if (!mounted) return;
            setState(() {
              _isWaitingForNetwork = false;
            });
            if (_resumePosition != null && _resumePosition!.inSeconds > 0) {
              thisPlayer.play();
              _seekWhenReady(_resumePosition!);
            } else {
              thisPlayer.play();
            }
          });
          return;
        }

        errorHandled = true;

        // Erreur non-réseau : tenter une reprise sur la même URL d'abord
        // Ne re-extraire que si la reprise échoue après tous les retries
        if (_playbackRetryCount < _maxPlaybackRetries) {
          _playbackRetryCount++;
          final pos = thisPlayer.state.position;
          if (pos.inSeconds > 0) _resumePosition = pos;
          setState(() => _isWaitingForNetwork = true);
          thisPlayer.pause();

          final retryDelay = Duration(seconds: 2 * _playbackRetryCount);
          _networkRetryTimer?.cancel();
          _networkRetryTimer = Timer(retryDelay, () {
            if (!mounted) return;
            setState(() => _isWaitingForNetwork = false);
            thisPlayer.play();
            if (_resumePosition != null && _resumePosition!.inSeconds > 0) {
              _seekWhenReady(_resumePosition!);
            }
          });
          return;
        }

        if (_error == null) {
          setState(() {
            _error = 'Erreur de lecture: $error';
            _isInitializing = false;
            _isExtracting = false;
          });
        }
      });

      _playerCompletedSub = thisPlayer.stream.completed.listen((completed) {
        if (completed) _saveProgress();
      });

      await _player!.open(
        Media(videoUrl, httpHeaders: headers),
        play: true,
      );
      
      await _selectVideoTrackWhenAvailable(thisPlayer);
      
      // Si on reprend après expiration URL / changement de lecteur → seek direct
      // sans passer par l'API. On attend que le stream soit chargé avant de seek.
      if (_resumePosition != null && _resumePosition!.inSeconds > 0) {
        final target = _resumePosition!;
        _resumePosition = null;
        _player!.play();
        await _seekWhenReady(target);
      } else {
        await _restoreProgress();
      }

      _startProgressTimer();
      _showControlsBriefly();

      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
      });

      } catch (e, stackTrace) {
      final nextStartIndex = _currentServerIndex + 1;
      if (nextStartIndex < _availableServers.length) {
        _lastFailureReason = 'Changement de source en cours...';
        await _startExtractionPipeline(startIndex: nextStartIndex);
        return;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
        _error = 'Impossible d\'initialiser le lecteur: ${e.toString()}';
      });
    }
  }

  Future<void> _selectVideoTrackWhenAvailable(Player player) async {
    try {
      var tracks = player.state.tracks;
      if (tracks.video.isEmpty) {
        tracks = await player.stream.tracks
            .firstWhere((value) => value.video.isNotEmpty)
            .timeout(const Duration(seconds: 12));
      }
      if (!mounted || _player != player) return;
      await player.setVideoTrack(
        tracks.video.isEmpty ? VideoTrack.auto() : tracks.video.first,
      );
    } catch (_) {
      if (mounted && _player == player) {
        await player.setVideoTrack(VideoTrack.auto());
      }
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(Duration(seconds: 15), (_) {
      _saveProgress();
    });
  }

  void _saveProgressSync() {
    if (_player == null) return;
    final position = _player!.state.position.inSeconds.toDouble();
    final duration = _player!.state.duration.inSeconds.toDouble();
    if (position <= 0) return;

    // Si la vidéo est quasi terminée, effacer la progression
    final percent = duration > 0 ? (position / duration) * 100 : 0;
    if (percent >= 95) {
      PlayerPrefs.clearLocalProgress(_progressKey);
      return;
    }

    // Toujours persister localement (instantané, fiable même hors-ligne).
    PlayerPrefs.saveLocalProgress(
      _progressKey,
      position: position,
      duration: duration,
    );
    if (duration <= 0) return;
    try {
      _api.saveProgress(
        contentId: widget.content.id,
        currentTime: position,
        totalDuration: duration,
        episodeId: widget.episodeId,
      );
    } catch (_) {}
  }

  Future<void> _saveProgress() async {
    if (_player == null) return;

    final position = _player!.state.position.inSeconds.toDouble();
    final duration = _player!.state.duration.inSeconds.toDouble();

    if (position <= 0) {
      return;
    }

    // Si la vidéo est quasi terminée (> 95%), on efface la progression
    // pour ne pas proposer de "reprendre" un contenu déjà vu.
    final percent = duration > 0 ? (position / duration) * 100 : 0;
    if (percent >= 95) {
      await PlayerPrefs.clearLocalProgress(_progressKey);
      return;
    }

    // Filet local d'abord : on ne perd jamais la position, même si la durée
    // n'est pas encore connue ou si l'API ne répond pas.
    await PlayerPrefs.saveLocalProgress(
      _progressKey,
      position: position,
      duration: duration,
    );

    if (duration <= 0) {
      return;
    }
    if ((position - _lastSavedTime).abs() < 5) {
      return;
    }

    _lastSavedTime = position;

    try {
      await _api.saveProgress(
        contentId: widget.content.id,
        currentTime: position,
        totalDuration: duration,
        episodeId: widget.episodeId,
      );
    } catch (_) {}
  }

  Future<void> _restoreProgress() async {
    if (!mounted || _player == null) return;

    var bestTime = 0.0;

    // 1) Reprise immédiate depuis le cache local (pas d'attente réseau).
    try {
      final local = await PlayerPrefs.loadLocalProgress(_progressKey);
      if (local != null) {
        final localPct =
            local.duration > 0 ? (local.position / local.duration) * 100 : 0;
        // Ignorer si quasi terminé (> 95%) ou trop court (< 10s)
        if (localPct < 95 && local.position > 10) {
          bestTime = local.position;
        }
      }
    } catch (_) {}

    // 2) Réconciliation avec l'API (timeout court : ne bloque jamais la lecture).
    try {
      final progress = await _api
          .getProgress(widget.content.id, episodeId: widget.episodeId)
          .timeout(Duration(seconds: 3));
      if (progress != null) {
        final currentTime = (progress['current_time'] as num?)?.toDouble() ?? 0;
        final progressPercent =
            double.tryParse(progress['progress_percent']?.toString() ?? '0') ?? 0;

        // On ne met à jour bestTime que si l'API est sensiblement plus avancée
        if (progressPercent < 95 &&
            currentTime > 10 &&
            currentTime > bestTime + 10) {
          bestTime = currentTime;
        }
      }
    } catch (_) {}

    if (!mounted || _player == null) return;

    // S'il y a une position de reprise significative (> 10 secondes)
    if (bestTime > 10) {
      final targetDuration = Duration(seconds: bestTime.toInt());
      bool shouldResume = false;

      if (mounted && _player != null) {
        _player!.pause();
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierColor: const Color(0xB3000000),
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

      if (!mounted || _player == null) return;

      if (shouldResume) {
        final seekTarget = Duration(
          seconds: (bestTime - 3).clamp(0, double.maxFinite).toInt(),
        );
        await _seekWhenReady(seekTarget);
      } else {
        await _seekWhenReady(Duration.zero);
      }
    }

    if (mounted && _player != null) {
      _player!.play();
    }
  }

  /// Effectue un seek robuste : si la durée du stream n'est pas encore connue
  /// (vidéo pas encore chargée), on attend le premier event `duration > 0`
  /// avant de seek — sinon media_kit ignore silencieusement le seek.
  Future<void> _seekWhenReady(Duration target) async {
    final player = _player;
    if (player == null || target.inSeconds <= 0) {
      return;
    }

    // Durée déjà connue → seek immédiat.
    if (player.state.duration.inSeconds > 0) {
      await player.seek(target);
      return;
    }

    // Sinon on attend que le stream charge (durée valide) avant de seek.
    try {
      await player.stream.duration
          .firstWhere((d) => d.inSeconds > 0)
          .timeout(Duration(seconds: 25));
    } catch (_) {
      // Timeout / stream fermé → on tente quand même un seek best-effort.
    }

    // Le player a pu être remplacé entre-temps (switch de lecteur).
    if (!mounted || _player != player) {
      return;
    }

    final dur = player.state.duration;
    final clamped = (dur.inSeconds > 0 && target > dur) ? dur : target;
    await player.seek(clamped);
  }

  void _retryFromStart() {
    _player?.pause();
    _player?.dispose();
    _player = null;
    _videoController = null;
    _startExtractionPipeline(
      startIndex: _currentServerIndex,
      allowFallbacks: false,
    );
  }

  Episode? _nextPlayableEpisode() {
    if (!widget.content.isSerie || widget.episodeId == null) return null;
    final episodes = <Episode>[];
    final seasons = widget.content.seasons.keys.toList()..sort();
    for (final season in seasons) {
      final items = List<Episode>.from(widget.content.seasons[season] ?? const [])
        ..sort((a, b) => a.episode.compareTo(b.episode));
      episodes.addAll(items.where((episode) => episode.watchLinks.isNotEmpty));
    }
    final currentIndex = episodes.indexWhere(
      (episode) => 'S${episode.season}E${episode.episode}' == widget.episodeId,
    );
    if (currentIndex < 0 || currentIndex + 1 >= episodes.length) return null;
    return episodes[currentIndex + 1];
  }

  void _playNextEpisode() {
    final next = _nextPlayableEpisode();
    if (next == null) return;
    final servers = WatchLinkUtils.prioritize(
      next.watchLinks,
      preferredLanguage: widget.preferredLanguage,
    );
    if (servers.isEmpty) return;
    _saveProgressSync();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          content: widget.content,
          videoSourceUrl: servers.first.url,
          candidateServers: servers,
          preferredLanguage: widget.preferredLanguage,
          episodeId: 'S${next.season}E${next.episode}',
        ),
      ),
    );
  }

  void _cancelExtractionSession() {
    _extractionSessionId++;
    _disposeActiveWebViews();
  }

  void _disposeActiveWebViews() {
    for (final webView in List<HeadlessInAppWebView>.from(_activeWebViews)) {
      webView.dispose();
    }
    _activeWebViews.clear();
  }

  /// Pas de seek progressif selon la durée du maintien (gauche/droite TV).
  /// Plus on reste appuyé, plus on avance/recule vite.
  int _seekStepSeconds() {
    final c = _seekRepeatCount;
    if (c < 4) return 10; // appui court
    if (c < 10) return 30;
    if (c < 18) return 60;
    return 120; // maintien long → 2 min par cran
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final player = _player;
    if (player == null) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Relâchement d'une touche de seek → on réinitialise l'accélération.
    if (event is KeyUpEvent) {
      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.mediaFastForward ||
          key == LogicalKeyboardKey.mediaRewind) {
        _seekRepeatCount = 0;
        _seekKey = null;
      }
      return KeyEventResult.ignored;
    }

    final isDown = event is KeyDownEvent;
    final isRepeat = event is KeyRepeatEvent;
    if (!isDown && !isRepeat) {
      return KeyEventResult.ignored;
    }

    final position = player.state.position;
    final duration = player.state.duration;

    final isSeekKey = key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.mediaFastForward ||
        key == LogicalKeyboardKey.mediaRewind;

    if (isSeekKey) {
      // Suivi de l'accélération : même touche maintenue → on incrémente.
      if (isRepeat && _seekKey == key) {
        _seekRepeatCount++;
      } else {
        _seekRepeatCount = 0;
        _seekKey = key;
      }
      final step = Duration(seconds: _seekStepSeconds());
      final forward = key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.mediaFastForward;
      final newPosition = forward ? position + step : position - step;
      final clamped = newPosition < Duration.zero
          ? Duration.zero
          : (duration > Duration.zero && newPosition > duration
              ? duration
              : newPosition);
      player.seek(clamped);
      _showControlsBriefly();
      return KeyEventResult.handled;
    }

    // Les autres touches n'agissent qu'à l'appui initial.
    if (!isDown) {
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      player.playOrPause();
      _showControlsBriefly();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      final volume = (player.state.volume + 5.0).clamp(0.0, 100.0);
      player.setVolume(volume);
      _showControlsBriefly();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      final volume = (player.state.volume - 5.0).clamp(0.0, 100.0);
      player.setVolume(volume);
      _showControlsBriefly();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      if (ModalRoute.of(context)?.isCurrent == true) {
        _saveProgress();
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // TV: touche Menu/Info/F1 → ouvre sélecteur de lecteur + paramètres
    if (key == LogicalKeyboardKey.contextMenu ||
        key == LogicalKeyboardKey.f1 ||
        key == LogicalKeyboardKey.info ||
        key == LogicalKeyboardKey.help) {
      _showControlsBriefly();
      _showTVOptionsDialog(context);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _showTVOptionsDialog(BuildContext ctx) {
    if (!NeoTheme.isTV(ctx)) return;
    showDialog<void>(
      context: ctx,
      barrierColor: Colors.black54,
      builder: (_) => _TVOptionsDialog(
        hasServers: _availableServers.isNotEmpty,
        onChangeServer: () {
          Navigator.pop(ctx);
          if (_availableServers.isNotEmpty) {
            showDialog(
              context: ctx,
              barrierColor: Colors.black54,
              builder: (_) => _ServerDialog(
                servers: _availableServers,
                currentIndex: _currentServerIndex,
                onSelect: (i) {
                  Navigator.pop(ctx);
                  if (i == _currentServerIndex) return;
                  final pos = _player?.state.position;
                  if (pos != null && pos.inSeconds > 0) _resumePosition = pos;
                  _currentServerIndex = i;
                  _cancelExtractionSession();
                  _player?.pause();
                  _player?.dispose();
                  _player = null;
                  _videoController = null;
                  _startExtractionPipeline(
                    startIndex: i,
                    allowFallbacks: false,
                  );
                },
              ),
            );
          }
        },
        onSettings: () {
          Navigator.pop(ctx);
          _showPlayerSettings(ctx);
        },
        onBack: () {
          Navigator.pop(ctx);
          _saveProgress();
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _showControlsBriefly() {
    setState(() => _showControls = true);
    _controlsTimer?.cancel();
    _controlsTimer = Timer(Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _playerFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_isExtracting || _isInitializing)
                _buildLoadingOverlay()
              else if (_error != null)
                _buildErrorOverlay(_error!)
              else if (_videoController != null)
                SizedBox.expand(
                  child: Video(
                    controller: _videoController!,
                    controls: NoVideoControls,
                    fit: BoxFit.contain,
                  ),
                ),
              // Overlay d'attente de connexion réseau
              if (_isWaitingForNetwork && !_isExtracting && !_isInitializing && _error == null)
                _buildNetworkWaitingOverlay(),
              if (!(_isExtracting || _isInitializing) && _player != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: AnimatedOpacity(
                      duration: NeoTheme.durationNormal,
                      opacity: _showControls ? 1.0 : 0.0,
                      child: _buildTopBar(),
                    ),
                  ),
                ),
              if (!(_isExtracting || _isInitializing) && _player != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: AnimatedOpacity(
                      duration: NeoTheme.durationNormal,
                      opacity: _showControls ? 1.0 : 0.0,
                      child: _buildBottomBar(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkWaitingOverlay() {
    final scale = NeoTheme.scaleFactor(context);

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: (72 * scale).roundToDouble(),
                height: (72 * scale).roundToDouble(),
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
                    size: (40 * scale).roundToDouble(),
                    color: Colors.orange,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Connexion instable détectée',
                style: Neo.titleMedium(context).copyWith(color: Colors.orange),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'Lecture mise en pause automatiquement',
                style: Neo.bodyMedium(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'En attente d\'une connexion réseau plus stable...',
                style: NeoTheme.labelSmall(context).copyWith(
                  color: Neo.textTertiary(context),
                ),
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
                    _player?.play();
                    _seekWhenReady(_resumePosition!);
                  } else {
                    _player?.play();
                  }
                },
                icon: Icon(Icons.refresh, size: 18 * scale),
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

  Widget _buildLoadingOverlay() {
    final preferredLanguage = widget.preferredLanguage == null
        ? null
        : WatchLinkUtils.labelForLanguage(widget.preferredLanguage!);
    final scale = NeoTheme.scaleFactor(context);

    return Container(
      color: Neo.bgBase(context),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: (72 * scale).roundToDouble(),
                height: (72 * scale).roundToDouble(),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    width: 0.5,
                  ),
                ),
                child: Center(
                  child: SizedBox(
                    width: (48 * scale).roundToDouble(),
                    height: (48 * scale).roundToDouble(),
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                _isExtracting
                    ? 'Recherche automatique d\'une source valide...'
                    : 'Initialisation du lecteur...',
                style: Neo.titleMedium(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                widget.content.displayTitle,
                style: Neo.bodyMedium(context),
                textAlign: TextAlign.center,
              ),

              if (preferredLanguage != null) ...[
                SizedBox(height: 4),
                Text(
                  'Langue prioritaire : $preferredLanguage',
                  style: NeoTheme.labelSmall(
                    context,
                  ).copyWith(color: Neo.textTertiary(context)),
                  textAlign: TextAlign.center,
                ),
              ],

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay(String error) {
    final scale = NeoTheme.scaleFactor(context);

    return Container(
      color: Neo.bgBase(context),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32 * scale),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: (80 * scale).roundToDouble(),
                height: (80 * scale).roundToDouble(),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NeoTheme.errorRed.withValues(alpha: 0.06),
                  border: Border.all(
                    color: NeoTheme.errorRed.withValues(alpha: 0.12),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  Icons.error_outline,
                  size: (40 * scale).roundToDouble(),
                  color: NeoTheme.errorRed.withValues(alpha: 0.8),
                ),
              ),
              SizedBox(height: 16),
              Text('Lecture indisponible', style: Neo.titleLarge(context)),
              SizedBox(height: 8),
              Text(
                error,
                style: Neo.bodyMedium(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Toutes les sources adaptées ont été essayées automatiquement.',
                style: NeoTheme.labelSmall(
                  context,
                ).copyWith(color: Neo.textTertiary(context)),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _retryFromStart,
                    icon: Icon(Icons.refresh, size: 18 * NeoTheme.scaleFactor(context)),
                    label: Text('Relancer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, size: 18 * NeoTheme.scaleFactor(context)),
                    label: Text('Retour'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_player == null) return const SizedBox.shrink();
    final scale = NeoTheme.scaleFactor(context);
    final player = _player!;

    return Container(
      padding: EdgeInsets.only(
        left: 16 * scale,
        right: 16 * scale,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color(0xFF06060C).withValues(alpha: 0.9),
            Color(0xFF06060C).withValues(alpha: 0.6),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<Duration>(
            stream: player.stream.position,
            initialData: player.state.position,
            builder: (context, positionSnapshot) {
              final position = positionSnapshot.data ?? Duration.zero;
              final duration = player.state.duration;
              final progress = duration.inMilliseconds > 0
                  ? position.inMilliseconds / duration.inMilliseconds
                  : 0.0;
              return StreamBuilder<Duration>(
                stream: player.stream.buffer,
                initialData: player.state.buffer,
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
                            style: TextStyle(color: Colors.white70, fontSize: 12 * scale),
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                              child: GestureDetector(
                                onTapDown: (details) {
                                  final RenderBox box = context.findRenderObject() as RenderBox;
                                  final frac = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                                  player.seek(Duration(milliseconds: (duration.inMilliseconds * frac).round()));
                                  _showControlsBriefly();
                                },
                                onHorizontalDragUpdate: (details) {
                                  final RenderBox box = context.findRenderObject() as RenderBox;
                                  final frac = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                                  player.seek(Duration(milliseconds: (duration.inMilliseconds * frac).round()));
                                  _showControlsBriefly();
                                },
                                child: SizedBox(
                                  height: 44 * scale,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final trackWidth = constraints.maxWidth;
                                      final thumbSize = 14 * scale;
                                      final p = progress.clamp(0.0, 1.0);
                                      // Le centre du thumb suit la progression sur
                                      // la largeur RÉELLE de la piste ; on borne
                                      // pour qu'il ne dépasse pas les extrémités.
                                      final thumbLeft =
                                          (p * trackWidth - thumbSize / 2)
                                              .clamp(0.0, trackWidth - thumbSize);
                                      return Stack(
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
                                            widthFactor: p,
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
                                              left: thumbLeft,
                                              child: Container(
                                                width: thumbSize,
                                                height: thumbSize,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: TextStyle(color: Colors.white70, fontSize: 12 * scale),
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
                icon: Icon(Icons.replay_10, color: Colors.white, size: 28 * scale),
                onPressed: () {
                  final pos = player.state.position - Duration(seconds: 10);
                  player.seek(pos < Duration.zero ? Duration.zero : pos);
                  _showControlsBriefly();
                },
              ),
              SizedBox(width: 8),
              StreamBuilder<bool>(
                stream: player.stream.playing,
                initialData: player.state.playing,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data ?? false;
                  return IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Colors.white,
                      size: 48 * scale,
                    ),
                    onPressed: () {
                      player.playOrPause();
                      _showControlsBriefly();
                    },
                  );
                },
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.forward_10, color: Colors.white, size: 28 * scale),
                onPressed: () {
                  final pos = player.state.position + Duration(seconds: 10);
                  player.seek(pos > player.state.duration ? player.state.duration : pos);
                  _showControlsBriefly();
                },
              ),
              if (_nextPlayableEpisode() != null)
                Padding(
                  padding: EdgeInsets.only(left: 8 * scale),
                  child: FilledButton.tonalIcon(
                    onPressed: _playNextEpisode,
                    icon: Icon(Icons.skip_next_rounded, size: 22 * scale),
                    label: Text(
                      'Suivant',
                      style: TextStyle(fontSize: 13 * scale),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: Size(0, 40 * scale),
                      padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
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

  Widget _buildTopBar() {
    final screenPad = NeoTheme.screenPadding(context);
    final scale = NeoTheme.scaleFactor(context);
    final backIconSize = NeoTheme.isTV(context) ? 24.0 : 20.0;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: screenPad.left,
        right: screenPad.right,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF06060C).withValues(alpha: 0.9),
            Color(0xFF06060C).withValues(alpha: 0.6),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(6 * scale),
              decoration: BoxDecoration(
                gradient: Neo.glassGradient(context),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: backIconSize,
              ),
            ),
            onPressed: () {
              _saveProgress();
              Navigator.pop(context);
            },
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.content.displayTitle,
                  style: Neo.titleMedium(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.episodeId != null)
                  Text(
                    widget.episodeId!,
                    style: NeoTheme.labelSmall(
                      context,
                    ).copyWith(color: Neo.textTertiary(context)),
                  ),
              ],
            ),
          ),

          // ── Sélecteur de lecteur ──────────────────────────────────
          if (_availableServers.isNotEmpty)
            _ServerSelectorButton(
              servers: _availableServers,
              currentIndex: _currentServerIndex,
              onSelect: (index) {
                if (index == _currentServerIndex) return;
                final pos = _player?.state.position;
                if (pos != null && pos.inSeconds > 0) _resumePosition = pos;
                _currentServerIndex = index;
                _cancelExtractionSession();
                _player?.pause();
                _player?.dispose();
                _player = null;
                _videoController = null;
                _startExtractionPipeline(
                  startIndex: index,
                  allowFallbacks: false,
                );
              },
            ),
          // ── Paramètres du lecteur ─────────────────────────────────
          if (NeoTheme.isTV(context))
            _TVMenuButton(
              onTap: () {
                _showControlsBriefly();
                _showTVOptionsDialog(context);
              },
            )
          else
            IconButton(
              tooltip: 'Paramètres du lecteur',
              icon: Container(
                padding: EdgeInsets.all(6 * scale),
                decoration: BoxDecoration(
                  gradient: Neo.glassGradient(context),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                ),
                child: Icon(Icons.settings_rounded, color: Colors.white, size: 18 * scale),
              ),
              onPressed: () => _showPlayerSettings(context),
            ),
        ],
      ),
    );
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
  _PlayerSettingsSheet({required this.player});

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

class _TVMenuButton extends StatefulWidget {
  final VoidCallback onTap;
  _TVMenuButton({required this.onTap});

  @override
  State<_TVMenuButton> createState() => _TVMenuButtonState();
}

class _TVMenuButtonState extends State<_TVMenuButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scale = NeoTheme.scaleFactor(context);
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
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
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
          decoration: BoxDecoration(
            gradient: _focused ? null : Neo.glassGradient(context),
            color: _focused ? Theme.of(context).colorScheme.primary : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.15),
              width: _focused ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_rounded,
                color: _focused ? Colors.white : Colors.white70,
                size: 16 * scale,
              ),
              SizedBox(width: 6 * scale),
              Text(
                'MENU',
                style: TextStyle(
                  color: _focused ? Colors.white : Colors.white70,
                  fontSize: 11 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TVSettingsDialog extends StatefulWidget {
  final Player? player;
  _TVSettingsDialog({required this.player});

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

// ── Dialogue options TV ───────────────────────────────────────────────────────

class _TVOptionsDialog extends StatelessWidget {
  final bool hasServers;
  final VoidCallback onChangeServer;
  final VoidCallback onSettings;
  final VoidCallback onBack;

  _TVOptionsDialog({
    required this.hasServers,
    required this.onChangeServer,
    required this.onSettings,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Color(0xFF0D1827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Options', style: Neo.titleMedium(context)),
            SizedBox(height: 16),
            if (hasServers)
              _TVOptionTile(
                autofocus: true,
                icon: Icons.video_library_outlined,
                label: 'Changer de lecteur',
                onTap: onChangeServer,
              ),
            _TVOptionTile(
              autofocus: !hasServers,
              icon: Icons.speed_rounded,
              label: 'Vitesse de lecture',
              onTap: onSettings,
            ),
            _TVOptionTile(
              icon: Icons.arrow_back_rounded,
              label: 'Quitter le contenu',
              color: NeoTheme.errorRed,
              onTap: onBack,
            ),
          ],
        ),
      ),
    );
  }
}

class _TVOptionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool autofocus;

  _TVOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.autofocus = false,
  });

  @override
  State<_TVOptionTile> createState() => _TVOptionTileState();
}

class _TVOptionTileState extends State<_TVOptionTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? Colors.white;
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _focused ? c.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused ? c : Colors.white.withValues(alpha: 0.08),
              width: _focused ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: _focused ? c : Colors.white70, size: 22),
              SizedBox(width: 14),
              Text(
                widget.label,
                style: Neo.bodyMedium(context).copyWith(
                  color: _focused ? c : Colors.white70,
                  fontWeight: _focused ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerCandidate {
  final int index;
  final WatchLink source;

  _ServerCandidate({required this.index, required this.source});
}

class _ExtractionResult {
  final int index;
  final WatchLink source;
  final String videoUrl;
  final String videoType;
  final Map<String, dynamic>? headers;
  final List<Map<String, String>>? qualities;

  _ExtractionResult({
    required this.index,
    required this.source,
    required this.videoUrl,
    required this.videoType,
    this.headers,
    this.qualities,
  });
}

// ─── Bouton + panel de sélection de lecteur ────────────────────────────────
class _ServerSelectorButton extends StatefulWidget {
  final List<WatchLink> servers;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  _ServerSelectorButton({
    required this.servers,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  State<_ServerSelectorButton> createState() => _ServerSelectorButtonState();
}

class _ServerSelectorButtonState extends State<_ServerSelectorButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scale = NeoTheme.scaleFactor(context);
    final isTV = NeoTheme.isTV(context);
    final current = widget.currentIndex < widget.servers.length
        ? widget.servers[widget.currentIndex]
        : null;
    final label = current != null
        ? WatchLinkUtils.serverDisplayName(current)
        : 'Lecteur';

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          _openSheet(context, isTV);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openSheet(context, isTV),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          padding:
              EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 7 * scale),
          decoration: BoxDecoration(
            color: _focused
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _focused
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white.withValues(alpha: 0.15),
              width: _focused ? 2 : 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.video_library_outlined,
                  color: _focused ? Colors.white : Colors.white70,
                  size: 16 * scale),
              SizedBox(width: 6 * scale),
              Text(
                label,
                style: TextStyle(
                    color: _focused ? Colors.white : Colors.white70,
                    fontSize: 12 * scale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, bool isTV) {
    if (isTV) {
      // TV: show a dialog overlay instead of bottom sheet
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => _ServerDialog(
          servers: widget.servers,
          currentIndex: widget.currentIndex,
          onSelect: (i) { Navigator.pop(context); widget.onSelect(i); },
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _ServerSheet(
          servers: widget.servers,
          currentIndex: widget.currentIndex,
          onSelect: (i) { Navigator.pop(context); widget.onSelect(i); },
        ),
      );
    }
  }
}

class _ServerSheet extends StatelessWidget {
  final List<WatchLink> servers;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  _ServerSheet({
    required this.servers,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: Color(0xFF0D1827),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Choisir un lecteur',
              style: Neo.titleMedium(context),
            ),
            SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: servers.length,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemBuilder: (_, i) => _ServerTile(
                  link: servers[i],
                  index: i,
                  isActive: i == currentIndex,
                  onTap: () => onSelect(i),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerDialog extends StatefulWidget {
  final List<WatchLink> servers;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  _ServerDialog({
    required this.servers,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late int _focused;

  @override
  void initState() {
    super.initState();
    _focused = widget.currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    final displayCount = widget.servers.length.clamp(0, 12);
    return Dialog(
      backgroundColor: Color(0xFF0D1827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 20),
            Text('Choisir un lecteur', style: Neo.titleMedium(context)),
            SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: displayCount,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemBuilder: (_, i) => Focus(
                  autofocus: i == _focused,
                  onFocusChange: (has) { if (has) setState(() => _focused = i); },
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        (event.logicalKey == LogicalKeyboardKey.enter ||
                            event.logicalKey == LogicalKeyboardKey.select ||
                            event.logicalKey == LogicalKeyboardKey.space)) {
                      widget.onSelect(i);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: _ServerTile(
                    link: widget.servers[i],
                    index: i,
                    isActive: i == widget.currentIndex,
                    isFocused: i == _focused,
                    onTap: () => widget.onSelect(i),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  final WatchLink link;
  final int index;
  final bool isActive;
  final bool isFocused;
  final VoidCallback onTap;

  _ServerTile({
    required this.link,
    required this.index,
    required this.isActive,
    required this.onTap,
    this.isFocused = false,
  });

  @override
  Widget build(BuildContext context) {
    final scale = NeoTheme.scaleFactor(context);
    final name = WatchLinkUtils.serverDisplayName(link);
    final lang = link.languageCode.toUpperCase();
    final extractable = WatchLinkUtils.isExtractable(link);
    final iframeOnly = WatchLinkUtils.isIframeOnly(link);

    Color bg = Colors.transparent;
    if (isActive) bg = Theme.of(context).colorScheme.primary.withValues(alpha: 0.15);
    if (isFocused && !isActive) bg = Colors.white.withValues(alpha: 0.08);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 10 * scale),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                : (isFocused ? Colors.white24 : Colors.transparent),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Server name
            Expanded(
              child: Text(
                '${index + 1}. $name',
                style: TextStyle(
                  color: isActive ? Theme.of(context).colorScheme.primary : Colors.white,
                  fontSize: 14 * scale,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            // Language badge
            if (lang != 'UNKNOWN') ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  lang,
                  style: TextStyle(color: Colors.white70, fontSize: 10 * scale),
                ),
              ),
              SizedBox(width: 6 * scale),
            ],
            // Quality badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
              decoration: BoxDecoration(
                color: (extractable && !iframeOnly)
                    ? Color(0xFF1A6B3C).withValues(alpha: 0.7)
                    : Color(0xFF8B4513).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                (extractable && !iframeOnly) ? 'SANS PUB' : 'AVEC PUB',
                style: TextStyle(
                  color: (extractable && !iframeOnly)
                      ? Color(0xFF4CAF50)
                      : Color(0xFFFF8C00),
                  fontSize: 9 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isActive) ...[
              SizedBox(width: 6 * scale),
              Icon(Icons.play_circle_filled, color: Theme.of(context).colorScheme.primary, size: 16 * scale),
            ],
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

  _ResumeDialog({
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

  _ResumeButton({
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
