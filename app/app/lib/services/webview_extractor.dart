import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Extracteur par **émulation navigateur** (WebView headless réelle).
///
/// Principe de la ruse : beaucoup d'hébergeurs (uqload « nouveau », vidmoly,
/// fsvid, kakaflix/kokoflix sous Cloudflare, doodstream… ) reconstruisent
/// l'URL vidéo **uniquement en JavaScript à l'exécution**, parfois après un
/// challenge Cloudflare auto-résolu. Aucun parsing de HTML statique ne suffit.
///
/// On charge la page dans un vrai moteur Chromium invisible, on attend que le
/// lecteur se configure, puis on récupère l'URL utile via :
///   - `performance.getEntriesByType('resource')` (reniflage réseau)
///   - les balises `<video>` / `<source>`
///   - l'API jwplayer si présente
///
/// Exclus les URL blob:, pub/trackers et motifs troll connus.
class WebViewExtractor {
  WebViewExtractor._();

  static bool _running = false;

  static const _ua =
      'Mozilla/5.0 (Linux; Android 13; 2201117TY Build/TKQ1.221114.001; wv) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/126.0.0.0 '
      'Mobile Safari/537.36';

  static bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Extrait la source vidéo d'une page embed en l'exécutant dans une
  /// WebView headless. Retourne le résultat au format extracteur ou null.
  static Future<Map<String, dynamic>?> extract(
    String url, {
    Duration maxWait = const Duration(seconds: 18),
  }) async {
    if (!isSupported) return null;

    // Une seule émulation à la fois (coût mémoire)
    while (_running) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    _running = true;

    HeadlessInAppWebView? headless;
    try {
      final completer = Completer<List<String>>();
      final found = <String>[];

      headless = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          javaScriptCanOpenWindowsAutomatically: false,
          mediaPlaybackRequiresUserGesture: false,
          userAgent: _ua,
          domStorageEnabled: true,
          cacheEnabled: true,
          blockNetworkImage: true, // allège le challenge (charge quand même le DOM)
          useWideViewPort: true,
          loadWithOverviewMode: true,
          disableDefaultErrorPage: true,
          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
          allowsBackForwardNavigationGestures: false,
        ),
        onProgressChanged: (controller, progress) async {
          // probe à chaque palier (le lecteur s'initialise progressivement)
          if (progress > 85 && !completer.isCompleted) {
            final urls = await _probe(controller);
            if (urls.isNotEmpty && !completer.isCompleted) {
              completer.complete(urls);
            }
          }
        },
        onLoadStop: (controller, _) async {
          // Laisse ~1.5 s au lecteur pour configurer la playlist
          await Future.delayed(const Duration(milliseconds: 1500));
          final urls = await _probe(controller);
          if (urls.isNotEmpty && !completer.isCompleted) {
            completer.complete(urls);
          }
        },
      );

      await headless.run();

      // polling jusqu'à succès ou timeout (le challenge CF prend ~5-10 s)
      final deadline = DateTime.now().add(maxWait);
      while (DateTime.now().isBefore(deadline)) {
        if (completer.isCompleted) break;
        final ctrl = headless.webViewController;
        if (ctrl != null) {
          final urls = await _probe(ctrl);
          if (urls.isNotEmpty && !completer.isCompleted) {
            completer.complete(urls);
            break;
          }
        }
        await Future.delayed(const Duration(milliseconds: 900));
      }

      final urls = completer.isCompleted ? await completer.future : <String>[];
      if (urls.isEmpty) return null;

      found.addAll(urls);
      // Priorité : m3u8 non-troll, puis mp4 non-troll
      String pick(List<String> list, Pattern kind) {
        for (final u in list) {
          if (u.contains(kind)) return u;
        }
        return '';
      }

      final videoUrl = pick(found, '.m3u8').isNotEmpty
          ? pick(found, '.m3u8')
          : pick(found, '.mp4');
      if (videoUrl.isEmpty) return null;

      final host = Uri.tryParse(url)?.host ?? '';
      return {
        'success': true,
        'video_url': videoUrl,
        'server': 'webview:${host.isNotEmpty ? host : 'emul'}',
        'type': videoUrl.contains('.m3u8') ? 'hls' : 'mp4',
        'is_hls': videoUrl.contains('.m3u8'),
        'headers': {'Referer': url, 'User-Agent': _ua},
      };
    } catch (e) {
      debugPrint('[WebViewExtractor] erreur: $e');
      return null;
    } finally {
      _running = false;
      try {
        await headless?.dispose();
      } catch (_) {}
    }
  }

  static const _probeJs = r"""
(function(){
  try{
    var bad=/troll|bigbuck|buck_bunny|doubleclick|googlesyndication|adsystem|adservice|measure|banner|pixel|trace|collect|analytic/i;
    var urls=[];
    performance.getEntriesByType('resource').forEach(function(r){
      var n=r.name;
      if((n.indexOf('.m3u8')>-1||/\.mp4(\?|#|$)/i.test(n))&&!bad.test(n)) urls.push(n);
    });
    document.querySelectorAll('video,source').forEach(function(v){
      var s=v.currentSrc||v.src||v.getAttribute('src');
      if(s&&!s.startsWith('blob:')&&s.startsWith('http')&&!bad.test(s)) urls.push(s);
    });
    if(window.jwplayer){
      try{
        var p=jwplayer(0).getPlaylist();
        if(p&&p.length&&p[0]){
          var cand=p[0];
          if(cand.file&&!bad.test(cand.file)) urls.push(cand.file);
          (cand.sources||[]).forEach(function(s){
            var u=s.url||s.file;
            if(u&&!bad.test(u)) urls.push(u);
          });
        }
      }catch(e){}
    }
    if(window.player_source){urls.push(window.player_source);}
    var uniq=[];var seen={};
    urls.forEach(function(u){if(!seen[u]){seen[u]=1;uniq.push(u);}});
    return JSON.stringify(uniq);
  }catch(e){return '[]';}
})()
""";

  static Future<List<String>> _probe(InAppWebViewController controller) async {
    try {
      final raw = await controller.evaluateJavascript(source: _probeJs);
      if (raw is String && raw.length > 2) {
        final list = jsonDecode(raw);
        if (list is List) {
          return list.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}
    return const [];
  }
}
