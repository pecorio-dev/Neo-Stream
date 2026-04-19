import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Neo-Stream Video Extractor
/// Extraction autonome de liens vidéo depuis différentes sources
class VideoExtractor {
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  /// Extrait l'URL vidéo depuis n'importe quelle source
  static Future<Map<String, dynamic>> extract(String url) async {
    final server = detectServer(url);

    try {
      switch (server) {
        case 'doodstream':
          return await _extractDoodstream(url);
        case 'filmoon':
          return await _extractFilemoon(url);
        case 'vidzy':
          return await _extractVidzy(url);
        case 'uqload':
          return await _extractUqload(url);
        case 'ninjastream':
          return await _extractNinjastream(url);
        default:
          return await _extractGeneric(url);
      }
    } catch (e) {
      return {
        'error': 'Extraction failed: ${e.toString()}',
        'server': server,
      };
    }
  }

  /// Détecte le serveur depuis l'URL
  static String detectServer(String url) {
    final u = url.toLowerCase();

    if (RegExp(r'dood\.|doodstream|d0o0d|d000d|do0od|ds2play|dsvplay|doods|dooood|vvide0|myvidplay|playmogo|kokoflix|kakaflix')
        .hasMatch(u)) {
      return 'doodstream';
    }
    if (RegExp(r'filmoon|filemoon|bysebuho|f75s|moonmov|kerapxy').hasMatch(u)) {
      return 'filmoon';
    }
    if (u.contains('vidzy')) return 'vidzy';
    if (u.contains('uqload')) return 'uqload';
    if (u.contains('mixdrop')) return 'mixdrop';
    if (u.contains('streamtape')) return 'streamtape';
    if (u.contains('voe')) return 'voe';
    if (u.contains('ninjastream')) return 'ninjastream';

    return 'unknown';
  }

  /// Extrait depuis DoodStream
  static Future<Map<String, dynamic>> _extractDoodstream(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': userAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      );

      if (response.statusCode != 200) {
        return {'error': 'DoodStream: page inaccessible (HTTP ${response.statusCode})'};
      }

      final html = response.body;
      final finalUrl = response.request?.url.toString() ?? url;
      final uri = Uri.parse(finalUrl);
      final base = '${uri.scheme}://${uri.host}';

      // Extraire pass_md5
      final passRegex = RegExp(r'(/pass_md5[^"' + "'" + r']+)["' + "'" + r']');
      final passMatch = passRegex.firstMatch(html);
      if (passMatch == null) {
        return {'error': 'DoodStream: pass_md5 non trouvé'};
      }

      final passPath = passMatch.group(1)!;

      // Extraire token
      final tokenRegex = RegExp(r'[?&]token=([a-z0-9]+)[&"' + "'" + r']', caseSensitive: false);
      final tokenMatch = tokenRegex.firstMatch(html);
      String? token;
      if (tokenMatch != null) {
        token = tokenMatch.group(1);
      } else {
        final parts = passPath.split('/');
        token = parts.isNotEmpty ? parts.last : null;
      }

      if (token == null || token.isEmpty) {
        return {'error': 'DoodStream: token non trouvé'};
      }

      // Appeler pass_md5
      final passResponse = await http.get(
        Uri.parse('$base$passPath'),
        headers: {
          'User-Agent': userAgent,
          'Referer': finalUrl,
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': '*/*',
        },
      );

      if (passResponse.statusCode != 200) {
        return {'error': 'DoodStream: pass_md5 échoué (HTTP ${passResponse.statusCode})'};
      }

      final prefix = passResponse.body.trim();

      if (prefix == 'RELOAD') {
        return {'error': 'DoodStream: serveur demande RELOAD', 'retry': true};
      }

      if (!prefix.startsWith('http')) {
        return {'error': 'DoodStream: préfixe URL invalide'};
      }

      // Construire l'URL finale
      final random = _generateRandomString(10);
      final expiry = DateTime.now().millisecondsSinceEpoch;
      final videoUrl = '$prefix$random?token=$token&expiry=$expiry';

      return {
        'success': true,
        'video_url': videoUrl,
        'server': 'doodstream',
        'type': 'mp4',
        'headers': {
          'Referer': '$base/',
          'User-Agent': userAgent,
        },
      };
    } catch (e) {
      return {'error': 'DoodStream: ${e.toString()}'};
    }
  }

  /// Extrait depuis Uqload
  static Future<Map<String, dynamic>> _extractUqload(String url) async {
    try {
      // Normaliser l'URL vers uqload.is
      url = url.replaceAll(RegExp(r'uqload\.\w+'), 'uqload.is');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': userAgent,
          'Referer': 'https://uqload.is/',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return {'error': 'Uqload: page inaccessible (HTTP ${response.statusCode})'};
      }

      final html = response.body;

      // Patterns de recherche
      final patterns = [
        RegExp(r'sources\s*:\s*\[\s*["' + "'" + r']([^"' + "'" + r']+\.mp4[^"' + "'" + r']*)["' + "'" + r']'),
        RegExp(r'file\s*:\s*["' + "'" + r']([^"' + "'" + r']+\.mp4[^"' + "'" + r']*)["' + "'" + r']'),
        RegExp(r'<source[^>]+src=["' + "'" + r']([^"' + "'" + r']+\.mp4[^"' + "'" + r']*)["' + "'" + r']'),
        RegExp(r'https?://[^\s"' + "'" + r'<>]+\.mp4[^\s"' + "'" + r'<>]*'),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(html);
        if (match != null) {
          var videoUrl = match.group(1) ?? match.group(0)!;
          videoUrl = videoUrl.replaceAll(r'\/', '/').replaceAll(r'\', '');

          return {
            'success': true,
            'video_url': videoUrl,
            'server': 'uqload',
            'type': 'mp4',
            'headers': {
              'Referer': 'https://uqload.is/',
              'User-Agent': userAgent,
            },
          };
        }
      }

      return {'error': 'Uqload: source non trouvée'};
    } catch (e) {
      return {'error': 'Uqload: ${e.toString()}'};
    }
  }

  /// Extrait depuis Vidzy
  static Future<Map<String, dynamic>> _extractVidzy(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': userAgent,
          'Referer': url,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return {'error': 'Vidzy: page inaccessible (HTTP ${response.statusCode})'};
      }

      final html = response.body;

      // Unpack eval JS si présent
      final unpacked = _unpackJs(html);
      final searchText = unpacked.isNotEmpty ? unpacked : html;

      // Chercher m3u8
      final m3u8Regex = RegExp(r'https?://[^\s"' + "'" + r'<>]+\.m3u8[^\s"' + "'" + r'<>]*');
      final m3u8Match = m3u8Regex.firstMatch(searchText);
      if (m3u8Match != null) {
        return {
          'success': true,
          'video_url': m3u8Match.group(0)!,
          'server': 'vidzy',
          'type': 'hls',
          'is_hls': true,
          'headers': {
            'Referer': 'https://vidzy.live/',
            'User-Agent': userAgent,
          },
        };
      }

      // Chercher mp4
      final mp4Regex = RegExp(r'https?://[^\s"' + "'" + r'<>]+\.mp4[^\s"' + "'" + r'<>]*');
      final mp4Match = mp4Regex.firstMatch(searchText);
      if (mp4Match != null) {
        return {
          'success': true,
          'video_url': mp4Match.group(0)!,
          'server': 'vidzy',
          'type': 'mp4',
          'headers': {
            'Referer': 'https://vidzy.live/',
            'User-Agent': userAgent,
          },
        };
      }

      return {'error': 'Vidzy: source non trouvée'};
    } catch (e) {
      return {'error': 'Vidzy: ${e.toString()}'};
    }
  }

  /// Extrait depuis Filmoon
  static Future<Map<String, dynamic>> _extractFilemoon(String url) async {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      final codeMatch = RegExp(r'/e/([a-zA-Z0-9]+)').firstMatch(url);

      if (codeMatch == null) {
        return {'error': 'Filmoon: code non trouvé'};
      }

      final code = codeMatch.group(1)!;
      final base = 'https://$host';
      final apiUrl = '$base/api/videos/$code';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'User-Agent': userAgent,
          'Referer': '$base/e/$code',
          'Origin': base,
          'Accept': 'application/json, */*',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return {'error': 'Filmoon: API inaccessible (HTTP ${response.statusCode})'};
      }

      final data = json.decode(response.body);
      if (data == null || !data.containsKey('playback')) {
        return {'error': 'Filmoon: JSON invalide'};
      }

      // Pour Filmoon, on retourne l'URL de l'API car le déchiffrement AES-GCM
      // nécessite des bibliothèques crypto natives
      // L'app devra utiliser le proxy PHP pour le déchiffrement
      return {
        'success': true,
        'video_url': apiUrl,
        'server': 'filmoon',
        'type': 'api',
        'requires_decryption': true,
        'headers': {
          'Referer': '$base/',
          'User-Agent': userAgent,
        },
      };
    } catch (e) {
      return {'error': 'Filmoon: ${e.toString()}'};
    }
  }

  /// Extrait depuis Ninjastream
  static Future<Map<String, dynamic>> _extractNinjastream(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': userAgent,
          'Referer': url,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      );

      if (response.statusCode != 200) {
        return {'error': 'Ninjastream: page inaccessible (HTTP ${response.statusCode})'};
      }

      final html = response.body;

      // Chercher m3u8
      final m3u8Regex = RegExp(r'https?://[^\s"' + "'" + r'<>]+\.m3u8[^\s"' + "'" + r'<>]*');
      final m3u8Match = m3u8Regex.firstMatch(html);
      if (m3u8Match != null) {
        return {
          'success': true,
          'video_url': m3u8Match.group(0)!,
          'server': 'ninjastream',
          'type': 'hls',
          'is_hls': true,
          'headers': {
            'Referer': url,
            'User-Agent': userAgent,
          },
        };
      }

      return {'error': 'Ninjastream: source non trouvée'};
    } catch (e) {
      return {'error': 'Ninjastream: ${e.toString()}'};
    }
  }

  /// Extraction générique
  static Future<Map<String, dynamic>> _extractGeneric(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': userAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      );

      if (response.statusCode != 200) {
        return {'error': 'Generic: page inaccessible (HTTP ${response.statusCode})'};
      }

      final html = response.body;

      // Chercher m3u8
      final m3u8Regex = RegExp(r'https?://[^\s"' + "'" + r'<>]+\.m3u8[^\s"' + "'" + r'<>]*');
      final m3u8Match = m3u8Regex.firstMatch(html);
      if (m3u8Match != null) {
        return {
          'success': true,
          'video_url': m3u8Match.group(0)!,
          'server': 'generic',
          'type': 'hls',
          'is_hls': true,
          'headers': {
            'Referer': url,
            'User-Agent': userAgent,
          },
        };
      }

      // Chercher mp4
      final mp4Regex = RegExp(r'https?://[^\s"' + "'" + r'<>]+\.mp4[^\s"' + "'" + r'<>]*');
      final mp4Match = mp4Regex.firstMatch(html);
      if (mp4Match != null) {
        return {
          'success': true,
          'video_url': mp4Match.group(0)!,
          'server': 'generic',
          'type': 'mp4',
          'headers': {
            'Referer': url,
            'User-Agent': userAgent,
          },
        };
      }

      return {'error': 'Generic: aucune source trouvée'};
    } catch (e) {
      return {'error': 'Generic: ${e.toString()}'};
    }
  }

  /// Unpacks eval(function(p,a,c,k,e,d){...}) JavaScript
  static String _unpackJs(String html) {
    final match = RegExp(
      r"eval\(function\(p,a,c,k,e,d\)\{.*?\}\('(.*?)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'(.*?)'\.split\s*\(\s*'([^']*)'\s*\)",
      dotAll: true,
    ).firstMatch(html);

    if (match == null) return '';

    final p = match.group(1)!;
    final a = int.parse(match.group(2)!);
    final c = int.parse(match.group(3)!);
    final kStr = match.group(4)!;
    final delimiter = match.group(5)!;

    final k = delimiter.isNotEmpty ? kStr.split(delimiter) : <String>[];
    var result = p;

    for (var i = c - 1; i >= 0; i--) {
      if (i < k.length && k[i].isNotEmpty) {
        String word;
        if (a == 36) {
          const digits = '0123456789abcdefghijklmnopqrstuvwxyz';
          var n = i;
          word = '';
          while (n > 0) {
            word = digits[n % 36] + word;
            n = n ~/ 36;
          }
          if (word.isEmpty) word = '0';
        } else {
          word = i.toRadixString(a == 16 ? 16 : (a == 2 ? 2 : 10));
        }

        result = result.replaceAll(RegExp('\\b${RegExp.escape(word)}\\b'), k[i]);
      }
    }

    return result;
  }

  /// Génère une chaîne aléatoire
  static String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }
}
