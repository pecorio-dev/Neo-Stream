import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service pour configurer et gérer le DNS système
class SystemDnsService {
  static const String _tag = 'SystemDnsService';

  /// Obtient le DNS actuellement utilisé
  static Future<String?> getCurrentDns() async {
    try {
      // Tenter de résoudre un domaine de test
      final addresses = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));

      if (addresses.isNotEmpty) {
        return addresses.first.address;
      }
    } catch (e) {
      print('$_tag: Failed to get current DNS: $e');
    }
    return null;
  }

  /// Vérifie si le DNS fonctionne
  static Future<bool> isDnsWorking() async {
    try {
      final results = await Connectivity().checkConnectivity();

      if (results.contains(ConnectivityResult.none)) {
        print('$_tag: No internet connection');
        return false;
      }

      // Tester la résolution DNS
      final addresses = await InternetAddress.lookup('8.8.8.8')
          .timeout(const Duration(seconds: 5));

      return addresses.isNotEmpty;
    } catch (e) {
      print('$_tag: DNS check failed: $e');
      return false;
    }
  }

  /// Teste la connectivité réseau générale
  static Future<bool> isConnected() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return !results.contains(ConnectivityResult.none);
    } catch (e) {
      print('$_tag: Connectivity check failed: $e');
      return false;
    }
  }

  /// Obtient le type de connexion actuelle
  static Future<String> getConnectionType() async {
    try {
      final results = await Connectivity().checkConnectivity();

      if (results.isEmpty || results.contains(ConnectivityResult.none)) {
        return 'None';
      } else if (results.contains(ConnectivityResult.wifi)) {
        return 'WiFi';
      } else if (results.contains(ConnectivityResult.mobile)) {
        return 'Mobile';
      } else if (results.contains(ConnectivityResult.ethernet)) {
        return 'Ethernet';
      }

      return 'Unknown';
    } catch (e) {
      print('$_tag: Failed to get connection type: $e');
      return 'Unknown';
    }
  }

  /// Teste un domaine spécifique
  static Future<bool> testDomain(String domain) async {
    try {
      final addresses = await InternetAddress.lookup(domain)
          .timeout(const Duration(seconds: 5));

      final isResolved = addresses.isNotEmpty;
      print('$_tag: Domain test for $domain: ${isResolved ? 'OK' : 'FAILED'}');

      return isResolved;
    } catch (e) {
      print('$_tag: Domain test failed for $domain: $e');
      return false;
    }
  }

  /// Teste plusieurs domaines
  static Future<Map<String, bool>> testMultipleDomains(
      List<String> domains) async {
    final results = <String, bool>{};

    for (final domain in domains) {
      results[domain] = await testDomain(domain);
    }

    return results;
  }

  /// Obtient les informations de diagnostic DNS
  static Future<Map<String, dynamic>> getDiagnostics() async {
    try {
      final connectedResult = await isConnected();
      final dnsWorkingResult = await isDnsWorking();
      final connTypeResult = await getConnectionType();
      final currentDnsResult = await getCurrentDns();

      return {
        'isConnected': connectedResult,
        'isDnsWorking': dnsWorkingResult,
        'connectionType': connTypeResult,
        'currentDns': currentDnsResult,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('$_tag: Diagnostics failed: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Affiche les informations de diagnostic
  static Future<void> printDiagnostics() async {
    final diagnostics = await getDiagnostics();

    print('$_tag: === DNS Diagnostics ===');
    print('  Connected: ${diagnostics['isConnected']}');
    print('  DNS Working: ${diagnostics['isDnsWorking']}');
    print('  Connection Type: ${diagnostics['connectionType']}');
    print('  Current DNS: ${diagnostics['currentDns'] ?? 'Unknown'}');
    print('  Timestamp: ${diagnostics['timestamp']}');
    print('$_tag: =====================');
  }

  /// Écoute les changements de connectivité
  static Stream<String> watchConnectivityChanges() async* {
    yield* Connectivity().onConnectivityChanged.asyncMap((results) async {
      if (results.contains(ConnectivityResult.none)) {
        return 'No Connection';
      } else if (results.contains(ConnectivityResult.wifi)) {
        return 'WiFi';
      } else if (results.contains(ConnectivityResult.mobile)) {
        return 'Mobile';
      } else if (results.contains(ConnectivityResult.ethernet)) {
        return 'Ethernet';
      }
      return 'Unknown';
    });
  }
}
