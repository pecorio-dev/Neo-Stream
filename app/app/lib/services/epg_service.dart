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

/// Guide des programmes TV (EPG) pour l'onglet En Direct.
///
/// Sources ouvertes, gratuites, sans clé (vérifiées le 19/09/2026) :
///
///  1. **xmltvfr.fr** (primaire, référence TNT française) —
///     `https://xmltvfr.fr/xmltv/xmltv_tnt.xml.gz`
///     ~30 chaînes TNT, ~5 jours de programmes, MAJ quotidienne,
///     ~1,1 Mo gzip. IDs stables type `TF1.fr`, `France2.fr`.
///  2. **epgshare01** (complément, hôte distinct — comble les trous et
///     couvre la panne de la source 1) —
///     `https://epgshare01.online/epgshare01/epg_ripper_FR1.xml.gz`
///     Large couverture FR (généralistes, régionales, sport dont beIN,
///     cinéma…), refresh ~12 h, ~5,6 Mo gzip.
///
/// La source 1 est prioritaire : à horaire chevauchant, son programme gagne.
/// (Variante large du même éditeur, non retenue car trop lourde pour un
/// mobile — 78 Mo de XML brut : `https://xmltvfr.fr/xmltv/xmltv_fr.xml.gz`.)
///
/// Notes :
///  - `iptv-org/epg` (guides `iptv-org.github.io/epg/guides/…`) n'est PAS
///    retenu : les guides pré-générés sont morts (GUIDES.md vide depuis la
///    coupure des GitHub Actions) et `tvtv.us` est US-only + protégé par
///    Cloudflare/429.
///  - Le mapping chaîne FSTV → chaîne XMLTV se fait par **nom normalisé**
///    ([EpgParser.normalizeName] : minuscules, sans accents, ponctuation
///    neutralisée, tokens techniques `hd/fhd/4k/fr…` retirés, comparaison
///    avec et sans espaces), avec repli sur l'ID XMLTV normalisé.
///  - Cache double niveau : mémoire + fichiers gzip bruts
///    (`getApplicationSupportDirectory`), refresh réseau si vieux de plus
///    de [cacheMaxAge] (12 h). En cas d'échec réseau, le cache périmé est
///    servi plutôt que rien. Zéro impact sur le live : ni le proxy
///    `iptv.mine.bz`, ni le lecteur ne sont touchés.
class EpgService {
  EpgService._();
  static final EpgService instance = EpgService._();

  static const Duration cacheMaxAge = Duration(hours: 12);
  static const Duration _httpTimeout = Duration(seconds: 30);

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

  EpgParsed _data = EpgParsed();

  bool _loaded = false;
  DateTime? _loadedAt;
  Future<void>? _loadingFuture;
  String? lastError;

  /// Cache slug/titre → ID XMLTV (resolveChannelId est O(nb chaînes) avec
  /// des RegExp : sans cache, chaque build de grille coûtait ~2 × N × C
  /// normalisations). Invalidé à chaque remplacement de [_data].
  final Map<String, String?> _resolveCache = {};

  bool get isLoaded => _loaded;
  DateTime? get lastUpdated => _loadedAt;

  /// Nombre de chaînes indexées (debug / tests).
  int get channelCount => _data.programsByChannel.length;

  // ── Chargement ───────────────────────────────────────────────────────

  /// Charge le guide (mémoire → fichiers → réseau). Appels concurrents
  /// fusionnés (single-flight). Ne lève jamais.
  Future<void> ensureLoaded({bool forceRefresh = false}) {
    if (_loaded &&
        !forceRefresh &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < cacheMaxAge) {
      return Future.value();
    }
    final inFlight = _loadingFuture;
    if (inFlight != null) return inFlight;
    final fut = _load(forceRefresh: forceRefresh);
    _loadingFuture = fut;
    fut.whenComplete(() => _loadingFuture = null);
    return fut;
  }

  Future<void> _load({bool forceRefresh = false}) async {
    // 1) Fichiers locaux frais → parse direct, zéro réseau.
    if (!forceRefresh) {
      if (await _loadFromFiles(maxAge: cacheMaxAge)) return;
    }
    // 2) Réseau : les deux sources en parallèle (une source lente ne doit
    //    pas retarder l'autre — avant : séquentiel, jusqu'à 30 s perdus).
    //    Chaque source reste indépendante : une panne ne bloque pas l'autre.
    final fetched = await Future.wait(_sources.map((src) async {
      try {
        final bytes = await _fetchSource(src);
        if (bytes == null || bytes.isEmpty) return null;
        await _writeCacheFile(src.cacheFile, bytes);
        return (src: src, bytes: bytes);
      } catch (_) {
        return null;
      }
    }));
    final merged = EpgParsed();
    var anyOk = false;
    for (final r in fetched) {
      if (r == null) continue;
      try {
        // Parse morcelé (yield tous les ~512 programmes côté parser) +
        // respiration entre les deux sources : le parse séquentiel des
        // ~58k programmes ne monopolise jamais l'event-loop.
        await EpgParser.parse(r.bytes, r.src.rank, into: merged);
        anyOk = true;
        await Future<void>.delayed(Duration.zero);
      } catch (_) {
        // Flux corrompu : on continue avec l'autre source.
        continue;
      }
    }
    if (anyOk) {
      _data = merged;
      _finalizeOk();
      await _writeMeta();
      return;
    }
    // 3) Repli : fichiers périmés plutôt que rien.
    if (!await _loadFromFiles()) {
      lastError = 'Guide TV indisponible (réseau + cache vides).';
    }
  }

  Future<List<int>?> _fetchSource(_EpgSource src) async {
    final uri = Uri.parse(src.url);
    final resp = await ResilientHttp.get(uri, headers: const {
      'Accept': 'application/gzip, application/xml, */*',
      'User-Agent': 'NEO-Stream/4.0 (EPG)',
    }).timeout(_httpTimeout);
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;
    final bytes = resp.bodyBytes;
    // Fichiers `.gz` : détection magique gzip, sinon XML brut.
    if (bytes.length >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B) {
      return GZipCodec().decode(bytes);
    }
    return bytes;
  }

  void _finalizeOk() {
    for (final list in _data.programsByChannel.values) {
      list.sort((a, b) {
        final c = a.start.compareTo(b.start);
        if (c != 0) return c;
        return a.sourceRank.compareTo(b.sourceRank);
      });
    }
    _resolveCache.clear();
    _loaded = true;
    _loadedAt = DateTime.now();
    lastError = null;
  }

  // ── Requêtes ─────────────────────────────────────────────────────────

  /// Résout un slug FSTV ou un titre de chaîne vers un ID XMLTV.
  /// Résultat mémoïsé (requêtes très fréquentes : grille + spotlight +
  /// pastilles appellent 2× par carte et par build).
  String? resolveChannelId(String slugOrTitle) {
    final q = slugOrTitle.trim();
    if (q.isEmpty || _data.programsByChannel.isEmpty) return null;
    final key = q.toLowerCase();
    if (_resolveCache.containsKey(key)) return _resolveCache[key];
    final id = _resolveUncached(q);
    _resolveCache[key] = id;
    return id;
  }

  String? _resolveUncached(String q) {
    // 1) ID exact (insensible à la casse).
    for (final id in _data.channelIds) {
      if (id.toLowerCase() == q.toLowerCase()) return id;
    }
    // 2) Nom normalisé (avec puis sans espaces), alias inclus.
    final norm = EpgParser.normalizeName(q);
    if (norm.isNotEmpty) {
      final aliased = EpgParser.queryAliases[norm] ?? norm;
      final hit = _data.nameToId[aliased] ??
          _data.nameToId[EpgParser.spaceless(aliased)];
      if (hit != null) return hit;
    }
    // 3) Repli : attribut `channel` des programmes, normalisé.
    for (final id in _data.programsByChannel.keys) {
      if (EpgParser.normalizeName(id) == norm) return id;
    }
    return null;
  }

  List<EpgProgram>? _programsOf(String slugOrTitle) {
    final id = resolveChannelId(slugOrTitle);
    if (id == null) return null;
    final list = _data.programsByChannel[id];
    if (list == null || list.isEmpty) return null;
    return list;
  }

  /// Programme en cours + suivant à l'instant [at] (défaut : maintenant).
  /// La source prioritaire gagne en cas de chevauchement inter-sources.
  /// Retourne null s'il n'y a pas de direct en cours (trou de grille ou
  /// chaîne inconnue).
  EpgNowNext? getNowAndNext(String slugOrTitle, {DateTime? at}) {
    final list = _programsOf(slugOrTitle);
    if (list == null) return null;
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

  /// Grille du jour calendaire local contenant [day] (défaut : aujourd'hui).
  List<EpgProgram> getDaySchedule(String slugOrTitle, {DateTime? day}) {
    final list = _programsOf(slugOrTitle);
    if (list == null) return const [];
    final ref = day ?? DateTime.now();
    final dayStart = DateTime(ref.year, ref.month, ref.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final ds = dayStart.toUtc();
    final de = dayEnd.toUtc();
    // Fenêtre élargie de 6 h pour capter les programmes à cheval.
    final out = list
        .where((p) =>
            p.end.isAfter(ds.subtract(const Duration(hours: 6))) &&
            p.start.isBefore(de))
        .toList(growable: false);
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  // ── Fichiers ─────────────────────────────────────────────────────────

  Future<Directory> _dir() => getApplicationSupportDirectory();

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

  /// Parse les fichiers locaux. Si [maxAge] est fourni, ne fait rien quand
  /// le cache est plus vieux (retourne false → fetch réseau).
  Future<bool> _loadFromFiles({Duration? maxAge}) async {
    try {
      if (maxAge != null) {
        final saved = await _metaTime();
        if (saved == null || DateTime.now().difference(saved) > maxAge) {
          return false;
        }
      }
      final dir = (await _dir()).path;
      final parsed = EpgParsed();
      var anyOk = false;
      for (final src in _sources) {
        try {
          final f = File('$dir/${src.cacheFile}');
          if (!await f.exists()) continue;
          final bytes = await f.readAsBytes();
          if (bytes.isEmpty) continue;
          final payload =
              (bytes.length >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B)
                  ? GZipCodec().decode(bytes)
                  : bytes;
          await EpgParser.parse(payload, src.rank, into: parsed);
          anyOk = true;
          // Respiration entre les deux fichiers (même raison que réseau).
          await Future<void>.delayed(Duration.zero);
        } catch (_) {
          continue;
        }
      }
      if (!anyOk) return false;
      _data = parsed;
      _finalizeOk();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Invalide tout (mémoire + fichiers). Appels suivants → réseau.
  Future<void> invalidate() async {
    _data = EpgParsed();
    _resolveCache.clear();
    _loaded = false;
    _loadedAt = null;
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
