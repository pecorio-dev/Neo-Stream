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
      _isPCCache = !_isTVCache;
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
      _isTVCache = _detectWindowsTV();
      _isPCCache = !_isTVCache;
    } else if (Platform.isIOS) {
      _isTVCache = false;
      _isPCCache = false;
    } else {
      _isTVCache = false;
      _isPCCache = false;
    }
  }

  // Improved reliability: more specific checks, avoid always-true default
  static bool _detectAndroidTV() {
    try {
      final brand = (Platform.environment['BRAND'] ?? '').toLowerCase();
      final model = (Platform.environment['MODEL'] ?? '').toLowerCase();
      final device = (Platform.environment['DEVICE'] ?? '').toLowerCase();
      final manufacturer = (Platform.environment['MANUFACTURER'] ?? '').toLowerCase();

      final tvIndicators = [
        'androidtv', 'firetv', 'fire tv', 'television', 'tv box',
        'chromecast', 'nvidia shield', 'mi box', 'apple tv', 'atv',
        'mibox', 'shield', 'dongle', 'smarttv', 'bbox', 'freebox',
        'livebox', 'sagemcom', 'bouygtel', 'tcl', 'hisense', 'sony', 'philips', 'realme',
        'tv', 'set-top', 'settop', 'ott', 'stb'
      ];

      final combined = '$brand $model $device $manufacturer';
      final isTv = tvIndicators.any((indicator) => combined.contains(indicator));

      // Only default to TV if clear TV signals, else false for phones/tablets
      if (isTv) return true;

      // Heuristic: large screen but avoid assuming all Android is TV
      return false;
    } catch (_) {
      return false; // Safer default
    }
  }

  static bool _detectLinuxTV() {
    try {
      final drm = (Platform.environment['XDG_SESSION_TYPE'] ?? '').toLowerCase();
      final desktop = (Platform.environment['XDG_CURRENT_DESKTOP'] ?? '').toLowerCase();

      return drm == 'drm' ||
          desktop.contains('kodi') ||
          desktop.contains('plex') ||
          desktop.contains('tv');
    } catch (_) {
      return false;
    }
  }

  static bool _detectWindowsTV() {
    try {
      final session = (Platform.environment['SESSIONNAME'] ?? '').toLowerCase();
      return session.contains('console') && Platform.environment.containsKey('TV_MODE');
    } catch (_) {
      return false;
    }
  }

  static bool _detectTVFromUserAgent() {
    try {
      // In real web, check navigator.userAgent but here conservative
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
