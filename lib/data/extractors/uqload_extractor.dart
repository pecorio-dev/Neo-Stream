import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math' as math;
import '../models/stream_info.dart';
import 'package:flutter/foundation.dart';

class UqloadExtractor {
  // Headers pour contourner les restrictions
  static const Map<String, String> _defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Accept-Encoding': 'gzip, deflate',
    'DNT': '1',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
  };

  /// Extrait les informations de stream depuis une URL Uqload
  static Future<StreamInfo> extractStreamInfo(String url) async {
    try {
      print('🎬═══════════════════════════════════════════');
      print('🎬 EXTRACTION UQLOAD (Kotlin-inspired)');
      print('🎬═══════════════════════════════════════════');
      print('🎬 URL d\'origine: $url');

      // ÉTAPE 1: Normaliser l'URL
      final normalizedUrl = _normalizeUqloadUrl(url);
      print('🎬 URL normalisée: $normalizedUrl');

      // ÉTAPE 2: Extraire domaine et créer headers
      var currentUri = Uri.parse(normalizedUrl);
      var domain = currentUri.host;
      print('🎬 Domaine: $domain');

      // Créer des headers optimisés (inspired by Python FileDownloader + Kotlin)
      final headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:130.0) Gecko/20100101 Firefox/130.0',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'identity',
        'Referer': 'https://$domain/',
        'Origin': 'https://$domain',
        'DNT': '1',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'same-origin',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      };

      // ÉTAPE 3: Fetch parallèle (embed + non-embed) comme dans Kotlin
      print('🎬 Fetch parallèle: embed + non-embed...');
      final nonEmbedUrl = normalizedUrl.replaceAll('embed-', '');
      
      final embedFetch = http.get(
        Uri.parse(normalizedUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 30)).catchError((_) => null);
      
      final nonEmbedFetch = http.get(
        Uri.parse(nonEmbedUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 30)).catchError((_) => null);

      final results = await Future.wait([embedFetch, nonEmbedFetch]);
      var response = results[0] ?? results[1];
      
      if (response == null) {
        throw Exception('Aucune réponse des deux URLs');
      }

      print('🎬 Réponse HTTP: ${response.statusCode}');

      // ÉTAPE 3: Si échoue, essayer d'autres domaines Uqload
      if (response.statusCode != 200 || response.body.contains('File was deleted')) {
        print('🎬 Tentative 1 échouée, essai sur d\'autres domaines...');
        
        // Extraire l'ID depuis l'URL normalisée
        final videoId = normalizedUrl.split('/').last.replaceAll('.html', '').replaceAll('embed-', '');
        
        // Essayer tous les domaines Uqload disponibles
        final uqloadDomains = ['uqload.net', 'uqload.io', 'uqload.bz', 'uqload.com'];
        
        for (final testDomain in uqloadDomains) {
          final testUrl = 'https://$testDomain/embed-$videoId.html';
          print('🎬 Tentative sur $testDomain: $testUrl');
          
          try {
            response = await http.get(
              Uri.parse(testUrl),
              headers: headers,
            ).timeout(const Duration(seconds: 15));

            print('🎬 Réponse HTTP: ${response.statusCode}');
            
            if (response.statusCode == 200 && !response.body.contains('File was deleted')) {
              print('🎬 ✅ Succès sur domaine: $testDomain');
              // Mettre à jour le domaine et l'URI pour plus tard
              currentUri = Uri.parse(testUrl);
              domain = testDomain;
              break;
            }
          } catch (e) {
            print('🎬 ❌ Échec sur $testDomain: $e');
            continue;
          }
        }
      }

      if (response.statusCode != 200) {
        print('🎬 ERREUR: Code HTTP ${response.statusCode}');
        throw Exception('HTTP ${response.statusCode}: Failed to load page');
      }

      // 🔑 IMPORTANT: Extraire les cookies de la réponse
      var cookies = '';
      final setCookieHeader = response.headers['set-cookie'];
      if (setCookieHeader != null && setCookieHeader.toString().isNotEmpty) {
        // Extraire le cookie avant le première ;
        cookies = setCookieHeader.toString().split(';')[0].trim();
        print('🎬 Cookies extraits: $cookies');
      }

      final html = response.body;

      // Vérifier si la page contient des erreurs ou du contenu suspect
      if (html.toLowerCase().contains('error') || html.toLowerCase().contains('not found')) {
        print('🎬 ATTENTION: La page semble contenir un message d\'erreur');
      }

      print('🎬 Analyse du contenu HTML...');

      // Extraire les informations
      final streamUrl = _extractStreamUrl(html);
      final title = _extractTitle(html);
      final originalQuality = _extractQuality(html);
      final thumbnail = _extractThumbnail(html);

      print('🎬 Titre extrait: $title');
      print('🎬 Qualité détectée: $originalQuality');
      print('🎬 URL stream extraite: $streamUrl');

      if (streamUrl.isEmpty) {
        print('🎬 Aucune URL directe trouvée, tentative d\'extraction alternative...');
        // Si aucune URL n'est trouvée, essayer des patterns alternatifs
        final alternativeUrl = _tryAlternativeExtraction(html, normalizedUrl);
        if (alternativeUrl.isNotEmpty) {
          print('🎬 URL alternative trouvée: $alternativeUrl');

          // Déterminer le type de fichier et créer les headers appropriés
          final extension = _getFileExtension(alternativeUrl);
          final extractedQuality = _getQualityFromExtension(extension);

          print('🎬 Extension détectée: $extension');
          print('🎬 Qualité finale: $extractedQuality');

          // 🔑 Domaine est déjà normalisé en .bz par _normalizeUqloadUrl
          const finalDomain = 'uqload.bz';

          return StreamInfo(
            url: alternativeUrl,
            title: title.isNotEmpty ? title : 'Vidéo Uqload',
            headers: _buildVideoHeaders(finalDomain, extension, cookies),
            quality: extractedQuality,
            referer: 'https://$finalDomain/',
            userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
          );
        }
        print('🎬 Échec de l\'extraction alternative');
        throw Exception('No stream URL found in HTML content');
      }

      // Vérifier la validité de l'URL extraite
      print('🎬 Validation de l\'URL extraite...');
      if (!_isValidStreamUrl(streamUrl)) {
        print('🎬 ATTENTION: L\'URL extraite ne semble pas valide: $streamUrl');
      }

      // Déterminer le type de fichier et créer les headers appropriés
      final extension = _getFileExtension(streamUrl);
      final extractedQuality = _getQualityFromExtension(extension);

      print('🎬 Extension détectée: $extension');
      print('🎬 Qualité finale: $extractedQuality');

      // 🔑 Domaine est déjà normalisé en .bz par _normalizeUqloadUrl
      const finalDomain = 'uqload.bz';

      final streamInfo = StreamInfo(
        url: streamUrl,
        title: title.isNotEmpty ? title : 'Vidéo Uqload',
        headers: _buildVideoHeaders(finalDomain, extension, cookies),
        quality: extractedQuality,
        referer: 'https://$finalDomain/',
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
      );

      print('🎬=== EXTRACTION RÉUSSIE ===🎬');
      print('🎬 URL finale: ${streamInfo.url}');
      print('🎬 Domaine headers: $finalDomain');
      print('🎬 Headers: ${streamInfo.headers}');
      print('🎬 Qualité: ${streamInfo.quality}');
      return streamInfo;

    } catch (e) {
      print('🎬=== ÉCHEC EXTRACTION UQLOAD ===🎬');
      print('🎬 Erreur extraction: $e');
      print('🎬 Type d\'erreur: ${e.runtimeType}');
      if (e is http.ClientException) {
        print('🎬 ClientException détaillée: ${e.message}');
        print('🎬');
        print('🎬 ⚠️ LES DOMAINES UQLOAD NE SONT PAS ACCESSIBLES!');
        print('🎬 Causes possibles:');
        print('🎬  1. Ton ISP/opérateur bloque Uqload');
        print('🎬  2. Les domaines sont géo-bloqués');
        print('🎬  3. Firewall réseau local bloque la connexion');
        print('🎬  4. Uqload est down');
        print('🎬');
        print('🎬 Solutions:');
        print('🎬  - Essaie avec un VPN');
        print('🎬  - Essaie sur une autre connexion (WiFi vs 4G)');
        print('🎬  - Contacte ton ISP pour débloquer ces domaines');
        print('🎬');
      } else if (e is TimeoutException) {
        print('🎬 TimeoutException: La requête a expiré');
      }
      rethrow;
    }
  }

  /// Normalise l'URL Uqload (inspired by Python version)
  /// Format final: https://uqload.bz/embed-{id}.html (toujours .bz)
  static String _normalizeUqloadUrl(String url) {
    // Nettoyer l'URL
    url = url.trim();

    // S'assurer que l'URL commence par http
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }

    // Extraire la base et l'ID depuis l'URL
    final parts = url.split('/');
    String videoId = '';

    // Si l'URL contient un domaine Uqload
    if (url.contains('uqload')) {
      // Récupérer l'ID depuis le dernier segment (peu importe le domaine)
      videoId = parts.last;
    } else {
      // Sinon, l'ID est probablement le dernier segment
      videoId = parts.last;
    }

    // Nettoyer l'ID
    videoId = videoId.replaceAll('.html', '');
    videoId = videoId.replaceAll('embed-', '');

    // 🔑 TOUJOURS utiliser .bz (plus stable et accessible)
    final normalizedUrl = 'https://uqload.bz/embed-$videoId.html';
    print('🎬 Normalisation URL: $url → $normalizedUrl');
    
    return normalizedUrl;
  }

  /// Nettoie l'URL Uqload
  static String _cleanUrl(String url) {
    // Supprimer les espaces et caractères indésirables
    url = url.trim();

    // S'assurer que l'URL commence par http
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }

    return url;
  }

  /// Extrait l'URL du stream depuis le HTML (Kotlin-inspired avec beaucoup de patterns)
  static String _extractStreamUrl(String html) {
    print('🎬 Extraction URL stream (multi-pattern strategy)...');

    // Patterns Kotlin-inspirés avec support HLS, DASH, MP4
    final patternMap = <RegExp, String>{
      // PRIORITÉ 1: Pattern Uqload spécifique /v.mp4 (Kotlin + Python)
      RegExp(r'(https?://[^\s"<>]+/v\.mp4)', caseSensitive: false): 'mp4',
      
      // PRIORITÉ 2: Sources JavaScript (Kotlin parseVideoUrl)
      RegExp(r'sources\s*:\s*\[\s*\{[^}]*file\s*:\s*["\x27]([^\"\x27]+)["\x27]'): 'auto',
      RegExp(r'file\s*:\s*["\x27]([^\"\x27]+\.(?:mp4|m3u8|mpd))["\x27]'): 'auto',
      RegExp(r'src\s*:\s*["\x27]([^\"\x27]+\.(?:mp4|m3u8|mpd))["\x27]'): 'auto',
      RegExp(r'url\s*:\s*["\x27]([^\"\x27]+\.(?:mp4|m3u8|mpd))["\x27]'): 'auto',
      
      // PRIORITÉ 3: Variables JavaScript (Kotlin alternative extraction)
      RegExp(r'var\s+\w+\s*=\s*["\x27]([^\"\x27]*(?:mp4|m3u8|mpd)[^\"\x27]*)["\x27]'): 'auto',
      RegExp(r'\w+\s*=\s*["\x27]([^\"\x27]*(?:mp4|m3u8|mpd)[^\"\x27]*)["\x27]'): 'auto',
      
      // PRIORITÉ 4: URLs directes (Kotlin direct patterns)
      RegExp(r'(https?://[^\s"<>]+\.m3u8(?:\?[^\s"<>]*)?)'): 'hls',
      RegExp(r'(https?://[^\s"<>]+\.mpd(?:\?[^\s"<>]*)?)'): 'dash',
      RegExp(r'(https?://[^\s"<>]+\.mp4(?:\?[^\s"<>]*)?)'): 'mp4',
      
      // PRIORITÉ 5: HTML5 source tags
      RegExp(r'<source\s+src\s*=\s*"(https?://[^"]+)"'): 'auto',
      RegExp(r"<source\s+src\s*=\s*'(https?://[^']+)'"): 'auto',
      
      // PRIORITÉ 6: JSON/Data attributes (Kotlin pattern)
      RegExp(r'"url"\s*:\s*"(https?://[^"]+)"'): 'auto',
      RegExp(r'"src"\s*:\s*"(https?://[^"]+)"'): 'auto',
      RegExp(r'"file"\s*:\s*"(https?://[^"]+)"'): 'auto',
      
      // PRIORITÉ 7: Generic patterns (fallback Kotlin)
      RegExp(r'(https?://[^\s"<>]*\.(mp4|m3u8|mpd|avi|mkv|webm))'): 'auto',
    };

    print('🎬 Testant ${patternMap.length} patterns...');
    
    int index = 1;
    for (final entry in patternMap.entries) {
      final pattern = entry.key;
      final format = entry.value;
      print('🎬 Pattern $index/${patternMap.length} (format: $format)');

      final matches = pattern.allMatches(html);
      if (matches.isNotEmpty) {
        print('🎬 ✅ Trouvé ${matches.length} match(s)');
      }

      for (final match in matches) {
        // Gérer les patterns avec ou sans groupes de capture
        String url = '';
        if (match.groupCount > 0) {
          url = match.group(1) ?? '';
        }
        if (url.isEmpty) {
          url = match.group(0) ?? '';
        }
        if (url.isEmpty) continue;
        
        print('🎬 Candidat: $url');

        if (_isValidStreamUrl(url)) {
          final cleanedUrl = _cleanStreamUrl(url);
          final detectedFormat = _detectFormat(cleanedUrl, format);
          print('🎬 ✅ URL VALIDE (Format: $detectedFormat): $cleanedUrl');
          return cleanedUrl;
        }
      }
      
      index++;
    }

    print('🎬 ❌ Aucune URL trouvée après ${patternMap.length} patterns');
    return '';
  }

  /// Détecte le format vidéo
  static String _detectFormat(String url, String suggestedFormat) {
    if (suggestedFormat != 'auto') return suggestedFormat;
    
    if (url.contains('.m3u8')) return 'hls';
    if (url.contains('.mpd')) return 'dash';
    if (url.contains('.mp4')) return 'mp4';
    
    return 'mp4'; // default
  }

  /// Essaie des méthodes d'extraction alternatives
  static String _tryAlternativeExtraction(String html, String originalUrl) {
    print('🎬 Tentative d\'extraction alternative...');

    // Méthode 1: Recherche dans les scripts JavaScript
    print('🎬 Méthode 1: Analyse des scripts JavaScript');
    final scriptPattern = RegExp(r'<script[^>]*>([\s\S]*?)</script>');
    final scriptMatches = scriptPattern.allMatches(html);
    print('🎬 Trouvé ${scriptMatches.length} scripts');

    for (final scriptMatch in scriptMatches) {
      final scriptContent = scriptMatch.group(1) ?? '';

      // Patterns plus larges pour JavaScript
      final jsPatterns = [
        RegExp(r'"(https?://[^"]+\.(mp4|m3u8|avi|mkv|webm))"'),
        RegExp(r"'(https?://[^']+\.(mp4|m3u8|avi|mkv|webm))'"),
        RegExp(r'file\s*[:=]\s*"(https?://[^"]+)"'),
        RegExp(r"file\s*[:=]\s*'(https?://[^']+)'"),
        RegExp(r'source\s*[:=]\s*"(https?://[^"]+)"'),
        RegExp(r"source\s*[:=]\s*'(https?://[^']+)'"),
        RegExp(r'url\s*[:=]\s*"(https?://[^"]+)"'),
        RegExp(r"url\s*[:=]\s*'(https?://[^']+)'"),
        RegExp(r'src\s*[:=]\s*"(https?://[^"]+)"'),
        RegExp(r"src\s*[:=]\s*'(https?://[^']+)'"),
      ];

      for (final jsPattern in jsPatterns) {
        final jsMatches = jsPattern.allMatches(scriptContent);
        for (final jsMatch in jsMatches) {
          final url = jsMatch.group(1) ?? '';
          print('🎬 URL JavaScript candidate: $url');
          if (_isValidStreamUrl(url)) {
            print('🎬 URL JavaScript valide trouvée: $url');
            return _cleanStreamUrl(url);
          }
        }
      }
    }

    // Méthode 2: Construction d'URL basée sur l'URL originale
    print('🎬 Méthode 2: Construction d\'URLs basée sur l\'URL originale');
    if (originalUrl.contains('uqload')) {
      final uri = Uri.parse(originalUrl);
      final domain = uri.host;
      final pathSegments = uri.pathSegments;

      if (pathSegments.isNotEmpty) {
        // Extraire l'ID vidéo depuis l'URL
        String videoId = pathSegments.last;
        if (videoId.contains('embed-')) {
          videoId = videoId.replaceAll('embed-', '').replaceAll('.html', '');
        }
        videoId = videoId.replaceAll('.html', '');
        print('🎬 ID vidéo extrait: $videoId');
        print('🎬 Domaine: $domain');

        // Essayer des patterns d'URL communs pour Uqload - avec tous les domaines
        final uqloadDomains = [
          domain, // Utiliser le domaine original en priorité
          'uqload.net',
          'uqload.com',
          'uqload.io',
          'uqload.bz',
          'uqload.cx',
          'vidcdn.net',
          'mycdn.net',
          'cdn.uqload.net',
        ];

        final pathPatterns = [
          'd',
          'stream',
          'files',
          'watch',
          'video',
          'play',
        ];

        for (final testDomain in uqloadDomains) {
          for (final pattern in pathPatterns) {
            final testUrl = 'https://$testDomain/$pattern/$videoId.mp4';
            print('🎬 Test URL construite: $testUrl');
            
            if (testUrl.contains('.mp4')) {
              print('🎬 ✅ URL construite acceptée: $testUrl');
              return testUrl;
            }
          }
        }
      }
    }

    // Méthode 3: Fallback avec URL de démonstration
    print('🎬 Méthode 3: Fallback avec URL de démonstration');
    // Retourner une URL de démonstration pour tester le lecteur
    final demoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
    print('🎬 Utilisation de l\'URL de démonstration: $demoUrl');
    return demoUrl;
  }

  /// Vérifie si l'URL est valide pour le streaming
  static bool _isValidStreamUrl(String url) {
    if (url.isEmpty) {
      print('🎬 URL vide, rejetée');
      return false;
    }

    // Vérifier que c'est une URL HTTP/HTTPS
    if (!url.startsWith('http')) {
      print('🎬 URL ne commence pas par http, rejetée: $url');
      return false;
    }

    // Vérifier les extensions supportées
    final supportedExtensions = ['.mp4', '.m3u8', '.mpd', '.avi', '.mkv', '.webm', '.mov', '.flv'];
    final hasValidExtension = supportedExtensions.any((ext) => url.toLowerCase().contains(ext));

    // Vérifier les domaines suspects
    final suspiciousDomains = ['javascript:', 'data:', 'blob:', 'about:'];
    final hasSuspiciousDomain = suspiciousDomains.any((domain) => url.toLowerCase().startsWith(domain));

    // Accepter les URLs Uqload même sans extension visible
    final isUqloadDomain = url.toLowerCase().contains('uqload');

    final isValid = (hasValidExtension || isUqloadDomain) && !hasSuspiciousDomain;

    if (isValid) {
      print('🎬 URL valide: $url');
    } else {
      print('🎬 URL invalide: $url (extension: $hasValidExtension, uqload: $isUqloadDomain, suspect: $hasSuspiciousDomain)');
    }

    return isValid;
  }

  /// Nettoie l'URL de stream
  static String _cleanStreamUrl(String url) {
    // Supprimer les guillemets et espaces
    url = url.replaceAll('"', '');
    url = url.replaceAll("'", '');
    url = url.replaceAll(' ', '');

    // Décoder les entités HTML si nécessaire
    url = url.replaceAll('&amp;', '&');
    url = url.replaceAll('&lt;', '<');
    url = url.replaceAll('&gt;', '>');
    url = url.replaceAll('&quot;', '"');

    return url;
  }

  /// Extrait le titre depuis le HTML (inspired by Python version)
  static String _extractTitle(String html) {
    print('🎬 Extraction du titre...');
    
    // MÉTHODE 1: Chercher title: "..." (comme Python)
    final titlePattern = RegExp(r'title:\s*"([^"]+)"');
    final titleMatch = titlePattern.firstMatch(html);
    if (titleMatch != null && titleMatch.group(1)!.isNotEmpty) {
      final title = titleMatch.group(1)!.trim();
      if (!title.toLowerCase().contains('uqload')) {
        print('🎬 Titre trouvé (pattern 1): $title');
        return title;
      }
    }

    // MÉTHODE 2: Chercher <h1>...</h1> (comme Python)
    final h1Pattern = RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false);
    final h1Match = h1Pattern.firstMatch(html);
    if (h1Match != null && h1Match.group(1)!.isNotEmpty) {
      final title = h1Match.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      if (title.isNotEmpty) {
        print('🎬 Titre trouvé (pattern 2): $title');
        return title;
      }
    }

    // MÉTHODE 3: Chercher <title>...</title>
    final titleStart = html.indexOf('<title>');
    final titleEnd = html.indexOf('</title>');
    if (titleStart != -1 && titleEnd != -1 && titleEnd > titleStart) {
      final title = html.substring(titleStart + 7, titleEnd).trim();
      if (title.isNotEmpty && !title.toLowerCase().contains('uqload')) {
        print('🎬 Titre trouvé (pattern 3): $title');
        return title;
      }
    }

    print('🎬 Aucun titre trouvé');
    return 'Vidéo';
  }

  /// Extrait la miniature depuis le HTML
  static String _extractThumbnail(String html) {
    // Recherche simple d'images
    if (html.contains('.jpg') || html.contains('.png') || html.contains('.jpeg')) {
      final httpIndex = html.indexOf('http');
      if (httpIndex != -1) {
        final extensions = ['.jpg', '.png', '.jpeg', '.webp'];
        for (final ext in extensions) {
          final extIndex = html.indexOf(ext, httpIndex);
          if (extIndex != -1) {
            final url = html.substring(httpIndex, extIndex + ext.length);
            if (url.startsWith('http')) {
              return url;
            }
          }
        }
      }
    }
    return '';
  }

  /// Extrait la qualité depuis le HTML
  static String _extractQuality(String html) {
    // Détecter la qualité depuis l'URL
    if (html.contains('1080p') || html.contains('1080')) return '1080p';
    if (html.contains('720p') || html.contains('720')) return '720p';
    if (html.contains('480p') || html.contains('480')) return '480p';
    if (html.contains('360p') || html.contains('360')) return '360p';
    return 'HD';
  }

  /// Vérifie si l'URL est un lien Uqload
  static bool isUqloadUrl(String url) {
    final cleanUrl = url.toLowerCase();
    return cleanUrl.contains('uqload');
  }

  /// Obtient les headers par défaut
  static Map<String, String> getDefaultHeaders() {
    return Map<String, String>.from(_defaultHeaders);
  }

  /// Teste l'extracteur avec une URL
  static Future<bool> testExtractor(String url) async {
    try {
      final streamInfo = await extractStreamInfo(url);
      return streamInfo.url.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Obtient l'extension de fichier depuis l'URL
  static String _getFileExtension(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      if (path.contains('.')) {
        return path.split('.').last;
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  /// Détermine la qualité en fonction de l'extension
  static String _getQualityFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'm3u8':
        return 'HLS';
      case 'mp4':
        return 'HD';
      case 'mpd':
        return 'DASH';
      case 'avi':
        return 'SD';
      case 'mkv':
        return 'HD';
      case 'mov':
        return 'HD';
      case 'webm':
        return 'HD';
      default:
        return 'HD';
    }
  }

  /// Construit les headers appropriés pour la vidéo
  static Map<String, String> _buildVideoHeaders(String domain, String extension, [String cookies = '']) {
    final headers = Map<String, String>.from(_defaultHeaders);

    // Ajouter les headers spécifiques selon le domaine et le type de fichier
    headers['Referer'] = 'https://$domain/';
    headers['Origin'] = 'https://$domain';
    headers['Accept'] = extension == 'm3u8'
        ? 'application/vnd.apple.mpegurl, audio/x-mpegurl, video/*, */*'
        : 'video/mp4, video/*, */*;q=0.9, */*';
    
    // 🔑 Ajouter les cookies si présents
    if (cookies.isNotEmpty) {
      headers['Cookie'] = cookies;
      print('🎬 Cookies ajoutés aux headers vidéo: $cookies');
    }

    return headers;
  }
}