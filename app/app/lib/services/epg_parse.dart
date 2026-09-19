import 'dart:convert';

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

/// Résultat brut du parsing d'un flux XMLTV (sans I/O, testable en pur Dart).
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
  static String normalizeName(String raw) {
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
  }

  /// Variante sans espaces pour les collages type `France2` vs `France 2`.
  static String spaceless(String normalized) => normalized.replaceAll(' ', '');

  // RegExp précompilées (le parse brosse ~60k programmes : construire un
  // RegExp par champ et par programme coûtait des secondes de CPU).
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
  static final RegExp _programmeRe =
      RegExp(r'<programme\s+([^>]*)>(.*?)</programme>', dotAll: true);
  static final RegExp _attrRe = RegExp(r'(\w+)="([^"]*)"');
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
    // Chemin rapide : la plupart des titres n'ont aucune entité.
    if (!s.contains('&')) return s.replaceAll(_wsRe, ' ').trim();
    var out = s;
    _entities.forEach((k, v) => out = out.replaceAll(k, v));
    out = out.replaceAllMapped(
      _numEntityRe,
      (m) => String.fromCharCode(int.parse(m.group(1)!)),
    );
    return out.replaceAll(_wsRe, ' ').trim();
  }

  static RegExp _tagRe(String tag) =>
      _tagRes.putIfAbsent(tag, () => RegExp('<$tag[^>]*>(.*?)</$tag>', dotAll: true));

  static String _tagText(String body, String tag) {
    final m = _tagRe(tag).firstMatch(body);
    if (m == null) return '';
    return _unescape(m.group(1) ?? '');
  }

  static String? _iconSrc(String body) {
    final m = _iconRe.firstMatch(body);
    final src = m?.group(1)?.trim();
    return (src == null || src.isEmpty) ? null : src;
  }

  /// `20260918000000 +0200` → instant UTC.
  static DateTime? parseXmltvDate(String raw) {
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
  }

  /// Parse un flux XMLTV **décompressé** et fusionne dans [into] (ou un
  /// nouveau [EpgParsed]). Seuls les programmes dans
  /// `[now-keepPast, now+keepFuture]` sont conservés (borne la RAM).
  /// [rank] = priorité de la source (0 = prioritaire, gagne les égalités
  /// de mapping mais les programmes fusionnent par ID de chaîne).
  /// Cède périodiquement la main (parse de ~60k programmes ≈ secondes)
  /// pour ne pas bloquer l'UI.
  static Future<EpgParsed> parse(
    List<int> xmlBytes,
    int rank, {
    EpgParsed? into,
    DateTime? now,
    Duration keepPast = const Duration(hours: 6),
    Duration keepFuture = const Duration(days: 6),
    int maxDescLength = 280,
  }) async {
    final out = into ?? EpgParsed();
    final ref = (now ?? DateTime.now()).toUtc();
    final keepFrom = ref.subtract(keepPast);
    final keepTo = ref.add(keepFuture);
    final xml = utf8.decode(xmlBytes, allowMalformed: true);

    for (final m in _channelRe.allMatches(xml)) {
      // Les IDs peuvent contenir des entités (`L&apos;Equipe.fr`) :
      // on les décode comme les display-names pour rester cohérent
      // avec l'attribut `channel` des programmes (décodé aussi).
      final id = _unescape((m.group(1) ?? '').trim());
      if (id.isEmpty) continue;
      out.channelIds.add(id);
      final names = _displayNameRe
          .allMatches(m.group(2) ?? '')
          .map((n) => _unescape(n.group(1) ?? ''))
          .where((n) => n.isNotEmpty)
          .toList();
      for (final c in <String>{id, ...names}) {
        final norm = normalizeName(c);
        if (norm.isEmpty) continue;
        out.nameToId.putIfAbsent(norm, () => id);
        final flat = spaceless(norm);
        if (flat.isNotEmpty && flat != norm) {
          out.nameToId.putIfAbsent(flat, () => id);
        }
      }
      out.programsByChannel.putIfAbsent(id, () => <EpgProgram>[]);
    }

    var count = 0;
    for (final m in _programmeRe.allMatches(xml)) {
      if ((++count & 1023) == 0) {
        // Rend la main à l'event-loop tous les ~1024 programmes.
        await Future<void>.delayed(Duration.zero);
      }
      final attrs = <String, String>{};
      for (final a in _attrRe.allMatches(m.group(1) ?? '')) {
        attrs[a.group(1)!] = a.group(2) ?? '';
      }
      final channel = _unescape((attrs['channel'] ?? '').trim());
      final start = parseXmltvDate(attrs['start'] ?? '');
      final stop = parseXmltvDate(attrs['stop'] ?? '');
      if (channel.isEmpty || start == null || stop == null) continue;
      if (!stop.isAfter(start)) continue;
      if (stop.isBefore(keepFrom) || start.isAfter(keepTo)) continue;
      final body = m.group(2) ?? '';
      final title = _tagText(body, 'title');
      if (title.isEmpty) continue;
      final desc = _tagText(body, 'desc');
      out.programsByChannel.putIfAbsent(channel, () => <EpgProgram>[]).add(
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
    }
    return out;
  }
}

extension EpgString on String {
  String? get nullIfEmpty => isEmpty ? null : this;

  String truncate(int max) =>
      length <= max ? this : '${substring(0, max).trimRight()}…';
}
