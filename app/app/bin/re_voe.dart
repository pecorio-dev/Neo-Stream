// re_voe.dart — Reverse-engineering VOE (voe.sx + aliases tournants)
//
// Algorithme exact cassé le 2026-08-08 depuis https://stevenfamilyedge.com
// (décodeur propriétaire : /js/loader.a40897e.js, fonction _0x469900).
//
// Pipeline de décodage du blob <script type="application/json">["..."] :
//   1. ROT13 sur tout le blob                    (_0x24839f)
//   2. Supprimer les 7 opérateurs 2-chars        (_0x2f72b8 + _0x42de60)
//      ['@\$', '^^', '~@', '%?', '*~', '!!', '#&']
//   3. base64 decode                             (_0x33f6fb : atob)
//   4. Caesar -3 sur chaque octet                (_0x31cc12, shift 0x3)
//   5. reverse                                   (_0x75a6b9)
//   6. base64 decode + JSON.parse                (atob)
//   → objet config jwplayer dont .source = master.m3u8 réel (IP-locké, ~4h)
//
// Le `var source='https://test-videos.co.uk/vids/bigbuckbunny/...'` visible
// dans le HTML est un LEURRE ; le vrai payload est le blob JSON.
//
// Usage : dart bin/re_voe.dart [url_voe_embed]

import 'dart:convert';
import 'dart:io';

const _ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

const _operators = ['@\$', '^^', '~@', '%?', '*~', '!!', '#&'];

/// Décodage exact du blob VOE (port de _0x469900 de loader.a40897e.js).
Map<String, dynamic> voeDecodeBlob(String ct) {
  // 1. ROT13
  final b = StringBuffer();
  for (final c in ct.codeUnits) {
    if (c >= 0x41 && c <= 0x5A) {
      b.writeCharCode((c - 0x41 + 0x0D) % 0x1A + 0x41);
    } else if (c >= 0x61 && c <= 0x7A) {
      b.writeCharCode((c - 0x61 + 0x0D) % 0x1A + 0x61);
    } else {
      b.writeCharCode(c);
    }
  }
  // 2. Strip des 7 opérateurs
  var s = b.toString();
  for (final op in _operators) {
    s = s.replaceAll(op, '');
  }
  // 3-5. atob → chaque octet -3 → reverse
  final layer1 = base64.decode(s);
  final shifted = [for (final byte in layer1) (byte - 3) & 0xFF];
  final reversedB64 = ascii.decode(shifted.reversed.toList(), allowInvalid: true);
  // 6. atob → JSON
  return jsonDecode(utf8.decode(base64.decode(reversedB64))) as Map<String, dynamic>;
}

/// Petit client HTTP avec jar à cookies (ddos-guard) + suivi manuel.
class _Client {
  final _http = HttpClient()..autoUncompress = true;
  final _cookies = <String, String>{};

  Future<String> get(String url, {String? referer, int maxHops = 5}) async {
    var current = url;
    for (var hop = 0; hop < maxHops; hop++) {
      final req = await _http.getUrl(Uri.parse(current));
      req.headers.set(HttpHeaders.userAgentHeader, _ua);
      if (referer != null) req.headers.set(HttpHeaders.refererHeader, referer);
      if (_cookies.isNotEmpty) {
        req.headers.set(HttpHeaders.cookieHeader,
            _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '));
      }
      req.followRedirects = false;
      final resp = await req.close();
      for (final c in resp.cookies) {
        _cookies[c.name] = c.value;
      }
      if (resp.isRedirect) {
        final loc = resp.headers.value(HttpHeaders.locationHeader);
        if (loc == null) break;
        current = Uri.parse(current).resolve(loc).toString();
        await resp.drain<void>();
        continue;
      }
      return await resp.transform(utf8.decoder).join();
    }
    throw StateError('too many redirects for $url');
  }

  Future<int> head(String url, {String? referer}) async {
    final req = await _http.getUrl(Uri.parse(url));
    req.headers.set(HttpHeaders.userAgentHeader, _ua);
    if (referer != null) req.headers.set(HttpHeaders.refererHeader, referer);
    final resp = await req.close();
    await resp.drain<void>();
    return resp.statusCode;
  }
}

/// Extraction autonome : embed voe.sx/e/{id} → master.m3u8 réel.
Future<Map<String, dynamic>> extractVoeFinal(String embedUrl) async {
  final client = _Client();
  final uri0 = Uri.parse(embedUrl);
  var base = '${uri0.scheme}://${uri0.host}';

  // Étape 1 : page voe.sx → redirect JS vers l'alias du moment
  var html = await client.get(embedUrl, referer: '$base/');
  final jsRedirect = RegExp(
    '''window\\.location\\.href\\s*=\\s*['"]([^'"]+)['"]''',
  ).firstMatch(html);
  if (jsRedirect != null && jsRedirect.group(1)!.startsWith('http')) {
    final aliasUrl = jsRedirect.group(1)!;
    base = '${Uri.parse(aliasUrl).scheme}://${Uri.parse(aliasUrl).host}';
    html = await client.get(aliasUrl, referer: '${uri0.scheme}://${uri0.host}/');
  }

  // Étape 2 : blob chiffré (ignore le leurre var source='...bigbuckbunny...')
  final m = RegExp(
    '<script type="application/json">\\s*(\\[.*?\\])\\s*</script>',
    dotAll: true,
  ).firstMatch(html);
  if (m == null) {
    // garde-fou : ne JAMAIS retourner le leurre test-videos/bigbuckbunny
    if (html.contains('bigbuckbunny') || html.contains('buck_bunny')) {
      throw StateError('VOE: seul le leurre bigbuckbunny est présent, blob absent');
    }
    throw StateError('VOE: blob application/json introuvable');
  }
  final blob = (jsonDecode(m.group(1)!) as List).first as String;

  // Étape 3 : décodage propriétaire
  final cfg = voeDecodeBlob(blob);
  final source = cfg['source'] as String?;
  if (source == null || !source.contains('m3u8')) {
    throw StateError('VOE: pas de source hls dans le config décodé');
  }

  return {
    'source': source,
    'title': cfg['title'],
    'thumbnail': cfg['thumbnail'],
    'alias_base': base,
    'headers': {'User-Agent': _ua, 'Referer': '$base/'},
  };
}

Future<void> main(List<String> args) async {
  final url = args.isNotEmpty ? args[0] : 'https://voe.sx/e/chhibsczi9y7';
  stdout.writeln('== re_voe: $url');
  try {
    final res = await extractVoeFinal(url);
    stdout.writeln('title   : ${res['title']}');
    stdout.writeln('alias   : ${res['alias_base']}');
    stdout.writeln('HLS     : ${res['source']}');
    final client = _Client();
    final code = await client.head(
      res['source'] as String,
      referer: (res['headers'] as Map)['Referer'] as String,
    );
    stdout.writeln('PROOF HTTP $code');
    exit(code == 200 ? 0 : 2);
  } catch (e) {
    stderr.writeln('FAIL: $e');
    exit(1);
  }
}
