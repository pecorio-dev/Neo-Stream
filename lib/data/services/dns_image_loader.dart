import 'package:flutter/material.dart';
import 'dns/dns_service.dart';

class DnsImageLoader {
  static final DnsService _dnsService = DnsService();

  static Future<String> resolveImageUrl(String imageUrl) async {
    if (!imageUrl.startsWith('http')) return imageUrl;

    try {
      final uri = Uri.parse(imageUrl);
      final hostname = uri.host;

      if (hostname.isEmpty) return imageUrl;

      final ip = await _dnsService.resolveDomain(hostname);
      if (ip == null) return imageUrl;

      final resolvedUrl = imageUrl.replaceFirst(hostname, ip);
      debugPrint('🖼️ DNS Image: $hostname → $ip');
      return resolvedUrl;
    } catch (e) {
      debugPrint('❌ DNS Image Resolution Failed: $e');
      return imageUrl;
    }
  }

  static Future<String> resolveImageUrlOrDefault(
    String? imageUrl, {
    String? defaultUrl,
  }) async {
    if (imageUrl == null || imageUrl.isEmpty) {
      return defaultUrl ?? '';
    }
    return resolveImageUrl(imageUrl);
  }
}
