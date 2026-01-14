import 'dart:convert';
import 'package:http/http.dart' as http;

class ImageProxyService {
  static const String _proxyBase = 'https://images.weserv.nl';
  
  /// Convertit une URL cpasmieux en URL proxifiée
  static String getProxyUrl(String originalUrl) {
    if (originalUrl.isEmpty) return originalUrl;
    
    // Si c'est déjà une URL cpasmieux, la passer par le proxy
    if (originalUrl.contains('cpasmieux')) {
      try {
        // Utiliser le service weserv.nl pour proxy les images
        // ?url=...&w=500&h=750&fit=cover&q=80
        final encoded = Uri.encodeComponent(originalUrl);
        return '$_proxyBase/?url=$encoded&w=500&h=750&fit=cover&q=85&a=attention';
      } catch (e) {
        print('❌ Error creating proxy URL: $e');
        return originalUrl;
      }
    }
    
    return originalUrl;
  }

  /// Alternative: Try to fetch with proxy headers
  static Future<String?> fetchImageWithProxy(String imageUrl) async {
    if (!imageUrl.contains('cpasmieux')) {
      return imageUrl; // Return original if not cpasmieux
    }

    try {
      // Try different proxy approaches
      final proxies = [
        // 1. weserv.nl proxy
        '${_proxyBase}/?url=${Uri.encodeComponent(imageUrl)}&w=500&h=750&fit=cover&q=85',
        
        // 2. Direct with custom headers
        imageUrl,
      ];

      for (final proxyUrl in proxies) {
        try {
          final response = await http.head(
            Uri.parse(proxyUrl),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Accept': 'image/*',
            },
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            print('✅ Image proxy successful: $proxyUrl');
            return proxyUrl;
          }
        } catch (e) {
          continue;
        }
      }

      print('⚠️ All proxies failed for: $imageUrl');
      return imageUrl; // Return original as fallback
    } catch (e) {
      print('❌ Error in image proxy service: $e');
      return imageUrl;
    }
  }

  /// Get CDN URL for images
  static String getCdnUrl(String imageUrl) {
    if (imageUrl.isEmpty) return imageUrl;

    // If it's a cpasmieux image, use proxy
    if (imageUrl.contains('cpasmieux')) {
      final proxiedUrl = getProxyUrl(imageUrl);
      print('🖼️ IMAGE PROXY: $imageUrl\n    ➜ $proxiedUrl');
      return proxiedUrl;
    }

    return imageUrl;
  }
}
