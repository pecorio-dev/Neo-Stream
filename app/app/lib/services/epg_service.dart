import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'epg_parse.dart';
import 'resilient_http.dart';

export 'epg_parse.dart' show EpgProgram, EpgNowNext;

class _EpgSource {
  final String name;
  final int rank;
  final String url;
  final String cacheFile;

  const _EpgSource({
    required this.name,
    required this.rank,
    required this.url,
    required this.cacheFile,
  });
}

/// Guide des programmes TV (EPG) — version anti-crash TV.
///
/// Principe radical : on ne charge/parse JAMAIS le guide entier
/// (~6,7 Mo gzip, ~58k programmes sur 5 jours → OOM sur TV low-end).
/// Quand le popup d'UNE chaîne s'ouvre :
///  1. les fichiers gzip en cache (12 h) sont réutilisés ou téléchargés
///     (téléchargement séquentiel, jamais les deux sources décodées en
///     même temps en RAM),
///  2. la petite section `<channel>` (592 entrées) est indexée pour
///     résoudre slug/nom → ID XMLTV,
///  3. `<programme>` est balayé en streaming filtrant
///     ([EpgParser.parseFiltered]) : seuls les programmes du canal résolu
///     dans la fenêtre courte (6 h avant → 24 h après) sont matérialisés
///     (typiquement < 20 objets),
///  4. à la fermeture du popup, [releaseMemory] vide la mémoire (les
///     fichiers gzip restent sur disque).
///
/// Zéro scan global : ni grille, ni spotlight, ni pré-chauffe ne touchent
/// le guide. Seul le popup appelle [loadChannel] puis [getNowAndNext].
/// Ni le proxy `iptv.mine.bz`, ni le lecteur ne sont touchés.
class EpgService {
  EpgService._();
  static final EpgService instance = EpgService._();

  static const Duration cacheMaxAge = Duration(hours: 12);
  static const Duration _httpTimeout = Duration(seconds: 30);

  /// Fenêtre courte mono-chaîne : 6 h de passé (capte le direct à cheval)
  /// → 24 h de futur (largement de quoi fournir Maintenant / À suivre).
  static const Duration windowPast = Duration(hours: 6);
  static const Duration windowFuture = Duration(hours: 24);

  static const List<_EpgSource> _sources = [
    _EpgSource(
      name: 'xmltvfr_tnt',
      rank: 0,
      url: 'https://xmltvfr.fr/xmltv/xmltv_tnt.xml.gz',
      cacheFile: 'epg_xmltvfr_tnt.xml.gz',
    ),
    _EpgSource(
      name: 'epgshare01_fr1',
      rank: 1,
      url: 'https://epgshare01.online/epgshare01/epg_ripper_FR1.xml.gz',
      cacheFile: 'epg_epgshare01_fr1.xml.gz',
    ),
  ];

  static const String _metaFile = 'epg_meta.json';

  // ── Mémoire mono-chaîne (libérée à la fermeture du popup) ──────────

  /// Programmes de la chaîne chargée, fenêtre courte uniquement.
  List<EpgProgram> _programs = const [];

  /// IDs XMLTV résolus pour la chaîne chargée (1 par source en général).
  Set<String> _loadedIds = const {};

  /// Clé `slug|name` (minuscules) de la chaîne chargée.
  String _loadedKey = '';

  DateTime? _loadedAt;
  String? lastError;

  Future<EpgNowNext?>? _loadingFuture;
  String _loadingKey = '';

  bool get isLoaded => _loadedAt != null && _programs.isNotEmpty;
  DateTime? get lastUpdated => _loadedAt;

  /// Nombre d'IDs résolus pour la chaîne courante (debug / tests).
  int get channelCount => _loadedIds.length;

  static String _keyOf(String slug, String name) =>
      '${slug.trim().toLowerCase()}|${name.trim().toLowerCase()}';

  // ── Chargement mono-chaîne ──────────────────────────────────────────

  /// Charge (fichiers → réseau si périmés) puis parse EN FILTRANT les
  /// programmes de la chaîne [slug]/[name] dans la fenêtre courte.
  /// Appels concurrents même chaîne fusionnés (single-flight). Ne lève
  /// jamais : retourne null si le guide est indisponible pour la chaîne.
  Future<EpgNowNext?> loadChannel(String slug, String name,
      {bool forceRefresh = false, DateTime? now}) {
    final key = _keyOf(slug, name);
    if (key == '|' || (!forceRefresh && _loadedAt != null && key == _loadedKey)) {
      if (_loadedAt != null &&
          DateTime.now().difference(_loadedAt!) < cacheMaxAge &&
          _programs.isNotEmpty) {
        return Future.value(getNowAndNext(slug, at: now));
      }
    }
    final inFlight = _loadingFuture;
    if (inFlight != null && _loadingKey == key && !forceRefresh) {
      return inFlight;
    }
    final fut = _loadChannel(slug, name, key, now: now, forceRefresh: forceRefresh);
    _loadingFuture = fut;
    _loadingKey = key;
    fut.whenComplete(() {
      if (_loadingKey == key) {
        _loadingFuture = null;
        _loadingKey = '';
      }
    });
    return fut;
  }

  Future<EpgNowNext?> _loadChannel(
    String slug,
    String name,
    String key, {
    DateTime? now,
    bool forceRefresh = false,
  }) async {
    try {
      final ref = (now ?? DateTime.now()).toUtc();
      final from = ref.subtract(windowPast);
      final to = ref.add(windowFuture);

      // 1) Fichiers frais ? Sinon téléchargement séquentiel (jamais les
      //    deux flux décodés simultanément en RAM).
      await _ensureFiles(forceRefresh: forceRefresh);

      // 2) Source par source : lit le fichier, décode, indexe les 592
      //    `<channel>`, résout les IDs de CETTE chaîne, parse filtrant.
      //    La chaîne XML est jetée avant la source suivante (pic RAM =
      //    1 seul flux + une poignée de programmes).
      final kept = <EpgProgram>[];
      final ids = <String>{};
      var anyFile = false;
      for (final src in _sources) {
        final xml = await _readXml(src.cacheFile);
        if (xml == null || xml.isEmpty) continue;
        anyFile = true;
        try {
          final nameToId = <String, String>{};
          final channelIds = <String>{};
          EpgParser.indexChannels(xml, nameToId, channelIds);
          await Future<void>.delayed(Duration.zero);
          var wanted = EpgParser.resolveIds(nameToId, channelIds, slug);
          wanted = {...wanted, ...EpgParser.resolveIds(nameToId, channelIds, name)};
          if (wanted.isEmpty) continue; // Chaîne absente de cette source.
          ids.addAll(wanted);
          await EpgParser.parseFiltered(xml, wanted, src.rank, from, to, into: kept);
        } catch (_) {
          // Flux corrompu : on continue avec l'autre source.
          continue;
        }
        // Respiration entre les deux sources.
        await Future<void>.delayed(Duration.zero);
      }
      if (!anyFile) {
        lastError = 'Guide TV indisponible (réseau + cache vides).';
        return null;
      }
      kept.sort((a, b) {
        final c = a.start.compareTo(b.start);
        if (c != 0) return c;
        return a.sourceRank.compareTo(b.sourceRank);
      });
      _programs = kept;
      _loadedIds = ids;
      _loadedKey = key;
      _loadedAt = DateTime.now();
      lastError = null;
      if (kept.isEmpty) return null;
      return getNowAndNext(slug, at: ref);
    } catch (_) {
      lastError = 'Guide TV indisponible.';
      return null;
    }
  }

  // ── Requêtes (mémoire mono-chaîne uniquement, zéro I/O) ─────────────

  /// Programme en cours + suivant à l'instant [at] (défaut : maintenant)
  /// pour la chaîne chargée par [loadChannel]. La source prioritaire gagne
  /// en cas de chevauchement inter-sources. Retourne null s'il n'y a pas
  /// de direct en cours (trou de grille ou chaîne non chargée).
  ///
  /// Note : [slugOrTitle] n'est conservé que pour compatibilité d'appel
  /// (le popup essaie slug puis nom) — la mémoire ne contient de toute
  /// façon que la chaîne chargée, aucun scan global n'a lieu.
  EpgNowNext? getNowAndNext(String slugOrTitle, {DateTime? at}) {
    final list = _programs;
    if (list.isEmpty) return null;
    final moment = (at ?? DateTime.now()).toUtc();
    EpgProgram? now;
    for (final p in list) {
      if (!p.start.isAfter(moment) && p.end.isAfter(moment)) {
        if (now == null || p.sourceRank < now.sourceRank) now = p;
      }
    }
    if (now == null) return null;
    final current = now;
    // "À suivre" : le plus tôt à partir de la fin du direct, en
    // privilégiant la même source (évite d'afficher le doublon
    // inter-sources du même programme avec un horaire décalé).
    EpgProgram? next;
    bool better(EpgProgram p, EpgProgram? cur) {
      if (cur == null) return true;
      final sameSrc = p.sourceRank == current.sourceRank;
      final curSameSrc = cur.sourceRank == current.sourceRank;
      if (sameSrc != curSameSrc) return sameSrc;
      if (p.start != cur.start) return p.start.isBefore(cur.start);
      return p.sourceRank < cur.sourceRank;
    }

    for (final p in list) {
      if (!p.start.isBefore(current.end) && better(p, next)) next = p;
    }
    return EpgNowNext(now: current, next: next);
  }

  /// Vide le cache mémoire des programmes (appelé à la fermeture du
  /// popup). Les fichiers gzip sur disque sont conservés (cache 12 h).
  void releaseMemory() {
    _programs = const [];
    _loadedIds = const {};
    _loadedKey = '';
    _loadedAt = null;
  }

  // ── Fichiers (gzip bruts sur disque, jamais décodés en cache) ───────

  Future<Directory> _dir() => getApplicationSupportDirectory();

  /// Garantit des fichiers présents et frais (téléchargement séquentiel
  /// si périmés/absents). Ne lève jamais.
  Future<void> _ensureFiles({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh) {
        final saved = await _metaTime();
        if (saved != null &&
            DateTime.now().difference(saved) < cacheMaxAge &&
            await _allFilesExist()) {
          return;
        }
      }
      // Réseau : sources EN SÉQUENCE (avant : Future.wait en parallèle
      // qui tenait les deux flux décompressés en RAM simultanément).
      var anyOk = false;
      for (final src in _sources) {
        try {
          final bytes = await _fetchSource(src);
          if (bytes == null || bytes.isEmpty) continue;
          await _writeCacheFile(src.cacheFile, bytes);
          anyOk = true;
        } catch (_) {
          continue;
        }
        await Future<void>.delayed(Duration.zero);
      }
      if (anyOk || await _allFilesExist()) {
        await _writeMeta();
      }
    } catch (_) {}
  }

  Future<bool> _allFilesExist() async {
    try {
      final dir = (await _dir()).path;
      for (final src in _sources) {
        if (!await File('$dir/${src.cacheFile}').exists()) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Lit un fichier cache et retourne le XML décompressé (ou null).
  /// Le tableau d'octets brut est jeté dès le décodage terminé.
  Future<String?> _readXml(String cacheFile) async {
    try {
      final f = File('${(await _dir()).path}/$cacheFile');
      if (!await f.exists()) return null;
      final bytes = await f.readAsBytes();
      if (bytes.isEmpty) return null;
      final payload =
          (bytes.length >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B)
              ? GZipCodec().decode(bytes)
              : bytes;
      final xml = utf8.decode(payload, allowMalformed: true);
      await Future<void>.delayed(Duration.zero);
      return xml;
    } catch (_) {
      return null;
    }
  }

  /// Télécharge une source et retourne les octets BRUTS (gzip conservé
  /// tel quel pour le cache disque ; la décompression a lieu à la
  /// lecture, source par source).
  Future<List<int>?> _fetchSource(_EpgSource src) async {
    final uri = Uri.parse(src.url);
    final resp = await ResilientHttp.get(uri, headers: const {
      'Accept': 'application/gzip, application/xml, */*',
      'User-Agent': 'NEO-Stream/4.0 (EPG)',
    }).timeout(_httpTimeout);
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;
    return resp.bodyBytes;
  }

  Future<void> _writeCacheFile(String name, List<int> bytes) async {
    try {
      final f = File('${(await _dir()).path}/$name');
      await f.writeAsBytes(bytes, flush: true);
    } catch (_) {
      // Cache fichier best-effort : la mémoire reste servie.
    }
  }

  Future<void> _writeMeta() async {
    try {
      final f = File('${(await _dir()).path}/$_metaFile');
      await f.writeAsString(
        jsonEncode({'savedAt': DateTime.now().millisecondsSinceEpoch}),
        flush: true,
      );
    } catch (_) {}
  }

  Future<DateTime?> _metaTime() async {
    try {
      final f = File('${(await _dir()).path}/$_metaFile');
      if (!await f.exists()) return null;
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final ms = data['savedAt'];
      if (ms is int) return DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {}
    return null;
  }

  /// Invalide tout (mémoire + fichiers). Appels suivants → réseau.
  Future<void> invalidate() async {
    releaseMemory();
    lastError = null;
    try {
      final dir = (await _dir()).path;
      for (final src in _sources) {
        final f = File('$dir/${src.cacheFile}');
        if (await f.exists()) await f.delete();
      }
      final meta = File('$dir/$_metaFile');
      if (await meta.exists()) await meta.delete();
    } catch (_) {}
  }
}
