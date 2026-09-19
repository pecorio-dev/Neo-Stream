import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Favoris IPTV (En Direct) persistés localement.
///
/// Stocke un set de slugs de chaînes sous la clé 'iptv_favorites'.
/// ChangeNotifier singleton : les écrans (grille + player) s'abonnent
/// pour rafraîchir les cœurs sans recharger les chaînes.
class IptvFavorites extends ChangeNotifier {
  IptvFavorites._();
  static final IptvFavorites instance = IptvFavorites._();

  static const storageKey = 'iptv_favorites';

  Set<String> _ids = {};
  bool _loaded = false;
  Future<void>? _loadingFuture;

  /// Slugs favoris (copie immuable).
  Set<String> get ids => Set<String>.unmodifiable(_ids);
  bool get isLoaded => _loaded;
  int get count => _ids.length;

  bool isFavorite(String slug) => _ids.contains(slug);

  /// Charge depuis SharedPreferences (idempotent, single-flight : les
  /// appels concurrents — grille + player — sont fusionnés en un seul).
  /// Ne notifie que si le contenu a réellement changé (évite un rebuild
  /// complet de la grille à chaque initState).
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
    Set<String> next;
    try {
      final prefs = await SharedPreferences.getInstance();
      next = Set<String>.from(prefs.getStringList(storageKey) ?? const []);
    } catch (_) {
      next = {};
    }
    final first = !_loaded;
    _loaded = true;
    if (!first && _ids.length == next.length && _ids.containsAll(next)) {
      return; // Inchangé : pas de notify → pas de rebuild.
    }
    _ids = next;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(storageKey, _ids.toList());
    } catch (_) {}
  }

  Future<void> add(String slug) async {
    if (slug.isEmpty || _ids.contains(slug)) return;
    _ids.add(slug);
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String slug) async {
    if (!_ids.remove(slug)) return;
    notifyListeners();
    await _persist();
  }

  /// Bascule le favori, retourne le nouvel état (true = favori).
  Future<bool> toggle(String slug) async {
    if (slug.isEmpty) return false;
    if (_ids.contains(slug)) {
      await remove(slug);
      return false;
    }
    await add(slug);
    return true;
  }
}
