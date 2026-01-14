import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

enum DnsStatus {
  systemDns,
  quad9Dns,
  checking,
  error,
  offline,
}

class DnsInfo {
  final String domainName;
  final String ipAddress;
  final DateTime resolvedAt;
  final int resolutionTimeMs;

  DnsInfo({
    required this.domainName,
    required this.ipAddress,
    required this.resolvedAt,
    required this.resolutionTimeMs,
  });

  @override
  String toString() => '$domainName → $ipAddress (${resolutionTimeMs}ms)';
}

class DnsService {
  static const String _tag = 'DnsService';
  static const String quad9Dns = '9.9.9.9';
  static const String quad9Secondary = '149.112.112.112';
  static const Duration _resolutionTimeout = Duration(seconds: 10);

  final StreamController<DnsStatus> _statusController =
      StreamController<DnsStatus>.broadcast();
  final Map<String, DnsInfo> _dnsCache = {};
  final Set<String> _failedDomains = {};

  DnsStatus _currentStatus = DnsStatus.systemDns;

  Stream<DnsStatus> get statusStream => _statusController.stream;
  DnsStatus get currentStatus => _currentStatus;
  Map<String, DnsInfo> get dnsCache => Map.unmodifiable(_dnsCache);

  DnsService() {
    _initialize();
  }

  void _initialize() {
    // Écouter les changements de connectivité
    Connectivity().onConnectivityChanged.listen((results) {
      _checkConnectivity();
    });

    // Vérifier l'état initial
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final isConnected = !results.contains(ConnectivityResult.none);

      if (!isConnected) {
        _setStatus(DnsStatus.offline);
        print('$_tag: No internet connection');
        return;
      }

      // Tester la résolution DNS
      final canResolve = await _testDnsResolution();
      if (canResolve) {
        _setStatus(DnsStatus.systemDns);
        print('$_tag: DNS is working');
      } else {
        _setStatus(DnsStatus.error);
        print('$_tag: DNS resolution failed');
      }
    } catch (e) {
      print('$_tag: Connectivity check error: $e');
      _setStatus(DnsStatus.error);
    }
  }

  Future<bool> _testDnsResolution() async {
    try {
      final addresses =
          await InternetAddress.lookup('8.8.8.8').timeout(_resolutionTimeout);
      return addresses.isNotEmpty;
    } catch (e) {
      print('$_tag: DNS test failed: $e');
      return false;
    }
  }

  /// Résout un domaine en adresse IP via Google DNS
  Future<String?> resolveDomain(String domain) async {
    // Retourner depuis le cache si disponible
    if (_dnsCache.containsKey(domain)) {
      final cached = _dnsCache[domain]!;
      final age = DateTime.now().difference(cached.resolvedAt).inMinutes;
      final ip = cached.ipAddress;

      // Ignorer les adresses loopback du cache
      if (ip == '::1' || ip == '127.0.0.1' || ip.startsWith('127.')) {
        print('$_tag: ⚠️ Ignoring cached loopback address for $domain: $ip');
        _dnsCache.remove(domain);
      } else if (age < 30) {
        // Cache valide pendant 30 minutes
        print('$_tag: Cache hit for $domain → $ip');
        return ip;
      } else {
        _dnsCache.remove(domain);
      }
    }

    // Ne pas réessayer les domaines en erreur pendant 5 minutes
    if (_failedDomains.contains(domain)) {
      print('$_tag: Skipping failed domain: $domain');
      return null;
    }

    try {
      _setStatus(DnsStatus.checking);

      final stopwatch = Stopwatch()..start();
      // Utiliser Google DNS directement (8.8.8.8)
      final addresses = await InternetAddress.lookup(domain)
          .timeout(_resolutionTimeout);
      stopwatch.stop();

      if (addresses.isNotEmpty) {
        // Filtrer les adresses IPv4 (ignorer IPv6 loopback comme ::1)
        String ip = '';
        for (final addr in addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            ip = addr.address;
            break;
          }
        }
        
        // Si aucune IPv4, utiliser la première adresse non-loopback
        if (ip.isEmpty) {
          for (final addr in addresses) {
            final address = addr.address;
            // Ignorer localhost (::1, 127.0.0.1)
            if (address != '::1' && address != '127.0.0.1' && !address.startsWith('127.')) {
              ip = address;
              break;
            }
          }
        }

        // Fallback à la première adresse si vraiment aucune n'est valide
        if (ip.isEmpty && addresses.isNotEmpty) {
          ip = addresses.first.address;
        }

        if (ip.isNotEmpty && ip != '::1' && !ip.startsWith('127.')) {
          // Mettre en cache
          _dnsCache[domain] = DnsInfo(
            domainName: domain,
            ipAddress: ip,
            resolvedAt: DateTime.now(),
            resolutionTimeMs: stopwatch.elapsedMilliseconds,
          );

          print('$_tag: ✅ $domain → $ip (${stopwatch.elapsedMilliseconds}ms)');
          _setStatus(DnsStatus.systemDns);
          return ip;
        }
      }
    } catch (e) {
      print('$_tag: ❌ Failed to resolve $domain: $e');
      _failedDomains.add(domain);

      // Réinitialiser la liste d'erreurs après 5 minutes
      Future.delayed(const Duration(minutes: 5), () {
        _failedDomains.remove(domain);
      });
    }

    _setStatus(DnsStatus.error);
    return null;
  }

  /// Résout plusieurs domaines en parallèle
  Future<Map<String, String?>> resolveMultiple(List<String> domains) async {
    final futures = domains.map((domain) async {
      final ip = await resolveDomain(domain);
      return MapEntry(domain, ip);
    });

    final results = await Future.wait(futures);
    return Map.fromEntries(results);
  }

  /// Teste la résolution d'un domaine spécifique
  Future<bool> testDomainResolution(String domain) async {
    try {
      final addresses =
          await InternetAddress.lookup(domain).timeout(_resolutionTimeout);
      return addresses.isNotEmpty;
    } catch (e) {
      print('$_tag: Domain test failed for $domain: $e');
      return false;
    }
  }

  /// Vide le cache DNS
  void clearCache() {
    _dnsCache.clear();
    _failedDomains.clear();
    print('$_tag: DNS cache cleared');
  }

  /// Obtient les statistiques du cache
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedDomains': _dnsCache.length,
      'failedDomains': _failedDomains.length,
      'oldestEntry': _dnsCache.values
          .map((info) => info.resolvedAt)
          .fold<DateTime?>(null,
              (prev, curr) => prev == null || curr.isBefore(prev) ? curr : prev)
          ?.toIso8601String(),
      'newestEntry': _dnsCache.values
          .map((info) => info.resolvedAt)
          .fold<DateTime?>(null,
              (prev, curr) => prev == null || curr.isAfter(prev) ? curr : prev)
          ?.toIso8601String(),
    };
  }

  /// Affiche les entrées du cache
  void printCacheStats() {
    print('$_tag: Cache Statistics');
    print('  Cached Domains: ${_dnsCache.length}');
    print('  Failed Domains: ${_failedDomains.length}');

    for (final entry in _dnsCache.entries) {
      print('  - ${entry.value}');
    }
  }

  void _setStatus(DnsStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
    }
  }

  void dispose() {
    _statusController.close();
  }
}
