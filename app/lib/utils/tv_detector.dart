import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class TVDetector {
  static bool _isTVCache = false;
  static bool _isPCCache = false;
  static bool _hasChecked = false;

  static bool get isTVMode {
    if (!_hasChecked) _detectAll();
    return _isTVCache;
  }

  static bool get isPCMode {
    if (!_hasChecked) _detectAll();
    return _isPCCache;
  }

  static void _detectAll() {
    _hasChecked = true;

    if (kIsWeb) {
      _isTVCache = _detectTVFromUserAgent();
      _isPCCache = false;
      return;
    }

    if (Platform.isAndroid) {
      _isTVCache = _detectAndroidTV();
      _isPCCache = false;
    } else if (Platform.isLinux) {
      _isTVCache = _detectLinuxTV();
      _isPCCache = !_isTVCache;
    } else if (Platform.isMacOS) {
      _isTVCache = false;
      _isPCCache = true;
    } else if (Platform.isWindows) {
      _isTVCache = false;
      _isPCCache = true;
    } else if (Platform.isIOS) {
      _isTVCache = false;
      _isPCCache = false;
    } else {
      _isTVCache = false;
      _isPCCache = false;
    }
  }

  static bool _detectAndroidTV() {
    try {
      final brand = Platform.environment['BRAND'] ?? '';
      final model = Platform.environment['MODEL'] ?? '';
      final device = Platform.environment['DEVICE'] ?? '';

      final tvIndicators = [
        'androidtv', 'firetv', 'fire tv', 'television', 'tv box',
        'chromecast', 'nvidia shield', 'mi box', 'apple tv',
      ];

      final combined = '$brand $model $device'.toLowerCase();
      return tvIndicators.any((indicator) => combined.contains(indicator));
    } catch (_) {
      return false;
    }
  }

  static bool _detectLinuxTV() {
    try {
      final drm = Platform.environment['XDG_SESSION_TYPE'] ?? '';
      final desktop = Platform.environment['XDG_CURRENT_DESKTOP'] ?? '';

      return drm.toLowerCase() == 'drm' ||
          desktop.toLowerCase().contains('kodi') ||
          desktop.toLowerCase().contains('plex');
    } catch (_) {
      return false;
    }
  }

  static bool _detectTVFromUserAgent() {
    try {
      return false;
    } catch (_) {
      return false;
    }
  }

  static void resetCache() {
    _hasChecked = false;
    _isTVCache = false;
    _isPCCache = false;
  }
}