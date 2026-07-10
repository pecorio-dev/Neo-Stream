import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'video_extractor.dart';

/// Extracteur dédié anime (anime-sama, etc.)
/// Délègue aux hébergeurs classiques via VideoExtractor,
/// et gère les players spécifiques anime (Sibnet, Sendvid, Vidmoly…).
class AnimeExtractor {
  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  static const Duration _timeout = Duration(seconds: 15);

  static Map<String, String> _headers({String? referer}) => {
        'User-Agent': _ua,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'fr-FR,fr;q=0.9,en-US;q=0.8',
        'Connection': 'keep-alive',
        if (referer != null) 'Referer': referer,
      };

  // ─────────────────────────────────────────────────────────────────
  // POINT D'ENTRÉE
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> extract(String url) async {
    try {
      debugPrint('[AnimeExtractor] Extraction: $url');

      // Déléguer à VideoExtractor pour tous les hébergeurs qu'il connaît
      final server = VideoExtractor.detectServer(url);
      if (server != 'unknown') {
        debugPrint('[AnimeExtractor] → VideoExtractor ($server)');
        final result = await VideoExtractor.extract(url);
        if (result['success'] == true) return result;
        debugPrint('[AnimeExtractor] VideoExtractor échec: ${result['error']}');
      }

      // Extracteurs spécifiques anime
      final result = await _dispatchAnime(url);
      if (result['success'] == true) {
        debugPrint('[AnimeExtractor] OK: ${result['video_url']}');
      } else {
        debugPrint('[AnimeExtractor] Échec: ${result['error']}');
      }
      return result;
    } catch (e) {
      return {'success': false, 'error': 'Erreur: $e', 'url': url};
    }
  }

  static Future<Map<String, dynamic>> _dispatchAnime(String url) async {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';

    if (host.contains('sibnet')) return _extractSibnet(url);
    if (host.contains('sendvid')) return _extractSendvid(url);
    if (host.contains('vidmoly')) return _extractVidmoly(url);
    if (host.contains('oneupload')) return _extractGeneric(url, 'oneupload');
    if (host.contains('goudcloud') || host.contains('gcloud')) return _extractGoudcloud(url);
    if (host.contains('streamwish') || host.contains('wish')) return _extractStreamwish(url);
    if (host.contains('filelions') || host.contains('vidhide')) return _extractFilelions(url);
    if (host.contains('mega.nz') || host.contains('mega.co')) return _extractMega(url);
    if (host.contains('youtu') || host.contains('youtube')) return _extractYouTube(url);

    return _extractGeneric(url, 'anime_generic');
  }

  // ─────────────────────────────────────────────────────────────────
  // MULTI-SOURCES
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> extractFromMultipleSources(
    List<Map<String, String>> sources,
  ) async {
    debugPrint('[AnimeExtractor] ${sources.length} sources');

    final sorted = List<Map<String, String>>.from(sources);
    sorted.sort((a, b) {
      final pa = (a['player'] ?? '').toLowerCase();
      final pb = (b['player'] ?? '').toLowerCase();
      return _playerPriority(pa).compareTo(_playerPriority(pb));
    });

    for (final source in sorted) {
      final url = source['url'];
      final player = source['player'];
      if (url == null || url.isEmpty) continue;

      debugPrint('[AnimeExtractor] Essai: $player ($url)');
      final result = await extract(url);
      if (result['success'] == true) {
        result['tried_player'] = player;
        return result;
      }
    }

    return {
      'success': false,
      'error': 'Aucune source extraite',
      'tried_count': sources.length,
    };
  }

  static int _playerPriority(String player) {
    // Priorité décroissante — chiffre bas = priorité haute
    if (player == 'sibnet') return 0;
    if (player == 'sendvid') return 1;
    if (player == 'vidmoly') return 2;
    if (player == 'streamtape') return 3;
    if (player == 'doodstream' || player.startsWith('doo')) return 4;
    if (player == 'voe') return 5;
    if (player == 'filemoon' || player.contains('moon')) return 6;
    if (player == 'uqload') return 7;
    if (player == 'okru' || player == 'ok.ru') return 8;
    if (player == 'vk') return 9;
    if (player == 'streamwish') return 10;
    if (player == 'goudcloud') return 11;
    return 50;
  }

  // ─────────────────────────────────────────────────────────────────
  // HLS QUALITY PARSER
  // ─────────────────────────────────────────────────────────────────

  static Future<List<Map<String, String>>> _parseHLSMaster(
    String masterUrl,
    Map<String, String> headers,
  ) async {
    try {
      final resp = await http.get(Uri.parse(masterUrl), headers: headers).timeout(_timeout);
      if (resp.statusCode != 200) return [];
      final body = resp.body;
      if (!body.contains('#EXTM3U')) return [];

      final qualities = <Map<String, String>>[];
      final lines = body.split('\n');
      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (!line.startsWith('#EXT-X-STREAM-INF')) continue;

        final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
        final resMatch = RegExp(r'RESOLUTION=(\d+x\d+)').firstMatch(line);
        final bandwidth = int.tryParse(bwMatch?.group(1) ?? '0') ?? 0;
        final resolution = resMatch?.group(1) ?? '';
        final height = int.tryParse(resolution.split('x').lastOrNull ?? '') ?? 0;

        var segUrl = lines[i + 1].trim();
        if (segUrl.isEmpty || segUrl.startsWith('#')) continue;
        if (!segUrl.startsWith('http')) {
          final base = masterUrl.substring(0, masterUrl.lastIndexOf('/') + 1);
          segUrl = '$base$segUrl';
        }

        final label = height > 0
            ? '${height}p'
            : (bandwidth > 0 ? '${(bandwidth / 1000).round()}k' : 'Auto');

        qualities.add({'label': label, 'url': segUrl, 'bandwidth': bandwidth.toString()});
      }

      qualities.sort((a, b) =>
          int.parse(b['bandwidth'] ?? '0').compareTo(int.parse(a['bandwidth'] ?? '0')));
      return qualities;
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // JS UNPACK
  // ─────────────────────────────────────────────────────────────────

  static String _unpackJs(String packed) {
    try {
      final payloadMatch = RegExp(
        r"eval\(function\(p,a,c,k,e,(?:r|d)\)\{.*?\}\('(.*?)',(\d+),(\d+),'(.*?)'\.",
        dotAll: true,
      ).firstMatch(packed);
      if (payloadMatch == null) return packed;

      final p = payloadMatch.group(1)!;
      final a = int.tryParse(payloadMatch.group(2)!) ?? 62;
      final k = payloadMatch.group(4)!.split('|');

      String decode(String word) {
        if (word.isEmpty) return word;
        int n = 0;
        for (int i = 0; i < word.length; i++) {
          final char = word[i];
          int v;
          if (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) {
            v = char.codeUnitAt(0) - 48;
          } else if (char.codeUnitAt(0) >= 97 && char.codeUnitAt(0) <= 122) {
            v = char.codeUnitAt(0) - 87;
          } else if (char.codeUnitAt(0) >= 65 && char.codeUnitAt(0) <= 90) {
            v = char.codeUnitAt(0) - 29;
          } else {
            return word;
          }
          n = n * a + v;
        }
        return n < k.length && k[n].isNotEmpty ? k[n] : word;
      }

      return p.replaceAllMapped(RegExp(r'\b\w+\b'), (m) => decode(m.group(0)!));
    } catch (_) {
      return packed;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // SIBNET
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractSibnet(String url) async {
    try {
      final headers = _headers(referer: 'https://sibnet.ru/');
      final resp = await http.get(Uri.parse(url), headers: headers).timeout(_timeout);
      if (resp.statusCode != 200) return {'success': false, 'error': 'Sibnet: HTTP ${resp.statusCode}'};
      final html = resp.body;

      // HLS first
      final hlsMatch = RegExp(r'src:\s*"([^"]+\.m3u8[^"]*)"', caseSensitive: false).firstMatch(html)
          ?? RegExp(r"src:\s*'([^']+\.m3u8[^']*)'", caseSensitive: false).firstMatch(html);
      if (hlsMatch != null) {
        var hlsUrl = hlsMatch.group(1)!;
        if (hlsUrl.startsWith('/')) hlsUrl = 'https://video.sibnet.ru$hlsUrl';
        final qualities = await _parseHLSMaster(hlsUrl, headers);
        return {
          'success': true,
          'video_url': hlsUrl,
          'type': 'hls',
          'extractor': 'sibnet',
          if (qualities.isNotEmpty) 'qualities': qualities,
          'headers': {'Referer': 'https://video.sibnet.ru/'},
        };
      }

      // MP4
      final mp4Match = RegExp(r'src:\s*"([^"]+\.mp4[^"]*)"', caseSensitive: false).firstMatch(html)
          ?? RegExp(r"src:\s*'([^']+\.mp4[^']*)'", caseSensitive: false).firstMatch(html);
      if (mp4Match != null) {
        var videoUrl = mp4Match.group(1)!;
        if (videoUrl.startsWith('/')) videoUrl = 'https://video.sibnet.ru$videoUrl';
        return {
          'success': true,
          'video_url': videoUrl,
          'type': 'mp4',
          'extractor': 'sibnet',
          'headers': {'Referer': 'https://video.sibnet.ru/', 'User-Agent': _ua},
        };
      }

      // player.ashx redirect
      final playerMatch = RegExp(r'(/shell\.php[^"]*|player\.ashx[^"]*)"').firstMatch(html)
          ?? RegExp(r"(/shell\.php[^']*|player\.ashx[^']*)'").firstMatch(html);
      if (playerMatch != null) {
        final playerUrl = 'https://video.sibnet.ru${playerMatch.group(1)!}';
        final resp2 = await http.get(Uri.parse(playerUrl), headers: headers).timeout(_timeout);
        final html2 = resp2.body;
        final mp4Match2 = RegExp(r'src:\s*"([^"]+\.mp4[^"]*)"', caseSensitive: false).firstMatch(html2)
            ?? RegExp(r"src:\s*'([^']+\.mp4[^']*)'", caseSensitive: false).firstMatch(html2);
        if (mp4Match2 != null) {
          var videoUrl = mp4Match2.group(1)!;
          if (videoUrl.startsWith('/')) videoUrl = 'https://video.sibnet.ru$videoUrl';
          return {
            'success': true,
            'video_url': videoUrl,
            'type': 'mp4',
            'extractor': 'sibnet',
            'headers': {'Referer': 'https://video.sibnet.ru/', 'User-Agent': _ua},
          };
        }
      }

      return {'success': false, 'error': 'Sibnet: lien non trouvé'};
    } catch (e) {
      return {'success': false, 'error': 'Sibnet: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // SENDVID
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractSendvid(String url) async {
    try {
      final headers = _headers(referer: 'https://sendvid.com/');
      final resp = await http.get(Uri.parse(url), headers: headers).timeout(_timeout);
      final html = resp.body;

      for (final pattern in [
        RegExp(r'<source[^>]+src="([^"]+\.mp4[^"]*)"', caseSensitive: false),
        RegExp(r'"file":\s*"([^"]+\.mp4[^"]*)"', caseSensitive: false),
        RegExp(r'<meta\s+property="og:video"\s+content="([^"]+)"', caseSensitive: false),
      ]) {
        final m = pattern.firstMatch(html);
        if (m != null) {
          return {
            'success': true,
            'video_url': m.group(1)!,
            'type': 'mp4',
            'extractor': 'sendvid',
          };
        }
      }

      return {'success': false, 'error': 'Sendvid: lien non trouvé'};
    } catch (e) {
      return {'success': false, 'error': 'Sendvid: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // VIDMOLY
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractVidmoly(String url) async {
    try {
      final headers = _headers(referer: 'https://vidmoly.to/');
      final resp = await http.get(Uri.parse(url), headers: headers).timeout(_timeout);
      final html = resp.body;

      // Try to unpack obfuscated JS
      final unpacked = html.contains('eval(function') ? _unpackJs(html) : html;

      for (final pattern in [
        RegExp(r'sources:\s*\[{[^}]*file:\s*"([^"]+)"', caseSensitive: false),
        RegExp(r'"file":\s*"([^"]+\.(m3u8|mp4)[^"]*)"', caseSensitive: false),
        RegExp(r"'file':\s*'([^']+\.(m3u8|mp4)[^']*)'", caseSensitive: false),
        RegExp(r'https?://[^\s"<>]+\.m3u8[^\s"<>]*', caseSensitive: false),
        RegExp(r'https?://[^\s"<>]+\.mp4[^\s"<>]*', caseSensitive: false),
      ]) {
        final m = pattern.firstMatch(unpacked);
        if (m != null) {
          var videoUrl = (m.group(1) ?? m.group(0)!).replaceAll(r'\/', '/');
          if (!videoUrl.startsWith('http') || videoUrl.length < 10) continue;
          final type = videoUrl.contains('.m3u8') ? 'hls' : 'mp4';
          if (type == 'hls') {
            final qualities = await _parseHLSMaster(videoUrl, headers);
            return {
              'success': true,
              'video_url': videoUrl,
              'type': 'hls',
              'extractor': 'vidmoly',
              if (qualities.isNotEmpty) 'qualities': qualities,
            };
          }
          return {'success': true, 'video_url': videoUrl, 'type': type, 'extractor': 'vidmoly'};
        }
      }

      return {'success': false, 'error': 'Vidmoly: lien non trouvé', 'needs_browser': true};
    } catch (e) {
      return {'success': false, 'error': 'Vidmoly: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // GOUDCLOUD / GCLOUD (fréquent sur anime-sama)
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractGoudcloud(String url) async {
    try {
      final headers = _headers(referer: url);
      final resp = await http.get(Uri.parse(url), headers: headers).timeout(_timeout);
      final html = resp.body;

      final unpacked = html.contains('eval(function') ? _unpackJs(html) : html;

      for (final pattern in [
        RegExp(r'"file":\s*"([^"]+\.m3u8[^"]*)"', caseSensitive: false),
        RegExp(r'"file":\s*"([^"]+\.mp4[^"]*)"', caseSensitive: false),
        RegExp(r'https?://[^\s"<>]+\.m3u8[^\s"<>]*', caseSensitive: false),
        RegExp(r'https?://[^\s"<>]+\.mp4[^\s"<>]*', caseSensitive: false),
      ]) {
        final m = pattern.firstMatch(unpacked);
        if (m != null) {
          var videoUrl = (m.group(1) ?? m.group(0)!).replaceAll(r'\/', '/');
          if (!videoUrl.startsWith('http')) continue;
          final type = videoUrl.contains('.m3u8') ? 'hls' : 'mp4';
          if (type == 'hls') {
            final qualities = await _parseHLSMaster(videoUrl, headers);
            return {
              'success': true,
              'video_url': videoUrl,
              'type': 'hls',
              'extractor': 'goudcloud',
              if (qualities.isNotEmpty) 'qualities': qualities,
            };
          }
          return {'success': true, 'video_url': videoUrl, 'type': type, 'extractor': 'goudcloud'};
        }
      }

      return {'success': false, 'error': 'Goudcloud: lien non trouvé'};
    } catch (e) {
      return {'success': false, 'error': 'Goudcloud: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // STREAMWISH / FILELIONS / VIDHIDE
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractStreamwish(String url) async {
    try {
      final headers = _headers(referer: url);
      final resp = await http.get(Uri.parse(url), headers: headers).timeout(_timeout);
      final html = resp.body;
      final unpacked = html.contains('eval(function') ? _unpackJs(html) : html;

      final m = RegExp(r'"file":\s*"([^"]+\.m3u8[^"]*)"', caseSensitive: false).firstMatch(unpacked)
          ?? RegExp(r'https?://[^\s"<>]+\.m3u8[^\s"<>]*', caseSensitive: false).firstMatch(unpacked);
      if (m != null) {
        var hlsUrl = (m.group(1) ?? m.group(0)!).replaceAll(r'\/', '/');
        final qualities = await _parseHLSMaster(hlsUrl, headers);
        return {
          'success': true,
          'video_url': hlsUrl,
          'type': 'hls',
          'extractor': 'streamwish',
          if (qualities.isNotEmpty) 'qualities': qualities,
        };
      }

      return {'success': false, 'error': 'Streamwish: lien non trouvé'};
    } catch (e) {
      return {'success': false, 'error': 'Streamwish: $e'};
    }
  }

  static Future<Map<String, dynamic>> _extractFilelions(String url) async =>
      _extractStreamwish(url).then((r) => r['extractor'] != null ? {...r, 'extractor': 'filelions'} : r);

  // ─────────────────────────────────────────────────────────────────
  // MEGA (lien direct uniquement, pas décryptage)
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractMega(String url) async {
    // Mega requires client-side decryption — signal needs_browser
    return {
      'success': false,
      'error': 'Mega: décryptage côté client requis',
      'needs_browser': true,
    };
  }

  // ─────────────────────────────────────────────────────────────────
  // YOUTUBE (embed → redirect → videoplayback)
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractYouTube(String url) async {
    // YouTube requires js challenge — signal needs_browser
    return {
      'success': false,
      'error': 'YouTube: challenge JS requis',
      'needs_browser': true,
    };
  }

  // ─────────────────────────────────────────────────────────────────
  // GÉNÉRIQUE avec JS unpack
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _extractGeneric(
    String url, [
    String extractor = 'generic',
  ]) async {
    try {
      final headers = _headers(referer: url);
      final resp = await http.get(Uri.parse(url), headers: headers).timeout(_timeout);
      final html = resp.body;

      // Unpack JS si présent
      final unpacked = html.contains('eval(function') ? _unpackJs(html) : html;

      for (final pattern in [
        RegExp(r'https?://[^\s"<>]+\.m3u8[^\s"<>]*', caseSensitive: false),
        RegExp(r'"file":\s*"([^"]+\.(m3u8|mp4)[^"]*)"', caseSensitive: false),
        RegExp(r"'file':\s*'([^']+\.(m3u8|mp4)[^']*)'", caseSensitive: false),
        RegExp(r'https?://[^\s"<>]+\.mp4[^\s"<>]*', caseSensitive: false),
        RegExp(r'source[^>]+src="([^"]+)"', caseSensitive: false),
        RegExp(r'video[^>]+src="([^"]+)"', caseSensitive: false),
        RegExp(r'<meta\s+property="og:video"\s+content="([^"]+)"', caseSensitive: false),
      ]) {
        final m = pattern.firstMatch(unpacked);
        if (m != null) {
          var videoUrl = (m.group(1) ?? m.group(0)!).replaceAll(r'\/', '/');
          if (videoUrl.length < 10 || !videoUrl.startsWith('http')) continue;
          final type = videoUrl.contains('.m3u8') ? 'hls' : 'mp4';
          if (type == 'hls') {
            final qualities = await _parseHLSMaster(videoUrl, headers);
            return {
              'success': true,
              'video_url': videoUrl,
              'type': 'hls',
              'extractor': extractor,
              if (qualities.isNotEmpty) 'qualities': qualities,
            };
          }
          return {'success': true, 'video_url': videoUrl, 'type': type, 'extractor': extractor};
        }
      }

      return {'success': false, 'error': 'Aucun lien trouvé', 'extractor': extractor};
    } catch (e) {
      return {'success': false, 'error': 'Erreur $extractor: $e'};
    }
  }
}
