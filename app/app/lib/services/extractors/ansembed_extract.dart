// re_ansembed.dart — Reverse-engineering ansembed.net (clone/miroir VidMoly :
// page « VidMoly - Fast And Secure Video Storage Center », CDN staticmoly.me,
// même pipeline player que vidmoly.me) — hébergeur anime très utilisé
// (PEMB, Psycho-Pass…).
//
// Algorithme cassé le 2026-08-08 depuis :
//   - https://ansembed.net/embed-rrjf3gowhe7m.html (PEMB S1 EP1)
//
// STRUCTURE de la page embed : PAS de packer, PAS de défi, PAS d'iframe en
// cascade. JWPlayer 8.36.4 (ssl.p.jwpcdn.com) configuré en clair dans le
// HTML :
//
//     var playerInstance = player.setup({
//       sources: [{ file: 'https://prx-XXXX-ant.vmget.online/hls2/…/master.m3u8
//                          ?t=<sign>&s=<ts>&e=43200&v=&srv=…&i=0.4&sp=0&asn=…'}],
//       image: "https://bck-…-u.getromes.space/i/…/{id}.jpg",
//       …
//     });
//
// → extraction = 1 GET de la page + 1 regex. Le flux est un master.m3u8
//   multi-variantes (720p / 1080p, segments .ts) signé 12 h (e=43200).
//   Le param asn= n'est PAS vérifié strictement côté CDN (testé depuis
//   une autre IP/ASN : 200 OK), Referer ansembed.net accepté (et même
//   l'abstention de Referer fonctionne — on l'envoie quand même).
//
// Variantes d'URL trouvées :
//   https://ansembed.net/embed-{id}.html
//   (mirroir probable : n'importe quel host vidmoly-like avec le même setup)
//
// Pur Dart (dart:io uniquement).
//
// Usage : dart bin/re_ansembed.dart [url_embed …]
// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures, unused_local_variable, unused_element, unused_import

import 'dart:convert';
import 'dart:io';
import 'dart:async';

// ══════════════════════════════════════════════════════════════════
//  0. HTTP TLS-tolérant
// ══════════════════════════════════════════════════════════════════

const _ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

HttpClient _client() {
  final c = HttpClient();
  c.badCertificateCallback = (_, __, ___) => true;
  c.connectionTimeout = const Duration(seconds: 15);
  c.userAgent = _ua;
  return c;
}

Future<(int, String)> _httpGet(String url, {Map<String, String>? headers}) async {
  final c = _client();
  try {
    final req = await c
        .openUrl('GET', Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    req.headers.set('User-Agent', _ua);
    headers?.forEach((k, v) => req.headers.set(k, v));
    final resp = await req.close().timeout(const Duration(seconds: 20));
    final txt = await resp.transform(utf8.decoder).join();
    return (resp.statusCode, txt);
  } finally {
    c.close(force: true);
  }
}

// ══════════════════════════════════════════════════════════════════
//  1. Extracteur ansembed.net
// ══════════════════════════════════════════════════════════════════

/// extractAnsembedFinal(url) — extracteur autonome ansembed.net.
///
/// Retourne un Map :
///   {success, video_url, server:'ansembed', type:'hls', is_hls:true, title,
///    headers:{User-Agent, Referer}} ou {error}.
Future<Map<String, dynamic>> extractAnsembedFinal(String url) async {
  final uri = Uri.parse(url);
  final m = RegExp(r'^/embed-([A-Za-z0-9]+)\.html$').firstMatch(uri.path);
  if (m == null) return {'error': 'ansembed: URL embed invalide: $url'};
  final base = '${uri.scheme}://${uri.host}';
  final referer = '$base/';

  try {
    final (status, html) = await _httpGet(url, headers: {'Referer': referer});
    if (status != 200) {
      return {'error': 'ansembed page HTTP $status'};
    }
    // sources: [{ file: '…' }] dans le setup JWPlayer (en clair)
    final src = RegExp(r"""sources:\s*\[\s*\{\s*file:\s*'([^']+)'""")
        .firstMatch(html);
    if (src == null) {
      return {'error': 'ansembed: sources JWPlayer introuvables '
          '(structure changée ?)'};
    }
    final videoUrl = src.group(1)!;
    final title = RegExp(r'<title>([^<]*)</title>')
        .firstMatch(html)
        ?.group(1)
        ?.trim();

    return {
      'success': true,
      'video_url': videoUrl,
      'server': 'ansembed',
      'type': 'hls',
      'is_hls': true,
      'title': title,
      'headers': {
        'User-Agent': _ua,
        'Referer': referer,
      },
    };
  } catch (e, st) {
    return {'error': 'ansembed: $e', 'stack': '$st'};
  }
}

// ══════════════════════════════════════════════════════════════════
//  main : extraction réelle + preuve HEAD/Range + authenticité
// ══════════════════════════════════════════════════════════════════

Future<(int, int)> _probe(String url, {bool range = false}) async {
  final c = _client();
  try {
    final req = await c
        .openUrl(range ? 'GET' : 'HEAD', Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    req.headers.set('User-Agent', _ua);
    req.headers.set('Referer', 'https://ansembed.net/');
    if (range) req.headers.set('Range', 'bytes=0-65535');
    final resp = await req.close().timeout(const Duration(seconds: 20));
    var total = 0;
    await for (final chunk in resp) {
      total += chunk.length;
      if (range && total >= 65536) break;
    }
    stdout.writeln(
        '   → HTTP ${resp.statusCode} (${resp.headers.contentType}) $total octets lus');
    return (resp.statusCode, total);
  } finally {
    c.close(force: true);
  }
}

/// Vérifie que le master n'est pas un leurre : durée cumulée EXTINF d'une
/// sous-playlist > 5 min et absence de marqueurs troll/BigBuckBunny.
Future<String?> _authenticate(String masterUrl) async {
  if (masterUrl.contains('/troll/')) return 'URL contient /troll/';
  final (code, body) =
      await _httpGet(masterUrl, headers: {'Referer': 'https://ansembed.net/'});
  if (code != 200) return 'master HTTP $code';
  if (!body.contains('#EXTM3U')) return 'pas un M3U8';
  if (body.toLowerCase().contains('bigbuckbunny') ||
      body.toLowerCase().contains('bbb_')) {
    return 'contenu Big Buck Bunny détecté';
  }
  final sub = body
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty && !l.startsWith('#'), orElse: () => '');
  if (sub.isEmpty) return 'master sans sous-playlist';
  final subUrl =
      sub.startsWith('http') ? sub : Uri.parse(masterUrl).resolve(sub).toString();
  final (sCode, sBody) =
      await _httpGet(subUrl, headers: {'Referer': 'https://ansembed.net/'});
  if (sCode != 200) return 'sous-playlist HTTP $sCode';
  var dur = 0.0;
  for (final m in RegExp(r'#EXTINF:([\d.]+)').allMatches(sBody)) {
    dur += double.tryParse(m.group(1)!) ?? 0;
  }
  final segs = sBody
      .split('\n')
      .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
      .length;
  stdout.writeln(
      '   → sous-playlist : $segs segments, durée cumulée ${dur.toStringAsFixed(1)} s');
  if (dur < 300) return 'durée suspecte (${dur}s < 300s) — probable leurre';
  return null;
}

Future<void> main(List<String> args) async {
  final urls = args.isNotEmpty
      ? args
      : [
          'https://ansembed.net/embed-rrjf3gowhe7m.html', // PEMB S1 EP1
          'https://ansembed.net/embed-eym7sun4sbkt.html', // PEMB S1 EP2
        ];

  var failures = 0;
  for (final url in urls) {
    stdout.writeln('\n[extract] $url');
    final sw = Stopwatch()..start();
    final res = await extractAnsembedFinal(url);
    stdout.writeln('[extract] terminé en ${sw.elapsed.inMilliseconds} ms');
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(res));

    if (res['success'] != true) {
      failures++;
      continue;
    }
    final v = res['video_url'] as String;
    final fraud = await _authenticate(v);
    if (fraud != null) {
      stdout.writeln('\n❌ LEURRE DÉTECTÉ : $fraud — URL rejetée');
      failures++;
      continue;
    }
    stdout.writeln('\n[proof] HEAD $v');
    final (headCode, _) = await _probe(v);
    stdout.writeln('[proof] GET Range bytes=0-65535 (segment)');
    final (_, masterBody) =
        await _httpGet(v, headers: {'Referer': 'https://ansembed.net/'});
    final sub = masterBody
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty && !l.startsWith('#'), orElse: () => '');
    final subUrl =
        sub.startsWith('http') ? sub : Uri.parse(v).resolve(sub).toString();
    final (_, subBody) =
        await _httpGet(subUrl, headers: {'Referer': 'https://ansembed.net/'});
    final seg = subBody
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty && !l.startsWith('#'), orElse: () => '');
    final segUrl = seg.startsWith('http')
        ? seg
        : Uri.parse(subUrl).resolve(seg).toString();
    final (rangeCode, _) = await _probe(segUrl, range: true);
    if (headCode == 200 && (rangeCode == 200 || rangeCode == 206)) {
      stdout.writeln('\n✅ STREAM VALIDE : HEAD=$headCode Range=$rangeCode');
    } else {
      stdout.writeln('\n⚠️  codes inattendus HEAD=$headCode Range=$rangeCode');
      failures++;
    }
  }
  if (failures > 0) exitCode = 1;
}
