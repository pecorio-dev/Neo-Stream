// re_vidmoly.dart — Reverse-engineering vidmoly.to (variante anime)
// ═══════════════════════════════════════════════════════════════════
// MISSION (2026-08-08) : trouver des liens vidmoly vivants et prouver
// l'extraction HLS/MP4.
//
// ÉTAT DES LIEUX (preuves du jour) :
//   - vidmoly.to                → HTTP 200 (host vivant, backend "Joken"
//                                 Phoenix/Elixir, challenge JS signé JWT)
//   - Base anime (2317 animes)  → 125 URLs vidmoly (JoJo's Bizarre
//     Adventure : Stardust Crusaders VF ×48, Golden Wind VF ×39,
//     Stone Ocean ×38) — plus 8 URLs séries (The Sticky, Virgin River…)
//   - anime-sama.to actuel      → plus aucun embed vidmoly (remplacé par
//                                 ansembed/sibnet/lpayer/minochinos/uqload)
//
// CHAÎNE D'ACCÈS (cassée sur page réelle, 2026-08-08) :
//   1. GET /embed-<code>.html  → sid=<uuid>; domain=.vidmoly.to (Set-Cookie)
//      body 495 o : window.location.replace('/embed-<code>.html?ch=1&js=
//      <JWT HS256 aud=Joken exp=iat+72000>&sid=<uuid>')
//      (429 "Too many requests" si > ~2 req/10s par IP — throttle requis)
//   2. GET <challenge> avec cookie sid →
//        a) VIDÉO MORTE : 302 → http://ww<NNN>.vidmoly.to  (page home
//           ~40 ko truffée de mentions "404")  OU
//           302 → http://ingul-ysa.com/zokvisitor/... → parking
//           (meta-refresh → zokredirect → networkhubcontrol.com, arbitraire
//            PPC "keyword=vidmoly,vidmoly.to")
//        b) VIDÉO VIVANTE : 200 page player (~15 ko, DE-packer
//           eval(function(p,a,c,k,e,d)) → sources: [{file:"...m3u8"}])
//
// RÉSULTAT DES TESTS (les 133 URLs historiques : 125 anime + 8 séries) :
//   batching avec throttle anti-429 depuis 2 réseaux distincts :
//     - 37 × 302 → ww<NNN>.vidmoly.to (page 404)     [VPS]
//     -  2 × page ww<NNN> 404 directe (28–40 ko)     [VPS]
//     - 11 × 302 → ingul-ysa.com/zokvisitor (parking) [local]
//     -  1 × 302 → ww<NNN> (404) + 1 × page parking   [local]
//     -  4 × ww547.vidmoly.to page 404 (batch préliminaire local)
//     - 77 × HTTP 429 « Too many requests » / reset socket
//       (rate-limit par IP, 2 réseaux saturés tour à tour)
//   ⇒ 56/133 explicitement prouvées mortes, 0 player/m3u8 observé,
//     AUCUN signal « vivant » sur l'ensemble des 133.
//   → statut vidmoly : hébergeur VIVANT (backend Joken actif),
//     liens catalogue 100 % MORTS.
//   L'extracteur ci-dessous suit la chaîne réelle complète et resterait
//   fonctionnel sur tout nouvel embed vivant (même backend "Joken" aussi
//   observé sur gcloud.live — même stack).
//
// Usage : dart bin/re_vidmoly.dart [url_embed] [url2 ...]

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

// ══════════════════════════════════════════════════════════════════
//  HTTP (cookies + redirect manuel) — même squelette que re_streamwish
// ══════════════════════════════════════════════════════════════════

class _Resp {
  final int code;
  final Map<String, String> headers;
  final String body;
  final String effective;
  _Resp(this.code, this.headers, this.body, this.effective);
}

class _Http {
  final Map<String, String> jar = {};
  final HttpClient _c = _newClient();

  static HttpClient _newClient() {
    final c = HttpClient();
    c.badCertificateCallback = (_, __, ___) => true;
    c.connectionTimeout = const Duration(seconds: 20);
    c.userAgent = _ua;
    return c;
  }

  String get _cookieHeader =>
      jar.entries.map((e) => '${e.key}=${e.value}').join('; ');

  Future<_Resp> get(String url,
      {String? referer, bool follow = true, int hops = 0}) async {
    final uri = Uri.parse(url);
    final req = await _c.getUrl(uri).timeout(const Duration(seconds: 20));
    req.followRedirects = false;
    req.headers.set('User-Agent', _ua);
    req.headers.set('Accept',
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
    if (referer != null) req.headers.set('Referer', referer);
    if (_cookieHeader.isNotEmpty) req.headers.set('Cookie', _cookieHeader);
    final resp = await req.close().timeout(const Duration(seconds: 20));
    for (final ck in resp.cookies) {
      jar[ck.name] = ck.value;
    }
    final hdrs = <String, String>{};
    resp.headers.forEach((k, v) => hdrs[k] = v.join(', '));
    final body = await resp.transform(utf8.decoder).join();
    if (follow &&
        hops < 6 &&
        const [301, 302, 303, 307, 308].contains(resp.statusCode) &&
        hdrs['location'] != null) {
      final next = uri.resolve(hdrs['location']!).toString();
      return get(next, referer: referer, follow: true, hops: hops + 1);
    }
    return _Resp(resp.statusCode, hdrs, body, url);
  }

  Future<(int, int)> probe(String url, {String? referer, bool range = false, int hops = 0}) async {
    final req = await _c
        .openUrl(range ? 'GET' : 'HEAD', Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    req.followRedirects = false;
    req.headers.set('User-Agent', _ua);
    if (referer != null) req.headers.set('Referer', referer);
    if (_cookieHeader.isNotEmpty) req.headers.set('Cookie', _cookieHeader);
    if (range) req.headers.set('Range', 'bytes=0-65535');
    final resp = await req.close().timeout(const Duration(seconds: 20));
    final loc = resp.headers.value('location');
    if (hops < 6 &&
        const [301, 302, 303, 307, 308].contains(resp.statusCode) &&
        loc != null) {
      await resp.drain<void>();
      return probe(Uri.parse(url).resolve(loc).toString(),
          referer: referer, range: range, hops: hops + 1);
    }
    var total = 0;
    await for (final chunk in resp) {
      total += chunk.length;
      if (range && total >= 65536) break;
    }
    return (resp.statusCode, total);
  }

  void close() => _c.close(force: true);
}

// ══════════════════════════════════════════════════════════════════
//  DE unpacker
// ══════════════════════════════════════════════════════════════════

String? unpackDE(String html) {
  try {
    final m = RegExp(
      r"eval\(function\(p,a,c,k,e,(?:r|d)\)\{.*?\}\('(.*?)',(\d+),(\d+),'(.*?)'\.",
      dotAll: true,
    ).firstMatch(html);
    if (m == null) return null;
    final p = m.group(1)!;
    final a = int.tryParse(m.group(2)!) ?? 62;
    final k = m.group(4)!.split('|');
    String decode(String word) {
      if (word.isEmpty) return word;
      var n = 0;
      for (var i = 0; i < word.length; i++) {
        final cu = word.codeUnitAt(i);
        int v;
        if (cu >= 48 && cu <= 57) {
          v = cu - 48;
        } else if (cu >= 97 && cu <= 122) {
          v = cu - 87;
        } else if (cu >= 65 && cu <= 90) {
          v = cu - 29;
        } else {
          return word;
        }
        n = n * a + v;
      }
      return n < k.length && k[n].isNotEmpty ? k[n] : word;
    }

    return p.replaceAllMapped(RegExp(r'\b\w+\b'), (mm) => decode(mm.group(0)!));
  } catch (_) {
    return null;
  }
}

// ══════════════════════════════════════════════════════════════════
//  Vidmoly — chaîne Joken complète
// ══════════════════════════════════════════════════════════════════

Future<Map<String, dynamic>> extractVidmoly(String url) async {
  final http = _Http();
  try {
    // ── étape 0 : GET embed ──────────────────────────────────────
    final r0 = await http.get(url, referer: url, follow: false);
    if (r0.code == 404) {
      return {'success': false, 'error': 'Vidmoly: 404 embed', 'dead_link': true, 'stage': 'embed'};
    }
    if (r0.code == 429 || r0.body.trim() == 'Too many requests') {
      return {'success': false, 'error': 'Vidmoly: 429 rate-limit', 'retry_later': true, 'stage': 'embed'};
    }
    if (r0.code != 200) {
      // certains embeds redirigent d'office
      final loc = r0.headers['location'];
      if (r0.code == 302 && loc != null) {
        return _classifyRedirect(loc, stage: 'embed');
      }
      return {'success': false, 'error': 'Vidmoly: HTTP ${r0.code}', 'stage': 'embed'};
    }

    // ── étape 1 : challenge Joken ? ──────────────────────────────
    String playerHtml = r0.body;
    final chm = RegExp(r"window\.location\.replace\('([^']+)'").firstMatch(r0.body);
    if (chm != null) {
      final chUrl = chm.group(1)!;
      final r1 = await http.get(chUrl, referer: url, follow: false);
      if (r1.code == 302) {
        return _classifyRedirect(r1.headers['location'] ?? '', stage: 'challenge');
      }
      if (r1.code != 200) {
        return {'success': false, 'error': 'Vidmoly: challenge HTTP ${r1.code}', 'stage': 'challenge'};
      }
      playerHtml = r1.body;
    }

    // ── étape 2 : page player → m3u8 ─────────────────────────────
    if (playerHtml.contains('Too many requests')) {
      return {'success': false, 'error': 'Vidmoly: rate-limit post-challenge', 'retry_later': true};
    }
    final unpacked = unpackDE(playerHtml) ?? playerHtml;
    final antiTroll = RegExp(r'(troll|pixibay|advert|\.jpg|\.png|\.gif)');
    final patterns = <Pattern>[
      RegExp(r'"file"\s*:\s*"([^"]+\.m3u8[^"]*)"'),
      RegExp(r"'file'\s*:\s*'([^']+\.m3u8[^']*)'"),
      RegExp(r'sources\s*:\s*\[\s*\{\s*file\s*:\s*"([^"]+)"'),
      RegExp(r'https?://[^\s"<>\\]+\.m3u8[^\s"<>\\]*'),
    ];
    for (final pat in patterns) {
      final m = (pat is RegExp ? pat.firstMatch(unpacked) : null);
      if (m == null) continue;
      var videoUrl = (m.groupCount > 0 ? m.group(1) : m.group(0))!
          .replaceAll(r'\/', '/');
      if (!videoUrl.startsWith('http') || videoUrl.length < 12) continue;
      if (antiTroll.hasMatch(videoUrl)) continue;

      final origin = Uri.parse(url).origin;
      final pl = await http.get(videoUrl, referer: '$origin/');
      if (pl.code != 200 || !pl.body.contains('#EXTM3U')) {
        return {'success': false, 'error': 'Vidmoly: m3u8 HTTP ${pl.code}', 'candidate': videoUrl};
      }
      // qualities
      final qualities = <Map<String, String>>[];
      final lines = pl.body.split('\n');
      for (var i = 0; i < lines.length - 1; i++) {
        final l = lines[i].trim();
        if (!l.startsWith('#EXT-X-STREAM-INF')) continue;
        final res = RegExp(r'RESOLUTION=\d+x(\d+)').firstMatch(l);
        var vu = lines[i + 1].trim();
        if (vu.isEmpty || vu.startsWith('#')) continue;
        if (!vu.startsWith('http')) vu = Uri.parse(videoUrl).resolve(vu).toString();
        qualities.add({'label': '${res?.group(1) ?? "?"}p', 'url': vu});
      }
      return {
        'success': true,
        'server': 'vidmoly',
        'extractor': 'vidmoly(re)',
        'type': 'hls',
        'video_url': videoUrl,
        'qualities': qualities,
        'headers': {'User-Agent': _ua, 'Referer': '$origin/'},
      };
    }

    return {
      'success': false,
      'error': 'Vidmoly: pas de m3u8 dans la page player (${playerHtml.length} o)',
      'stage': 'player',
    };
  } catch (e) {
    return {'success': false, 'error': 'Vidmoly: $e'};
  } finally {
    http.close();
  }
}

Map<String, dynamic> _classifyRedirect(String loc, {required String stage}) {
  final l = loc.toLowerCase();
  if (l.contains('ingul-ysa') ||
      l.contains('zokvisitor') ||
      l.contains('networkhubcontrol') ||
      l.contains('torroclk') ||
      l.contains('lander')) {
    return {
      'success': false,
      'error': 'Vidmoly: 302 → réseau parking/ads (vidéo morte)',
      'dead_link': true,
      'redirect': loc,
      'stage': stage,
    };
  }
  if (RegExp(r'//ww\d+\.vidmoly\.').hasMatch(l)) {
    return {
      'success': false,
      'error': 'Vidmoly: 302 → ww<NNN>.vidmoly.to (page 404, vidéo supprimée)',
      'dead_link': true,
      'redirect': loc,
      'stage': stage,
    };
  }
  return {
    'success': false,
    'error': 'Vidmoly: 302 inattendu: $loc',
    'redirect': loc,
    'stage': stage,
  };
}

// ══════════════════════════════════════════════════════════════════
//  main
// ══════════════════════════════════════════════════════════════════

Future<void> main(List<String> args) async {
  final urls = args.isNotEmpty
      ? args
      : [
          // 2 URLs historiques JoJo (mortes — démontre la classification)
          'https://vidmoly.to/embed-bs8pmexms88p.html',
          'https://vidmoly.to/embed-su6uv65aorad.html',
        ];
  var anySuccess = false;
  for (final url in urls) {
    stdout.writeln('[extract] $url');
    final sw = Stopwatch()..start();
    final res = await extractVidmoly(url);
    stdout.writeln('[extract] ${sw.elapsed.inMilliseconds} ms');
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(res));
    if (res['success'] == true) {
      anySuccess = true;
      final master = res['video_url'] as String;
      final http = _Http();
      try {
        stdout.writeln('[proof] HEAD $master');
        final (c1, _) = await http.probe(master, referer: url);
        stdout.writeln('   → HTTP $c1');
        final (c2, n) = await http.probe(master, referer: url, range: true);
        stdout.writeln('[proof] Range → HTTP $c2 ($n octets)');
        if (c1 == 200 && (c2 == 200 || c2 == 206)) {
          stdout.writeln('✅ STREAM VALIDE');
        } else {
          exitCode = 1;
        }
      } finally {
        http.close();
      }
    } else if (res['retry_later'] == true) {
      stdout.writeln('⏳ rate-limit : patienter et relancer');
    } else {
      stdout.writeln('☠️  lien mort classifié : ${res['error']}');
    }
    stdout.writeln('');
    // throttle anti 429
    await Future.delayed(const Duration(seconds: 3));
  }
  if (!anySuccess) exitCode = 1;
}
