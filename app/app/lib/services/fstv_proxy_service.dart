import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/fstv_channel.dart';

/// Client IPTV via le système NEO-STREAM FSTV (gratuit, pas d'auth requise).
///
/// Endpoints :
///   GET /api/live_channels.php → {total, items: [{slug, name, category, sources}]}
///   GET /api/live_sources.php?slug=xxx → {slug, name, sources: [{url, label}]}
///   GET /api/live_proxy.php?action=m3u8&id=<fstv_stream_id> → M3U8 playlist
class FstvProxyService {
  FstvProxyService._();
  static final FstvProxyService instance = FstvProxyService._();

  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _cacheMaxAge = Duration(minutes: 30);

  String get _apiBase => AppConstants.phpProxyBaseUrl;

  // Cache mémoire
  Map<String, List<FstvChannel>>? _channelsCache;
  DateTime? _channelsCacheTime;

  // ── Chaînes ─────────────────────────────────────────────────────────────

  /// Récupère toutes les chaînes FSTV groupées par catégorie.
  Future<Map<String, List<FstvChannel>>> getChannels({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _channelsCache != null &&
        _channelsCacheTime != null &&
        DateTime.now().difference(_channelsCacheTime!) < _cacheMaxAge) {
      return _channelsCache!;
    }

    final url = Uri.parse('${_apiBase}live_channels.php?limit=200');
    final response = await http
        .get(url, headers: {'Accept': 'application/json', 'User-Agent': 'NEO-Stream/4.0'})
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw FstvException('Erreur serveur (${response.statusCode})');
    }

    final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final result = <String, List<FstvChannel>>{};

    for (final item in items) {
      try {
        final channel = FstvChannel.fromJson(item);
        result.putIfAbsent(channel.category, () => <FstvChannel>[]).add(channel);
      } catch (e) {
        // Skip invalid channels
        continue;
      }
    }

    // Trier par catégorie puis par nom
    final ordered = Map.fromEntries(
      result.entries.toList()
        ..sort((a, b) => _categoryOrder(a.key).compareTo(_categoryOrder(b.key))),
    );
    for (final cat in ordered.keys) {
      ordered[cat]!.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    _channelsCache = ordered;
    _channelsCacheTime = DateTime.now();
    return ordered;
  }

  /// Toutes les chaînes à plat.
  Future<List<FstvChannel>> getAllChannels({bool forceRefresh = false}) async {
    final grouped = await getChannels(forceRefresh: forceRefresh);
    return grouped.values.expand((list) => list).toList(growable: false);
  }

  /// URL du stream HLS pour une chaîne (via son slug).
  /// Fetch d'abord live_sources.php pour obtenir le fstv_stream_id.
  Future<String> streamUrlFor(String slug) async {
    final url = Uri.parse('${_apiBase}live_sources.php?slug=$slug');
    final response = await http
        .get(url, headers: {'Accept': 'application/json', 'User-Agent': 'NEO-Stream/4.0'})
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw FstvException('Chaîne introuvable');
    }

    final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final sources = (data['sources'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (sources.isEmpty) {
      throw FstvException('Aucune source disponible');
    }

    // Prendre la première source (meilleur score)
    return sources.first['url'] as String;
  }

  /// Headers pour le player (pas besoin de cookie, FSTV est gratuit)
  Map<String, String> playerHeaders() => {
        'User-Agent': 'NEO-Stream/4.0 (Flutter)',
        'Accept': '*/*',
      };

  /// Invalide le cache
  void invalidateChannels() {
    _channelsCache = null;
    _channelsCacheTime = null;
  }

  /// Pas d'authentification requise pour FSTV
  Future<void> ensureAuthenticated() async {
    // FSTV est gratuit, rien à faire
    return;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  int _categoryOrder(String cat) {
    const order = [
      'Sport',
      'Généraliste',
      'Cinéma',
      'Enfants',
      'Documentaire',
      'Info',
      'Musique',
    ];
    final idx = order.indexOf(cat);
    return idx >= 0 ? idx : 999;
  }

  static String humanize(Object e) {
    if (e is FstvException) return e.message;
    if (e is TimeoutException) return 'Délai expiré. Vérifiez votre connexion.';
    return 'Erreur réseau : ${e.toString()}';
  }
}

// ── Exceptions ─────────────────────────────────────────────────────────────

class FstvException implements Exception {
  final String message;
  FstvException(this.message);
  @override
  String toString() => message;
}

class FstvAuthException extends FstvException {
  FstvAuthException(super.message);
}

class FstvPremiumRequiredException extends FstvException {
  FstvPremiumRequiredException(super.message);
}
