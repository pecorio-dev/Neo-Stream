import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../config/constants.dart';
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
/// Principe radical : on ne charge/parse JAMAIS le guide entier.
/// Quand le popup d'UNE chaîne s'ouvre :
///  1. FAST-PATH serveur : `live_proxy.php?action=epg&slug=<slug>`
///     (mini-JSON pré-calculé `epg_now.json`, timeout 10 s, try/catch
///     absolu) → [EpgNowNext]. En cas de succès, AUCUN XMLTV n'est
///     téléchargé ni parsé,
///  2. REPLI XMLTV mono-chaîne (code historique conservé tel quel) : UNE
///     SEULE source est utilisée : dès que la 1re source résout la
///     chaîne (IDs trouvés), la 2e n'est NI téléchargée NI parsée,
///     petite section `<channel>` indexée, `<programme>` balayé en
///     streaming filtrant ([EpgParser.parseFiltered]) dans la fenêtre
///     courte (-30 min → +12 h),
///  3. à la fermeture du popup, [releaseMemory] vide la mémoire.
///
/// Zéro scan global : ni grille, ni spotlight, ni pré-chauffe ne touchent
/// le guide. Seul le popup appelle [loadChannel] puis [getNowAndNext].
/// Tout échec → null (section "Programmes indisponibles"), JAMAIS
/// d'exception propagée, JAMAIS de crash.
/// Ni le proxy `iptv.mine.bz`, ni le lecteur ne sont touchés.
class EpgService {
  EpgService._();
  static final EpgService instance = EpgService._();

  static const Duration cacheMaxAge = Duration(hours: 12);

  /// Timeout STRICT du download EPG : 15 s max, jamais plus.
  static const Duration _httpTimeout = Duration(seconds: 15);

  /// Timeout du fast-path serveur (`?action=epg&slug=`) : 10 s max.
  static const Duration _serverTimeout = Duration(seconds: 10);

  /// Rang source des programmes venus du serveur pré-calculé. La mémoire
  /// mono-chaîne ne contient alors QUE ces 1-2 objets : le rang est
  /// anecdotique (aucun conflit inter-sources), -1 les distingue en debug.
  static const int _serverSourceRank = -1;

  /// Fenêtre réduite mono-chaîne : -30 min (juste de quoi déterminer
  /// l'émission en cours à cheval) → +12 h. Zéro passé inutile.
  static const Duration windowPast = Duration(minutes: 30);
  static const Duration windowFuture = Duration(hours: 12);

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

  /// Charge le Now/Next de la chaîne [slug]/[name] : fast-path serveur
  /// (`?action=epg&slug=`, 10 s max) PUIS repli XMLTV mono-chaîne
  /// (fenêtre -30 min → +12 h, UNE SEULE source). Appels concurrents même
  /// chaîne fusionnés (single-flight). Ne lève JAMAIS : retourne null si
  /// le guide est indisponible pour la chaîne.
  Future<EpgNowNext?> loadChannel(String slug, String name,
      {bool forceRefresh = false, DateTime? now}) {
    try {
      final key = _keyOf(slug, name);
      if (key == '|' ||
          (!forceRefresh && _loadedAt != null && key == _loadedKey)) {
        if (_loadedAt != null &&
            DateTime.now().difference(_loadedAt!) < cacheMaxAge &&
            _programs.isNotEmpty) {
          try {
            return Future.value(getNowAndNext(slug, at: now));
          } catch (_) {
            return Future.value(null);
          }
        }
      }
      final inFlight = _loadingFuture;
      if (inFlight != null && _loadingKey == key && !forceRefresh) {
        return inFlight;
      }
      // Garde absolue : _loadChannel ne lève jamais, mais on verrouille
      // quand même la propagation (le popup n'a aucun catch à faire).
      final fut = _loadChannel(slug, name, key,
              now: now, forceRefresh: forceRefresh)
          .then<EpgNowNext?>((v) => v, onError: (_) {
        lastError = 'Guide TV indisponible.';
        return null;
      });
      _loadingFuture = fut;
      _loadingKey = key;
      fut.whenComplete(() {
        if (_loadingKey == key) {
          _loadingFuture = null;
          _loadingKey = '';
        }
      });
      return fut;
    } catch (_) {
      lastError = 'Guide TV indisponible.';
      return Future.value(null);
    }
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

      // ── FAST-PATH : EPG pré-calculé serveur ─────────────────────────
      // `live_proxy.php?action=epg&slug=<slug>` (mini-JSON issu de
      // `epg_now.json`). Zéro download XMLTV si succès. Tout échec
      // (endpoint absent, timeout 10 s, JSON inattendu, trou de grille)
      // → null silencieux puis REPLI XMLTV ci-dessous. Ne lève jamais.
      try {
        final fast = await _fetchServerNowNext(slug, name, ref: ref, key: key);
        if (fast != null) return fast;
      } catch (_) {
        // Repli XMLTV.
      }

      // ── REPLI : XMLTV mono-chaîne (code historique, conservé) ───────
      // Source par source, ARRÊT dès que la 1re source résout la chaîne :
      // la 2e n'est ni téléchargée ni parsée (pic RAM = 1 seul flux +
      // une poignée de programmes). Chaque étape est en try/catch absolu.
      final kept = <EpgProgram>[];
      final ids = <String>{};
      var anyFile = false;
      var resolved = false;
      for (final src in _sources) {
        String? xml;
        try {
          // Fichier frais ? Sinon download de CETTE source uniquement
          // (15 s max, best-effort).
          await _ensureSourceFile(src, forceRefresh: forceRefresh);
          xml = await _readXml(src.cacheFile);
        } catch (_) {
          xml = null;
        }
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
          // 1re source qui résout → on parse PUIS ON S'ARRÊTE.
          resolved = true;
          ids.addAll(wanted);
          await EpgParser.parseFiltered(xml, wanted, src.rank, from, to,
              into: kept);
        } catch (_) {
          // Flux corrompu : si déjà résolu on garde, sinon on tente l'autre.
          if (resolved) break;
          continue;
        }
        if (resolved) break;
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

  // ── Fast-path serveur pré-calculé (`epg_now.json`) ───────────────────
  //
  // `GET live_proxy.php?action=epg&slug=<slug>` où <slug> = forme stricte
  // serveur ([EpgParser.serverSlug] : minuscules, sans accents,
  // non-alphanum retirés). Réponse attendue (filtrée) : mini-JSON
  // `{"ts":..,"programs":{"<cle>":{"now":{title,sub,start,end},
  // "next":{...}}}}` — mais le parsing accepte les variantes
  // (`{"now":..,"next":..}`, `{"programs":{"now":..,"next":..}}`,
  // programme seul `{"title":..}`) car le contrat `?action=epg&slug=`
  // reste à confirmer côté serveur. Then fallback XMLTV si quoi que ce
  // soit dévie. Ne lève JAMAIS.

  /// Base proxy LIVE + chemin EPG. Best-effort : tout échec → null.
  String? _serverEpgBase() {
    try {
      const base = AppConstants.fstvProxyBaseUrl;
      if (base.isEmpty) return null;
      return base.endsWith('/') ? base : '$base/';
    } catch (_) {
      return null;
    }
  }

  /// Tente le fast-path serveur pour [slug]/[name] : 1 à 2 requêtes
  /// (`serverSlug(slug)` puis `serverSlug(name)` si distinct), 10 s max
  /// chacune, try/catch absolu. Succès → mémoire mono-chaîne remplie
  /// (1-2 objets) + [EpgNowNext] à [ref]. Échec → null (repli XMLTV).
  Future<EpgNowNext?> _fetchServerNowNext(
    String slug,
    String name, {
    required DateTime ref,
    required String key,
  }) async {
    try {
      final base = _serverEpgBase();
      if (base == null) return null;
      final candidates = <String>[];
      for (final c in [EpgParser.serverSlug(slug), EpgParser.serverSlug(name)]) {
        if (c.isNotEmpty && !candidates.contains(c)) candidates.add(c);
      }
      if (candidates.isEmpty) return null;
      for (final cand in candidates) {
        try {
          final uri = Uri.parse(
            '${base}live_proxy.php?action=epg&slug=${Uri.encodeComponent(cand)}',
          );
          final resp = await ResilientHttp.get(uri, headers: const {
            'Accept': 'application/json',
            'User-Agent': 'NEO-Stream/4.0 (EPG)',
            'Referer': 'https://iptv.mine.bz/',
          }).timeout(_serverTimeout);
          if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) continue;
          final list = _parseServerPayload(resp.bodyBytes, cand);
          if (list == null || list.isEmpty) continue;
          list.sort((a, b) {
            final c = a.start.compareTo(b.start);
            if (c != 0) return c;
            return a.sourceRank.compareTo(b.sourceRank);
          });
          _programs = list;
          _loadedIds = {cand};
          _loadedKey = key;
          _loadedAt = DateTime.now();
          lastError = null;
          final nn = getNowAndNext(slug, at: ref);
          // Trou de grille côté serveur (que du futur / que du passé) :
          // on garde la mémoire mais on retourne null → le popup affiche
          // "Programmes indisponibles", SANS déclencher le repli XMLTV
          // (le serveur a répondu : inutile de télécharger 2 flux gzip).
          return nn;
        } catch (_) {
          continue;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Parse le corps du mini-JSON serveur → 1-2 [EpgProgram] ([cand] comme
  /// `channelId`). Retourne null si le contenu est inexploitable
  /// (→ repli XMLTV par l'appelant). Ne lève jamais.
  List<EpgProgram>? _parseServerPayload(List<int> bytes, String cand) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      dynamic entry;
      final programs = map['programs'];
      if (programs is Map && programs.isNotEmpty) {
        final pm = Map<String, dynamic>.from(programs);
        if (pm.containsKey('now') || pm.containsKey('next')) {
          entry = pm; // Déjà filtré : {"now":..,"next":..}.
        } else {
          // Filtré par clé : {"<cle>":{"now":..,"next":..}}.
          final byKey = pm[cand];
          if (byKey != null) {
            entry = byKey;
          } else if (pm.length == 1) {
            entry = pm.values.first;
          } else {
            // Non filtré (contrat `tout`) : cherche la clé exacte, sinon
            // la première entrée ressemblant à {now,next} ou programme.
            for (final v in pm.values) {
              if (v is Map) {
                final vm = Map<String, dynamic>.from(v);
                if (vm.containsKey('now') ||
                    vm.containsKey('next') ||
                    vm.containsKey('title')) {
                  entry = vm;
                  break;
                }
              }
            }
            entry ??= pm.values.isEmpty ? null : pm.values.first;
          }
        }
      } else if (map.containsKey('now') || map.containsKey('next')) {
        entry = map; // {"ts":..,"now":..,"next":..}.
      } else if (map.containsKey('title')) {
        entry = {'now': map}; // Programme seul → considéré "en cours".
      } else {
        return null;
      }
      if (entry is! Map) return null;
      final em = Map<String, dynamic>.from(entry);
      final out = <EpgProgram>[];
      // Cas imbriqué {"now":{...},"next":{...}} vs programme direct.
      if (em.containsKey('now') || em.containsKey('next')) {
        final nowP = _serverProgram(em['now'], cand);
        if (nowP != null) out.add(nowP);
        final nextP = _serverProgram(em['next'], cand);
        if (nextP != null && !out.any((p) => p.start == nextP.start && p.title == nextP.title)) {
          out.add(nextP);
        }
      } else {
        final single = _serverProgram(em, cand);
        if (single != null) out.add(single);
      }
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  /// Construit un [EpgProgram] depuis un nœud serveur
  /// `{title, sub|subTitle, start, end|stop, desc, category, icon}`.
  /// Null si titre ou bornes inexploitables. Ne lève jamais.
  EpgProgram? _serverProgram(dynamic raw, String channelId) {
    try {
      if (raw is! Map) return null;
      final m = Map<String, dynamic>.from(raw);
      final title = (m['title'] ?? m['name'] ?? '').toString().trim();
      if (title.isEmpty) return null;
      final start = _parseServerTime(m['start']);
      final end = _parseServerTime(m['end'] ?? m['stop'] ?? m['endTime']);
      if (start == null || end == null || !end.isAfter(start)) return null;
      String? opt(dynamic v) {
        try {
          final s = v?.toString().trim() ?? '';
          return s.isEmpty ? null : s;
        } catch (_) {
          return null;
        }
      }
      return EpgProgram(
        channelId: channelId,
        sourceRank: _serverSourceRank,
        title: title,
        subTitle: opt(m['sub'] ?? m['subTitle'] ?? m['subtitle']),
        desc: opt(m['desc'] ?? m['description']),
        category: opt(m['category'] ?? m['genre']),
        icon: opt(m['icon'] ?? m['image'] ?? m['logo']),
        start: start,
        end: end,
      );
    } catch (_) {
      return null;
    }
  }

  /// Bornes serveur tolérantes : epoch s (10 chiffres) ou ms (13 chiffres)
  /// en int/double/chaîne numérique, ISO-8601 (`DateTime.parse`), ou
  /// format XMLTV (`EpgParser.parseXmltvDate`). Retour UTC. Null si
  /// inexploitable. Ne lève jamais.
  DateTime? _parseServerTime(dynamic v) {
    try {
      if (v == null) return null;
      if (v is int) {
        if (v >= 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
        }
        if (v >= 1000000000) {
          return DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true);
        }
        return null;
      }
      if (v is double) {
        if (!v.isFinite) return null;
        return _parseServerTime(v.truncate());
      }
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      if (RegExp(r'^\d+$').hasMatch(s)) {
        try {
          return _parseServerTime(int.parse(s));
        } catch (_) {
          return null;
        }
      }
      try {
        return DateTime.parse(s).toUtc();
      } catch (_) {}
      return EpgParser.parseXmltvDate(s)?.toUtc();
    } catch (_) {
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
    try {
      final list = _programs;
      if (list.isEmpty) return null;
      final moment = (at ?? DateTime.now()).toUtc();
      EpgProgram? now;
      for (final p in list) {
        try {
          if (!p.start.isAfter(moment) && p.end.isAfter(moment)) {
            if (now == null || p.sourceRank < now.sourceRank) now = p;
          }
        } catch (_) {
          continue;
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
        try {
          if (!p.start.isBefore(current.end) && better(p, next)) next = p;
        } catch (_) {
          continue;
        }
      }
      return EpgNowNext(now: current, next: next);
    } catch (_) {
      return null;
    }
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

  /// Garantit le fichier d'UNE source : cache frais réutilisé, sinon
  /// download de CETTE source uniquement (15 s max). Ne lève jamais.
  /// Retourne true si le fichier est présent après coup.
  Future<bool> _ensureSourceFile(_EpgSource src,
      {bool forceRefresh = false}) async {
    try {
      final dir = (await _dir()).path;
      final f = File('$dir/${src.cacheFile}');
      if (!forceRefresh) {
        try {
          final saved = await _metaTime();
          final freshMeta = saved != null &&
              DateTime.now().difference(saved) < cacheMaxAge;
          if (freshMeta && await f.exists()) return true;
          // Sans méta mais fichier présent : on le garde (évite un
          // download inutile quand seule la 1re source est nécessaire).
          if (!freshMeta && await f.exists()) {
            try {
              if (await f.length() > 0) return true;
            } catch (_) {}
          }
        } catch (_) {}
      }
      // Réseau : CETTE source uniquement, 15 s max, best-effort.
      try {
        final bytes = await _fetchSource(src);
        if (bytes == null || bytes.isEmpty) {
          try {
            return await f.exists();
          } catch (_) {
            return false;
          }
        }
        await _writeCacheFile(src.cacheFile, bytes);
        await _writeMeta();
        return true;
      } catch (_) {
        try {
          return await f.exists();
        } catch (_) {
          return false;
        }
      }
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
  /// lecture, source par source). Timeout STRICT 15 s max. Ne lève
  /// jamais : tout échec → null.
  Future<List<int>?> _fetchSource(_EpgSource src) async {
    try {
      final uri = Uri.parse(src.url);
      final resp = await ResilientHttp.get(uri, headers: const {
        'Accept': 'application/gzip, application/xml, */*',
        'User-Agent': 'NEO-Stream/4.0 (EPG)',
      }).timeout(_httpTimeout);
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;
      return resp.bodyBytes;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
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
