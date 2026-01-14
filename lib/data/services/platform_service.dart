import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

enum PlatformType { tv, android }

class PlatformService {
  static const String _platformKey = 'selected_platform';
  static const String _setupCompletedKey = 'platform_setup_completed';
  
  // État du mode TV
  static bool _isTVMode = false;
  static PlatformType? _currentPlatform;

/// Sauvegarde le choix de plateforme
  static Future<void> savePlatformChoice(PlatformType platform) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          throw TimeoutException('SharedPreferences timeout', const Duration(seconds: 2));
        },
      );
      await prefs.setString(_platformKey, platform.name);
      await prefs.setBool(_setupCompletedKey, true);
      
      debugPrint('🖥️ Plateforme sauvegardée: ${platform.name}, Mode TV: $_isTVMode');
    } catch (e) {
      debugPrint('⚠️ Erreur sauvegarde plateforme (utilisation mémoire uniquement): $e');
    }
    
    // Mettre à jour l'état local (toujours fait même si sauvegarde échoue)
    _currentPlatform = platform;
    _isTVMode = platform == PlatformType.tv;
    debugPrint('🖥️ Plateforme en mémoire: ${platform.name}, Mode TV: $_isTVMode');
  }

  /// Récupère le choix de plateforme sauvegardé
  static Future<PlatformType?> getSavedPlatform() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      final platformName = prefs.getString(_platformKey);
      if (platformName != null) {
        final platform = PlatformType.values.firstWhere(
          (e) => e.name == platformName,
          orElse: () => PlatformType.android,
        );
        
        // Mettre à jour l'état local
        _currentPlatform = platform;
        _isTVMode = platform == PlatformType.tv;
        
        return platform;
      }
    } catch (e) {
      debugPrint('⚠️ Erreur récupération plateforme: $e');
    }
    
    // Retourner la plateforme en mémoire si disponible
    return _currentPlatform;
  }

  /// Vérifie si la configuration de plateforme est terminée
  static Future<bool> isPlatformSetupCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      return prefs.getBool(_setupCompletedKey) ?? false;
    } catch (e) {
      debugPrint('⚠️ Erreur vérification setup plateforme: $e');
      // Si on a une plateforme en mémoire, considérer comme configuré
      return _currentPlatform != null;
    }
  }

  /// Remet à zéro la configuration de plateforme
  static Future<void> resetPlatformSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_platformKey);
    await prefs.remove(_setupCompletedKey);
  }

  /// Obtient le nom d'affichage de la plateforme
  static String getPlatformDisplayName(PlatformType platform) {
    switch (platform) {
      case PlatformType.tv:
        return 'Mode TV';
      case PlatformType.android:
        return 'Mode Mobile';
    }
  }

  /// Obtient la description de la plateforme
  static String getPlatformDescription(PlatformType platform) {
    switch (platform) {
      case PlatformType.tv:
        return 'Optimisé pour les téléviseurs et Android TV';
      case PlatformType.android:
        return 'Optimisé pour smartphones et tablettes';
    }
  }
  
  /// Vérifie si le mode TV est actif
  static bool get isTVMode => _isTVMode;
  
  /// Obtient la plateforme actuelle
  static PlatformType? get currentPlatform => _currentPlatform;
  
  /// Initialise le service avec la plateforme sauvegardée
  static Future<void> initialize() async {
    await getSavedPlatform();
  }
  
  /// Configure les raccourcis clavier pour la télécommande TV
  static Map<LogicalKeySet, Intent> getTVShortcuts() {
    if (!_isTVMode) return {};
    
    return {
      // Navigation directionnelle
      LogicalKeySet(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),
      LogicalKeySet(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
      LogicalKeySet(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
      LogicalKeySet(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
      
      // Boutons de la télécommande
      LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
      LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      LogicalKeySet(LogicalKeyboardKey.space): const ActivateIntent(),
      
      // Navigation
      LogicalKeySet(LogicalKeyboardKey.escape): const _BackIntent(),
      LogicalKeySet(LogicalKeyboardKey.goBack): const _BackIntent(),
    };
  }
  
  /// Actions pour les raccourcis TV
  static Map<Type, Action<Intent>> getTVActions(BuildContext context) {
    if (!_isTVMode) return {};
    
    return {
      _BackIntent: CallbackAction<_BackIntent>(
        onInvoke: (intent) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          return null;
        },
      ),
    };
  }
}

// Intent personnalisé pour la navigation
class _BackIntent extends Intent {
  const _BackIntent();
}