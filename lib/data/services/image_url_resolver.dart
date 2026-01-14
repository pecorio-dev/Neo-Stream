import 'image_proxy_service.dart';

/// Global image URL resolver that applies proxy to all cpasmieux.is images
class ImageUrlResolver {
  /// Get resolved image URL (applies proxy if needed)
  static String resolve(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return '';
    }

    // Apply proxy for cpasmieux images
    return ImageProxyService.getCdnUrl(imageUrl);
  }

  /// Batch resolve multiple URLs
  static List<String> resolveBatch(List<String>? urls) {
    if (urls == null || urls.isEmpty) {
      return [];
    }
    return urls.map((url) => resolve(url)).toList();
  }
}
