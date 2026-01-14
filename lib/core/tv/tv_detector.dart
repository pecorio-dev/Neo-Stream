import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service de détection de l'environnement TV
class TVDetector {
  static bool? _isTVMode;
  static bool? _hasLeanback;
  static bool? _hasTouchscreen;

  /// Vérifie si l'application s'exécute sur un Android TV
  static Future<bool> isRunningOnTV() async {
    if (_isTVMode != null) return _isTVMode!;

    try {
      // Vérifier les features Android TV
      _hasLeanback = await _hasFeature('android.software.leanback');
      _hasTouchscreen = await _hasFeature('android.hardware.touchscreen');
      
      // Mode TV si leanback disponible ET pas d'écran tactile requis
      _isTVMode = (_hasLeanback == true) || (_hasTouchscreen == false);
      
      debugPrint('🖥️ TV Detection: leanback=$_hasLeanback, touchscreen=$_hasTouchscreen, isTV=$_isTVMode');
      
      return _isTVMode!;
    } catch (e) {
      debugPrint('❌ Erreur détection TV: $e');
      _isTVMode = false;
      return false;
    }
  }

  /// Vérifie si une feature Android est disponible
  static Future<bool> _hasFeature(String feature) async {
    try {
      const platform = MethodChannel('neostream/tv_detector');
      final result = await platform.invokeMethod('hasSystemFeature', feature);
      return result == true;
    } catch (e) {
      debugPrint('❌ Erreur vérification feature $feature: $e');
      return false;
    }
  }

  /// Force le mode TV (pour les tests)
  static void forceTVMode(bool enabled) {
    _isTVMode = enabled;
    debugPrint('🖥️ Mode TV forcé: $enabled');
  }

  /// Réinitialise la détection
  static void reset() {
    _isTVMode = null;
    _hasLeanback = null;
    _hasTouchscreen = null;
  }

  /// Getters pour les informations de détection
  static bool get isTVMode => _isTVMode ?? false;
  static bool get hasLeanback => _hasLeanback ?? false;
  static bool get hasTouchscreen => _hasTouchscreen ?? true;
}