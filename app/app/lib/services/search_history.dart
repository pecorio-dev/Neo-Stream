import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Historique de recherche local (max 15 entrées, plus récentes en tête).
class SearchHistory extends ChangeNotifier {
  SearchHistory._();
  static final SearchHistory instance = SearchHistory._();

  static const _key = 'search_history_v1';
  static const _max = 15;

  List<String> _items = [];
  bool _loaded = false;

  List<String> get items => List.unmodifiable(_items);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is List) {
        _items = list.whereType<String>().where((s) => s.trim().isNotEmpty).toList();
      }
    } catch (_) {}
  }

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.length < 2) return;
    _items.removeWhere((s) => s.toLowerCase() == q.toLowerCase());
    _items.insert(0, q);
    if (_items.length > _max) _items = _items.sublist(0, _max);
    await _save();
    notifyListeners();
  }

  Future<void> remove(String query) async {
    _items.remove(query);
    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    _items = [];
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_items));
    } catch (_) {}
  }
}
