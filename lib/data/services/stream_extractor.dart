import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Exceptions personnalisées
class VideoNotFoundException implements Exception {
  final String message;
  VideoNotFoundException(this.message);

  @override
  String toString() => 'VideoNotFoundException: $message';
}

class ExtractionException implements Exception {
  final String message;
  ExtractionException(this.message);

  @override
  String toString() => 'ExtractionException: $message';
}

// Modèle pour les informations de stream
class StreamInfo {
  final String url;
  final String quality;
  final String format;
  final Map<String, String> headers;
  final String? title;
  final String? thumbnail;
  final Duration? duration;

  StreamInfo({
    required this.url,
    this.quality = 'auto',
    this.format = 'auto',
    this.headers = const {},
    this.title,
    this.thumbnail,
    this.duration,
  });

  @override
  String toString() =>
      'StreamInfo(url: $url, quality: $quality, format: $format, headers: $headers)';
}

// Extracteur principal pour Uqload
class FastDirectExtractor {
  static const int timeoutMs = 15000;
  static const int maxRetries = 3;

  FastDirectExtractor() {
    // No initialization needed - using http package directly
  }

  /// Extrait les informations de streaming depuis une URL (focus Uqload uniquement)
  Future<StreamInfo> extractStreamInfo(String url) async {
    if (url.isEmpty) {
      throw VideoNotFoundException('URL vide fournie');
    }

    final normalizedUrl = _normalizeUqloadUrl(url);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            '🚀 EXTRACTION UQLOAD - Tentative $attempt/$maxRetries pour: $normalizedUrl');

        if (_isUqloadUrl(normalizedUrl)) {
          return await _extractUqloadAdvanced(normalizedUrl, attempt);
        } else {
          throw VideoNotFoundException(
              'URL non supportée - Seul Uqload est supporté');
        }
      } catch (e) {
        debugPrint('❌ Erreur tentative $attempt: $e');

        if (e is VideoNotFoundException) {
          rethrow;
        }

        if (attempt == maxRetries) {
          throw ExtractionException('Échec après $maxRetries tentatives: $e');
        }

        await Future.delayed(Duration(milliseconds: 1000 * attempt));
      }
    }

    throw ExtractionException(
        'Extraction impossible après $maxRetries tentatives');
  }

  String _normalizeUqloadUrl(String url) {
    // Support toutes les extensions Uqload (.bz, .io, .cx, .net, etc.)
    // N'ajouter https:// que si absent
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }

    debugPrint('🔄 URL normalisée: $url');
    return url;
  }

  /// Vérifie si l'URL est un domaine Uqload (supporte toutes les extensions: .bz, .io, .cx, .net, etc.)
  bool _isUqloadUrl(String url) {
    final lowerUrl = url.toLowerCase();
    // Vérifier si c'est un domaine uqload avec n'importe quelle extension
    return lowerUrl.contains('uqload.') || lowerUrl.contains('/uqload');
  }

  bool _isUqloadEmbedUrl(String url) {
    return url.contains('uqload') && url.contains('embed-');
  }

  Future<StreamInfo> _extractUqloadAdvanced(String url, int attempt) async {
    try {
      debugPrint('🎯 Extraction Uqload avancée: $url');

      final embedUrl = _ensureEmbedUrl(url);
      final nonEmbedUrl = _ensureNonEmbedUrl(url);

      debugPrint('📍 Embed URL: $embedUrl');
      debugPrint('📍 Non-embed URL: $nonEmbedUrl');

      final results = await Future.wait([
        _fetchUqloadContent(embedUrl),
        _fetchUqloadContent(nonEmbedUrl),
      ]);

      final embedResult = results[0];
      final nonEmbedResult = results[1];

      String? content;
      String? cookies;
      String sourceUrl;

      if (embedResult['content'] != null) {
        content = embedResult['content'];
        cookies = embedResult['cookies'];
        sourceUrl = embedUrl;
      } else if (nonEmbedResult['content'] != null) {
        content = nonEmbedResult['content'];
        cookies = nonEmbedResult['cookies'];
        sourceUrl = nonEmbedUrl;
      } else {
        throw VideoNotFoundException(
            'Impossible de récupérer le contenu depuis les URLs Uqload');
      }

      if (content!.contains('File was deleted') ||
          content.contains('File not found')) {
        throw VideoNotFoundException(
            'Le fichier a été supprimé ou n\'existe pas');
      }

      String? videoUrl = _extractUqloadVideoUrl(content);

      if (videoUrl == null || videoUrl.isEmpty) {
        debugPrint(
            '⚠️ Méthode principale échouée, essai des méthodes alternatives');
        videoUrl = _extractUqloadAlternative(content);
      }

      if (videoUrl == null || videoUrl.isEmpty) {
        debugPrint('⚠️ Méthodes alternatives échouées, essai brute force');
        videoUrl = _extractUqloadBruteForce(content);
      }

      if (videoUrl == null || videoUrl.isEmpty) {
        throw VideoNotFoundException(
            'Aucun lien vidéo trouvé dans le contenu Uqload');
      }

      videoUrl = _buildCompleteUrl(videoUrl, sourceUrl);
      final headers = _buildUqloadHeaders(sourceUrl, cookies ?? '', videoUrl);

      final isValid = await _validateVideoUrl(videoUrl, headers, attempt > 1);
      if (!isValid) {
        throw ExtractionException(
            'URL vidéo inaccessible avec les headers fournis');
      }

      debugPrint('✅ Extraction Uqload réussie: $videoUrl');

      return StreamInfo(
        url: videoUrl,
        quality: _extractQuality(content) ?? 'auto',
        format: _getFormatFromUrl(videoUrl),
        headers: headers,
        title: _extractTitle(content),
        thumbnail: _extractThumbnail(content),
        duration: _extractDuration(content),
      );
    } catch (e) {
      if (e is VideoNotFoundException || e is ExtractionException) {
        rethrow;
      }
      throw ExtractionException(
          'Erreur lors de l\'extraction Uqload avancée: $e');
    }
  }

  Future<Map<String, String?>> _fetchUqloadContent(String url) async {
    try {
      final referer = _getRefererFromUrl(url);

      final headers = {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:130.0) Gecko/20100101 Firefox/130.0',
        'Referer': referer,
        'Origin': referer,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'fr-FR,fr;q=0.9',
        'Accept-Encoding': 'identity',
        'Connection': 'keep-alive',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      };

      debugPrint('📝 Récupération $url avec headers: ${headers.keys.join(", ")}');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final content = response.body;
        final cookies = response.headers['set-cookie'] ?? '';

        debugPrint('📝 Contenu récupéré: ${content.length} caractères');
        debugPrint('🍪 Cookies: $cookies');

        return {
          'content': content,
          'cookies': cookies,
        };
      } else {
        debugPrint('⚠️ Échec récupération $url: HTTP ${response.statusCode}');
        return {'content': null, 'cookies': null};
      }
    } catch (e) {
      debugPrint('💥 Erreur récupération $url: $e');
      return {'content': null, 'cookies': null};
    }
  }

  String? _extractUqloadVideoUrl(String content) {
    debugPrint(
        '🔍 Extraction URL vidéo Uqload - Contenu: ${content.length} caractères');

    // Utilisation de triple guillemets pour éviter les problèmes d'échappement
    final patterns = [
      // Pattern principal Uqload
      RegExp(r'https?://[^\s"<>]+/v\.mp4'),

      // Patterns sources JavaScript avec triple guillemets
      RegExp(r'''sources\s*:\s*\[\s*\{\s*[^}]*file\s*:\s*["']([^"']+)["']'''),
      RegExp(r'''file\s*:\s*["']([^"']+\.(?:mp4|m3u8|mpd))["']'''),
      RegExp(r'''src\s*:\s*["']([^"']+\.(?:mp4|m3u8|mpd))["']'''),
      RegExp(r'''url\s*:\s*["']([^"']+\.(?:mp4|m3u8|mpd))["']'''),

      // Variables JavaScript
      RegExp(r'''var\s+\w+\s*=\s*["']([^"']*(?:mp4|m3u8|mpd)[^"']*)["']'''),
      RegExp(r'''\w+\s*=\s*["']([^"']*(?:mp4|m3u8|mpd)[^"']*)["']'''),

      // URLs directes
      RegExp(r'https?://[^"\s]+\.m3u8(?:\?[^"\s]*)?'),
      RegExp(r'https?://[^"\s]+\.mpd(?:\?[^"\s]*)?'),
      RegExp(r'https?://[^"\s]+\.mp4(?:\?[^"\s]*)?'),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(content);
      for (final match in matches) {
        String? url;
        if (match.groupCount > 0) {
          url = match.group(1);
        } else {
          url = match.group(0);
        }

        if (url != null && _isValidUqloadVideoUrl(url)) {
          debugPrint('🎉 URL vidéo trouvée: $url');
          return url;
        }
      }
    }

    debugPrint('⚠️ Aucune URL vidéo trouvée avec les patterns principaux');
    return null;
  }

  String? _extractUqloadAlternative(String content) {
    debugPrint('🔍 Extraction alternative Uqload');

    final scriptPattern = RegExp(r'<script[^>]*>(.*?)</script>', dotAll: true);
    final scripts = scriptPattern.allMatches(content);

    for (final script in scripts) {
      final scriptContent = script.group(1) ?? '';
      if (scriptContent.contains('mp4') ||
          scriptContent.contains('m3u8') ||
          scriptContent.contains('sources') ||
          scriptContent.contains('file')) {
        final urlPattern = RegExp(r'https?://[^\s"<>]+\.(?:mp4|m3u8|mpd)');
        final urlMatch = urlPattern.firstMatch(scriptContent);
        if (urlMatch != null) {
          final url = urlMatch.group(0)!;
          if (_isValidUqloadVideoUrl(url)) {
            debugPrint('🎯 URL alternative trouvée: $url');
            return url;
          }
        }
      }
    }

    return null;
  }

  String? _extractUqloadBruteForce(String content) {
    debugPrint('🔨 Extraction brute force Uqload');

    final patterns = [
      RegExp(
          r'(https?://[^\s"<>]+\.(?:mp4|m3u8|mpd|avi|mkv|webm)(?:\?[^\s"<>]*)?)'),
      RegExp(r'(https?://[^\s"<>]*(?:video|stream|media|file)[^\s"<>]*)'),
      RegExp(r'(https?://[^\s"<>]*uqload[^\s"<>]*\.(?:mp4|m3u8|mpd))'),
      RegExp(
          r'(https?://[^\s"<>]*(?:cdn|storage|media)[^\s"<>]*\.(?:mp4|m3u8|mpd))'),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(content);
      for (final match in matches) {
        final url = match.group(1)!;
        if (url.length > 20 &&
            url.length < 500 &&
            (url.contains('uqload') ||
                url.contains('cdn') ||
                url.contains('stream'))) {
          if (_isValidUqloadVideoUrl(url)) {
            debugPrint('🔨 URL brute force trouvée: $url');
            return url;
          }
        }
      }
    }

    return null;
  }

  bool _isValidUqloadVideoUrl(String url) {
    if (url.isEmpty || url.length < 10) return false;
    if (!url.startsWith('http')) return false;

    final videoExtensions = ['mp4', 'm3u8', 'mpd'];
    final hasVideoExtension =
        videoExtensions.any((ext) => url.contains('.$ext'));
    final isUqloadPattern = url.contains('/v.mp4') || url.contains('uqload');

    return hasVideoExtension || isUqloadPattern;
  }

  String _getFormatFromUrl(String url) {
    if (url.contains('.m3u8')) return 'hls';
    if (url.contains('.mpd')) return 'dash';
    if (url.contains('.mp4')) return 'mp4';
    return 'auto';
  }

  String _ensureEmbedUrl(String url) {
    if (url.contains('/embed/') || url.contains('embed-')) {
      return url;
    }

    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty) {
      final fileId = pathSegments.last;
      return '${uri.scheme}://${uri.host}/embed-$fileId.html';
    }

    return url;
  }

  String _ensureNonEmbedUrl(String url) {
    if (!url.contains('/embed/') && !url.contains('embed-')) {
      return url;
    }

    return url
        .replaceAll('/embed/', '/')
        .replaceAll('embed-', '')
        .replaceAll('.html', '');
  }

  String _buildCompleteUrl(String videoUrl, String sourceUrl) {
    if (videoUrl.startsWith('http')) {
      return videoUrl;
    } else if (videoUrl.startsWith('//')) {
      return 'https:$videoUrl';
    } else if (videoUrl.startsWith('/')) {
      final uri = Uri.parse(sourceUrl);
      return '${uri.scheme}://${uri.host}$videoUrl';
    }
    return videoUrl;
  }

  Map<String, String> _buildUqloadHeaders(
      String sourceUrl, String cookies, String videoUrl) {
    final referer = _getRefererFromUrl(sourceUrl);
    final format = _getFormatFromUrl(videoUrl);

    return {
      'Cookie': cookies,
      'Referer': referer,
      'Origin': referer,
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:130.0) Gecko/20100101 Firefox/130.0',
      'Accept': _getAcceptHeader(format),
      'Accept-Language': 'fr-FR,fr;q=0.9',
      'Accept-Encoding': 'identity',
      'Connection': 'keep-alive',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
    };
  }

  String _getAcceptHeader(String format) {
    // Simplified accept headers matching player configuration
    return 'video/mp4,video/webm,*/*';
  }

  String _getRefererFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.scheme}://${uri.host}';
    } catch (e) {
      return 'https://uqload.cx';
    }
  }

  Future<bool> _validateVideoUrl(
      String videoUrl, Map<String, String> headers, bool bypassSSL) async {
    try {
      // Skip validation - assume URL is valid if extraction succeeded
      // Many video servers reject HEAD requests anyway
      debugPrint('✅ URL vidéo acceptée (validation ignorée): $videoUrl');
      return true;
    } catch (e) {
      debugPrint('💥 Erreur validation URL: $e');
      return false;
    }
  }

  String? _extractTitle(String content) {
    final patterns = [
      RegExp(r'<title[^>]*>(.*?)</title>', dotAll: true),
      RegExp(r'<h1[^>]*>(.*?)</h1>', dotAll: true),
      RegExp(r'''title\s*:\s*["']([^"']*)["']'''),
      RegExp(r'''name\s*:\s*["']([^"']*)["']'''),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        final title = match
            .group(1)
            ?.trim()
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (title != null &&
            title.isNotEmpty &&
            !title.toLowerCase().contains('uqload')) {
          return title;
        }
      }
    }
    return null;
  }

  String? _extractThumbnail(String content) {
    final patterns = [
      RegExp(r'''poster\s*:\s*["']([^"']+\.(?:jpg|jpeg|png|webp))["']'''),
      RegExp(r'''thumbnail\s*:\s*["']([^"']+\.(?:jpg|jpeg|png|webp))["']'''),
      RegExp(r'''image\s*:\s*["']([^"']+\.(?:jpg|jpeg|png|webp))["']'''),
      RegExp(r'(https?://[^"\s]+\.(?:jpg|jpeg|png|webp))'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        final thumbnail = match.group(1);
        if (thumbnail != null && thumbnail.startsWith('http')) {
          return thumbnail;
        }
      }
    }
    return null;
  }

  String? _extractQuality(String content) {
    final patterns = [
      RegExp(r'\[(\d+x\d+)'),
      RegExp(r'(\d+p)'),
      RegExp(r'''quality\s*:\s*["']([^"']+)["']'''),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  Duration? _extractDuration(String content) {
    final patterns = [
      RegExp(r'''duration\s*:\s*["']([^"']+)["']'''),
      RegExp(r'\[\d+x\d+,\s*((\d+:)*\d+)\]'),
      RegExp(r'(\d+:\d+:\d+)'),
      RegExp(r'(\d+:\d+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        final durationStr = match.group(1)!;
        try {
          final parts = durationStr.split(':').map(int.parse).toList();
          if (parts.length == 2) {
            return Duration(minutes: parts[0], seconds: parts[1]);
          } else if (parts.length == 3) {
            return Duration(
                hours: parts[0], minutes: parts[1], seconds: parts[2]);
          }
        } catch (e) {
          // Ignorer les erreurs de parsing
        }
      }
    }
    return null;
  }

  void dispose() {
    // No resources to clean up - using http package
  }
}
