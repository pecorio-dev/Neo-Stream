import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class TVDetector {
  static const MethodChannel _channel =
      MethodChannel('eu.neostream.neo_stream/tv_detector');

  static bool _isTVCache = false;
  static bool _isPCCache = false;
  static bool _hasChecked = false;
  static bool _initDone = false;

  /// Async initializer: calls the platform channel to get real Android TV
  /// detection (via [android.content.res.Configuration.UI_MODE_TYPE_TELEVISION]).
  /// Must be called before reading [isTVMode] / [isPCMode] for reliable results.
  static Future<void> init() async {
    if (_initDone) return;
    _initDone = true;

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final isTv = await _channel.invokeMethod<bool>('isAndroidTv') ?? false;
        if (isTv) {
          _isTVCache = true;
          _hasChecked = true;
          return;
        }
        // Fallback: try build props for keyword matching
        final props = await _channel.invokeMethod<Map<dynamic, dynamic>>('getBuildProps') ?? {};
        final combined = props.values.join(' ').toLowerCase();
        const tvIndicators = [
          'androidtv', 'firetv', 'fire tv', 'television', 'tv box',
          'chromecast', 'nvidia shield', 'mi box', 'apple tv', 'atv',
          'mibox', 'shield', 'dongle', 'smarttv', 'bbox', 'freebox',
          'livebox', 'sagemcom', 'sony tv', 'sony bravia', 'tcl tv',
          'tcl smart', 'philips tv', 'philips smart', 'hisense tv',
          'hisense smart', 'smart tv', 'set-top', 'settop', 'ott', 'stb',
        ];
        if (tvIndicators.any((i) => combined.contains(i))) {
          _isTVCache = true;
          _hasChecked = true;
          return;
        }
      } catch (_) {
        // Channel unavailable → fall through to synchronous detection
      }
    }
    // Synchronous detection runs lazily on first getter access
  }

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
      // If init() already set the cache, keep it; otherwise run fallback.
      if (!_initDone) _detectAndroidTVFallback();
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

  /// Synchronous fallback using [Platform.environment].
  /// On standard Android, environment variables are empty strings, so this
  /// typically returns false — the [init()] async path should be preferred.
  static void _detectAndroidTVFallback() {
    try {
      final brand = (Platform.environment['BRAND'] ?? '').toLowerCase();
      final model = (Platform.environment['MODEL'] ?? '').toLowerCase();
      final device = (Platform.environment['DEVICE'] ?? '').toLowerCase();
      final manufacturer = (Platform.environment['MANUFACTURER'] ?? '').toLowerCase();

      const tvIndicators = [
        'androidtv', 'firetv', 'fire tv', 'television', 'tv box',
        'chromecast', 'nvidia shield', 'mi box', 'apple tv', 'atv',
        'mibox', 'shield', 'dongle', 'smarttv', 'bbox', 'freebox',
        'livebox', 'sagemcom', 'bouygtel', 'sony tv', 'sony bravia',
        'tcl tv', 'tcl smart', 'philips tv', 'philips smart',
        'hisense tv', 'hisense smart', 'smart tv', 'set-top', 'settop',
        'ott', 'stb',
      ];

      final combined = '$brand $model $device $manufacturer';
      _isTVCache = tvIndicators.any((indicator) => combined.contains(indicator));
      _isPCCache = false;
    } catch (_) {
      _isTVCache = false;
      _isPCCache = false;
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
      return false;
    } catch (_) {
      return false;
    }
  }

  static void resetCache() {
    _hasChecked = false;
    _isTVCache = false;
    _isPCCache = false;
    _initDone = false;
  }
}
