import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'player_prefs.dart';

/// Historique local "Reprendre" des chaînes IPTV (En Direct).
///
/// Le direct n'a pas de position/durée (pas de timeline) : la reprise =
/// "dernière chaîne regardée" par slug, avec horodatage. Persisté en local
/// sous [storageKey] (`{slug: epochMillis}`), sans appel réseau ni impact
/// sur le proxy `iptv.mine.bz`.
///
/// Migration / interop [PlayerPrefs] : si le lecteur a un jour sauvegardé
/// une progression locale sous la clé `iptv_<slug>` (via
/// `PlayerPrefs.saveLocalProgress`), l'horodatage embarqué (3e segment
/// `pos|dur|ts`) est importé au chargement — le meilleur des deux gagne.
class IptvResume extends ChangeNotifier {
  IptvResume._();
  static final IptvResume instance = IptvResume._();

  static const storageKey = 'iptv_last_seen_v1';

  /// Cap anti-croissance (garde les plus récents).
  static const maxEntries = 60;

  Map<String, int> _millis = {};
  bool _loaded = false;
  Future<void>? _loadingFuture;

  bool get isLoaded => _loaded;

  /// Charge depuis SharedPreferences (idempotent, single-flight).
  Future<void> load() {
    final inFlight = _loadingFuture;
    if (inFlight != null) return inFlight;
    if (_loaded) return Future.value();
    final fut = _doLoad();
    _loadingFuture = fut;
    fut.whenComplete(() => _loadingFuture = null);
    return fut;
  }

  Future<void> _doLoad() async {
    Map<String, int> next = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        // Format : "slug1:millis1,slug2:millis2" (slugs sans ',' ni ':').
        for (final entry in raw.split(',')) {
          final idx = entry.lastIndexOf(':');
          if (idx <= 0) continue;
          final slug = entry.substring(0, idx).trim();
          final ts = int.tryParse(entry.substring(idx + 1).trim());
          if (slug.isEmpty || ts == null || ts <= 0) continue;
          next[slug] = ts;
        }
      }
      // Interop PlayerPrefs : importe les timestamps `local_progress_iptv_*`.
      for (final key in prefs.getKeys()) {
        if (!key.startsWith('local_progress_iptv_')) continue;
        final slug = key.substring('local_progress_iptv_'.length);
        if (slug.isEmpty) continue;
        final rec = await PlayerPrefs.loadLocalProgress('iptv_$slug');
        if (rec == null) continue;
        final ts = _timestampOfIptvProgress(prefs, key);
        if (ts == null) continue;
        final prev = next[slug];
        if (prev == null || ts > prev) next[slug] = ts;
      }
      next = _capped(next);
    } catch (_) {
      next = {};
    }
    _millis = next;
    _loaded = true;
    notifyListeners();
  }

  /// Timestamp (epoch millis) embarqué dans la valeur PlayerPrefs
  /// `pos|dur|ts` — null si absent/illisible.
  static int? _timestampOfIptvProgress(
    SharedPreferences prefs,
    String fullKey,
  ) {
    try {
      final raw = prefs.getString(fullKey);
      final parts = (raw ?? '').split('|');
      if (parts.length < 3) return null;
      return int.tryParse(parts[2].trim());
    } catch (_) {
      return null;
    }
  }

  static Map<String, int> _capped(Map<String, int> src) {
    if (src.length <= maxEntries) return Map<String, int>.of(src);
    final ordered = src.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map<String, int>.fromEntries(ordered.take(maxEntries));
  }

  /// Dernière vue d'une chaîne (local), null si jamais regardée.
  DateTime? lastSeen(String slug) {
    final ts = _millis[slug];
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }

  /// true si la chaîne a été regardée (affiche "Reprendre").
  bool wasWatched(String slug) => _millis.containsKey(slug);

  /// Slugs triés du plus récent au plus ancien (sous-ensemble de [slugs]
  /// si fourni, sinon tout l'historique).
  List<String> recentFirst([Iterable<String>? slugs]) {
    final entries = slugs == null
        ? _millis.entries.toList()
        : _millis.entries.where((e) => slugs.contains(e.key)).toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList(growable: false);
  }

  /// Mémorise une ouverture de chaîne (appelé au tap "Lancer le direct").
  Future<void> touch(String slug) async {
    if (slug.isEmpty) return;
    _millis[slug] = DateTime.now().millisecondsSinceEpoch;
    _millis = _capped(_millis);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = _millis.entries.map((e) => '${e.key}:${e.value}').join(',');
      await prefs.setString(storageKey, raw);
    } catch (_) {}
  }

  /// Libellé relatif FR court ("à l'instant", "il y a 5 min", "il y a 2 h"…).
  static String relativeLabel(DateTime seen, {DateTime? now}) {
    final at = (now ?? DateTime.now()).difference(seen);
    if (at.inSeconds < 60) return "à l'instant";
    if (at.inMinutes < 60) return 'il y a ${at.inMinutes} min';
    if (at.inHours < 24) return 'il y a ${at.inHours} h';
    final days = at.inDays;
    if (days < 7) return 'il y a $days j';
    if (days < 30) return 'il y a ${days ~/ 7} sem.';
    if (days < 365) return 'il y a ${days ~/ 30} mois';
    return 'il y a ${days ~/ 365} an${days ~/ 365 > 1 ? 's' : ''}';
  }
}
