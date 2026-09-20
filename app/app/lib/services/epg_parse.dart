/// Un programme TV issu d'un guide XMLTV.
class EpgProgram {
  /// Identifiant XMLTV de la chaîne (ex. `TF1.fr`).
  final String channelId;

  /// Rang de la source (0 = prioritaire). Sert à départager les
  /// chevauchements quand les deux sources couvrent la même chaîne.
  final int sourceRank;

  final String title;
  final String? subTitle;
  final String? desc;
  final String? category;
  final String? icon;

  final DateTime start;
  final DateTime end;

  const EpgProgram({
    required this.channelId,
    required this.sourceRank,
    required this.title,
    required this.start,
    required this.end,
    this.subTitle,
    this.desc,
    this.category,
    this.icon,
  });

  /// Progression de la diffusion à l'instant [at] (0.0 → 1.0).
  double progressAt(DateTime at) {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    final elapsed = at.difference(start).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  /// `HH:mm` local.
  static String timeLabel(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  String get rangeLabel => '${timeLabel(start)} – ${timeLabel(end)}';
}

/// Couple "en cours / à suivre" pour une chaîne.
class EpgNowNext {
  final EpgProgram now;
  final EpgProgram? next;

  const EpgNowNext({required this.now, this.next});
}

/// Index léger des chaînes d'un flux XMLTV (592 entrées : quelques Ko).
/// Conservé pour compatibilité ; le service ne garde plus les programmes
/// en mémoire globale.
class EpgParsed {
  final Map<String, List<EpgProgram>> programsByChannel;
  final Map<String, String> nameToId;
  final Set<String> channelIds;

  EpgParsed({
    Map<String, List<EpgProgram>>? programsByChannel,
    Map<String, String>? nameToId,
    Set<String>? channelIds,
  })  : programsByChannel = programsByChannel ?? {},
        nameToId = nameToId ?? {},
        channelIds = channelIds ?? {};
}

/// Parsing XMLTV pur (aucune dépendance Flutter) : normalisation des noms,
/// décodage des dates `20260918000000 +0200`, extraction du sous-ensemble
/// `channel` / `programme` (title, sub-title, desc, category, icon).
///
/// Stratégie anti-crash TV : JAMAIS de scan global des programmes.
/// Le popup d'une chaîne fait :
///  1. [indexChannels] sur la petite section `<channel>` (592 entrées),
///  2. [resolveIds] slug/nom → set d'IDs XMLTV candidats,
///  3. [parseFiltered] qui balaie `<programme>` en streaming (indexOf, sans
///     RegExp globale) et ne matérialise que les programmes du canal
///     demandé dans la fenêtre [from, to].
class EpgParser {
  static const Map<String, String> _accents = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ø': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
    'ý': 'y',
    'ÿ': 'y',
    'æ': 'ae',
    'œ': 'oe',
    'ß': 'ss',
    'ð': 'd',
    'þ': 'th',
  };

  /// Mots techniques / suffixes sans valeur discriminante.
  static const Set<String> _noiseTokens = {
    'hd',
    'fhd',
    'uhd',
    '4k',
    '8k',
    'sd',
    'hq',
    'lq',
    'hevc',
    'tv',
    'tele',
    'channel',
    'chaine',
    'live',
    'direct',
    'plus',
    'fr',
    'fra',
    'french',
    'france',
    'francais',
    'francaise',
  };

  /// Articles initiaux retirés (`la chaine l equipe` → `equipe`).
  static const Set<String> _leadingArticles = {'le', 'la', 'les'};

  /// Alias de requêtes (clé = nom normalisé cherché, valeur = nom
  /// normalisé indexé). Couvre les acronymes et formes collées que la
  /// normalisation seule ne réconcilie pas.
  static const Map<String, String> queryAliases = {
    'lcp': 'parlementaire', // "LCP" vs "La chaine parlementaire"
    'lequipe': 'equipe', // "LEquipe" collé vs "L'Equipe"
    'equipe 21': 'equipe',
  };

  /// Normalise un nom (ou slug, ou ID XMLTV) de chaîne pour le mapping :
  /// minuscules, accents retirés, ponctuation → espaces, tokens de bruit
  /// retirés. Ex. `France2.fr` → `france 2`, `TF1 HD` → `tf1`.
  /// Ne lève jamais (retourne '' en cas d'entrée inattendue).
  static String normalizeName(String raw) {
    try {
      var s = raw.toLowerCase().trim();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      buf.write(_accents[ch] ?? ch);
    }
    s = buf.toString();
    s = s.replaceAll(_sepRe, ' ');
    s = s.replaceAll(_punctRe, ' ');
    s = s.replaceAll(_wsRe, ' ').trim();
    if (s.isEmpty) return '';
    final kept = <String>[];
    for (final tok in s.split(' ')) {
      if (tok.isEmpty) continue;
      // Garde les chiffres (`france 2`, `6ter`) et les tokens
      // significatifs ; jette le bruit et les lettres isolées
      // (`l equipe` → `equipe`).
      if (_digitsRe.hasMatch(tok)) {
        kept.add(tok);
        continue;
      }
      if (tok.length <= 1) continue;
      if (_noiseTokens.contains(tok)) continue;
      kept.add(tok);
    }
    // Article initial : `la chaine l equipe` est déjà `la equipe` ici
    // (chaine = bruit, l = lettre isolée) → `equipe`.
    if (kept.length > 1 && _leadingArticles.contains(kept.first)) {
      kept.removeAt(0);
    }
    return kept.join(' ');
    } catch (_) {
      return '';
    }
  }

  /// Variante sans espaces pour les collages type `France2` vs `France 2`.
  /// Ne lève jamais.
  static String spaceless(String normalized) {
    try {
      return normalized.replaceAll(' ', '');
    } catch (_) {
      return '';
    }
  }

  /// Slug strict du cache serveur pré-calculé (`epg_now.json` exposé via
  /// `live_proxy.php?action=epg&slug=<slug>`) : minuscules, accents retirés,
  /// tout caractère non-alphanum SUPPRIMÉ (sans espaces).
  /// Ex. `France 2` → `france2`, `M6-HD` → `m6hd`, `L'Équipe` → `lequipe`.
  ///
  /// DIFFÈRE volontairement de [normalizeName] (qui retire les tokens de
  /// bruit et garde les espaces : `TF1 HD` → `tf1`) : le serveur utilise
  /// cette forme stricte, d'où des clés type `tf1hd` possibles côté
  /// serveur là où [normalizeName] donnerait `tf1`. Ne pas les confondre :
  /// [serverSlug] sert UNIQUEMENT à interroger l'endpoint serveur, jamais
  /// au mapping XMLTV local (fallback). Ne lève jamais.
  static String serverSlug(String raw) {
    try {
      var s = raw.toLowerCase().trim();
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        final ch = s[i];
        buf.write(_accents[ch] ?? ch);
      }
      s = buf.toString();
      final out = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        final c = s.codeUnitAt(i);
        final isDigit = c >= 0x30 && c <= 0x39; // 0-9
        final isLower = c >= 0x61 && c <= 0x7A; // a-z
        if (isDigit || isLower) out.writeCharCode(c);
      }
      return out.toString();
    } catch (_) {
      return '';
    }
  }

  // RegExp précompilées (petites sections uniquement : display-names,
  // champs d'un programme retenu — jamais de balayage global).
  static final RegExp _sepRe = RegExp(r'[._\-+/|]+');
  static final RegExp _punctRe =
      RegExp(r'''['"’‘`´^~:;!?()\[\]{}<>*=&#@%$,]''');
  static final RegExp _wsRe = RegExp(r'\s+');
  static final RegExp _digitsRe = RegExp(r'^\d+$');
  static final RegExp _numEntityRe = RegExp(r'&#(\d+);');
  static final RegExp _iconRe = RegExp(r'<icon\s+[^>]*src="([^"]*)"');
  static final Map<String, RegExp> _tagRes = {};

  static final RegExp _channelRe =
      RegExp(r'<channel\s+id="([^"]+)"[^>]*>(.*?)</channel>', dotAll: true);
  static final RegExp _displayNameRe =
      RegExp(r'<display-name[^>]*>(.*?)</display-name>', dotAll: true);
  static final RegExp _dateRe =
      RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})\s*([+-]\d{4}|Z)?$');

  static const Map<String, String> _entities = {
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&apos;': "'",
    '&#39;': "'",
    '&#34;': '"',
    '&nbsp;': ' ',
  };

  static String _unescape(String s) {
    try {
      // Chemin rapide : la plupart des titres n'ont aucune entité.
      if (!s.contains('&')) return s.replaceAll(_wsRe, ' ').trim();
      var out = s;
      _entities.forEach((k, v) => out = out.replaceAll(k, v));
      out = out.replaceAllMapped(
        _numEntityRe,
        (m) {
          try {
            return String.fromCharCode(int.parse(m.group(1)!));
          } catch (_) {
            return '';
          }
        },
      );
      return out.replaceAll(_wsRe, ' ').trim();
    } catch (_) {
      return '';
    }
  }

  static RegExp _tagRe(String tag) =>
      _tagRes.putIfAbsent(tag, () => RegExp('<$tag[^>]*>(.*?)</$tag>', dotAll: true));

  static String _tagText(String body, String tag) {
    try {
      final m = _tagRe(tag).firstMatch(body);
      if (m == null) return '';
      return _unescape(m.group(1) ?? '');
    } catch (_) {
      return '';
    }
  }

  static String? _iconSrc(String body) {
    try {
      final m = _iconRe.firstMatch(body);
      final src = m?.group(1)?.trim();
      return (src == null || src.isEmpty) ? null : src;
    } catch (_) {
      return null;
    }
  }

  /// `20260918000000 +0200` → instant UTC. Ne lève jamais (null si invalide).
  static DateTime? parseXmltvDate(String raw) {
    try {
      final m = _dateRe.firstMatch(raw.trim());
      if (m == null) return null;
      final dt = DateTime.utc(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
        int.parse(m.group(6)!),
      );
      final tz = m.group(7);
      if (tz == null || tz.isEmpty || tz == 'Z') return dt;
      final sign = tz[0] == '-' ? -1 : 1;
      final off = Duration(
        hours: int.parse(tz.substring(1, 3)),
        minutes: int.parse(tz.substring(3, 5)),
      );
      return dt.subtract(off * sign);
    } catch (_) {
      return null;
    }
  }

  // ── Index léger des chaînes ──────────────────────────────────────────
  //
  // Ne touche QUE la petite section `<channel>` (592 entrées) : on coupe
  // le XML au premier `<programme` pour ne jamais balayer les ~58k
  // programmes avec une RegExp globale.

  /// Remplit [nameToId] (nom normalisé → ID) et [channelIds] depuis la
  /// section `<channel>` de [xml]. Léger : quelques centaines d'entrées.
  /// Ne lève jamais.
  static void indexChannels(
    String xml,
    Map<String, String> nameToId,
    Set<String> channelIds,
  ) {
    try {
      final cut = xml.indexOf('<programme');
      final head = cut < 0 ? xml : xml.substring(0, cut);
      for (final m in _channelRe.allMatches(head)) {
        try {
          final id = _unescape((m.group(1) ?? '').trim());
          if (id.isEmpty) continue;
          channelIds.add(id);
          final names = _displayNameRe
              .allMatches(m.group(2) ?? '')
              .map((n) => _unescape(n.group(1) ?? ''))
              .where((n) => n.isNotEmpty)
              .toList();
          for (final c in <String>{id, ...names}) {
            final norm = normalizeName(c);
            if (norm.isEmpty) continue;
            nameToId.putIfAbsent(norm, () => id);
            final flat = spaceless(norm);
            if (flat.isNotEmpty && flat != norm) {
              nameToId.putIfAbsent(flat, () => id);
            }
          }
        } catch (_) {
          continue;
        }
      }
    } catch (_) {}
  }

  /// Résout une requête (slug FSTV ou titre) vers le set d'IDs XMLTV
  /// candidats dans l'index fourni (en général UN seul ID ; plusieurs si
  /// des alias pointent vers des IDs distincts). Ensemble vide = inconnue.
  /// Ne lève jamais.
  static Set<String> resolveIds(
    Map<String, String> nameToId,
    Set<String> channelIds,
    String query,
  ) {
    try {
      final q = query.trim();
      if (q.isEmpty || channelIds.isEmpty) return const {};
      // 1) ID exact (insensible à la casse).
      for (final id in channelIds) {
        if (id.toLowerCase() == q.toLowerCase()) return {id};
      }
      // 2) Nom normalisé (avec puis sans espaces), alias inclus.
      final out = <String>{};
      final norm = normalizeName(q);
      if (norm.isNotEmpty) {
        final aliased = queryAliases[norm] ?? norm;
        final hit =
            nameToId[aliased] ?? nameToId[spaceless(aliased)];
        if (hit != null) out.add(hit);
      }
      if (out.isNotEmpty) return out;
      // 3) Repli : IDs dont la forme normalisée colle à la requête.
      for (final id in channelIds) {
        if (normalizeName(id) == norm) out.add(id);
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  // ── Parse filtrant en streaming ──────────────────────────────────────
  //
  // Balaie `<programme>` par indexOf (aucune RegExp globale, aucun
  // `allMatches` sur 58k entrées) et ne matérialise un [EpgProgram] que si
  // le canal fait partie de [wanted] ET chevauche [from, to]. Tout le reste
  // est sauté par simple avance d'index (zéro substring du body, zéro
  // allocation d'objet). Cède la main périodiquement pour ne pas bloquer
  // l'UI.

  /// Valeur d'un attribut XML dans un fragment de balise ouvrante
  /// (ex. `channel="TF1.fr"` dans `<programme channel="..." ...>`).
  /// Retourne null si absent. Rapide : deux indexOf, pas de RegExp.
  /// Ne lève jamais.
  static String? _attrValue(String tagFragment, String name) {
    try {
      final key = '$name="';
      final s = tagFragment.indexOf(key);
      if (s < 0) return null;
      final vStart = s + key.length;
      final vEnd = tagFragment.indexOf('"', vStart);
      if (vEnd < 0) return null;
      return tagFragment.substring(vStart, vEnd);
    } catch (_) {
      return null;
    }
  }

  /// Parse [xml] en ne gardant que les programmes de [wanted] chevauchant
  /// [from, to]. Ajoute à [into] (ou nouvelle liste). Pic mémoire : la
  /// chaîne XML (incompressible sans parser SAX) + une poignée de
  /// programmes retenus (fenêtre -30 min → +12 h : typiquement < 15).
  /// Ne lève JAMAIS : tout échec → retourne ce qui a été retenu.
  static Future<List<EpgProgram>> parseFiltered(
    String xml,
    Set<String> wanted,
    int rank,
    DateTime from,
    DateTime to, {
    List<EpgProgram>? into,
    int maxDescLength = 280,
  }) async {
    final out = into ?? <EpgProgram>[];
    try {
      if (wanted.isEmpty) return out;
      var pos = 0;
      var scanned = 0;
      while (true) {
        int tagStart;
        int attrEnd;
        try {
          tagStart = xml.indexOf('<programme', pos);
          if (tagStart < 0) break;
          attrEnd = xml.indexOf('>', tagStart);
          if (attrEnd < 0) break;
        } catch (_) {
          break;
        }
        scanned++;
        // Respiration : 1 frame tous les ~1024 balayés (skip ou retenu).
        if ((scanned & 1023) == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        try {
          // Filtre canal AVANT toute allocation : extrait juste l'attribut.
          final rawChannel = _attrValue(
            xml.substring(tagStart, attrEnd),
            'channel',
          );
          final channel =
              rawChannel == null ? '' : _unescape(rawChannel.trim());
          if (channel.isEmpty || !wanted.contains(channel)) {
            final close = xml.indexOf('</programme>', attrEnd);
            if (close < 0) break;
            pos = close + 12; // '</programme>'.length
            continue;
          }
          // Canal voulu : dates (toujours dans la balise ouvrante).
          final openTag = xml.substring(tagStart, attrEnd);
          final start = parseXmltvDate(_attrValue(openTag, 'start') ?? '');
          final stop = parseXmltvDate(_attrValue(openTag, 'stop') ?? '');
          final bodyEnd = xml.indexOf('</programme>', attrEnd);
          if (bodyEnd < 0) break;
          if (start == null || stop == null || !stop.isAfter(start)) {
            pos = bodyEnd + 12;
            continue;
          }
          // Fenêtre réduite avec recouvrement (capte le direct à cheval
          // qui a démarré avant [from]).
          if (stop.isBefore(from) || start.isAfter(to)) {
            pos = bodyEnd + 12;
            continue;
          }
          final body = xml.substring(attrEnd + 1, bodyEnd);
          final title = _tagText(body, 'title');
          if (title.isEmpty) {
            pos = bodyEnd + 12;
            continue;
          }
          final desc = _tagText(body, 'desc');
          out.add(
            EpgProgram(
              channelId: channel,
              sourceRank: rank,
              title: title,
              subTitle: _tagText(body, 'sub-title').nullIfEmpty,
              desc: desc.nullIfEmpty?.truncate(maxDescLength),
              category: _tagText(body, 'category').nullIfEmpty,
              icon: _iconSrc(body),
              start: start,
              end: stop,
            ),
          );
          pos = bodyEnd + 12;
        } catch (_) {
          // Entrée corrompue : on avance sans jamais propager.
          try {
            final bodyEnd = xml.indexOf('</programme>', attrEnd);
            if (bodyEnd < 0) break;
            pos = bodyEnd + 12;
          } catch (_) {
            break;
          }
          continue;
        }
      }
      return out;
    } catch (_) {
      return out;
    }
  }
}

extension EpgString on String {
  String? get nullIfEmpty => isEmpty ? null : this;

  String truncate(int max) =>
      length <= max ? this : '${substring(0, max).trimRight()}…';
}
