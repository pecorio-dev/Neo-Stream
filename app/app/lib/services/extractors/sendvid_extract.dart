// ─────────────────────────────────────────────────────────────────────────────
// re_sendvid.dart — Extracteur Sendvid (sendvid.com) 2026
//
// Chaîne établie par reverse-engineering (wayback 2024-10 → 2026-07,
// structure stable) :
//   1. GET https://sendvid.com/embed/{id}  (browser UA)
//      Aussi /{id} → normalisé vers /embed/{id}.
//   2. La page embed contient 3 occurrences de la même URL signée :
//        <source src="{URL}" type="video/mp4" id="video_source"/>
//        var video_source = "{URL}";
//        <meta property="og:video" content="{URL}"/>
//      URL = https://videos2.sendvid.com/{h1}/{h2}/{id}.mp4
//            ?validfrom={epoch}&validto={epoch+4h}&rate=250k
//            &ip={IP_CLIENT}&hash={base64}
//      → SIGNÉE, VALIDE ~4 h, LIÉE À L'IP DU CLIENT qui a fetché l'embed.
//      (extraction et lecture doivent donc venir de la même machine/IP —
//       pas de problème pour l'app : le device extrait puis lit.)
//   3. GET/Range direct sur l'URL signée → 200/206 video/mp4 (CDN :
//      videos2.sendvid.com → cdn-nf.sendvid.com). Pas de Referer requis.
//
// Points de vue mesurés (08/08/2026) :
//   - sendvid.com était en PANNE GLOBALE (HTTP 502 « Technical Difficulties »
//     depuis 4 réseaux distincts : VPS DE, IP FR, allorigins, r.jina.ai) ;
//     le CDN vidéos2 (185.107.92.224) ne répondait plus non plus.
//   - sendvid.net = parking, sendvid.co = « domain is for sale ». AUCUN miroir.
//   → L'extracteur ci-dessous applique la chaîne documentée ; les tests réels
//     tournent dès que l'origine est rétablie.
//
// Usage : dart run bin/re_sendvid.dart [urls…]
// ─────────────────────────────────────────────────────────────────────────────
// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures, unused_local_variable, unused_element, unused_import
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const String kUa =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36';
const String kBase = 'https://sendvid.com';
const Duration kTimeout = Duration(seconds: 25);

class _Resp {
  final int status;
  final Map<String, List<String>> headers;
  final List<int> bodyBytes;
  final String effectiveUrl;
  _Resp(this.status, this.headers, this.bodyBytes, this.effectiveUrl);
  String? header(String n) => headers[n.toLowerCase()]?.first;
  String get bodyUtf8 => utf8.decode(bodyBytes, allowMalformed: true);
}

/// Client HTTP/1.1 brut sur SecureSocket (TLS tolérant, redirects manuels).
/// (HttpClient dart:io reste muet sur le réseau de test NAT64 ici.)
class _RawHttp {
  static Future<List<int>> _readAll(SecureSocket sock,
      {int cap = 4 << 20}) async {
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

/// id sendvid : /embed/{id}, /{id} (8 alphanum).
String? _sendvidId(String url) {
  final m = RegExp(r'sendvid\.(?:com)/(?:embed/)?([a-zA-Z0-9]{6,12})')
      .firstMatch(url) ??
      RegExp(r'^([a-zA-Z0-9]{6,12})$').firstMatch(url.trim());
  return m?.group(1);
}

String _htmlUnescape(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&#38;', '&')
    .replaceAll('&quot;', '"');

/// Point d'entrée : success/video_url/type/is_hls/headers + proof.
Future<Map<String, dynamic>> extractSendvid(String url) async {
  final http = _RawHttp();
  final id = _sendvidId(url);
  if (id == null) return {'success': false, 'error': 'Sendvid: id introuvable'};

  final embedUrl = '$kBase/embed/$id';
  try {
    final page = await http.get(embedUrl, headers: {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
      'Referer': '$kBase/',
    });
    if (page.status != 200) {
      return {
        'success': false,
        'error': 'Sendvid: embed HTTP ${page.status}'
            '${page.status == 502 ? ' (panne amont mesurée 08/2026)' : ''}',
        'id': id,
      };
    }
    final html = page.bodyUtf8;

    // 3 portes documentées (même URL signée) : <source>, var JS, og:video
    String? videoUrl;
    for (final re in [
      RegExp(r'<source[^>]+src="([^"]+)"[^>]*id="video_source"',
          caseSensitive: false),
      RegExp(r'<source[^>]+id="video_source"[^>]*src="([^"]+)"',
          caseSensitive: false),
      RegExp(r'video_source\s*=\s*"([^"]+)"', caseSensitive: false),
      RegExp(r'property="og:video(?::secure_url)?"\s+content="([^"]+)"',
          caseSensitive: false),
    ]) {
      videoUrl = re.firstMatch(html)?.group(1);
      if (videoUrl != null && videoUrl.isNotEmpty) break;
      videoUrl = null;
    }
    if (videoUrl == null) {
      return {
        'success': false,
        'error': 'Sendvid: video_source introuvable (structure changée ?)',
        'id': id,
      };
    }
    videoUrl = _htmlUnescape(videoUrl);
    final isHls = videoUrl.contains('.m3u8');

    // Preuve : Range sur l'URL signée (IP-bound à cette machine — cohérent)
    final vr = await http.get(videoUrl, headers: {
      'Range': 'bytes=0-99999',
      'Referer': embedUrl,
    });
    final ctype = vr.header('content-type') ?? '';
    final crange = vr.header('content-range') ?? '';
    final total = crange.contains('/') ? crange.split('/').last : '';
    final magicOk = vr.bodyBytes.length > 8 &&
        (latin1.decode(vr.bodyBytes.sublist(4, 8)) == 'ftyp' || isHls);

    if (vr.status == 200 || vr.status == 206) {
      return {
        'success': true,
        'video_url': videoUrl,
        'type': isHls ? 'hls' : 'mp4',
        'is_hls': isHls,
        'extractor': 'sendvid',
        'proof': {
          'http_status': vr.status,
          'content_type': ctype,
          'content_range': crange,
          'total_bytes': total,
          'magic_ftyp': magicOk,
          'chain': 'embed → <source id=video_source> (signée ip+4h) → CDn videos2',
          'ip_bound': true,
          'expires': RegExp(r'validto=(\d+)').firstMatch(videoUrl)?.group(1),
        },
        'headers': {'User-Agent': kUa},
      };
    }
    return {
      'success': false,
      'error': 'Sendvid: URL signée HTTP ${vr.status}',
      'video_url': videoUrl,
    };
  } catch (e) {
    return {'success': false, 'error': 'Sendvid: $e', 'id': id};
  }
}

// ── Démo / preuve sur liens réels ────────────────────────────────────────────

Future<void> main(List<String> args) async {
  print('=== PROOF Sendvid — ${DateTime.now().toUtc()} ===');
  final tests = args.isNotEmpty
      ? args
      : <String>[
          'https://sendvid.com/embed/bf0qkrl4', // Psycho Pass EP1
          'https://sendvid.com/embed/ezdi5eb0', // Yano-kun EP1
        ];
  for (final t in tests) {
    print('\n→ $t');
    final sw = Stopwatch()..start();
    final r = await extractSendvid(t);
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
