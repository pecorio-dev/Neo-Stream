import 'package:shared_preferences/shared_preferences.dart';

class PlayerPrefs {
  static const _keyHwdec = 'player_hwdec';
  static const _keyAudioDelay = 'player_audio_delay_ms';
  static const _keySubScale = 'player_sub_scale';
  static const _keyRate = 'player_playback_rate';

  bool hwdecEnabled;
  int audioDelayMs;
  double subScale;
  double playbackRate;

  PlayerPrefs({
    this.hwdecEnabled = true,
    this.audioDelayMs = 0,
    this.subScale = 1.0,
    this.playbackRate = 1.0,
  });

  static Future<PlayerPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PlayerPrefs(
      hwdecEnabled: prefs.getBool(_keyHwdec) ?? true,
      audioDelayMs: prefs.getInt(_keyAudioDelay) ?? 0,
      subScale: prefs.getDouble(_keySubScale) ?? 1.0,
      playbackRate: prefs.getDouble(_keyRate) ?? 1.0,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHwdec, hwdecEnabled);
    await prefs.setInt(_keyAudioDelay, audioDelayMs);
    await prefs.setDouble(_keySubScale, subScale);
    await prefs.setDouble(_keyRate, playbackRate);
  }

  // ── Cache local de la position de lecture ─────────────────────────
  // Filet de sécurité quand l'API de progression est lente ou indisponible :
  // la reprise lit d'abord cette valeur locale (instantanée) puis se réconcilie
  // avec l'API en arrière-plan. Évite le « retour au début ».

  static String _progressKey(String id) => 'local_progress_$id';

  /// Sauvegarde la position (et la durée) en secondes pour un média donné.
  static Future<void> saveLocalProgress(
    String id, {
    required double position,
    required double duration,
  }) async {
    if (position <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _progressKey(id),
        '$position|$duration|${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (_) {}
  }

  /// Renvoie la dernière position connue (en secondes) ou null.
  /// `position` et `duration` sont en secondes.
  static Future<({double position, double duration})?> loadLocalProgress(
    String id,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_progressKey(id));
      if (raw == null) return null;
      final parts = raw.split('|');
      if (parts.isEmpty) return null;
      final pos = double.tryParse(parts[0]) ?? 0.0;
      final dur = parts.length > 1 ? (double.tryParse(parts[1]) ?? 0.0) : 0.0;
      if (pos <= 0) return null;
      return (position: pos, duration: dur);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearLocalProgress(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_progressKey(id));
    } catch (_) {}
  }
}
