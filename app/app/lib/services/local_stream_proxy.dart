import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'direct_tls_fetch.dart';
import 'resilient_http.dart';

void _log(String m) {
  // ignore: avoid_print
  print(m);
}

/// Proxy de streaming vidéo **local** (boucle interne 127.0.0.1).
///
/// Le lecteur (ExoPlayer natif / media_kit) ne résout JAMAIS lui-même les
/// hébergeurs : il demande tout à ce proxy. Le proxy, lui, contourne les
/// blocages du réseau (DNS empoisonné / connexions refusées) grace à la
/// cascade :
///
///   1. Requête directe classique          (rapide — réseau propre)
///   2. TLS/SNI sur IP résolue par DoH     (casse le blocage DNS « 127.0.0.1 »)
///   3. Relais via le serveur o2switch     (casse le blocage IP)
///
/// Réécrit les playlists HLS pour y réintroduire le proxy, forwarde les
/// ranges ExoPlayer, et ne met en mémoire que ce qui est nécessaire.
class LocalStreamProxy {
  LocalStreamProxy._();
  static final LocalStreamProxy instance = LocalStreamProxy._();

  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  HttpServer? _server;
  int _port = 0;
  bool _starting = false;

  bool get isRunning => _server != null;

  /// Démarre le serveur s'il ne tourne pas (idempotent, thread-safe).
  Future<bool> ensureRunning() async {
    if (_server != null) return true;
    if (_starting) {
      while (_starting) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _server != null;
    }
    _starting = true;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      unawaited(_server!.forEach(_handle));
      _log('[StreamProxy] démarré sur 127.0.0.1:$_port');
      return true;
    } catch (e) {
      _log('[StreamProxy] échec démarrage: $e');
      return false;
    } finally {
      _starting = false;
    }
  }

  /// Enrobe une URL originale en URL proxy locale (si proxy disponible).
  /// Les headers exportés via `h` (JSON base64url) — le proxy les rejoue.
  String wrap(String originalUrl, {Map<String, String>? headers}) {
    if (_server == null) return originalUrl;
    final q = StringBuffer('url=${Uri.encodeComponent(originalUrl)}');
    if (headers != null && headers.isNotEmpty) {
      q.write('&h=${Uri.encodeComponent(base64Url.encode(utf8.encode(jsonEncode(headers))))}');
    }
    return 'http://127.0.0.1:$_port/proxy?$q';
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = 0;
  }

  // ── Handler ──────────────────────────────────────────────────────────

  Future<void> _handle(HttpRequest client) async {
    HttpResponse resp = client.response;
    try {
      final target = client.uri.queryParameters['url'];
      if (target == null || target.isEmpty) {
        resp.statusCode = 400;
        resp.write('missing url');
        await resp.close();
        return;
      }
      final headers = _decodeHeaders(client.uri.queryParameters['h']);
      // Forwarder le Range d'ExoPlayer si présent (seek mp4)
      final range = client.headers.value('range');
      if (range != null) headers['Range'] = range;

      final fetched = await _fetchCascade(target, headers);
      if (fetched == null) {
        resp.statusCode = 502;
        await resp.close();
        return;
      }

      var body = fetched.body;
      var contentType = fetched.contentType ?? _guessContentType(target);

      // Réécriture des playlists HLS → tout repasse par le proxy.
      final isPlaylist = target.contains('.m3u8') ||
          (contentType?.contains('mpegurl') ?? false) ||
          (body != null &&
              body.length > 7 &&
              String.fromCharCodes(body.sublist(0, 7)) == '#EXTM3U');
      if (isPlaylist && body != null) {
        final text = utf8.decode(body, allowMalformed: true);
        if (text.contains('#EXTM3U')) {
          final rewritten = _rewritePlaylist(text, target, headers);
          body = Uint8List.fromList(utf8.encode(rewritten));
          contentType = 'application/vnd.apple.mpegurl';
        }
      }

      resp.statusCode = fetched.status;
      if (contentType != null) {
        resp.headers.set(HttpHeaders.contentTypeHeader, contentType);
      }
      final contentRange = fetched.contentRange;
      if (contentRange != null) {
        resp.headers.set('content-range', contentRange);
        resp.headers.set('accept-ranges', 'bytes');
      }
      if (body != null) {
        resp.headers.contentLength = body.length;
        resp.add(body); // close() flushera le buffer
      } else {
        resp.headers.contentLength = 0;
      }
      await resp.close();
    } catch (e) {
      _log('[StreamProxy] handler error: $e');
      try {
        resp.statusCode = 500;
        await resp.close();
      } catch (_) {}
    }
  }

  Map<String, String> _decodeHeaders(String? b64) {
    if (b64 == null || b64.isEmpty) return {'User-Agent': _ua};
    try {
      final map = jsonDecode(utf8.decode(base64Url.decode(b64)));
      final out = <String, String>{'User-Agent': _ua};
      if (map is Map) {
        map.forEach((k, v) => out[k.toString()] = v.toString());
      }
      return out;
    } catch (_) {
      return {'User-Agent': _ua};
    }
  }

  // ── Cascade d'accès réseau ──────────────────────────────────────────

  Future<_Fetched?> _fetchCascade(String url, Map<String, String> headers) async {
    // 1) Direct (rapide quand le réseau est propre)
    try {
      final r = await ResilientHttp.send('GET', Uri.parse(url),
          headers: headers, timeout: const Duration(seconds: 12));
      if (r.statusCode >= 200 && r.statusCode < 400) {
        final buffered = await http.Response.fromStream(r);
        _log('[StreamProxy] direct OK ${r.statusCode} ${buffered.bodyBytes.length}o ${url.substring(0, url.length > 70 ? 70 : url.length)}');
        return _FromResponse(buffered);
      }
      _log('[StreamProxy] direct HTTP ${r.statusCode}');
    } catch (e) {
      _log('[StreamProxy] direct KO: ${e.toString().substring(0, e.toString().length > 90 ? 90 : e.toString().length)}');
    }

    // 2) TLS/SNI sur IP DoH (casse l'empoisonnement DNS)
    final direct = await DirectTlsFetch.get(url, headers: headers);
    if (direct != null && direct.status >= 200 && direct.status < 400) {
      _log('[StreamProxy] DoH OK ${direct.status} ${direct.body.length}o');
      return _FromDirect(direct);
    }
    _log('[StreamProxy] DoH KO (${direct?.status ?? 'null'})');

    // 3) Relais serveur o2switch (casse le blocage IP complet)
    try {
      final r = await ResilientHttp.send(
        'GET',
        Uri.parse(ResilientHttp.relayFor(url)),
        headers: headers,
        timeout: const Duration(seconds: 20),
      );
      if (r.statusCode >= 200 && r.statusCode < 400) {
        _log('[StreamProxy] relais OK ${r.statusCode}');
        return _FromResponse(await http.Response.fromStream(r));
      }
      _log('[StreamProxy] relais HTTP ${r.statusCode}');
    } catch (e) {
      _log('[StreamProxy] relais KO: ${e.toString().substring(0, e.toString().length > 90 ? 90 : e.toString().length)}');
    }

    return null;
  }

  // ── Réécriture HLS ──────────────────────────────────────────────────

  String _rewritePlaylist(String body, String baseUrl, Map<String, String> headers) {
    final out = StringBuffer();
    for (final line in body.split('\n')) {
      final trimmed = line.trimRight();
      if (trimmed.startsWith('#')) {
        // URI= dans les directives (#EXT-X-KEY, #EXT-X-MEDIA, #EXT-X-I-FRAME…)
        final rewritten = trimmed.replaceAllMapped(
          RegExp(r'URI="([^"]+)"'),
          (m) => 'URI="${wrap(_absolutize(baseUrl, m[1]!), headers: headers)}"',
        );
        out.writeln(rewritten);
      } else if (trimmed.isNotEmpty) {
        out.writeln(wrap(_absolutize(baseUrl, trimmed), headers: headers));
      } else {
        out.writeln();
      }
    }
    return out.toString();
  }

  String _absolutize(String base, String maybeRel) {
    if (maybeRel.startsWith('http://') || maybeRel.startsWith('https://')) {
      return maybeRel;
    }
    return Uri.parse(base).resolve(maybeRel).toString();
  }

  String? _guessContentType(String url) {
    final u = url.toLowerCase();
    if (u.contains('.m3u8')) return 'application/vnd.apple.mpegurl';
    if (u.contains('.ts')) return 'video/mp2t';
    if (u.contains('.m4s')) return 'video/iso.segment';
    if (u.contains('.mp4') || u.contains('.mkv')) return 'video/mp4';
    if (u.contains('.key')) return 'application/octet-stream';
    return null;
  }
}

class _Fetched {
  final int status;
  final Uint8List? body;
  final String? contentType;
  final String? contentRange;
  _Fetched(this.status, this.body, this.contentType, this.contentRange);
}

class _FromResponse extends _Fetched {
  _FromResponse(http.Response r)
      : super(
          r.statusCode,
          r.bodyBytes,
          r.headers['content-type'],
          r.headers['content-range'],
        );
}

class _FromDirect extends _Fetched {
  _FromDirect(DirectFetchResult r)
      : super(
          r.status,
          r.body,
          r.headers['content-type'],
          r.headers['content-range'],
        );
}
