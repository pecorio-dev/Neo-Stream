// ─────────────────────────────────────────────────────────────────────────────
// re_sibnet.dart — Extracteur Sibnet (video.sibnet.ru) 2026
//
// Chaîne prouvée (08/2026, 5 vidéos du catalogue anime-sama testées) :
//   1. GET https://video.sibnet.ru/shell.php?videoid={id}
//      → HTTP 200, HTML windows-1251 (chunked). UA NAVIGATEUR OBLIGATOIRE
//        (UA curl/Dart → HTTP 400).
//   2. La page contient : player.src([{src: "/v/{md5}/{id}.mp4", ...}])
//      → regex `src:\s*"([^"]+\.(mp4|m3u8)[^"]*)"` (src relatif, ASCII-safe).
//   3. GET sur l'URL /v/... avec Referer: https://video.sibnet.ru/
//      (SANS Referer → 403) → 302 → //dvNN.sibnet.ru/... (protocol-relative)
//      → 302 → https://dvNN-2.sibnet.ru/{path}/{fileid}.mp4?st=..&e=..&stor=NN&noip=1
//   4. URL finale signée (~13 h de validité) lisible SANS Referer
//      (noip=1) : HTTP 206, Content-Type: video/mp4, ftypisom.
//
// Domaines : seul video.sibnet.ru sert shell.php.
//   sibnet.ru/shell.php → 301 → www.sibnet.ru/shell.php → 307 → /404
//   sibnet.cc → NXDOMAIN. http://video.sibnet.ru → 302 → https.
//
// Note transport : HttpClient (dart:io) reste muet sur ce réseau NAT64 ici,
// donc client HTTP/1.1 brut sur SecureSocket (TLS tolérant), comme re_dood.
//
// Usage : dart run bin/re_sibnet.dart
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const String kUa =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36';
const String kBase = 'https://video.sibnet.ru';
const Duration kTimeout = Duration(seconds: 25);

class _Resp {
  final int status;
  final Map<String, List<String>> headers;
  final List<int> bodyBytes;
  final String effectiveUrl;
  _Resp(this.status, this.headers, this.bodyBytes, this.effectiveUrl);
  String? header(String n) => headers[n.toLowerCase()]?.first;
  String get bodyLatin1 =>
      latin1.decode(bodyBytes); // sibnet = windows-1251 ; latin1 safe pour ASCII
}

/// Client HTTP/1.1 brut sur SecureSocket (TLS tolérant, redirects manuels
/// pour gérer les Location protocol-relatifs `//host/...`).
class _RawHttp {
  static Future<List<int>> _readAll(SecureSocket sock, {int cap = 4 << 20}) async {
    final chunks = <int>[];
    try {
      await for (final c in sock.timeout(kTimeout)) {
        chunks.addAll(c);
        if (chunks.length >= cap) break;
      }
    } on TimeoutException {
      // fin de flux tolérée si on a déjà des données
    }
    return chunks;
  }

  static _Resp _parse(List<int> rawBytes, String url) {
    final raw = String.fromCharCodes(rawBytes);
    final i = raw.indexOf('\r\n\r\n');
    if (i < 0) return _Resp(0, {}, rawBytes, url);
    final head = raw.substring(0, i);
    var bodyBytes = rawBytes.sublist(i + 4);
    final lines = head.split('\r\n');
    final status = int.tryParse(lines.first.split(' ').elementAt(1)) ?? 0;
    final headers = <String, List<String>>{};
    for (final l in lines.skip(1)) {
      final j = l.indexOf(':');
      if (j > 0) {
        headers
            .putIfAbsent(l.substring(0, j).trim().toLowerCase(), () => [])
            .add(l.substring(j + 1).trim());
      }
    }
    if ((headers['transfer-encoding']?.join(' ') ?? '').contains('chunked')) {
      bodyBytes = _dechunk(bodyBytes);
    }
    return _Resp(status, headers, bodyBytes, url);
  }

  static List<int> _dechunk(List<int> data) {
    final out = <int>[];
    var off = 0;
    while (off < data.length) {
      var end = -1;
      for (var k = off; k + 1 < data.length; k++) {
        if (data[k] == 13 && data[k + 1] == 10) {
          end = k;
          break;
        }
      }
      if (end < 0) break;
      final sizeStr =
          String.fromCharCodes(data.sublist(off, end)).split(';').first.trim();
      final size = int.tryParse(sizeStr, radix: 16) ?? 0;
      if (size == 0) break;
      final start = end + 2;
      if (start + size > data.length) {
        out.addAll(data.sublist(start));
        break;
      }
      out.addAll(data.sublist(start, start + size));
      off = start + size + 2;
    }
    return out;
  }

  Future<_Resp> _single(String url, Map<String, String> extra) async {
    final uri = Uri.parse(url);
    final host = uri.host;
    final path = (uri.path.isEmpty ? '/' : uri.path) +
        (uri.hasQuery ? '?${uri.query}' : '');
    SecureSocket? sock;
    try {
      final raw = await Socket.connect(host, 443, timeout: kTimeout);
      sock = await SecureSocket.secure(raw,
          host: host,
          onBadCertificate: (_) => true,
          supportedProtocols: const ['http/1.1']).timeout(kTimeout);
      final sb = StringBuffer()
        ..write('GET $path HTTP/1.1\r\n')
        ..write('Host: $host\r\n')
        ..write('User-Agent: $kUa\r\n')
        ..write('Accept: */*\r\n')
        ..write('Accept-Encoding: identity\r\n')
        ..write('Connection: close\r\n');
      extra.forEach((k, v) => sb.write('$k: $v\r\n'));
      sb.write('\r\n');
      sock.write(sb.toString());
      final data = await _readAll(sock);
      return _parse(data, url);
    } finally {
      try {
        await sock?.close();
      } catch (_) {}
    }
  }

  Future<_Resp> get(String url,
      {Map<String, String>? headers, int maxRedirects = 6}) async {
    var current = url;
    final extra = headers ?? const <String, String>{};
    for (var hop = 0; hop <= maxRedirects; hop++) {
      final r = await _single(current, extra);
      final loc = r.header('location');
      if ([301, 302, 303, 307, 308].contains(r.status) &&
          loc != null &&
          loc.isNotEmpty &&
          hop < maxRedirects) {
        if (loc.startsWith('//')) {
          current = '${Uri.parse(current).scheme}:$loc';
        } else {
          current = Uri.parse(current).resolve(loc).toString();
        }
        continue;
      }
      return _Resp(r.status, r.headers, r.bodyBytes, current);
    }
    throw StateError('trop de redirections');
  }
}

/// Extraction id depuis shell.php?videoid=, /video{id}-..., ou id nu.
String? _sibnetId(String url) {
  final m = RegExp(r'[?&]videoid=(\d+)').firstMatch(url) ??
      RegExp(r'/video(\d+)[-_/]').firstMatch(url) ??
      RegExp(r'^(?:https?://[^/]+/)?(\d{5,10})/?$').firstMatch(url.trim());
  return m?.group(1);
}

/// Point d'entrée : retourne success/video_url/type/is_hls/headers + proof.
Future<Map<String, dynamic>> extractSibnet(String url) async {
  final http = _RawHttp();
  final id = _sibnetId(url);
  if (id == null) return {'success': false, 'error': 'Sibnet: id introuvable'};

  final shellUrl = '$kBase/shell.php?videoid=$id';
  try {
    final page = await http.get(shellUrl, headers: {
      'Referer': '$kBase/',
      'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
    });
    if (page.status != 200) {
      return {
        'success': false,
        'error': 'Sibnet: shell.php HTTP ${page.status}',
        'videoid': id,
      };
    }
    final html = page.bodyLatin1;

    // Toutes les sources player.src (mp4 prioritaire, m3u8 toléré)
    final sources = <String>[];
    for (final m in RegExp(r'src:\s*"([^"]+\.(?:mp4|m3u8)[^"]*)"',
            caseSensitive: false)
        .allMatches(html)) {
      var u = m.group(1)!;
      if (u.startsWith('/')) u = '$kBase$u';
      if (!sources.contains(u)) sources.add(u);
    }
    if (sources.isEmpty) {
      return {
        'success': false,
        'error': 'Sibnet: aucune source player.src dans la page',
        'videoid': id,
      };
    }
    final srcUrl = sources.firstWhere((u) => u.contains('.mp4'),
        orElse: () => sources.first);
    final isHls = srcUrl.contains('.m3u8');

    // Preuve : GET Range sur /v/ (Referer obligatoire), 302 suivis jusqu'au CDN
    final vr = await http.get(srcUrl, headers: {
      'Referer': '$kBase/',
      'Range': 'bytes=0-99999',
    });
    final ctype = vr.header('content-type') ?? '';
    final crange = vr.header('content-range') ?? '';
    final total = crange.contains('/') ? crange.split('/').last : '';
    final magicOk = vr.bodyBytes.length > 8 &&
        (latin1.decode(vr.bodyBytes.sublist(4, 8)) == 'ftyp' || isHls);

    if (vr.status == 200 || vr.status == 206) {
      return {
        'success': true,
        'video_url': vr.effectiveUrl, // URL CDN signée finale
        'src_url': srcUrl, // URL /v/ stable côté embed
        'type': isHls ? 'hls' : 'mp4',
        'is_hls': isHls,
        'extractor': 'sibnet',
        'proof': {
          'http_status': vr.status,
          'content_type': ctype,
          'content_range': crange,
          'total_bytes': total,
          'magic_ftyp': magicOk,
          'chain': 'shell.php → player.src /v/ → 302 dvNN → 302 dvNN-2 (signée)',
        },
        'headers': {'User-Agent': kUa}, // URL finale noip=1 : Referer optionnel
      };
    }
    return {
      'success': false,
      'error': 'Sibnet: source HTTP ${vr.status}',
      'src_url': srcUrl,
    };
  } catch (e) {
    return {'success': false, 'error': 'Sibnet: $e', 'videoid': id};
  }
}

// ── Démo / preuve sur liens réels ────────────────────────────────────────────

Future<void> main(List<String> args) async {
  print('=== PROOF Sibnet — ${DateTime.now().toUtc()} ===');
  final tests = args.isNotEmpty
      ? args
      : <String>[
          'https://video.sibnet.ru/shell.php?videoid=3731681', // Psycho Pass
          'https://video.sibnet.ru/shell.php?videoid=6024062', // Yano-kun
          'https://video.sibnet.ru/shell.php?videoid=6233861',
          'https://video.sibnet.ru/shell.php?videoid=6244914',
        ];
  for (final t in tests) {
    print('\n→ $t');
    final sw = Stopwatch()..start();
    final r = await extractSibnet(t);
    sw.stop();
    if (r['success'] == true) {
      final p = r['proof'] as Map;
      print('  ✔ SUCCESS en ${sw.elapsedMilliseconds} ms');
      print('  video_url : ${r['video_url']}');
      print('  HTTP      : ${p['http_status']} ${p['content_type']} '
          'range=${p['content_range']} ftyp=${p['magic_ftyp']}');
    } else {
      print('  ✘ ${r['error']}');
    }
  }
}
