import 'dart:io';
import 'package:dio/dio.dart';

/// Interceptor to handle DNS resolution properly
class Quad9DnsInterceptor extends Interceptor {
  static const String _tag = 'Quad9DnsInterceptor';

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      // Resolve host using system DNS (may be configured for Quad9)
      if (options.uri.host.isNotEmpty && !_isIpAddress(options.uri.host)) {
        final resolvedAddress = await _resolveHost(options.uri.host);
        if (resolvedAddress != null) {
          print('$_tag: ${options.uri.host} → ${resolvedAddress.address}');
        }
      }
    } catch (e) {
      print('$_tag: DNS resolution error: $e');
      // Continue with original request even if DNS resolution fails
    }

    handler.next(options);
  }

  /// Resolves host using standard DNS lookup
  Future<InternetAddress?> _resolveHost(String host) async {
    try {
      final addresses = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 10));

      if (addresses.isNotEmpty) {
        return addresses.first;
      }
    } catch (e) {
      print('$_tag: Failed to resolve $host: $e');
    }

    return null;
  }

  /// Check if host is already an IP address
  bool _isIpAddress(String host) {
    try {
      InternetAddress(host);
      return true;
    } catch (e) {
      return false;
    }
  }
}
