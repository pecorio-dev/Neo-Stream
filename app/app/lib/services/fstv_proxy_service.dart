import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/constants.dart';
import 'resilient_http.dart';

import '../models/fstv_channel.dart';

/// Client IPTV ULTRA — connexion **DIRECTE** au proxy `https://iptv.mine.bz`.
///
/// AUCUN appel live ne transite par `neo-stream.eu` (réservé VOD films/séries).
///
/// Contrat d'API d'origine (restauré) :
///   GET /live_proxy.php?action=channels          → {_meta, channels: {id: {slug, name, category, logo, sources: [{id, label}]}}}
///   GET /live_proxy.php?action=m3u8&id=<src_id>  → playlist M3U8 (segments via ?action=proxy_segment)
///   GET /live_proxy.php?action=stream&id=<id>    → alias playlist M3U8
///   GET /live_proxy.php?action=validate          → {success, is_premium}
///
/// Cycle lecteur (voir `iptv_screen.dart`) :
///   ensureAuthenticated() → getChannels() → streamUrlsFor(slug) →
///   playerHeaders() → refresh/replay via getChannels(forceRefresh: true).
class FstvProxyService {
  FstvProxyService._();
  static final FstvProxyService instance = FstvProxyService._();

  // Increased timeout for stability on slow connections/TV
  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _validateTimeout = Duration(seconds: 10);

  /// Timeout d'un probe de playlist (rankSources) : court pour ne pas
  /// retarder l'ouverture du lecteur (5 s : une playlist M3U8 saine répond
  /// en < 2 s ; au-delà c'est une source morte qui bloque le zapping).
  static const Duration _probeTimeout = Duration(seconds: 5);
  static const Duration _cacheMaxAge = Duration(minutes: 30);

  /// Base LIVE directe — jamais neo-stream.eu (VOD uniquement).
  /// Normalisée avec slash final pour la résolution des chemins.
  String get _liveBase {
    const base = AppConstants.fstvProxyBaseUrl;
    return base.endsWith('/') ? base : '$base/';
  }

  Uri get _channelsUri =>
      Uri.parse('${_liveBase}live_proxy.php?action=channels');

  Uri get _validateUri =>
      Uri.parse('${_liveBase}live_proxy.php?action=validate');

  /// URL directe de playlist pour un identifiant de source FSTV.
  String m3u8UrlForId(String id) =>
      '${_liveBase}live_proxy.php?action=m3u8&id=${Uri.encodeComponent(id)}';

  Map<String, String> get _jsonHeaders => {
        'Accept': 'application/json',
        'User-Agent': 'NEO-Stream/4.0',
        'Referer': 'https://iptv.mine.bz/',
      };

  // Cache mémoire
  Map<String, List<FstvChannel>>? _channelsCache;
  DateTime? _channelsCacheTime;

  // ── Auth ─────────────────────────────────────────────────────────────────

  /// FSTV est gratuit : ping `validate` contre iptv.mine.bz (2 essais courts)
  /// pour vérifier que le proxy est joignable. Ne lève jamais — le live ne
  /// doit jamais être bloqué par ce contrôle.
  Future<void> ensureAuthenticated() async {
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        await ResilientHttp.get(_validateUri, headers: _jsonHeaders)
            .timeout(_validateTimeout);
        return;
      } catch (_) {
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    return;
  }

  // ── Chaînes ─────────────────────────────────────────────────────────────

  /// Récupère toutes les chaînes FSTV groupées par catégorie (cache 30 min).
  /// En cas d'échec réseau avec cache périmé disponible : sert le cache
  /// périmé plutôt que de casser le direct.
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
      final response =
          await _getWithRetry(_channelsUri, timeout: _timeout, attempts: 3);

      if (response.statusCode != 200) {
        return _staleCacheOrThrow(
            'Erreur serveur (${response.statusCode})');
      }

      final decoded = json.decode(utf8.decode(response.bodyBytes));
      final data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      final entries = _channelEntries(data);
      if (entries.isEmpty) {
        return _staleCacheOrThrow('Aucune chaîne reçue');
      }

      final result = <String, List<FstvChannel>>{};

      for (final entry in entries) {
        try {
          final channel = _channelFromDirectEntry(entry);
          // Slug vide = chaîne inexploitable → skip
          if (channel.slug.isEmpty) continue;
          result.putIfAbsent(channel.category, () => <FstvChannel>[]).add(channel);
        } catch (_) {
          // Skip invalid channels - safe
          continue;
        }
      }

      if (result.isEmpty) {
        return _staleCacheOrThrow('Aucune chaîne exploitable');
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
      return _staleCacheOrThrow('Timeout: serveur lent');
    } on FstvException {
      rethrow;
    } catch (e) {
      return _staleCacheOrThrow('Erreur chargement chaînes: $e');
    }
  }

  /// Toutes les chaînes à plat.
  Future<List<FstvChannel>> getAllChannels({bool forceRefresh = false}) async {
    final grouped = await getChannels(forceRefresh: forceRefresh);
    return grouped.values.expand((list) => list).toList(growable: false);
  }

  // ── Sources ─────────────────────────────────────────────────────────────

  /// Retourne **toutes** les URLs directes iptv.mine.bz d'une chaîne, dans
  /// l'ordre API. Zéro appel vers neo-stream.eu : les URLs sont construites
  /// depuis les ids de sources du cache (`m3u8&id=`).
  /// Le lecteur fait 1 essai par source puis bascule (pas de skip de la 1re).
  Future<List<String>> streamUrlsFor(String slug) async {
    final s = slug.trim();
    if (s.isEmpty) throw FstvException('Chaîne introuvable');

    // 1) Cache (zéro réseau — le plus rapide après getChannels)
    var cached = _urlsFromChannelCache(s);
    if (cached.isNotEmpty) return cached;

    // 2) Remplir via getChannels (réseau si cache absent/périmé)
    final cacheTimeBefore = _channelsCacheTime;
    try {
      await getChannels();
    } catch (_) {
      // getChannels ne lève que sans aucun cache : on retente en force
    }
    cached = _urlsFromChannelCache(s);
    if (cached.isNotEmpty) return cached;

    // 3) Dernier recours : refresh forcé (jetons CDN amont expirés).
    //    Skip si l'étape 2 vient déjà de faire du réseau : le slug est
    //    vraiment inconnu, un 2e fetch (30 s × 3 essais) ne servirait à rien.
    final justFetched = _channelsCacheTime != null &&
        _channelsCacheTime != cacheTimeBefore;
    if (justFetched) throw FstvException('Aucune source disponible');
    await getChannels(forceRefresh: true);
    cached = _urlsFromChannelCache(s);
    if (cached.isNotEmpty) return cached;
    throw FstvException('Aucune source disponible');
  }

  /// Refresh + replay : force des ids de sources neufs puis reconstruit les
  /// URLs. Utilisé par le lecteur quand toutes les sources échouent
  /// (jetons CDN amont à courte durée de vie).
  Future<List<String>> refreshSources(String slug) async {
    await getChannels(forceRefresh: true);
    return streamUrlsFor(slug);
  }

  /// Construit un [FstvChannel] depuis une entrée du format direct
  /// iptv.mine.bz (`channels` dict). Les sources `{id, label}` deviennent
  /// `{url: <liveBase>/live_proxy.php?action=m3u8&id=…, label}`.
  /// Accepte aussi le format legacy `items` (sources avec `url` absolue).
  FstvChannel _channelFromDirectEntry(Map<String, dynamic> entry) {
    final slug = (entry['slug'] as String?)?.trim() ?? '';
    final name = (entry['name'] as String?)?.trim() ??
        (entry['title'] as String?)?.trim() ??
        'Chaîne';
    final category = (entry['category'] as String?)?.trim() ?? 'Autre';
    final logo = (entry['logo'] as String?)?.trim();
    final rawSources = entry['sources'];
    final sources = <Map<String, dynamic>>[];
    if (rawSources is List) {
      for (final item in rawSources) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final url = m['url'];
        if (url is String && url.trim().isNotEmpty) {
          // Format legacy : URL déjà fournie → absolutiser contre iptv.mine.bz
          final abs = _absolutizeLive(url.trim());
          if (abs != null) {
            sources.add({...m, 'url': abs});
          }
          continue;
        }
        final id = m['id'];
        if (id is String && id.trim().isNotEmpty) {
          sources.add({...m, 'url': m3u8UrlForId(id.trim())});
        }
      }
    }

    return FstvChannel(
      slug: slug,
      name: name,
      category: category,
      logo: logo,
      sources: sources,
    );
  }

  /// Entrées canaux depuis les 2 formats connus :
  /// direct (`channels` dict) et legacy (`items` list).
  List<Map<String, dynamic>> _channelEntries(Map<String, dynamic> data) {
    final channels = data['channels'];
    if (channels is Map) {
      return channels.values
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    final items = data['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return const [];
  }

  /// Résout une URL (absolue ou relative) contre la base live iptv.mine.bz.
  String? _absolutizeLive(String raw) {
    final base = Uri.parse(_liveBase);
    final uri =
        raw.startsWith('/') ? base.resolve(raw) : Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    return uri.toString();
  }

  /// Sources déjà présentes sur le modèle canal (cache getChannels).
  List<String> _urlsFromChannelCache(String slug) {
    final cache = _channelsCache;
    if (cache == null) return const [];
    for (final list in cache.values) {
      for (final ch in list) {
        if (ch.slug == slug && ch.sources.isNotEmpty) {
          final urls = <String>[];
          final seen = <String>{};
          for (final source in ch.sources) {
            final value = source['url'];
            if (value is! String) continue;
            final raw = value.trim();
            if (raw.isEmpty || seen.contains(raw)) continue;
            final abs = raw.startsWith('http') ? raw : _absolutizeLive(raw);
            if (abs == null) continue;
            seen.add(raw);
            urls.add(abs);
          }
          if (urls.isNotEmpty) return List<String>.unmodifiable(urls);
        }
      }
    }
    return const [];
  }

  /// Raccourci de compatibilité pour les appels qui n'ont besoin que de la
  /// première source.
  Future<String> streamUrlFor(String slug) async =>
      (await streamUrlsFor(slug)).first;

  // ── Probe / tri des sources ────────────────────────────────────────────
  //
  // Mesures terrain (135 chaînes, 849 sources) : ~80 % des slugs ont au
  // moins 1 source OK, mais les échecs sont quasi tous des HTTP 502
  // transitoires côté amont FSTV, et beaucoup de chaînes n'ont qu'1 source
  // OK sur N (ex : 1/9). D'où : tester vite chaque playlist puis jouer les
  // sources OK d'abord — sans jamais jeter les KO (un 502 peut se
  // résorber entre le probe et la lecture).

  /// Teste une playlist M3U8 : 200 + corps commençant par `#EXTM3U`.
  /// 1 retry après 1 s sur erreur transitoire (timeout / 502 / 503).
  /// Ne lève jamais. Redirects suivis par le client HTTP.
  Future<bool> probeSource(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) return false;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await ResilientHttp.get(uri, headers: _jsonHeaders)
            .timeout(_probeTimeout);
        if (response.statusCode == 200) {
          final body = utf8.decode(response.bodyBytes, allowMalformed: true);
          if (body.trimLeft().startsWith('#EXTM3U')) return true;
          return false; // Playlist vide / non-M3U8 : pas de retry utile.
        }
        // 502/503/504/429/timeout : transitoire → 1 retry.
        if (attempt == 1 &&
            (response.statusCode == 502 ||
                response.statusCode == 503 ||
                response.statusCode == 504 ||
                response.statusCode == 429 ||
                response.statusCode == 408)) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        return false;
      } on TimeoutException {
        if (attempt == 1) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        return false;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Ordonne les URLs : sources dont la playlist répond en premier (ordre
  /// API préservé dans chaque groupe), sources KO ensuite — jamais jetées.
  /// Seules les 6 premières sont probées (les suivantes, rarement utilisées,
  /// gardent l'ordre API sans coûter de probes). Probes en parallèle, budget
  /// global ~8 s. Ne lève jamais : en cas d'échec, retourne l'ordre d'origine.
  Future<List<String>> rankSources(List<String> urls) async {
    if (urls.length <= 1) return urls;
    // Au-delà de 6 sources, le gain marginal ne vaut pas les probes
    // (chaque probe = 1 GET playlist + éventuel retry 1 s).
    const maxProbed = 6;
    final probed = urls.length > maxProbed ? urls.sublist(0, maxProbed) : urls;
    final rest =
        urls.length > maxProbed ? urls.sublist(maxProbed) : const <String>[];
    try {
      final checks = await Future.wait(
        probed.map(probeSource),
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () => List<bool>.filled(probed.length, false),
      );
      final ok = <String>[];
      final ko = <String>[];
      for (var i = 0; i < probed.length; i++) {
        (checks[i] ? ok : ko).add(probed[i]);
      }
      if (ok.isEmpty) return urls; // Rien de concluant : garder l'ordre API.
      return [...ok, ...ko, ...rest];
    } catch (_) {
      return urls;
    }
  }

  /// Headers pour le player ExoPlayer (Freebox Mini 4K / Android TV).
  /// UA type box TV + Accept HLS : certains CDN refusent les UA desktop.
  /// Referer/Origin = proxy live direct (iptv.mine.bz) : les playlists
  /// `live_proxy.php?action=m3u8` et les segments `proxy_segment` y sont
  /// servis — jamais neo-stream.eu (VOD uniquement).
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

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// GET avec retry + backoff (1s, 2s). Lève après épuisement des essais.
  Future<http.Response> _getWithRetry(
    Uri url, {
    required Duration timeout,
    int attempts = 3,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        return await ResilientHttp.get(url, headers: _jsonHeaders)
            .timeout(timeout);
      } catch (e) {
        lastError = e;
        if (attempt < attempts) {
          await Future.delayed(Duration(seconds: attempt));
        }
      }
    }
    throw lastError is TimeoutException
        ? lastError
        : FstvException('Réseau indisponible: $lastError');
  }

  /// Sert le cache périmé s'il existe, sinon lève l'erreur demandée.
  Map<String, List<FstvChannel>> _staleCacheOrThrow(String message) {
    final stale = _channelsCache;
    if (stale != null && stale.isNotEmpty) return stale;
    throw FstvException(message);
  }

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
