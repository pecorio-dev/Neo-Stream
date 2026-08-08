// re_dingtezuni.dart — Reverse-engineering dingtezuni.com (VidHide engine)
//
// Cassé le 2026-08-08 depuis l'embed réel :
//   https://dingtezuni.com/embed/olo398feeyja
//
// Mécanique :
//   1. dingtezuni.com répond 301 vers un alias tournant (constaté :
//      callistanise.com) — le client SUIT les redirections et utilise
//      l'origine FINALE comme base (Referer + résolution des URLs relatives).
//   2. Identique à minochinos (même moteur VidHide) : blob Dean Edwards
//      packer eval(function(p,a,c,k,e,d){...}) contenant
//      var links={"hls4":"...","hls2":"...","hls3":"..."}.
//   3. Sémantique des clés (vérifiée) :
//      - hls4 : /stream/<token>/hjkrhuihghfvu/<epoch>/<fileId>/master.m3u8
//        → TROLL : variante 1080p = 138 « segments » 100 % images pub
//        p1X-ad-site-sign-sg.tiktokcdn.com/ad-site-i18n-sg/...image.
//      - hls2 : https://<rand>.dramiyos-cdn.com/hls2/01/<id>/<name>_,l,n,h,
//        .urlset/master.m3u8?t=…&s=…&e=129600… → RÉEL : 3 variantes
//        (480/720/1080), segments MPEG-TS, Range → HTTP 206 (aucun Referer
//        requis par le CDN). Validité ~36 h.
//      - hls3 : master.txt sur domaine random — segments 404 au test.
//   4. Extraction : priorité hls2 → hls3 → hls4 + validation anti-troll
//      (rejet /troll/, rejet segments images/pub, sonde Range 200/206 avec
//      sync 0x47 MPEG-TS, rejet fichiers < 100 KB).
//
// Usage : dart run bin/re_dingtezuni.dart [url_embed ...]

import 'dart:convert';
import 'dart:io';

const _ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

// ─────────────────────────── Dean Edwards unpacker ───────────────────────────

String _encodeBase(int n, int base) {
  if (base <= 36) return n.toRadixString(base);
  const digits =
      '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  if (n == 0) return '0';
  var s = '';
  while (n > 0) {
    s = digits[n % base] + s;
    n = n ~/ base;
  }
  return s;
}

String unpackJs(String html) {
  final m = RegExp(
    r"eval\(function\(p,a,c,k,e,(?:r|d)?\)\{.*?\}\('(.*?)'\s*,\s*(\d+)\s*,"
    r"\s*(\d+)\s*,\s*'(.*?)'\.split\s*\(\s*'([^']*)'\s*\)",
    dotAll: true,
  ).firstMatch(html);
  if (m == null) return '';
  final p = m.group(1)!;
  final a = int.tryParse(m.group(2) ?? '') ?? 10;
  final c = int.tryParse(m.group(3) ?? '') ?? 0;
  final k = m.group(4)!.split(m.group(5)!);
  var out = p;
  for (var i = c - 1; i >= 0; i--) {
    if (i < k.length && k[i].isNotEmpty) {
      out = out.replaceAll(
          RegExp('\\b${RegExp.escape(_encodeBase(i, a))}\\b'), k[i]);
    }
  }
  return out;
}

// ─────────────────────────── HTTP minimal (redirects manuels) ────────────────

class _Resp {
  _Resp(this.status, this.finalUrl, this.body, this.headers);
  final int status;
  final Uri finalUrl;
  final List<int> body;
  final HttpHeaders? headers;
  String get text => utf8.decode(body, allowMalformed: true);
}

Future<_Resp> _get(String url, {String? referer, String? range, int hops = 5}) async {
  var current = url;
  for (var hop = 0; hop <= hops; hop++) {
    final client = HttpClient()
      ..autoUncompress = true
      ..idleTimeout = const Duration(seconds: 20);
    try {
      final req = await client.getUrl(Uri.parse(current));
      req.followRedirects = false;
      req.headers.set(HttpHeaders.userAgentHeader, _ua);
      if (referer != null) req.headers.set(HttpHeaders.refererHeader, referer);
      if (range != null) req.headers.set(HttpHeaders.rangeHeader, range);
      final resp = await req.close().timeout(const Duration(seconds: 20));
      if (resp.isRedirect) {
        final loc = resp.headers.value(HttpHeaders.locationHeader);
        await resp.drain<void>();
        if (loc == null) break;
        current = Uri.parse(current).resolve(loc).toString();
        continue;
      }
      final bytes = await resp.fold<List<int>>(
          <int>[], (acc, chunk) => acc..addAll(chunk));
      return _Resp(resp.statusCode, Uri.parse(current), bytes, resp.headers);
    } finally {
      client.close(force: true);
    }
  }
  return _Resp(0, Uri.parse(current), <int>[], null);
}

// ─────────────────────────── Anti-troll / validation HLS ─────────────────────

bool _looksLikeAdSeg(String segUri, String playlistHost) {
  final u = Uri.tryParse(segUri);
  if (u == null) return true;
  final p = u.path.toLowerCase();
  final h = u.host.toLowerCase();
  if (p.contains('/troll/')) return true;
  if (h.contains('ad-site') || h.contains('tiktokcdn')) return true;
  if (RegExp(r'\.(image|jpe?g|png|webp|gif|bmp)([?#].*)?$').hasMatch(p)) {
    return true;
  }
  if (u.hasAbsolutePath && segUri.startsWith('http') && h != playlistHost) {
    return true;
  }
  return false;
}

Future<List<Map<String, String>>?> _validateHls(String masterUrl,
    {String? referer}) async {
  final master = await _get(masterUrl, referer: referer);
  if (master.status != 200 || !master.text.contains('#EXTM3U')) return null;

  final masterUri = Uri.parse(masterUrl);
  final lines = master.text.split(RegExp(r'\r?\n'));
  final qualities = <Map<String, String>>[];
  String? firstVariant;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('#EXT-X-STREAM-INF')) {
      final next = lines.skip(i + 1).firstWhere((l) => l.trim().isNotEmpty,
          orElse: () => '');
      final res = RegExp(r'RESOLUTION=(\d+x\d+)').firstMatch(lines[i]);
      final url = masterUri.resolve(next.trim()).toString();
      qualities.add({'quality': res?.group(1) ?? '?', 'url': url});
      firstVariant ??= url;
    }
  }

  final variantUrl = firstVariant ?? masterUrl;
  final variant = firstVariant == null
      ? master
      : await _get(variantUrl, referer: referer);
  if (variant.status != 200 || !variant.text.contains('#EXTM3U')) return null;
  if (RegExp(r'#EXT-X-STREAM-INF').hasMatch(variant.text) &&
      firstVariant != null) {
    return null;
  }

  final segs = variant.text
      .split(RegExp(r'\r?\n'))
      .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
      .toList();
  if (segs.isEmpty) return null;

  final adCount = segs
      .where((s) => _looksLikeAdSeg(s.trim(), Uri.parse(variantUrl).host))
      .length;
  if (adCount * 10 > segs.length) return null;

  final firstSeg = Uri.parse(variantUrl)
      .resolve(segs.firstWhere((s) => !_looksLikeAdSeg(s.trim(),
          Uri.parse(variantUrl).host)).trim())
      .toString();
  final probe = await _get(firstSeg, referer: referer, range: 'bytes=0-2047');
  if (probe.status != 200 && probe.status != 206) return null;
  final ct = probe.headers?.value(HttpHeaders.contentTypeHeader) ?? '';
  final isTs = probe.body.isNotEmpty && probe.body[0] == 0x47;
  final isMp4 = probe.body.length > 8 &&
      String.fromCharCodes(probe.body.sublist(4, 8)) == 'ftyp';
  if (!isTs && !isMp4 && !ct.contains('video') && !ct.contains('MP2T')) {
    return null;
  }
  final cr = probe.headers?.value('content-range') ?? '';
  final totalM = RegExp(r'/(\d+)\s*$').firstMatch(cr);
  final total = totalM != null
      ? int.tryParse(totalM.group(1)!) ?? 0
      : probe.body.length;
  if (probe.status == 206 && total > 0 && total < 100 * 1024) return null;

  return qualities;
}

// ─────────────────────────── Extraction VidHide générique ────────────────────

Map<String, String>? _parseLinks(String js) {
  final m =
      RegExp(r'''var\s+links\s*=\s*\{([^}]+)\}''', caseSensitive: false)
          .firstMatch(js);
  if (m == null) return null;
  final out = <String, String>{};
  for (final kv
      in RegExp(r'''"(hls\d+)"\s*:\s*"([^"]+)"''').allMatches(m.group(1)!)) {
    out[kv.group(1)!] = kv.group(2)!.replaceAll(r'\/', '/');
  }
  return out.isEmpty ? null : out;
}

Future<Map<String, dynamic>> _extractVidHide(
  String url,
  String serverName,
  List<String> priority,
) async {
  try {
    final embed = await _get(url, referer: _origin(url) + '/');
    if (embed.status != 200) {
      return {'error': '$serverName: embed HTTP ${embed.status}'};
    }
    final base = _origin(embed.finalUrl.toString());
    final referer = '$base/';
    final html = embed.text;
    final src = html.contains('eval(function') ? unpackJs(html) : html;
    final links = _parseLinks(src);
    if (links == null) {
      return {'error': '$serverName: var links introuvable'};
    }

    final tried = <String>[];
    for (final key in priority) {
      var v = links[key];
      if (v == null || v.isEmpty) continue;
      if (!v.startsWith('http')) v = '$base$v';
      if (v.contains('/troll/')) {
        tried.add('$key=troll-path');
        continue;
      }
      final qualities = await _validateHls(v, referer: referer);
      if (qualities != null) {
        return {
          'success': true,
          'video_url': v,
          'server': serverName,
          'type': 'hls',
          'is_hls': true,
          'link_key': key,
          'qualities': qualities,
          'headers': {'Referer': referer, 'User-Agent': _ua},
        };
      }
      tried.add('$key=troll/invalid');
    }
    return {'error': '$serverName: toutes les sources rejetées ($tried)'};
  } catch (e) {
    return {'error': '$serverName: $e'};
  }
}

String _origin(String url) {
  final u = Uri.parse(url);
  return '${u.scheme}://${u.host}${u.hasPort ? ':${u.port}' : ''}';
}

// ─────────────────────────── API publique ────────────────────────────────────

/// Extraction dingtezuni.com (suit la 301 vers l'alias actif, ex.
/// callistanise.com) — hls2 (CDN signé dramiyos-cdn.com) validé en priorité.
Future<Map<String, dynamic>> extractDingtezuniFinal(String url) =>
    _extractVidHide(url, 'dingtezuni', const ['hls2', 'hls3', 'hls4']);

// ─────────────────────────── CLI de preuve ───────────────────────────────────

Future<void> main(List<String> args) async {
  final urls = args.isNotEmpty
      ? args
      : const [
          'https://dingtezuni.com/embed/olo398feeyja',
          // Même vidéo via l'alias tournant actuel (301) : prouve que
          // l'extracteur gère les deux formes d'URL.
          'https://callistanise.com/embed/olo398feeyja',
        ];
  var ok = 0;
  for (final u in urls) {
    final r = await extractDingtezuniFinal(u);
    if (r['success'] == true) {
      ok++;
      print('[OK] $u');
      print('     key=${r['link_key']}  url=${r['video_url']}');
      print('     qualities=${r['qualities']?.length} '
          '${(r['qualities'] as List?)?.map((q) => q['quality']).join(',')}');
    } else {
      print('[KO] $u -> ${r['error']}');
    }
  }
  print('===> $ok/${urls.length} liens dingtezuni résolus');
  exit(ok == urls.length ? 0 : 1);
}
