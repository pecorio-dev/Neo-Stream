import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config/theme.dart';
import '../models/content.dart';
import '../services/api_service.dart';
import '../services/video_extractor.dart';
import '../utils/watch_link_utils.dart';

class PlayerScreen extends StatefulWidget {
  final Content content;
  final String videoSourceUrl;
  final List<WatchLink> candidateServers;
  final String? preferredLanguage;
  final String? episodeId;

  const PlayerScreen({
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

  bool _showControls = true;
  Timer? _controlsTimer;
  final FocusNode _playerFocusNode = FocusNode();

  int _currentServerIndex = 0;
  List<WatchLink> _availableServers = <WatchLink>[];
  final List<HeadlessInAppWebView> _activeWebViews = <HeadlessInAppWebView>[];
  int _extractionSessionId = 0;
  int _parallelism = 1;
  String? _lastFailureReason;

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

    _startExtractionPipeline();
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
    _player?.dispose();
    _playerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _startExtractionPipeline({int startIndex = 0}) async {
    if (_availableServers.isEmpty || startIndex >= _availableServers.length) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isExtracting = false;
        _isInitializing = false;
        _error =
            _lastFailureReason ??
            'Aucune source lisible n a pu etre extraite automatiquement.';
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
            'Aucune source lisible n a pu etre extraite automatiquement.';
      });
      return;
    }

    _currentServerIndex = result.index;
    _startPlayerAfterExtraction(
      result.videoUrl,
      result.videoType,
      result.source,
    );
  }

  Future<_ExtractionResult?> _extractFirstSuccessful({
    required int sessionId,
    required int startIndex,
  }) async {
    final queue = Queue<_ServerCandidate>.from(
      List<_ServerCandidate>.generate(_availableServers.length - startIndex, (
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
    // Essayer l'extraction locale avec VideoExtractor
    try {
      debugPrint('=== EXTRACTION START ===');
      debugPrint('Server: ${candidate.source.server}');
      debugPrint('URL: ${candidate.source.url}');
      
      final localResult = await VideoExtractor.extract(candidate.source.url);
      
      debugPrint('Extraction result: $localResult');
      
      if (localResult['success'] == true && localResult['video_url'] != null) {
        var videoUrl = localResult['video_url'] as String;
        final videoType = localResult['type'] as String? ?? 'mp4';
        final headers = localResult['headers'] as Map<String, dynamic>?;
        
        debugPrint('✓ Extraction SUCCESS');
        debugPrint('Video URL: $videoUrl');
        debugPrint('Type: $videoType');
        debugPrint('Headers: $headers');
        debugPrint('=== EXTRACTION END ===');
        
        // Retourner l'URL directe avec les headers
        return _ExtractionResult(
          index: candidate.index,
          source: candidate.source,
          videoUrl: videoUrl,
          videoType: videoType,
          headers: headers,
        );
      }
      
      debugPrint('✗ Extraction FAILED: ${localResult['error']}');
      debugPrint('=== EXTRACTION END ===');
    } catch (e, stack) {
      debugPrint('✗ Extraction ERROR: $e');
      debugPrint('Stack: $stack');
      debugPrint('=== EXTRACTION END ===');
    }
    
    // Fallback vers WebView si l'extraction native échoue
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

            await Future.delayed(const Duration(milliseconds: 900));
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
      return const Duration(seconds: 18);
    }
    return const Duration(seconds: 14);
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

  void _startPlayerAfterExtraction(String url, String type, WatchLink source) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isExtracting = false;
      _isInitializing = true;
    });

    _initializePlayer(url, type, source);
  }

  Future<void> _initializePlayer(
    String videoUrl,
    String type,
    WatchLink source,
  ) async {
    try {
      _player?.dispose();

      debugPrint('=== PLAYER INIT START ===');
      debugPrint('URL: $videoUrl');
      debugPrint('Type: $type');
      debugPrint('Platform: ${Platform.operatingSystem}');

      // Headers complets qui imitent un navigateur Chrome
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
      };

      // Ajouter Referer et Origin depuis la source
      final sourceUri = Uri.parse(source.url);
      final referer = '${sourceUri.scheme}://${sourceUri.host}/';
      headers['Referer'] = referer;
      headers['Origin'] = referer.substring(0, referer.length - 1);

      debugPrint('Headers: $headers');

      // Créer le Player et VideoController
      debugPrint('Creating Player and VideoController...');
      _player = Player();
      _videoController = VideoController(_player!);

      debugPrint('Opening media...');
      await _player!.open(
        Media(videoUrl, httpHeaders: headers),
        play: true,
      );
      
      debugPrint('✓ Player initialized successfully');
      
      await _restoreProgress();

      _startProgressTimer();
      _showControlsBriefly();

      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
      });
      
      debugPrint('✓ Player fully initialized');
      debugPrint('=== PLAYER INIT END ===');
    } catch (e, stackTrace) {
      debugPrint('✗ Player initialization FAILED');
      debugPrint('Error: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('=== PLAYER INIT END ===');
      
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
        _error = 'Impossible d initialiser le lecteur: ${e.toString()}';
      });
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _saveProgress();
    });
  }

  void _saveProgressSync() {
    if (_player == null) return;
    final position = _player!.state.position.inSeconds.toDouble();
    final duration = _player!.state.duration.inSeconds.toDouble();
    if (duration <= 0 || position <= 0) return;
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

    if (duration <= 0 || position <= 0) {
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
    try {
      final progress = await _api.getProgress(widget.content.id);
      if (progress == null) {
        return;
      }
      final currentTime = (progress['current_time'] as num?)?.toDouble() ?? 0;
      final progressPercent = double.tryParse(progress['progress_percent']?.toString() ?? '0') ?? 0;

      if (progressPercent >= 90) {
        return;
      }

      if (currentTime > 10 && mounted) {
        final resume = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: NeoTheme.bgOverlay,
            title: Text('Reprendre la lecture ?', style: NeoTheme.titleLarge(context)),
            content: Text(
              'Vous avez déjà regardé ${progressPercent.toStringAsFixed(0)}% de ce contenu.',
              style: NeoTheme.bodyMedium(context),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Recommencer'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: NeoTheme.primaryRed),
                child: const Text('Reprendre'),
              ),
            ],
          ),
        );

        if (resume == true && mounted) {
          await _player!.seek(Duration(seconds: (currentTime - 3).toInt()));
        }
      }
    } catch (_) {}
  }

  void _retryFromStart() {
    _player?.pause();
    _player?.dispose();
    _player = null;
    _videoController = null;
    _startExtractionPipeline();
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

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final player = _player;
    if (player == null) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final position = player.state.position;
    final duration = player.state.duration;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      player.playOrPause();
      _showControlsBriefly();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaFastForward) {
      final newPosition = position + const Duration(seconds: 10);
      player.seek(newPosition > duration ? duration : newPosition);
      _showControlsBriefly();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.mediaRewind) {
      final newPosition = position - const Duration(seconds: 10);
      player.seek(
        newPosition < Duration.zero ? Duration.zero : newPosition,
      );
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
      _saveProgress();
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _showControlsBriefly() {
    setState(() => _showControls = true);
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _seekForward() {
    if (_player == null) {
      return;
    }
    final position = _player!.state.position + const Duration(seconds: 10);
    final duration = _player!.state.duration;
    _player!.seek(position > duration ? duration : position);
  }

  void _seekBackward() {
    if (_player == null) {
      return;
    }
    final position = _player!.state.position - const Duration(seconds: 10);
    _player!.seek(
      position < Duration.zero ? Duration.zero : position,
    );
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
                Video(
                  controller: _videoController!,
                  controls: NoVideoControls,
                ),
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

  Widget _buildLoadingOverlay() {
    final preferredLanguage = widget.preferredLanguage == null
        ? null
        : WatchLinkUtils.labelForLanguage(widget.preferredLanguage!);
    final scale = NeoTheme.scaleFactor(context);

    return Container(
      color: NeoTheme.bgBase,
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
                  color: NeoTheme.primaryRed.withValues(alpha: 0.06),
                  border: Border.all(
                    color: NeoTheme.primaryRed.withValues(alpha: 0.12),
                    width: 0.5,
                  ),
                ),
                child: Center(
                  child: SizedBox(
                    width: (48 * scale).roundToDouble(),
                    height: (48 * scale).roundToDouble(),
                    child: const CircularProgressIndicator(
                      color: NeoTheme.primaryRed,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isExtracting
                    ? 'Recherche automatique d une source valide...'
                    : 'Initialisation du lecteur...',
                style: NeoTheme.titleMedium(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.content.displayTitle,
                style: NeoTheme.bodyMedium(context),
                textAlign: TextAlign.center,
              ),

              if (preferredLanguage != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Langue prioritaire : $preferredLanguage',
                  style: NeoTheme.labelSmall(
                    context,
                  ).copyWith(color: NeoTheme.textTertiary),
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
      color: NeoTheme.bgBase,
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
              const SizedBox(height: 16),
              Text('Lecture indisponible', style: NeoTheme.titleLarge(context)),
              const SizedBox(height: 8),
              Text(
                error,
                style: NeoTheme.bodyMedium(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Toutes les sources adaptees ont ete essayees automatiquement.',
                style: NeoTheme.labelSmall(
                  context,
                ).copyWith(color: NeoTheme.textTertiary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _retryFromStart,
                    icon: Icon(Icons.refresh, size: 18 * NeoTheme.scaleFactor(context)),
                    label: const Text('Relancer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NeoTheme.primaryRed,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, size: 18 * NeoTheme.scaleFactor(context)),
                    label: const Text('Retour'),
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
            const Color(0xFF06060C).withValues(alpha: 0.9),
            const Color(0xFF06060C).withValues(alpha: 0.6),
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
                                  final localPos = details.localPosition;
                                  final progressBarWidth = box.size.width - 16 * scale * 2;
                                  final seekFraction = (localPos.dx / progressBarWidth).clamp(0.0, 1.0);
                                  final seekPosition = Duration(milliseconds: (duration.inMilliseconds * seekFraction).round());
                                  player.seek(seekPosition);
                                  _showControlsBriefly();
                                },
                                child: SizedBox(
                                  height: 24 * scale,
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
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.replay_10, color: Colors.white, size: 28 * scale),
                onPressed: () {
                  final pos = player.state.position - const Duration(seconds: 10);
                  player.seek(pos < Duration.zero ? Duration.zero : pos);
                  _showControlsBriefly();
                },
              ),
              const SizedBox(width: 8),
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
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.forward_10, color: Colors.white, size: 28 * scale),
                onPressed: () {
                  final pos = player.state.position + const Duration(seconds: 10);
                  player.seek(pos > player.state.duration ? player.state.duration : pos);
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
            const Color(0xFF06060C).withValues(alpha: 0.9),
            const Color(0xFF06060C).withValues(alpha: 0.6),
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
                gradient: NeoTheme.glassGradient,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.content.displayTitle,
                  style: NeoTheme.titleMedium(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.episodeId != null)
                  Text(
                    widget.episodeId!,
                    style: NeoTheme.labelSmall(
                      context,
                    ).copyWith(color: NeoTheme.textTertiary),
                  ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}

class _ServerCandidate {
  final int index;
  final WatchLink source;

  const _ServerCandidate({required this.index, required this.source});
}

class _ExtractionResult {
  final int index;
  final WatchLink source;
  final String videoUrl;
  final String videoType;
  final Map<String, dynamic>? headers;

  const _ExtractionResult({
    required this.index,
    required this.source,
    required this.videoUrl,
    required this.videoType,
    this.headers,
  });
}
