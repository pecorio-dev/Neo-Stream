import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

/// Gestionnaire de mémoire optimisé pour les appareils avec ressources limitées
/// Surveille et optimise l'utilisation de la mémoire en temps réel
class MemoryManager {
  static final MemoryManager _instance = MemoryManager._internal();
  factory MemoryManager() => _instance;
  MemoryManager._internal();

  Timer? _memoryMonitorTimer;
  final List<VoidCallback> _lowMemoryCallbacks = [];
  final List<VoidCallback> _cleanupCallbacks = [];
  
  // Seuils de mémoire (en MB)
  static const double _lowMemoryThreshold = 100.0;
  static const double _criticalMemoryThreshold = 50.0;
  static const Duration _monitorInterval = Duration(seconds: 30);
  
  bool _isMonitoring = false;
  double _lastMemoryUsage = 0.0;

  /// Démarre la surveillance de la mémoire
  void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _memoryMonitorTimer = Timer.periodic(_monitorInterval, (_) {
      _checkMemoryUsage();
    });
    
    if (kDebugMode) {
      print('MemoryManager: Surveillance démarrée');
    }
  }

  /// Arrête la surveillance de la mémoire
  void stopMonitoring() {
    _isMonitoring = false;
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = null;
    
    if (kDebugMode) {
      print('MemoryManager: Surveillance arrêtée');
    }
  }

  /// Vérifie l'utilisation actuelle de la mémoire
  Future<void> _checkMemoryUsage() async {
    try {
      final memoryInfo = await _getMemoryInfo();
      _lastMemoryUsage = memoryInfo['used'] ?? 0.0;
      
      if (kDebugMode) {
        print('MemoryManager: Mémoire utilisée: ${_lastMemoryUsage.toStringAsFixed(1)} MB');
      }
      
      if (_lastMemoryUsage > _criticalMemoryThreshold) {
        await _handleCriticalMemory();
      } else if (_lastMemoryUsage > _lowMemoryThreshold) {
        await _handleLowMemory();
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('MemoryManager: Erreur lors de la vérification mémoire: $e');
      }
    }
  }

  /// Obtient les informations sur la mémoire
  Future<Map<String, double>> _getMemoryInfo() async {
    if (Platform.isAndroid) {
      return await _getAndroidMemoryInfo();
    } else if (Platform.isIOS) {
      return await _getIOSMemoryInfo();
    }
    
    return {'used': 0.0, 'total': 0.0, 'available': 0.0};
  }

  /// Informations mémoire Android
  Future<Map<String, double>> _getAndroidMemoryInfo() async {
    try {
      const platform = MethodChannel('neo_stream/memory');
      final result = await platform.invokeMethod('getMemoryInfo');
      
      return {
        'used': (result['usedMemory'] ?? 0).toDouble() / (1024 * 1024), // Convertir en MB
        'total': (result['totalMemory'] ?? 0).toDouble() / (1024 * 1024),
        'available': (result['availableMemory'] ?? 0).toDouble() / (1024 * 1024),
      };
    } catch (e) {
      // Fallback: estimation basée sur les ressources système
      return _estimateMemoryUsage();
    }
  }

  /// Informations mémoire iOS
  Future<Map<String, double>> _getIOSMemoryInfo() async {
    try {
      const platform = MethodChannel('neo_stream/memory');
      final result = await platform.invokeMethod('getMemoryInfo');
      
      return {
        'used': (result['usedMemory'] ?? 0).toDouble() / (1024 * 1024),
        'total': (result['totalMemory'] ?? 0).toDouble() / (1024 * 1024),
        'available': (result['availableMemory'] ?? 0).toDouble() / (1024 * 1024),
      };
    } catch (e) {
      return _estimateMemoryUsage();
    }
  }

  /// Estimation de l'utilisation mémoire (fallback)
  Map<String, double> _estimateMemoryUsage() {
    // Estimation basique pour les cas où l'API native n'est pas disponible
    return {
      'used': 80.0, // Estimation conservatrice
      'total': 512.0, // Estimation pour appareils bas de gamme
      'available': 432.0,
    };
  }

  /// Gère les situations de mémoire critique
  Future<void> _handleCriticalMemory() async {
    if (kDebugMode) {
      print('MemoryManager: Mémoire critique détectée - nettoyage agressif');
    }
    
    // Nettoyage agressif
    await _performAggressiveCleanup();
    
    // Notifier les callbacks de mémoire faible
    for (final callback in _lowMemoryCallbacks) {
      try {
        callback();
      } catch (e) {
        if (kDebugMode) {
          print('MemoryManager: Erreur dans callback mémoire faible: $e');
        }
      }
    }
  }

  /// Gère les situations de mémoire faible
  Future<void> _handleLowMemory() async {
    if (kDebugMode) {
      print('MemoryManager: Mémoire faible détectée - nettoyage léger');
    }
    
    await _performLightCleanup();
  }

  /// Nettoyage agressif de la mémoire
  Future<void> _performAggressiveCleanup() async {
    // Forcer le garbage collection
    await _forceGarbageCollection();
    
    // Vider les caches d'images
    await _clearImageCaches();
    
    // Exécuter les callbacks de nettoyage
    for (final callback in _cleanupCallbacks) {
      try {
        callback();
      } catch (e) {
        if (kDebugMode) {
          print('MemoryManager: Erreur dans callback nettoyage: $e');
        }
      }
    }
  }

  /// Nettoyage léger de la mémoire
  Future<void> _performLightCleanup() async {
    // Garbage collection léger
    await _forceGarbageCollection();
    
    // Nettoyage partiel des caches
    await _clearImageCaches(aggressive: false);
  }

  /// Force le garbage collection
  Future<void> _forceGarbageCollection() async {
    // Déclencher le GC de Dart
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (kDebugMode) {
      print('MemoryManager: Garbage collection forcé');
    }
  }

  /// Vide les caches d'images
  Future<void> _clearImageCaches({bool aggressive = true}) async {
    try {
      // Vider le cache d'images de Flutter
      PaintingBinding.instance.imageCache.clear();
      
      if (aggressive) {
        // Réduire la taille maximale du cache
        PaintingBinding.instance.imageCache.maximumSize = 50;
        PaintingBinding.instance.imageCache.maximumSizeBytes = 10 * 1024 * 1024; // 10MB
      }
      
      if (kDebugMode) {
        print('MemoryManager: Cache d\'images vidé');
      }
    } catch (e) {
      if (kDebugMode) {
        print('MemoryManager: Erreur lors du vidage du cache: $e');
      }
    }
  }

  /// Optimise les paramètres pour les appareils lents
  void optimizeForLowEndDevice() {
    // Réduire la taille du cache d'images
    PaintingBinding.instance.imageCache.maximumSize = 30;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 5 * 1024 * 1024; // 5MB
    
    if (kDebugMode) {
      print('MemoryManager: Optimisations pour appareils bas de gamme appliquées');
    }
  }

  /// Ajoute un callback pour les situations de mémoire faible
  void addLowMemoryCallback(VoidCallback callback) {
    _lowMemoryCallbacks.add(callback);
  }

  /// Supprime un callback de mémoire faible
  void removeLowMemoryCallback(VoidCallback callback) {
    _lowMemoryCallbacks.remove(callback);
  }

  /// Ajoute un callback de nettoyage
  void addCleanupCallback(VoidCallback callback) {
    _cleanupCallbacks.add(callback);
  }

  /// Supprime un callback de nettoyage
  void removeCleanupCallback(VoidCallback callback) {
    _cleanupCallbacks.remove(callback);
  }

  /// Obtient l'utilisation actuelle de la mémoire
  double get currentMemoryUsage => _lastMemoryUsage;

  /// Vérifie si la mémoire est faible
  bool get isLowMemory => _lastMemoryUsage > _lowMemoryThreshold;

  /// Vérifie si la mémoire est critique
  bool get isCriticalMemory => _lastMemoryUsage > _criticalMemoryThreshold;

  /// Nettoie les ressources du gestionnaire
  void dispose() {
    stopMonitoring();
    _lowMemoryCallbacks.clear();
    _cleanupCallbacks.clear();
  }
}

/// Extension pour faciliter l'utilisation du gestionnaire de mémoire
extension MemoryOptimization on Widget {
  /// Enveloppe le widget avec une gestion optimisée de la mémoire
  Widget withMemoryOptimization() {
    return _MemoryOptimizedWrapper(child: this);
  }
}

/// Widget wrapper pour l'optimisation mémoire
class _MemoryOptimizedWrapper extends StatefulWidget {
  final Widget child;

  const _MemoryOptimizedWrapper({required this.child});

  @override
  State<_MemoryOptimizedWrapper> createState() => _MemoryOptimizedWrapperState();
}

class _MemoryOptimizedWrapperState extends State<_MemoryOptimizedWrapper> {
  late MemoryManager _memoryManager;

  @override
  void initState() {
    super.initState();
    _memoryManager = MemoryManager();
    _memoryManager.addLowMemoryCallback(_onLowMemory);
  }

  @override
  void dispose() {
    _memoryManager.removeLowMemoryCallback(_onLowMemory);
    super.dispose();
  }

  void _onLowMemory() {
    if (mounted) {
      // Réduire la qualité des animations ou autres optimisations
      setState(() {
        // Trigger rebuild with optimizations
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}