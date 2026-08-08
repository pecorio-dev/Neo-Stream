// ─────────────────────────────────────────────────────────────────────────────
// re_dood.dart — Extracteur DoodStream 2026 (playmogo / do7go / dsvplay …)
//
// Chaîne prouvée (08/2026, mesurée de bout en bout) :
//   1. Tous les domaines historiques (do7go.com, dsvplay.com, dood.li, d0o0d,
//      do0od, ds2play, myvidplay, d0000d, dood.wf…) → 301 vers playmogo.com.
//      vvide0.com / vide0.net / vidply.com sont des façades Cloudflare du même
//      backend (même id vidéo, même structure de page).
//   2. GET /e/{id} → page player (IP résidentielle : HTTP 200 direct, empreinte
//      TLS Dart acceptée sans challenge ; IP datacenter → page Turnstile,
//      non contournable par HTTP pur — signalé needs_browser).
//   3. La page contient `$.get('/pass_md5/{sel}/{token}')` et `token={token}`.
//   4. GET /pass_md5/{sel}/{token}  (Referer: page embed, X-Requested-With:
//      XMLHttpRequest) → 200, corps = préfixe CDN (…cloudatacdn.com/…/{f}~).
//   5. URL vidéo = préfixe + rand10 + '?token={token}&expiry={epoch_ms}'.
//   6. GET vidéo (Referer: {base}/) → HTTP 200/206, Content-Type video/mp4.
//   (Turnstile présent dans la page = télémétrie /dood?op=play au 1er play,
//    NON requis pour obtenir l'URL vod.)
//
// DNS : les FAI/filtres empoisonnent playmogo.com et *cloudatacdn.com
// (réponse ::1 / 127.x) → résolution DoH (dns.google → cloudflare-dns.com →
// système en repli), connexion TLS directe sur IP avec SNI = host.
//
// Usage : dart run bin/re_dood.dart
//   Modifier les URLs de test dans main().
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const String kUa =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36';

// ── Mini client HTTPS : DoH + TLS direct (SNI=host) + cookies + redirects ────

class _Resp {
  final int status;
  final Map<String, List<String>> headers;
  final String body;
  final String url; // URL effective après redirections
  _Resp(this.status, this.headers, this.body, this.url);
  String? header(String n) => headers[n.toLowerCase()]?.first;
}

class _DoodHttp {
  final Map<String, String> _cookies = {};
  final Map<String, String> _dnsCache = {};

  static String _randomIp(List<String> ips) => ips[Random().nextInt(ips.length)];

  Future<List<String>> _doh(String host, String endpoint) async {
    final ips = <String>[];

    if (InternetAddress.tryParse(host) != null) return [host];
    final uri = Uri.parse('$endpoint?name=$host&type=A');

    SecureSocket? sock;
    try {
      final dohHost = uri.host;
      var dohIps = <String>[];
      try {
        dohIps = (await InternetAddress.lookup(dohHost)
                .timeout(const Duration(seconds: 5)))
            .where((a) => a.type == InternetAddressType.IPv4)
            .map((a) => a.address)
            .toList();
      } catch (_) {}
      for (final dip in dohIps) {
        try {
          final raw = await Socket.connect(dip, 443,
              timeout: const Duration(seconds: 6));
          sock = await SecureSocket.secure(raw, host: dohHost);
          break;
        } catch (_) {}
      }
      if (sock == null) return ips;
      sock.write('GET ${uri.path}?${uri.query} HTTP/1.1\r\n'
          'Host: $dohHost\r\n'
          'Accept: application/dns-json\r\n'
          'Connection: close\r\n\r\n');
      final data = await _readAll(sock);
      final resp = _parseWithChunked(data);
      if (resp.status == 200) {
        final js = jsonDecode(resp.body);
        final answers = js['Answer'];
        if (answers is List) {
          for (final a in answers) {
            if (a is Map && a['type'] == 1 && a['data'] is String) {
              final ip = a['data'] as String;
              if (!_poison(ip)) ips.add(ip);
            }
          }
        }
      }
    } catch (_) {
    } finally {
      try { await sock?.close(); } catch (_) {}
    }
    return ips;
  }

  bool _poison(String ip) =>
      ip.startsWith('127.') || ip == '0.0.0.0' || ip == '::1';

  Future<String> _resolve(String host) async {
    final c = _dnsCache[host];
    if (c != null) return c;
    var ips = await _doh(host, 'https://dns.google/resolve');
    if (ips.isEmpty) {
      ips = await _doh(host, 'https://cloudflare-dns.com/dns-query');
    }
    if (ips.isEmpty) {
      try {
        ips = (await InternetAddress.lookup(host)
                .timeout(const Duration(seconds: 5)))
            .where((a) => a.type == InternetAddressType.IPv4)
            .map((a) => a.address)
            .where((ip) => !_poison(ip))
            .toList();
      } catch (_) {}
    }
    if (ips.isEmpty) {
      throw const SocketException('DNS: aucune IP saine');
    }
    final ip = _randomIp(ips);
    _dnsCache[host] = ip;
    return ip;
  }

  static Future<List<int>> _readAll(SecureSocket sock) async {
    final chunks = <int>[];
    await for (final c in sock.timeout(const Duration(seconds: 20))) {
      chunks.addAll(c);
    }
    return chunks;
  }

  _Resp _parseWithChunked(List<int> rawBytes) {
    final raw = String.fromCharCodes(rawBytes);
    final i = raw.indexOf('\r\n\r\n');
    if (i < 0) return _Resp(0, {}, '', '');
    final head = raw.substring(0, i);
    var bodyBytes = rawBytes.sublist(i + 4);
    final lines = head.split('\r\n');
    final status =
        int.tryParse(lines.first.split(' ').elementAt(1)) ?? 0;
    final headers = <String, List<String>>{};
    for (final l in lines.skip(1)) {
      final j = l.indexOf(':');
      if (j > 0) {
        headers.putIfAbsent(l.substring(0, j).trim().toLowerCase(), () => [])
            .add(l.substring(j + 1).trim());
      }
    }
    if ((headers['transfer-encoding']?.join(' ') ?? '').contains('chunked')) {
      bodyBytes = _dechunk(bodyBytes);
    }
    return _Resp(status, headers, utf8.decode(bodyBytes, allowMalformed: true), '');
  }

  static List<int> _dechunk(List<int> data) {
    final out = <int>[];
    var off = 0;
    while (off < data.length) {
      final end = _indexOf(data, const [13, 10], off);
      if (end < 0) break;
      final sizeStr = String.fromCharCodes(data.sublist(off, end)).split(';').first.trim();
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

  static int _indexOf(List<int> hay, List<int> needle, int from) {
    outer:
    for (var i = from; i <= hay.length - needle.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (hay[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  String _cookieFor(String host) {
    final pairs = <String>[];
    _cookies.forEach((domain, cookie) {
      if (host == domain || host.endsWith('.$domain') || domain.endsWith('.$host')) {
        pairs.add(cookie);
      }
    });
    return pairs.join('; ');
  }

  void _storeCookies(String host, _Resp r) {
    for (final sc in r.headers['set-cookie'] ?? const <String>[]) {
      final first = sc.split(';').first;
      if (first.contains('=')) _cookies[host] = first;
    }
  }

  Future<_Resp> _single(String url, Map<String, String> headers) async {
    final uri = Uri.parse(url);
    final host = uri.host;
    final path = uri.path.isEmpty ? '/' : uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    final ip = await _resolve(host);

    final raw = await Socket.connect(ip, 443,
        timeout: const Duration(seconds: 15));
    final sock = await SecureSocket.secure(
      raw,
      host: host,
      onBadCertificate: (_) => true,
      supportedProtocols: const ['http/1.1'],
    );
    final sb = StringBuffer()
      ..write('GET $path HTTP/1.1\r\n')
      ..write('Host: $host\r\n')
      ..write('User-Agent: $kUa\r\n')
      ..write('Accept-Encoding: identity\r\n')
      ..write('Connection: close\r\n');
    final jar = _cookieFor(host);
    if (jar.isNotEmpty && !headers.containsKey('Cookie')) {
      sb.write('Cookie: $jar\r\n');
    }
    headers.forEach((k, v) => sb.write('$k: $v\r\n'));
    sb.write('\r\n');
    sock.write(sb.toString());
    final data = await _readAll(sock);
    await sock.close();
    final resp = _parseWithChunked(data);
    _storeCookies(host, resp);
    return _Resp(resp.status, resp.headers, resp.body, url);
  }

  Future<_Resp> get(String url,
      {Map<String, String>? headers, int maxRedirects = 8}) async {
    var current = url;
    final extra = headers ?? const <String, String>{};
    for (var hop = 0; hop <= maxRedirects; hop++) {
      final r = await _single(current, extra);
      final loc = r.header('location');
      if ([301, 302, 303, 307, 308].contains(r.status) &&
          loc != null &&
          hop < maxRedirects) {
        current = Uri.parse(current).resolve(loc).toString();
        continue;
      }
      return _Resp(r.status, r.headers, r.body, current);
    }
    return _single(current, extra);
  }
}

// ── Extracteur ──────────────────────────────────────────────────────────────

String _rand10() {
  const c = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random.secure();
  return List.generate(10, (_) => c[r.nextInt(c.length)]).join();
}

bool _isCfChallenge(_Resp r) =>
    r.status == 403 && r.body.contains('Just a moment');

/// Point d'entrée demandé par la mission.
/// Retourne: success/video_url/type/headers + preuve HTTP, ou error/needs_browser.
Future<Map<String, dynamic>> extractDoodFinal(String url) async {
  final http = _DoodHttp();

  final idM = RegExp(r'/(?:e|d)/([a-z0-9]{8,16})').firstMatch(url);
  if (idM == null) return {'error': 'Dood: id introuvable'};
  final id = idM.group(1)!;

  // Candidats : URL donnée d'abord (la 301 est suivie), puis miroirs connus
  final candidates = <String>[
    url,
    'https://playmogo.com/e/$id',
    'https://vvide0.com/e/$id',
    'https://vide0.net/e/$id',
  ];

  for (final cand in candidates) {
    try {
      final embed = await http.get(cand, headers: {
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
      });
      if (_isCfChallenge(embed)) continue; // challenge → essai hôte suivant
      final html = embed.body;
      if (html.contains('Video not found')) {
        return {'error': 'Dood: vidéo supprimée/introuvable', 'id': id};
      }
      if (embed.status != 200) continue;

      // 1. Chemin pass_md5
      final passM = RegExp(r"""(/pass_md5/[^\s"'<>]+)""").firstMatch(html);
      if (passM == null) {
        if (html.contains('turnstile') && html.contains('captcha_l')) {
          // Portail Turnstile (IP datacenter) — non contournable sans navigateur
          return {
            'needs_browser': true,
            'error': 'Dood: Turnstile (IP datacenter), navigateur requis',
          };
        }
        continue;
      }
      final passPath = passM.group(1)!;

      // 2. Token (dernier segment du path OU ?token= dans la page)
      final tokM = RegExp(r'[?&]token=([a-z0-9]{10,})').firstMatch(html);
      final token = tokM?.group(1) ?? passPath.split('/').last;
      if (token.isEmpty) continue;

      final base = Uri.parse(embed.url).origin;

      // 3. Ajax pass_md5 → préfixe CDN
      final pr = await http.get('$base$passPath', headers: {
        'Referer': embed.url,
        'X-Requested-With': 'XMLHttpRequest',
        'Accept': '*/*',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-origin',
      });
      final prefix = pr.body.trim();
      if (pr.status != 200 || prefix == 'RELOAD' || !prefix.startsWith('http')) {
        return {'error': 'Dood: pass_md5 a échoué (${pr.status}): ${prefix.substring(0, prefix.length.clamp(0, 80))}'};
      }

      // 4. URL vidéo finale
      final expiry = DateTime.now().millisecondsSinceEpoch;
      final videoUrl = '$prefix${_rand10()}?token=$token&expiry=$expiry';

      // 5. Preuve HTTP (Range 0-1 pour ne pas télécharger)
      final vr = await http.get(videoUrl, headers: {
        'Referer': '$base/',
        'Origin': base,
        'Range': 'bytes=0-1',
        'Accept': '*/*',
      });
      final ctype = vr.header('content-type') ?? '';
      final crange = vr.header('content-range') ?? '';
      final total = crange.contains('/') ? crange.split('/').last : '';

      if (vr.status == 200 || vr.status == 206) {
        return {
          'success': true,
          'video_url': videoUrl,
          'server': 'doodstream',
          'type': 'mp4',
          'is_hls': false,
          'proof': {
            'http_status': vr.status,
            'content_type': ctype,
            'content_range': crange,
            'total_bytes': total,
            'embed_final_url': embed.url,
            'chain': 'embed → /pass_md5/ → prefix+rand10?token&expiry',
          },
          'headers': {
            'Referer': '$base/',
            'Origin': base,
            'User-Agent': kUa,
          },
        };
      }
      return {
        'error': 'Dood: URL composée rejetée (HTTP ${vr.status})',
        'video_url': videoUrl,
      };
    } catch (e) {
      // transport/DNS/TLS → hôte suivant
      continue;
    }
  }
  return {'error': 'Dood: tous les hôtes ont échoué', 'needs_browser': true};
}

// ── Démo / preuve ───────────────────────────────────────────────────────────

Future<void> main() async {
  print('=== PROOF DoodStream chain — ${DateTime.now().toUtc()} ===');
  const dead = 'https://do7go.com/e/oxxm1pnpdk5b';
  const liveId = 'ne4eo30dq3is';
  final tests = <String>[
    dead, // lien réel de la mission (supprimé côté doodstream)
    'https://do7go.com/e/$liveId', // même vidéo via façade 301
    'https://dsvplay.com/e/$liveId',
    'https://dood.li/d/$liveId', // variante /d/
    'https://playmogo.com/e/$liveId', // canonique
    'https://vvide0.com/e/$liveId', // façade CF indépendante
  ];
  for (final t in tests) {
    print('\n→ $t');
    final sw = Stopwatch()..start();
    final r = await extractDoodFinal(t);
    sw.stop();
    if (r['success'] == true) {
      final p = r['proof'] as Map;
      print('  ✔ SUCCESS en ${sw.elapsedMilliseconds} ms');
      print('  video_url : ${r['video_url']}');
      print('  HTTP      : ${p['http_status']} ${p['content_type']} '
          'total=${p['total_bytes']} o');
      print('  embed     : ${p['embed_final_url']}');
    } else {
      print('  ✘ ${r['error']}  (needs_browser=${r['needs_browser'] == true})');
    }
  }
}
