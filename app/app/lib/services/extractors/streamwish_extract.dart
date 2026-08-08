// re_streamwish.dart — Reverse-engineering famille StreamWish / VidHide
// ═══════════════════════════════════════════════════════════════════
// MISSION (2026-08-08) : retrouver des liens vivants streamwish dans les
// catalogues anime (anime-sama.to + API neo-stream) et prouver l'extraction.
//
// ÉTAT DES LIEUX (preuves collectées ce jour) :
//   - streamwish.to          → HTTP 522 (origine HS, seul CF répond)
//   - ajo.st / recentwishsse → NX/timeout (morts)
//   - streamwish.com         → HTTP 200, <title>StreamHG</title> (rebrand)
//   - filelions.com|to|online, vidhide.* , dlions.com → morts ou parkés
//     (dlions.com → JS redirect "/lander" = parking)
//   - embedwish.com          → vivant, mais les 8 embeds du catalogue
//     (movies neo-stream) répondent "File is no longer available..."
//   - wishfast.top           → 302 parking urldance.com
//   - Base anime complète (2317 animes, ~192 000 sources) : 0 URL
//     streamwish/filelions/vidhide/ajo.st.
//
// MAIS : la famille StreamWish/VidHide (même réseau, cf. abouttext
// "VidHide" du player) est VIVANTE sous ses domaines rotatifs actuels :
//   - movearnpre.com (3 667 embeds anime) → 301 → callistanise.com
//   - Smoothpre.com   (4 525 embeds anime) → 200 direct, même player
//   - callistanise.com/embed/<code>      → player JWPlayer packé
//
// ALGORITHME (cassé sur page réelle, 2026-08-08) :
//   1. GET /e/<code> ou /embed/<code> (UA navigateur)
//      - "File is no longer available as it expired or has been deleted"
//        → vidéo morte (DELETED)
//      - sinon HTML contenant eval(function(p,a,c,k,e,d){...}) (DE packer)
//   2. Unpack DE packer → var links={"hls4": "<relative>", "hls2":
//      "<https signé expire=129600s>", "hls3": "<https master.txt>"}
//   3. Priorité frontend : hls4 || hls3 || hls2
//      hls4 = /stream/<rand>/<rand>/<exp>/<file_id>/master.m3u8 (même host)
//      hls2 = https://<rand>.acek-cdn.com/hls2/.../master.m3u8?t&s&e&f...
//      hls3 = https://<rand>.<domaine variable>.sbs|cyou/.../master.txt
//   4. master.m3u8 → #EXT-X-STREAM-INF variants → qualities (1080/720/480)
//
// PREUVE (callistanise.com/embed/ff8ou5mdf7bi, Ferrier/Kodocha ep64) :
//   hls4 → HTTP 200 application/vnd.apple.mpegurl (470 o, 3 variants)
//          variant index-f1-v1-a1.m3u8 HTTP 200 (142 segments)
//          segment Range bytes=0-65535 → HTTP 206
//   hls2 → HTTP 200 (1824 o, 3 variants), segment Range → HTTP 206 video/MP2T
//
// Usage : dart bin/re_streamwish.dart [url_embed]
//   (les domaines callistanise/acek-cdn peuvent être DNS-filtrés en local ;
//    compiler : dart compile exe → exécuter sur hôte au DNS propre)
// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures, unused_local_variable, unused_element, unused_import

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

// ══════════════════════════════════════════════════════════════════
//  HTTP minimaliste (redirect manuel + cookie jar + TLS tolérant)
// ══════════════════════════════════════════════════════════════════

class _Resp {
  final int code;
  final Map<String, String> headers;
  final String body;
  final String effective; // URL finale après redirections suivies
  _Resp(this.code, this.headers, this.body, this.effective);
}

class _Http {
  final Map<String, String> jar = {}; // host-scope simplifié : clé = nom
  final HttpClient _c = _newClient();

  static HttpClient _newClient() {
    final c = HttpClient();
    c.badCertificateCallback = (cert, host, port) => true;
    c.connectionTimeout = const Duration(seconds: 20);
    c.userAgent = _ua;
    return c;
  }

  void _eatCookies(String host, HttpClientResponse resp) {
    for (final ck in resp.cookies) {
      jar[ck.name] = ck.value;
    }
  }

  String get _cookieHeader =>
      jar.entries.map((e) => '${e.key}=${e.value}').join('; ');

  Future<_Resp> get(String url,
      {String? referer, bool follow = true, int hops = 0}) async {
    final uri = Uri.parse(url);
    final req = await _c
        .getUrl(uri)
        .timeout(const Duration(seconds: 20));
    req.followRedirects = false;
    req.headers.set('User-Agent', _ua);
    req.headers.set('Accept',
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
    req.headers.set('Accept-Language', 'fr-FR,fr;q=0.9,en-US;q=0.8');
    if (referer != null) req.headers.set('Referer', referer);
    if (_cookieHeader.isNotEmpty) req.headers.set('Cookie', _cookieHeader);
    final resp =
        await req.close().timeout(const Duration(seconds: 20));
    _eatCookies(uri.host, resp);
    final code = resp.statusCode;
    final hdrs = <String, String>{};
    resp.headers.forEach((k, v) => hdrs[k] = v.join(', '));
    final body = await resp.transform(utf8.decoder).join();
    if (follow &&
        hops < 6 &&
        const [301, 302, 303, 307, 308].contains(code) &&
        hdrs['location'] != null) {
      final next = uri.resolve(hdrs['location']!).toString();
      return get(next, referer: referer, follow: true, hops: hops + 1);
    }
    return _Resp(code, hdrs, body, url);
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
      // Range non reporté sur un redirect de master (certains CDN 301→variant)
      final next = Uri.parse(url).resolve(loc).toString();
      return probe(next, referer: referer, range: range, hops: hops + 1);
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
//  Dean Edwards unpacker (p,a,c,k,e,d) — style anime_extractor.dart
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
//  Extracteur famille StreamWish/VidHide
// ══════════════════════════════════════════════════════════════════

Future<Map<String, dynamic>> extractStreamwishFamily(String url) async {
  final http = _Http();
  try {
    // 1. page embed (suit les 301 : movearnpre → callistanise, etc.)
    final origin = Uri.parse(url).origin;
    final r = await http.get(url, referer: '$origin/');
    final html = r.body;

    if (r.code == 404 ||
        html.contains('no longer available') ||
        html.contains('has been deleted') ||
        html.contains('was deleted')) {
      return {
        'success': false,
        'error': 'StreamWish: vidéo expirée/supprimée (file not available)',
        'http': r.code,
        'final_url': url,
        'dead_link': true,
      };
    }
    if (r.code != 200) {
      return {
        'success': false,
        'error': 'StreamWish: HTTP ${r.code}',
        'http': r.code,
      };
    }

    // 2. unpack (page toujours packée sur cette famille)
    final unpacked = unpackDE(html) ??
        (html.contains('var links') || html.contains('"file"')
            ? html
            : null);
    if (unpacked == null) {
      return {
        'success': false,
        'error': 'StreamWish: ni packer DE ni config lisible',
        'head': html.substring(0, html.length < 300 ? html.length : 300),
      };
    }

    // 3. extraire links.hls4 / hls3 / hls2 (fallback générique "file")
    String? pick(String key) {
      final m = RegExp('"$key"\\s*:\\s*"([^"]+)"').firstMatch(unpacked);
      return m?.group(1);
    }

    final cand = <String>[
      if (pick('hls4') != null) pick('hls4')!,
      if (pick('hls3') != null) pick('hls3')!,
      if (pick('hls2') != null) pick('hls2')!,
      // génériques
      ...RegExp(r'"file"\s*:\s*"([^"]+\.m3u8[^"]*)"')
          .allMatches(unpacked)
          .map((m) => m.group(1)!),
    ];

    // anti-troll : écarte chemins /troll/, pubs, thumbnails
    bool bad(String u) =>
        u.contains('/troll/') ||
        u.contains('pixibay') ||
        u.contains('_xt.jpg') ||
        u.contains('get_slides') ||
        u.contains('mosevura') ||
        !u.contains('m3u8') && !u.contains('master.txt');

    final urls = cand
        .map((u) => u.startsWith('/')
            ? Uri.parse(r.effective).resolve(u).toString()
            : u)
        .where((u) => u.startsWith('http') && !bad(u))
        .toSet()
        .toList();
    if (urls.isEmpty) {
      return {
        'success': false,
        'error': 'StreamWish: aucun lien hls2/3/4 exploitable',
      };
    }

    // 4. valider chaque master + parser variants
    List<Map<String, String>> qualitiesOf(String master, String body) {
      final q = <Map<String, String>>[];
      final lines = body.split('\n');
      for (var i = 0; i < lines.length - 1; i++) {
        final l = lines[i].trim();
        if (!l.startsWith('#EXT-X-STREAM-INF')) continue;
        final res = RegExp(r'RESOLUTION=\d+x(\d+)').firstMatch(l);
        var vu = lines[i + 1].trim();
        if (vu.isEmpty || vu.startsWith('#')) continue;
        if (!vu.startsWith('http')) vu = Uri.parse(master).resolve(vu).toString();
        q.add({'label': '${res?.group(1) ?? "?"}p', 'url': vu});
      }
      q.sort((a, b) =>
          (int.tryParse(b['label']!.replaceAll('p', '')) ?? 0)
              .compareTo(int.tryParse(a['label']!.replaceAll('p', '')) ?? 0));
      return q;
    }

    for (final master in urls) {
      try {
        final pl = await http.get(master, referer: url);
        if (pl.code != 200 || !pl.body.contains('#EXTM3U')) continue;
        final qualities = qualitiesOf(master, pl.body);
        return {
          'success': true,
          'server': 'streamwish',
          'extractor': 'streamwish(re)',
          'type': 'hls',
          'video_url': master,
          'chosen': master.contains('master.txt')
              ? 'hls3'
              : (master.contains('/stream/') ? 'hls4' : 'hls2'),
          'qualities': qualities,
          'headers': {'User-Agent': _ua, 'Referer': '$origin/'},
        };
      } catch (_) {
        continue;
      }
    }

    return {
      'success': false,
      'error': 'StreamWish: masters injoignables',
      'candidates': urls,
    };
  } catch (e) {
    return {'success': false, 'error': 'StreamWish: $e'};
  } finally {
    http.close();
  }
}

// ══════════════════════════════════════════════════════════════════
//  main : extraction + preuve HEAD/Range sur master, variant, segment
// ══════════════════════════════════════════════════════════════════

Future<void> main(List<String> args) async {
  final url = args.isNotEmpty
      ? args[0]
      : 'https://movearnpre.com/embed/ff8ou5mdf7bi'; // Kodocha S1 ep64 (vivant)

  stdout.writeln('[extract] $url');
  final sw = Stopwatch()..start();
  final res = await extractStreamwishFamily(url);
  stdout.writeln('[extract] ${sw.elapsed.inMilliseconds} ms');
  stdout
      .writeln(const JsonEncoder.withIndent('  ').convert(res));

  if (res['success'] != true) {
    exitCode = 1;
    return;
  }

  final master = res['video_url'] as String;
  final http = _Http();
  try {
    stdout.writeln('\n[proof] HEAD master');
    var (c1, _) = await http.probe(master, referer: url);
    stdout.writeln('   → HTTP $c1');
    stdout.writeln('[proof] GET Range master');
    var (c2, n2) = await http.probe(master, referer: url, range: true);
    stdout.writeln('   → HTTP $c2 ($n2 octets)');

    final qualities = (res['qualities'] as List?) ?? [];
    var okSeg = 0, codeSeg = 0;
    if (qualities.isNotEmpty) {
      final vurl = qualities.first['url']!;
      stdout.writeln('[proof] GET variant $vurl');
      final vr = await http.get(vurl, referer: url);
      final segs = vr.body
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();
      stdout.writeln('   → HTTP ${vr.code}, ${segs.length} segments');
      if (segs.isNotEmpty) {
        var s = segs.first;
        if (!s.startsWith('http')) s = Uri.parse(vurl).resolve(s).toString();
        stdout.writeln('[proof] GET Range segment');
        final (c3, n3) = await http.probe(s, referer: url, range: true);
        codeSeg = c3;
        okSeg = n3;
        stdout.writeln('   → HTTP $c3 ($n3 octets)');
      }
    }
    if ((c1 == 200 || c2 == 200) && (codeSeg == 200 || codeSeg == 206) && okSeg > 0) {
      stdout.writeln('\n✅ STREAM VALIDE : master=$c1 segment=$codeSeg');
    } else {
      stdout.writeln('\n⚠️  codes inattendus master=$c1/$c2 segment=$codeSeg');
      exitCode = 1;
    }
  } finally {
    http.close();
  }
}
