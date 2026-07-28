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

  // Increased timeout for stability on slow connections/TV
  static const Duration _timeout = Duration(seconds: 30);
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

    try {
      final url = Uri.parse('${_apiBase}live_channels.php?limit=200');
      final response = await http
          .get(url, headers: {'Accept': 'application/json', 'User-Agent': 'NEO-Stream/4.0'})
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw FstvException('Erreur serveur (${response.statusCode})');
      }

      final decoded = json.decode(utf8.decode(response.bodyBytes));
      final data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      final itemsRaw = data['items'];
      final items = itemsRaw is List
          ? itemsRaw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
          : <Map<String, dynamic>>[];

      final result = <String, List<FstvChannel>>{};

      for (final item in items) {
        try {
          final channel = FstvChannel.fromJson(item);
          result.putIfAbsent(channel.category, () => <FstvChannel>[]).add(channel);
        } catch (_) {
          // Skip invalid channels - safe
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
    } on TimeoutException {
      throw FstvException('Timeout: serveur lent');
    } catch (e) {
      throw FstvException('Erreur chargement chaînes: $e');
    }
  }

  /// Toutes les chaînes à plat.
  Future<List<FstvChannel>> getAllChannels({bool forceRefresh = false}) async {
    final grouped = await getChannels(forceRefresh: forceRefresh);
    return grouped.values.expand((list) => list).toList(growable: false);
  }

  /// Retourne **toutes** les sources valides d'une chaîne, dans l'ordre API.
  /// Le lecteur fait 1 essai par source puis bascule (pas de skip de la 1re).
  Future<List<String>> streamUrlsFor(String slug) async {
    try {
      final url = Uri.parse('${_apiBase}live_sources.php?slug=$slug');
      final response = await http
          .get(url, headers: {'Accept': 'application/json', 'User-Agent': 'NEO-Stream/4.0'})
          .timeout(_timeout);

      if (response.statusCode != 200) {
        // Fallback : sources embarquées dans le cache canaux
        final cached = _urlsFromChannelCache(slug);
        if (cached.isNotEmpty) return cached;
        throw FstvException('Chaîne introuvable');
      }

      final decoded = json.decode(utf8.decode(response.bodyBytes));
      final data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      final sourcesRaw = data['sources'];
      final sources = sourcesRaw is List
          ? sourcesRaw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
          : <Map<String, dynamic>>[];

      final urls = _parseSourceUrls(sources);
      if (urls.isEmpty) {
        final cached = _urlsFromChannelCache(slug);
        if (cached.isNotEmpty) return cached;
        throw FstvException('Aucune source disponible');
      }
      return urls;
    } on TimeoutException {
      final cached = _urlsFromChannelCache(slug);
      if (cached.isNotEmpty) return cached;
      throw FstvException('Timeout: récupération source');
    } on FstvException {
      rethrow;
    } catch (e) {
      final cached = _urlsFromChannelCache(slug);
      if (cached.isNotEmpty) return cached;
      throw FstvException('Erreur source: $e');
    }
  }

  /// Extrait les URLs http(s) uniques en conservant l'ordre.
  List<String> _parseSourceUrls(List<Map<String, dynamic>> sources) {
    final urls = <String>[];
    final seen = <String>{};
    for (final source in sources) {
      final value = source['url'];
      if (value is! String) continue;
      final raw = value.trim();
      if (raw.isEmpty || seen.contains(raw)) continue;
      final uri = Uri.tryParse(raw);
      if (uri == null || !uri.hasScheme) continue;
      if (uri.scheme != 'https' && uri.scheme != 'http') continue;
      seen.add(raw);
      urls.add(raw);
    }
    return List<String>.unmodifiable(urls);
  }

  /// Sources déjà présentes sur le modèle canal (live_channels.php).
  List<String> _urlsFromChannelCache(String slug) {
    final cache = _channelsCache;
    if (cache == null) return const [];
    for (final list in cache.values) {
      for (final ch in list) {
        if (ch.slug == slug && ch.sources.isNotEmpty) {
          return _parseSourceUrls(ch.sources);
        }
      }
    }
    return const [];
  }

  /// Raccourci de compatibilité pour les appels qui n'ont besoin que de la
  /// première source.
  Future<String> streamUrlFor(String slug) async =>
      (await streamUrlsFor(slug)).first;

  /// Headers pour le player ExoPlayer (Freebox Mini 4K / Android TV).
  /// UA type box TV + Accept HLS : certains CDN refusent les UA desktop.
  Map<String, String> playerHeaders() => {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 12; Freebox Player Mini 4K) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept':
            'application/vnd.apple.mpegurl, application/x-mpegURL, application/octet-stream, */*',
        'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
        'Referer': 'https://iptv.mine.bz/',
        'Origin': 'https://iptv.mine.bz',
        'Connection': 'keep-alive',
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
