import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AnimeExtractor {
  static const Duration _timeout = Duration(seconds: 10);
  
  static final Map<String, String> _browserHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'fr-FR,fr;q=0.9',
    'Connection': 'keep-alive',
    'Referer': 'https://anime-sama.to/',
  };

  static Future<Map<String, dynamic>> extract(String url) async {
    try {
      debugPrint('[AnimeExtractor] Extraction: $url');
      
      final extractor = _getExtractorForUrl(url);
      if (extractor == null) {
        return {'success': false, 'error': 'Type non supporté', 'url': url};
      }
      
      final result = await extractor(url);
      
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
  
  static Future<Map<String, dynamic>> extractFromMultipleSources(
    List<Map<String, String>> sources,
  ) async {
    debugPrint('[AnimeExtractor] Essai de ${sources.length} sources');
    
    final sortedSources = List<Map<String, String>>.from(sources);
    sortedSources.sort((a, b) {
      final playerA = (a['player'] ?? '').toLowerCase();
      final playerB = (b['player'] ?? '').toLowerCase();
      
      if (playerA == 'sibnet') return -1;
      if (playerB == 'sibnet') return 1;
      if (playerA == 'sendvid') return -1;
      if (playerB == 'sendvid') return 1;
      return 0;
    });
    
    for (final source in sortedSources) {
      final url = source['url'];
      final player = source['player'];
      
      if (url == null || url.isEmpty) continue;
      
      debugPrint('[AnimeExtractor] Essai: $player');
      final result = await extract(url);
      
      if (result['success'] == true) {
        result['tried_player'] = player;
        return result;
      }
    }
    
    return {'success': false, 'error': 'Aucune source extraite', 'tried_count': sources.length};
  }

  static Future<Map<String, dynamic>> Function(String)? _getExtractorForUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    
    final host = uri.host.toLowerCase();
    
    if (host.contains('sibnet')) return _extractSibnet;
    if (host.contains('sendvid')) return _extractSendvid;
    if (host.contains('vidmoly')) return _extractVidmoly;
    if (host.contains('oneupload')) return _extractOneupload;
    if (host.contains('movearnpre')) return _extractMovearnpre;
    
    return _extractGeneric;
  }

  static Future<Map<String, dynamic>> _extractSibnet(String url) async {
    try {
      final response = await http.get(Uri.parse(url), headers: _browserHeaders).timeout(_timeout);
      final html = response.body;
      
      final srcMatch = RegExp(r'src:\s*"([^"]+\.mp4)"').firstMatch(html);
      if (srcMatch != null) {
        var videoUrl = srcMatch.group(1)!;
        if (videoUrl.startsWith('/')) {
          videoUrl = 'https://video.sibnet.ru$videoUrl';
        }
        return {'success': true, 'video_url': videoUrl, 'type': 'mp4', 'extractor': 'sibnet'};
      }
      
      return {'success': false, 'error': 'Lien non trouvé (Sibnet)'};
    } catch (e) {
      return {'success': false, 'error': 'Erreur Sibnet: $e'};
    }
  }

  static Future<Map<String, dynamic>> _extractSendvid(String url) async {
    try {
      final response = await http.get(Uri.parse(url), headers: _browserHeaders).timeout(_timeout);
      final html = response.body;
      
      final srcMatch = RegExp(r'<source\s+src="([^"]+\.mp4[^"]*)"').firstMatch(html);
      if (srcMatch != null) {
        return {'success': true, 'video_url': srcMatch.group(1)!, 'type': 'mp4', 'extractor': 'sendvid'};
      }
      
      final ogMatch = RegExp(r'<meta\s+property="og:video"\s+content="([^"]+)"').firstMatch(html);
      if (ogMatch != null) {
        return {'success': true, 'video_url': ogMatch.group(1)!, 'type': 'mp4', 'extractor': 'sendvid'};
      }
      
      return {'success': false, 'error': 'Lien non trouvé (Sendvid)'};
    } catch (e) {
      return {'success': false, 'error': 'Erreur Sendvid: $e'};
    }
  }

  static Future<Map<String, dynamic>> _extractVidmoly(String url) async {
    try {
      final idMatch = RegExp(r'embed-([^.]+)\.html').firstMatch(url);
      if (idMatch != null) {
        final videoId = idMatch.group(1)!;
        
        try {
          final apiUrl = 'https://vidmoly.to/api/source/$videoId';
          final apiResponse = await http.post(
            Uri.parse(apiUrl),
            headers: {..._browserHeaders, 'Content-Type': 'application/json'},
          ).timeout(Duration(seconds: 5));
          
          if (apiResponse.statusCode == 200) {
            final data = apiResponse.body;
            final urlPattern = RegExp(r'https?://[^\s"<>]+\.(m3u8|mp4)[^\s"<>]*');
            final urlMatch = urlPattern.firstMatch(data);
            if (urlMatch != null) {
              final videoUrl = urlMatch.group(0)!;
              final type = videoUrl.contains('.m3u8') ? 'hls' : 'mp4';
              return {'success': true, 'video_url': videoUrl, 'type': type, 'extractor': 'vidmoly_api'};
            }
          }
        } catch (_) {}
      }
      
      final response = await http.get(Uri.parse(url), headers: _browserHeaders).timeout(_timeout);
      final html = response.body;
      
      if (html.contains('window.location') && html.contains('redirect')) {
        return {'success': false, 'error': 'Vidmoly: Anti-bot actif', 'needs_browser': true};
      }
      
      final patterns = [
        RegExp(r'sources:\s*\[{[^}]*file:\s*"([^"]+)"', caseSensitive: false),
        RegExp(r'"file":\s*"([^"]+\.(m3u8|mp4)[^"]*)"', caseSensitive: false),
        RegExp(r'https?://[^\s"<>]+\.m3u8[^\s"<>]*', caseSensitive: false),
        RegExp(r'https?://[^\s"<>]+\.mp4[^\s"<>]*', caseSensitive: false),
      ];
      
      for (final pattern in patterns) {
        final match = pattern.firstMatch(html);
        if (match != null) {
          var videoUrl = match.group(1) ?? match.group(0)!;
          videoUrl = videoUrl.replaceAll(r'\/', '/');
          
          if (videoUrl.startsWith('http') && videoUrl.length > 20) {
            final type = videoUrl.contains('.m3u8') ? 'hls' : 'mp4';
            return {'success': true, 'video_url': videoUrl, 'type': type, 'extractor': 'vidmoly_html'};
          }
        }
      }
      
      return {'success': false, 'error': 'Vidmoly: Lien non trouvé', 'needs_browser': true};
    } catch (e) {
      return {'success': false, 'error': 'Erreur Vidmoly: $e'};
    }
  }

  static Future<Map<String, dynamic>> _extractOneupload(String url) async {
    return _extractGeneric(url, 'oneupload');
  }

  static Future<Map<String, dynamic>> _extractMovearnpre(String url) async {
    return _extractGeneric(url, 'movearnpre');
  }

  static Future<Map<String, dynamic>> _extractGeneric(String url, [String extractor = 'generic']) async {
    try {
      final response = await http.get(Uri.parse(url), headers: _browserHeaders).timeout(_timeout);
      final html = response.body;
      
      final patterns = [
        RegExp(r'https?://[^"<>\s]+\.m3u8[^"<>\s]*', caseSensitive: false),
        RegExp(r'https?://[^"<>\s]+\.mp4[^"<>\s]*', caseSensitive: false),
        RegExp(r'"file":\s*"([^"]+)"', caseSensitive: false),
        RegExp(r"'file':\s*'([^']+)'", caseSensitive: false),
        RegExp(r'source[^>]+src="([^"]+)"', caseSensitive: false),
        RegExp(r'video[^>]+src="([^"]+)"', caseSensitive: false),
        RegExp(r'<meta\s+property="og:video"\s+content="([^"]+)"', caseSensitive: false),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(html);
        if (match != null) {
          var videoUrl = match.group(1) ?? match.group(0)!;
          videoUrl = videoUrl.replaceAll(r'\/', '/');
          
          if (videoUrl.length < 10 || !videoUrl.startsWith('http')) continue;
          
          final type = videoUrl.contains('.m3u8') ? 'hls' : 'mp4';
          return {'success': true, 'video_url': videoUrl, 'type': type, 'extractor': extractor};
        }
      }

      return {'success': false, 'error': 'Aucun lien trouvé', 'extractor': extractor};
    } catch (e) {
      return {'success': false, 'error': 'Erreur $extractor: $e'};
    }
  }
}
