// =============================================================================
// re_uqload.dart — Reverse-engineered UQLOAD extractor (PROVEN 2026-08-08)
//
// Technique (verified live on both test links):
//   1. GET https://uqload.is/embed-{file_code}.html  (all uqload.* domains
//      redirect / alias to uqload.is; .net returns 301 -> .is)
//   2. The page embeds a classic Dean Edwards JS packer:
//        eval(function(p,a,c,k,e,d){while(c--)if(k[c])p=p.replace(
//            new RegExp('\\b'+c.toString(a)+'\\b','g'),k[c]);
//        return p}('PAYLOAD', A, C, 'DICT'.split('|')))
//      with A = 36. The HLS URL (strm{N}.uqload.is/hls2/.../master.m3u8?...)
//      is STATICALLY recoverable by unpacking — token t, epoch s, e=43200,
//      v and the hls2/{MM}/{NNNNNN}/{file}_n substrate are plain entries of
//      the packer dictionary.
//   3. Hidden endpoints checked (none useful):
//        /dl?op=embed&file_code=X  -> alias of the embed page (same bytes)
//        /api/video/X              -> JSON {"status":400,"msg":"Invalid key"}
//   4. No cookie / UA / Referer needed on the final stream (200 without);
//      browser headers are still sent defensively.
//   5. uqload.is serves an incomplete TLS chain -> tolerant HttpClient
//      (badCertificateCallback) + package:http IOClient.
//
// Result map keys: success, video_url, server, type, is_hls, qualities,
// headers, file_code, stream_host.
// =============================================================================
// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures, unused_local_variable, unused_element, unused_import

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

const String _ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';

http.Client _tlsTolerantClient() {
  final inner = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20);
  inner.badCertificateCallback =
      (X509Certificate cert, String host, int port) => true;
  return IOClient(inner);
}

/// JS string-literal unescape: backslash + next char -> literal char.
String _jsUnescape(String s) {
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (s[i] == '\\' && i + 1 < s.length) {
      out.write(s[i + 1]);
      i++;
    } else {
      out.write(s[i]);
    }
  }
  return out.toString();
}

/// JS Number.prototype.toString(radix) for radix <= 36.
String _toBase(int n, int radix) {
  const digits = '0123456789abcdefghijklmnopqrstuvwxyz';
  if (n == 0) return '0';
  final buf = StringBuffer();
  while (n > 0) {
    buf.write(digits[n % radix]);
    n ~/= radix;
  }
  return buf.toString().split('').reversed.join();
}

/// Unpacks every `eval(function(p,a,c,k,e,d){...}('p',a,c,'k'.split('|')))`
/// block found in [html]. Returns the decoded scripts.
List<String> unpackUqloadJs(String html) {
  final results = <String>[];
  final re = RegExp(
    r"\}\('([\s\S]*?)',(\d+),(\d+),'([\s\S]*?)'\.split\('\|'\)",
  );
  for (final m in re.allMatches(html)) {
    try {
      var p = _jsUnescape(m.group(1)!);
      final a = int.tryParse(m.group(2)!) ?? 36;
      var c = int.tryParse(m.group(3)!) ?? 0;
      final k = _jsUnescape(m.group(4)!).split('|');
      while (c-- > 0) {
        if (c < k.length && k[c].isNotEmpty) {
          p = p.replaceAll(RegExp('\\b${_toBase(c, a)}\\b'), k[c]);
        }
      }
      results.add(p);
    } catch (_) {/* keep going with other blocks */}
  }
  return results;
}

String? _firstUrl(String haystack, RegExp re) {
  final m = re.firstMatch(haystack.replaceAll(r'\/', '/'));
  return m?.group(0);
}

final RegExp _m3u8Re =
    RegExp(r'''https?://[^\s"'<>\\]+\.m3u8(?:\?[^\s"'<>\\]*)?''');
final RegExp _mp4Re =
    RegExp(r'''https?://[^\s"'<>\\]+\.mp4(?:\?[^\s"'<>\\]*)?''');
final RegExp _fileCodeRe = RegExp(
  r'uqload\.(?:bz|is|org|co|to|net|com)/(?:embed-)?([a-z0-9]+)\.html',
  caseSensitive: false,
);

/// Counts quality variants of an HLS master playlist.
Future<List<Map<String, String>>> _parseHlsVariants(
    http.Client client, String masterUrl) async {
  final variants = <Map<String, String>>[];
  try {
    final resp = await client.get(Uri.parse(masterUrl), headers: {
      'User-Agent': _ua,
      'Referer': 'https://uqload.is/',
    });
    if (resp.statusCode != 200) return variants;
    final lines = resp.body.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].startsWith('#EXT-X-STREAM-INF')) {
        final res =
            RegExp(r'RESOLUTION=(\d+x\d+)').firstMatch(lines[i])?.group(1);
        String? child;
        for (var j = i + 1; j < lines.length; j++) {
          final l = lines[j].trim();
          if (l.isNotEmpty && !l.startsWith('#')) {
            child = l;
            break;
          }
        }
        variants.add({'resolution': res ?? '?', 'url': child ?? ''});
      }
    }
  } catch (_) {}
  return variants;
}

/// Main entry point: extracts the final HLS/MP4 URL of a uqload embed link.
Future<Map<String, dynamic>> extractUqloadFinal(String url) async {
  final codeMatch = _fileCodeRe.firstMatch(url);
  if (codeMatch == null) {
    return {'success': false, 'error': 'Not a uqload embed URL: $url'};
  }
  final fileCode = codeMatch.group(1)!;
  final embedUrl = 'https://uqload.is/embed-$fileCode.html';

  final client = _tlsTolerantClient();
  try {
    final resp = await client.get(
      Uri.parse(embedUrl),
      headers: {'User-Agent': _ua, 'Referer': 'https://uqload.is/'},
    );
    if (resp.statusCode != 200) {
      return {'success': false, 'error': 'embed HTTP ${resp.statusCode}'};
    }

    // Haystack = raw HTML + every unpacked packer payload.
    final parts = <String>[resp.body, ...unpackUqloadJs(resp.body)];
    final haystack = parts.join('\n');

    final m3u8 = _firstUrl(haystack, _m3u8Re);
    if (m3u8 != null) {
      final qualities = await _parseHlsVariants(client, m3u8);
      return {
        'success': true,
        'video_url': m3u8,
        'server': 'uqload',
        'type': 'hls',
        'is_hls': true,
        'file_code': fileCode,
        'stream_host': Uri.parse(m3u8).host,
        'qualities': qualities,
        'headers': {'User-Agent': _ua, 'Referer': 'https://uqload.is/'},
      };
    }
    final mp4 = _firstUrl(haystack, _mp4Re);
    if (mp4 != null) {
      return {
        'success': true,
        'video_url': mp4,
        'server': 'uqload',
        'type': 'mp4',
        'is_hls': false,
        'file_code': fileCode,
        'stream_host': Uri.parse(mp4).host,
        'headers': {'User-Agent': _ua, 'Referer': 'https://uqload.is/'},
      };
    }
    return {'success': false, 'error': 'Uqload: no m3u8/mp4 found'};
  } catch (e) {
    return {'success': false, 'error': 'Uqload: $e'};
  } finally {
    client.close();
  }
}

// =============================================================================
// Proof harness — run: dart run bin/re_uqload.dart
// =============================================================================

Future<void> main(List<String> args) async {
  final tests = args.isNotEmpty
      ? args
      : [
          'https://uqload.is/embed-qdmj53zjm8w0.html', // série Veille sur moi S01E01
          'https://uqload.net/embed-qiv3leywr7oi.html', // film Les nouveaux guerriers
        ];

  for (final link in tests) {
    stdout.writeln('\n================ $link');
    final res = await extractUqloadFinal(link);
    if (res['success'] != true) {
      stdout.writeln('  ERROR: ${res['error']}');
      continue;
    }
    final videoUrl = res['video_url'] as String;
    stdout.writeln('  VIDEO_URL: $videoUrl');
    stdout.writeln('  TYPE: ${res['type']}   HOST: ${res['stream_host']}');
    final q = res['qualities'] as List? ?? [];
    for (final v in q) {
      stdout.writeln('  VARIANT: ${v['resolution']} -> ${v['url']}');
    }

    // --- PROOF: HEAD + GET on master, Range on a real segment ---
    final client = _tlsTolerantClient();
    try {
      final head = await client
          .head(Uri.parse(videoUrl), headers: {'User-Agent': _ua});
      stdout.writeln('  HEAD master.m3u8 -> HTTP ${head.statusCode}');

      if (res['is_hls'] == true && q.isNotEmpty) {
        final child = (q.first['url'] as String?) ?? '';
        if (child.isNotEmpty) {
          final segList = await client
              .get(Uri.parse(child), headers: {'User-Agent': _ua});
          final seg = segList.body
              .split('\n')
              .map((l) => l.trim())
              .firstWhere((l) => l.endsWith('.ts') || l.contains('.ts?'),
                  orElse: () => '');
          if (seg.isNotEmpty) {
            final segUri = Uri.parse(child).resolve(seg).toString();
            final r = await client.get(Uri.parse(segUri),
                headers: {'User-Agent': _ua, 'Range': 'bytes=0-99'});
            stdout.writeln(
                '  GET segment (Range 0-99) -> HTTP ${r.statusCode}, ${r.bodyBytes.length} bytes, magic=${r.bodyBytes.isNotEmpty ? r.bodyBytes[0].toRadixString(16) : '-'}');
          }
        }
      }
    } finally {
      client.close();
    }
  }
}
