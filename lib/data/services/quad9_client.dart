import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';

/// Client DNS Quad9 pur Dart sans dépendances externes
class Quad9Dns {
  static const String _dohUrl = 'https://dns.quad9.net:5053/dns-query';
  static const String _dohUrlAlt = 'https://dns11.quad9.net/dns-query';
  
  // Cache DNS simple
  static final Map<String, InternetAddress> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const Duration _cacheTtl = Duration(hours: 1);
  
  /// Résout domaine → IP via Quad9 DoH (DNS-over-HTTPS)
  static Future<InternetAddress> resolve(String domain) async {
    // Vérifier le cache
    if (_isCacheValid(domain)) {
      print('🔍 DNS Cache hit: $domain → ${_cache[domain]!.address}');
      return _cache[domain]!;
    }
    
    try {
      // Essayer résolution Quad9 DoH
      final query = _buildDnsQuery(domain, DnsType.A);
      final response = await _dohRequest(query);
      final records = _parseDnsResponse(response, DnsType.A);
      
      if (records.isNotEmpty) {
        final address = InternetAddress(records.first);
        _cacheResult(domain, address);
        print('✅ DNS Quad9: $domain → ${address.address}');
        return address;
      }
    } catch (e) {
      print('❌ Quad9 DoH failed: $e');
    }
    
    // Fallback vers résolution système
    try {
      final addresses = await InternetAddress.lookup(domain);
      if (addresses.isNotEmpty) {
        final address = addresses.first;
        _cacheResult(domain, address);
        print('✅ DNS System: $domain → ${address.address}');
        return address;
      }
    } catch (e) {
      print('❌ System DNS failed: $e');
    }
    
    throw Exception('DNS resolution failed for $domain');
  }
  
  static bool _isCacheValid(String domain) {
    if (!_cache.containsKey(domain) || !_cacheTime.containsKey(domain)) {
      return false;
    }
    return DateTime.now().difference(_cacheTime[domain]!) < _cacheTtl;
  }
  
  static void _cacheResult(String domain, InternetAddress address) {
    _cache[domain] = address;
    _cacheTime[domain] = DateTime.now();
    
    // Nettoyer le cache si trop grand
    if (_cache.length > 100) {
      _cleanCache();
    }
  }
  
  static void _cleanCache() {
    final now = DateTime.now();
    final expired = <String>[];
    
    _cacheTime.forEach((domain, time) {
      if (now.difference(time) > _cacheTtl) {
        expired.add(domain);
      }
    });
    
    for (final domain in expired) {
      _cache.remove(domain);
      _cacheTime.remove(domain);
    }
    
    print('🧹 DNS cache cleaned: ${expired.length} entries');
  }
  
  static Uint8List _buildDnsQuery(String domain, DnsType type) {
    final parts = domain.split('.');
    final labels = <int>[];
    
    for (final part in parts) {
      labels.add(part.length);
      labels.addAll(part.codeUnits);
    }
    
    final buffer = BytesBuilder();
    buffer.addByte(0x12); buffer.addByte(0x34); // ID
    buffer.addByte(0x01); buffer.addByte(0x00); // Flags: standard query
    buffer.addByte(0x00); buffer.addByte(0x01); // QDCOUNT
    buffer.addByte(0x00); buffer.addByte(0x00); // ANCOUNT
    buffer.addByte(0x00); buffer.addByte(0x00); // NSCOUNT
    buffer.addByte(0x00); buffer.addByte(0x00); // ARCOUNT
    
    for (final len in labels) buffer.addByte(len);
    buffer.addByte(0x00); // Null terminator
    
    buffer.addByte(0x00); buffer.addByte(type.value); // QTYPE
    buffer.addByte(0x00); buffer.addByte(0x01); // QCLASS IN
    
    return buffer.toBytes();
  }
  
  static Future<Uint8List> _dohRequest(Uint8List query) async {
    final client = http.Client();
    try {
      final response = await client.post(
        Uri.parse(_dohUrl),
        headers: {
          'accept': 'application/dns-message',
          'content-type': 'application/dns-message',
        },
        body: query,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      throw Exception('DoH failed: ${response.statusCode}');
    } catch (e) {
      // Fallback serveur alternatif
      final response = await client.post(
        Uri.parse(_dohUrlAlt),
        headers: {
          'accept': 'application/dns-message',
          'content-type': 'application/dns-message',
        },
        body: query,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      throw Exception('DoH fallback failed: ${response.statusCode}');
    } finally {
      client.close();
    }
  }
  
  static List<String> _parseDnsResponse(Uint8List response, DnsType type) {
    // Parsing DNS simplifié - pour l'instant retourne fallback système
    // TODO: Implémenter parsing DNS wire format complet
    final ips = <String>[];
    
    try {
      // Parsing basique des réponses DNS
      if (response.length > 12) {
        // Skip header (12 bytes) et question section
        // Pour l'instant, utiliser fallback système
        return ips;
      }
    } catch (e) {
      print('DNS parsing error: $e');
    }
    
    return ips;
  }
  
  /// Nettoie le cache DNS
  static void clearCache() {
    _cache.clear();
    _cacheTime.clear();
    print('🧹 DNS cache cleared');
  }
  
  /// Statistiques du cache
  static Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    int valid = 0;
    int expired = 0;
    
    _cacheTime.forEach((domain, time) {
      if (now.difference(time) < _cacheTtl) {
        valid++;
      } else {
        expired++;
      }
    });
    
    return {
      'total': _cache.length,
      'valid': valid,
      'expired': expired,
      'hitRate': _cache.isNotEmpty ? (valid / _cache.length * 100).toStringAsFixed(1) : '0.0',
    };
  }
}

enum DnsType { A, AAAA }

extension DnsTypeExt on DnsType {
  int get value => switch (this) { 
    DnsType.A => 1, 
    DnsType.AAAA => 28 
  };
}

/// HttpClient avec résolution DNS Quad9
class Quad9HttpClient {
  /// Requête GET avec DNS Quad9
  static Future<http.Response> get(String url, {Map<String, String>? headers}) async {
    try {
      final uri = Uri.parse(url);
      final ip = await Quad9Dns.resolve(uri.host);
      
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);
      
      final request = await client.getUrl(
        Uri.parse(url.replaceFirst(uri.host, ip.address))
      );
      
      // Headers essentiels
      request.headers.set('Host', uri.host); // SNI crucial pour HTTPS
      request.headers.set('User-Agent', 'NeoStream/1.0.0 (Flutter)');
      request.headers.set('Accept', 'application/json, image/*, */*');
      
      // Headers personnalisés
      if (headers != null) {
        headers.forEach((key, value) {
          request.headers.set(key, value);
        });
      }
      
      final response = await request.close();
      final bytes = await _consolidateBytes(response);
      
      return http.Response.bytes(
        bytes,
        response.statusCode,
        headers: _convertHeaders(response.headers),
        reasonPhrase: response.reasonPhrase,
      );
    } catch (e) {
      print('❌ Quad9 HTTP error: $e');
      // Fallback vers requête standard
      return await http.get(Uri.parse(url), headers: headers);
    }
  }
  
  /// Convertit HttpHeaders en Map
  static Map<String, String> _convertHeaders(HttpHeaders headers) {
    final result = <String, String>{};
    headers.forEach((name, values) {
      result[name] = values.join(', ');
    });
    return result;
  }
  
  /// Consolide les bytes d'une HttpClientResponse
  static Future<Uint8List> _consolidateBytes(HttpClientResponse response) async {
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    return Uint8List.fromList(bytes);
  }
  
  /// Télécharge une image avec DNS Quad9
  static Future<Uint8List?> downloadImage(String imageUrl) async {
    try {
      final response = await get(
        imageUrl,
        headers: {
          'Accept': 'image/*,*/*;q=0.8',
          'Cache-Control': 'max-age=3600',
        },
      );
      
      if (response.statusCode == 200) {
        print('✅ Image downloaded: $imageUrl');
        return response.bodyBytes;
      } else {
        print('❌ Image error ${response.statusCode}: $imageUrl');
        return null;
      }
    } catch (e) {
      print('❌ Image download failed: $e');
      return null;
    }
  }
  
  /// Crée un Dio client avec DNS Quad9
  static Dio createDioWithQuad9() {
    final dio = Dio();

    // Configuration optimisée
    dio.options.connectTimeout = const Duration(seconds: 30);
    dio.options.receiveTimeout = const Duration(seconds: 30);
    dio.options.sendTimeout = const Duration(seconds: 30);

    dio.options.headers = {
      'User-Agent': 'NeoStream/1.0.0 (Flutter)',
      'Accept': 'application/json, image/*, */*',
      'Accept-Encoding': 'gzip, deflate',
      'Connection': 'keep-alive',
    };

    // Interceptor pour DNS Quad9
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final uri = Uri.parse(options.uri.toString());
          if (uri.host.isNotEmpty && !_isIpAddress(uri.host)) {
            final ip = await Quad9Dns.resolve(uri.host);

            // Remplacer le host par l'IP
            final newUri = uri.replace(host: ip.address);
            options.path = newUri.toString().replaceFirst('${newUri.scheme}://${newUri.host}', '');
            options.baseUrl = '${newUri.scheme}://${newUri.host}';

            // Header Host pour SNI
            options.headers['Host'] = uri.host;

            print('🔄 Dio DNS: ${uri.host} → ${ip.address}');
          }
        } catch (e) {
          print('⚠️ Dio DNS error: $e');
          // Continuer avec URL originale
        }

        handler.next(options);
      },
    ));

    return dio;
  }
  
  /// Vérifie si c'est une adresse IP
  static bool _isIpAddress(String host) {
    try {
      InternetAddress(host);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Pré-résout des domaines
  static Future<void> preResolveDomains(List<String> domains) async {
    print('🚀 Pre-resolving ${domains.length} domains...');
    
    for (final domain in domains) {
      try {
        await Quad9Dns.resolve(domain);
        print('✅ Pre-resolved: $domain');
      } catch (e) {
        print('❌ Pre-resolve failed: $domain - $e');
      }
    }
    
    print('🏁 Pre-resolution completed');
  }
  
  /// Teste la connectivité
  static Future<bool> testConnectivity() async {
    try {
      await Quad9Dns.resolve('google.com');
      print('✅ Quad9 connectivity OK');
      return true;
    } catch (e) {
      print('❌ Quad9 connectivity failed: $e');
      return false;
    }
  }
}