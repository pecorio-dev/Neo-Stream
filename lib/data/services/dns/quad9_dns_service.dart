import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service simplifié pour Quad9 DNS
/// Évite les modifications d'URL qui causent des erreurs 422
class Quad9DnsService {
  static const String _tag = 'Quad9DnsService';
  static const String quad9Dns = '9.9.9.9';
  static const String quad9Secondary = '149.112.112.112';

  final StreamController<DnsStatus> _statusController =
      StreamController<DnsStatus>.broadcast();
  final Map<String, String> _dnsCache = {};

  DnsStatus _currentStatus = DnsStatus.offline;

  Stream<DnsStatus> get statusStream => _statusController.stream;
  DnsStatus get currentStatus => _currentStatus;
  Map<String, String> get dnsCache => Map.unmodifiable(_dnsCache);

  Quad9DnsService() {
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

  /// Vérifie la connectivité
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
        _setStatus(DnsStatus.working);
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

  /// Teste la résolution DNS
  Future<bool> _testDnsResolution() async {
    try {
      // Tester avec un domaine simple
      final addresses = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 10));
      return addresses.isNotEmpty;
    } catch (e) {
      print('$_tag: DNS test failed: $e');
      return false;
    }
  }

  /// Résout un domaine en IP
  Future<String?> resolveDomain(String domain) async {
    try {
      // Vérifier le cache
      if (_dnsCache.containsKey(domain)) {
        print('$_tag: Cache hit for $domain');
        return _dnsCache[domain];
      }

      // Résoudre le domaine
      final addresses = await InternetAddress.lookup(domain)
          .timeout(const Duration(seconds: 10));

      if (addresses.isNotEmpty) {
        final ip = addresses.first.address;
        _dnsCache[domain] = ip;
        print('$_tag: Resolved $domain → $ip');
        return ip;
      }
    } catch (e) {
      print('$_tag: Failed to resolve $domain: $e');
    }

    return null;
  }

  /// Teste la connectivité Quad9
  Future<bool> testQuad9Connectivity() async {
    try {
      _setStatus(DnsStatus.checking);

      final result = await InternetAddress.lookup('quad9.net')
          .timeout(const Duration(seconds: 10));

      final isWorking = result.isNotEmpty;
      _setStatus(isWorking ? DnsStatus.working : DnsStatus.error);

      print('$_tag: Quad9 connectivity: ${isWorking ? 'OK' : 'FAILED'}');
      return isWorking;
    } catch (e) {
      print('$_tag: Quad9 connectivity test failed: $e');
      _setStatus(DnsStatus.error);
      return false;
    }
  }

  /// Obtient les infos de performance DNS
  Future<Map<String, dynamic>?> getPerformanceInfo() async {
    try {
      final stopwatch = Stopwatch()..start();

      final futures = [
        InternetAddress.lookup('google.com'),
        InternetAddress.lookup('youtube.com'),
        InternetAddress.lookup('github.com'),
      ];

      await Future.wait(futures);
      stopwatch.stop();

      final avgTime = stopwatch.elapsedMilliseconds / futures.length;

      return {
        'averageTime': '${avgTime.toStringAsFixed(1)}ms',
        'status': avgTime < 100
            ? 'Excellent'
            : avgTime < 300
                ? 'Good'
                : 'Slow',
        'lastChecked': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('$_tag: Performance test failed: $e');
      return null;
    }
  }

  /// Vide le cache DNS
  void clearCache() {
    _dnsCache.clear();
    print('$_tag: DNS cache cleared');
  }

  /// Met à jour le statut
  void _setStatus(DnsStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
    }
  }

  /// Nettoie les ressources
  void dispose() {
    _statusController.close();
  }
}

/// Énumération des statuts DNS
enum DnsStatus {
  offline,
  checking,
  working,
  error,
}
