import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/dns/dns_service.dart' as dns_lib;
import '../../data/services/dns/quad9_dns_service.dart';
import '../../data/services/dns/system_dns_service.dart';

class DnsProvider extends ChangeNotifier {
  final dns_lib.DnsService _dnsService = dns_lib.DnsService();
  final Quad9DnsService _quad9Service = Quad9DnsService();

  // État du DNS
  DnsStatus _status = DnsStatus.offline;
  bool _isInitialized = false;
  bool _hasShownWarning = false;
  bool _autoOptimizeEnabled = false;
  String? _currentDns;
  bool _isConnected = false;
  bool _isDnsWorking = false;

  // Subscriptions
  StreamSubscription<DnsStatus>? _statusSubscription;

  // Getters
  DnsStatus get status => _status;
  bool get isInitialized => _isInitialized;
  bool get hasShownWarning => _hasShownWarning;
  bool get autoOptimizeEnabled => _autoOptimizeEnabled;
  bool get isOptimized => _status == DnsStatus.working;
  bool get isChecking => _status == DnsStatus.checking;
  bool get hasError => _status == DnsStatus.error;
  bool get isOffline => _status == DnsStatus.offline;
  String? get currentDns => _currentDns;
  bool get isConnected => _isConnected;
  bool get isDnsWorking => _isDnsWorking;

  DnsProvider() {
    _initializeProvider();
  }

  Future<void> _initializeProvider() async {
    try {
      // Charger les préférences
      await _loadPreferences();

      // S'abonner aux changements de statut
      _statusSubscription = _quad9Service.statusStream.listen((status) {
        _status = status;
        notifyListeners();
      });

      // Vérifier la connectivité initiale
      await _checkConnectivity();

      _isInitialized = true;
      notifyListeners();

      // Auto-optimiser si activé
      if (_autoOptimizeEnabled && !isOptimized) {
        await testQuad9DnsConnectivity();
      }

      print('DnsProvider initialisé avec succès');
    } catch (e) {
      print('Erreur lors de l\'initialisation du DnsProvider: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasShownWarning = prefs.getBool('dns_warning_shown') ?? false;
      _autoOptimizeEnabled = prefs.getBool('dns_auto_optimize') ?? false;
    } catch (e) {
      print('Erreur lors du chargement des préférences DNS: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dns_warning_shown', _hasShownWarning);
      await prefs.setBool('dns_auto_optimize', _autoOptimizeEnabled);
    } catch (e) {
      print('Erreur lors de la sauvegarde des préférences DNS: $e');
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      _isConnected = await SystemDnsService.isConnected();
      _isDnsWorking = await SystemDnsService.isDnsWorking();
      _currentDns = await SystemDnsService.getCurrentDns();

      if (!_isConnected) {
        _status = DnsStatus.offline;
      } else if (_isDnsWorking) {
        _status = DnsStatus.working;
      } else {
        _status = DnsStatus.error;
      }

      notifyListeners();
    } catch (e) {
      print('Erreur lors de la vérification de la connectivité: $e');
      _status = DnsStatus.error;
      notifyListeners();
    }
  }

  /// Marque l'avertissement comme affiché
  Future<void> markWarningAsShown() async {
    _hasShownWarning = true;
    await _savePreferences();
    notifyListeners();
  }

  /// Active/désactive l'optimisation automatique
  Future<void> setAutoOptimize(bool enabled) async {
    _autoOptimizeEnabled = enabled;
    await _savePreferences();
    notifyListeners();

    if (enabled) {
      await testQuad9DnsConnectivity();
    }
  }

  /// Teste la connectivité Quad9 DNS
  Future<bool> testQuad9DnsConnectivity() async {
    try {
      print('🔍 Test de connectivité Quad9 DNS...');
      _status = DnsStatus.checking;
      notifyListeners();

      final result = await _quad9Service.testQuad9Connectivity();

      if (result) {
        _status = DnsStatus.working;
        print('✅ Quad9 DNS disponible');
      } else {
        _status = DnsStatus.error;
        print('❌ Quad9 DNS non disponible');
      }

      notifyListeners();
      return result;
    } catch (e) {
      print('🔍 Erreur test Quad9 DNS: $e');
      _status = DnsStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Teste un domaine spécifique
  Future<bool> testDomain(String domain) async {
    try {
      return await _dnsService.testDomainResolution(domain);
    } catch (e) {
      print('Erreur lors du test du domaine $domain: $e');
      return false;
    }
  }

  /// Résout un domaine en adresse IP
  Future<String?> resolveDomain(String domain) async {
    try {
      return await _dnsService.resolveDomain(domain);
    } catch (e) {
      print('Erreur lors de la résolution du domaine $domain: $e');
      return null;
    }
  }

  /// Obtient les informations de diagnostic DNS
  Future<Map<String, dynamic>> getSystemDnsInfo() async {
    try {
      return await SystemDnsService.getDiagnostics();
    } catch (e) {
      print('Erreur lors de l\'obtention des infos DNS: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  /// Obtient les informations de performance DNS
  Future<Map<String, dynamic>?> getDnsPerformanceInfo() async {
    try {
      return await _quad9Service.getPerformanceInfo();
    } catch (e) {
      print('Erreur lors de la récupération des performances DNS: $e');
      return null;
    }
  }

  /// Obtient les statistiques du cache DNS
  Map<String, dynamic> getDnsCacheStats() {
    return _dnsService.getCacheStats();
  }

  /// Vide le cache DNS
  void clearDnsCache() {
    _dnsService.clearCache();
    notifyListeners();
  }

  /// Affiche les statistiques du cache DNS
  void printDnsCacheStats() {
    _dnsService.printCacheStats();
  }

  /// Rafraîchit l'état du DNS
  Future<void> refreshDnsStatus() async {
    await _checkConnectivity();
  }

  /// Obtient le message d'erreur actuel
  String? get errorMessage {
    if (_status == DnsStatus.offline) {
      return 'Pas de connexion internet';
    } else if (_status == DnsStatus.error) {
      return 'Erreur de résolution DNS';
    }
    return null;
  }

  /// Obtient le statut formaté
  String get formattedStatus {
    switch (_status) {
      case DnsStatus.offline:
        return 'Hors ligne';
      case DnsStatus.working:
        return 'DNS Fonctionnel';
      case DnsStatus.checking:
        return 'Vérification...';
      case DnsStatus.error:
        return 'Erreur DNS';
    }
  }

  /// Obtient la description du statut
  String get statusDescription {
    switch (_status) {
      case DnsStatus.offline:
        return 'Pas de connexion internet';
      case DnsStatus.working:
        return 'DNS fonctionne correctement';
      case DnsStatus.checking:
        return 'Vérification de la résolution DNS...';
      case DnsStatus.error:
        return errorMessage ?? 'Problème de résolution DNS';
    }
  }

  /// Réinitialise l'état d'erreur
  void clearError() {
    if (_status == DnsStatus.error) {
      _status = DnsStatus.offline;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _dnsService.dispose();
    _quad9Service.dispose();
    super.dispose();
  }
}
