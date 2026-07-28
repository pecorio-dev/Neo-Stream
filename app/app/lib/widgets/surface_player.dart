import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lance le lecteur natif ExoPlayer ([NativeVideoActivity]) sur Android / Android TV.
///
/// Conçu pour Freebox Mini 4K et box TV : SurfaceView natif, pas de PlatformView
/// Flutter (souvent écran noir sur ces appareils).
///
/// Multi-sources : passer [urls] pour bascule 1-try-par-source **dans** l'Activity
/// native (sans fermer/rouvrir → plus d'écran noir entre sources).
class SurfacePlayerController {
  static const _playerChannel = MethodChannel('eu.neostream.neo_stream/player');

  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// Ouvre le player natif plein écran et attend la fermeture.
  ///
  /// Retourne un map :
  /// - `ok` : lecture OK (utilisateur a quitté sans erreur fatale)
  /// - `position` : position ms
  /// - `completed` : fin de média VOD
  /// - `hadError` / `error` : échec de lecture (toutes sources épuisées)
  ///
  /// Retourne `null` si le channel échoue ou si le controller est disposé.
  Future<Map<String, dynamic>?> play({
    required String url,
    List<String>? urls,
    Map<String, String>? headers,
    List<Map<String, String>>? headersList,
    int position = 0,
    bool isLive = false,
  }) async {
    if (_disposed) return null;
    try {
      final allUrls = <String>[];
      if (urls != null) {
        for (final u in urls) {
          final t = u.trim();
          if ((t.startsWith('http://') || t.startsWith('https://')) &&
              !allUrls.contains(t)) {
            allUrls.add(t);
          }
        }
      }
      final primary = url.trim();
      if ((primary.startsWith('http://') || primary.startsWith('https://')) &&
          !allUrls.contains(primary)) {
        allUrls.insert(0, primary);
      }
      if (allUrls.isEmpty) {
        return {
          'ok': false,
          'hadError': true,
          'error': 'URL manquante',
          'position': 0,
          'completed': false,
        };
      }

      final result = await _playerChannel.invokeMethod<dynamic>('play', {
        'url': allUrls.first,
        'urls': allUrls,
        'headers': headers ?? <String, String>{},
        if (headersList != null && headersList.isNotEmpty)
          'headersList': headersList,
        'position': position,
        'isLive': isLive,
      });
      if (result is Map) {
        return result.map((k, v) => MapEntry(k.toString(), v));
      }
      return {'ok': true, 'position': 0, 'completed': false, 'hadError': false};
    } on PlatformException catch (e) {
      debugPrint('[SurfacePlayer] PlatformException: ${e.code} ${e.message}');
      return {
        'ok': false,
        'hadError': true,
        'error': e.message ?? e.code,
        'position': 0,
        'completed': false,
      };
    } catch (e) {
      debugPrint('[SurfacePlayer] error: $e');
      return {
        'ok': false,
        'hadError': true,
        'error': e.toString(),
        'position': 0,
        'completed': false,
      };
    }
  }

  /// Compat : ancien nom utilisé par UniversalPlayerController.
  Future<Map<String, dynamic>?> initialize({
    required String url,
    List<String>? urls,
    Map<String, String>? headers,
    List<Map<String, String>>? headersList,
    int position = 0,
    bool isLive = false,
  }) {
    return play(
      url: url,
      urls: urls,
      headers: headers,
      headersList: headersList,
      position: position,
      isLive: isLive,
    );
  }

  void dispose() {
    _disposed = true;
  }
}
