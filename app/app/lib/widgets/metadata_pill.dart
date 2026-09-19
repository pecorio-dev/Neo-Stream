import 'package:flutter/material.dart';

import '../models/anime.dart';
import '../models/content.dart';
import '../services/player_prefs.dart';

/// Tonalités visuelles des pills de métadonnées.
///
/// Le violet anime (#A78BFA) est volontairement distinct du bleu série
/// (#38BDF8) pour lever toute ambiguïté visuelle entre les deux types.
enum PillTone {
  film,
  serie,
  anime,
  rating,
  year,
  seasons,
  episodes,
  genre,
  lang,
  match,
  views,
  premium,
  progress,
  watched,
}

/// Donnée unitaire affichée par [MetadataPill] / [MetadataPillsRow].
class PillData {
  final String label;
  final IconData? icon;
  final PillTone tone;
  final String? semanticsLabel;

  const PillData(this.label, {this.icon, required this.tone, this.semanticsLabel});
}

/// Couleur d'accent associée à chaque tonalité.
Color pillToneColor(PillTone tone) {
  switch (tone) {
    case PillTone.film:
      return const Color(0xFFE50914);
    case PillTone.serie:
      return const Color(0xFF38BDF8);
    case PillTone.anime:
      return const Color(0xFFA78BFA);
    case PillTone.rating:
      return const Color(0xFFE8B84A);
    case PillTone.match:
      return const Color(0xFF0AD48B);
    case PillTone.premium:
      return const Color(0xFFE8B84A);
    case PillTone.progress:
      return const Color(0xFFE50914);
    case PillTone.watched:
      return const Color(0xFF0AD48B);
    case PillTone.year:
    case PillTone.seasons:
    case PillTone.episodes:
    case PillTone.genre:
    case PillTone.views:
      return const Color(0xFF9E9E9E);
    case PillTone.lang:
      return const Color(0xFF6366F1);
  }
}

/// Icône par défaut associée à chaque tonalité.
IconData? pillToneIcon(PillTone tone) {
  switch (tone) {
    case PillTone.film:
      return Icons.movie_rounded;
    case PillTone.serie:
      return Icons.tv_rounded;
    case PillTone.anime:
      return Icons.animation_rounded;
    case PillTone.rating:
      return Icons.star_rounded;
    case PillTone.year:
      return Icons.calendar_today_rounded;
    case PillTone.seasons:
      return Icons.layers_rounded;
    case PillTone.episodes:
      return Icons.list_rounded;
    case PillTone.genre:
      return null;
    case PillTone.lang:
      return Icons.g_translate_rounded;
    case PillTone.match:
      return Icons.auto_awesome_rounded;
    case PillTone.views:
      return Icons.visibility_rounded;
    case PillTone.premium:
      return Icons.workspace_premium_rounded;
    case PillTone.progress:
      return Icons.play_circle_fill_rounded;
    case PillTone.watched:
      return Icons.check_circle_rounded;
  }
}

/// Pill unitaire 10-12px bold avec ellipsis.
///
/// [onPoster] : fond noir 0.75 (sur poster). Sinon fond surface sombre.
/// Le widget ne prend jamais le focus (cartes TV/mobile déjà focusables).
class MetadataPill extends StatelessWidget {
  final PillData pill;
  final bool onPoster;
  final double fontSize;

  const MetadataPill(this.pill, {super.key, this.onPoster = false, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    final accent = pillToneColor(pill.tone);
    final icon = pill.icon ?? pillToneIcon(pill.tone);
    final isType = pill.tone == PillTone.film ||
        pill.tone == PillTone.serie ||
        pill.tone == PillTone.anime;
    final isOutline = pill.tone == PillTone.lang;

    final bg = onPoster
        ? Colors.black.withValues(alpha: 0.75)
        : isType
            ? accent.withValues(alpha: 0.15)
            : const Color(0xFF1E1E1E).withValues(alpha: 0.9);
    final border = isType || isOutline
        ? Border.all(color: accent.withValues(alpha: 0.35), width: 0.5)
        : Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.5);
    final fg = isType ? accent : Colors.white.withValues(alpha: 0.92);

    return ExcludeFocus(
      excluding: true,
      child: Semantics(
        container: true,
        label: pill.semanticsLabel ?? pill.label,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: border),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: fontSize + 2, color: fg),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  pill.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: fontSize, fontWeight: FontWeight.w700, height: 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne de pills en [Wrap] avec limite d'affichage.
class MetadataPillsRow extends StatelessWidget {
  final List<PillData> pills;
  final int maxPills;
  final bool onPoster;
  final double fontSize;
  final double spacing;

  const MetadataPillsRow({
    super.key,
    required this.pills,
    this.maxPills = 3,
    this.onPoster = false,
    this.fontSize = 10,
    this.spacing = 6,
  });

  @override
  Widget build(BuildContext context) {
    final visible = pills.take(maxPills).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return ExcludeFocus(
      excluding: true,
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final p in visible) MetadataPill(p, onPoster: onPoster, fontSize: fontSize)],
      ),
    );
  }
}

// ─── Helpers Content / Anime ─────────────────────────────────────────────

/// Pills pour un [Content] : année + saisons + épisodes + genre + langue +
/// match/rating + vues + premium. Le type est inclus par défaut.
List<PillData> pillsFromContent(Content c, {bool short = false, bool includeType = true}) {
  final pills = <PillData>[];
  if (includeType) {
    if (c.isAnime) {
      pills.add(const PillData('Anime', tone: PillTone.anime));
    } else if (c.isSerie) {
      pills.add(const PillData('Série', tone: PillTone.serie));
    } else {
      pills.add(const PillData('Film', tone: PillTone.film));
    }
  }
  if (c.releaseDate != null) {
    pills.add(PillData('${c.releaseDate}', tone: PillTone.year));
  }
  if (c.isSerie && c.seasonCount > 0) {
    pills.add(PillData(
      c.seasonCount > 1 ? '${c.seasonCount} saisons' : '1 saison',
      tone: PillTone.seasons,
    ));
  }
  if (c.episodeCount > 0 && (c.isSerie || c.isAnime)) {
    pills.add(PillData('${c.episodeCount} ép.', tone: PillTone.episodes));
  }
  if (c.mainGenre.isNotEmpty && !short) {
    pills.add(PillData(c.mainGenre, tone: PillTone.genre));
  }
  if (c.languageTag.isNotEmpty) {
    pills.add(PillData(c.languageTag, tone: PillTone.lang));
  }
  if (c.matchPercent != null) {
    pills.add(PillData('${c.matchPercent}% match', tone: PillTone.match));
  } else if (c.rating > 0 && short) {
    pills.add(PillData(c.rating.toStringAsFixed(1), tone: PillTone.rating));
  }
  if (!short && (c.todayViews ?? 0) > 0) {
    pills.add(PillData('${c.todayViews} vues', tone: PillTone.views));
  }
  if (c.isPremiumContent && !short) {
    pills.add(const PillData('Premium', tone: PillTone.premium));
  }
  return pills;
}

/// Pills pour un [Anime] : type + saisons + épisodes + genre + langue.
List<PillData> pillsFromAnime(Anime a, {bool short = false}) {
  final pills = <PillData>[
    const PillData('Anime', tone: PillTone.anime),
    PillData(
      a.totalSeasons > 1 ? '${a.totalSeasons} saisons' : '${a.totalSeasons} saison',
      tone: PillTone.seasons,
    ),
    PillData('${a.totalEpisodes} ép.', tone: PillTone.episodes),
  ];
  if (!short && a.genres.isNotEmpty) {
    pills.add(PillData(a.genres.first, tone: PillTone.genre));
  }
  final lang = _animeLanguage(a);
  if (lang.isNotEmpty) {
    pills.add(PillData(lang, tone: PillTone.lang));
  }
  return pills;
}

String _animeLanguage(Anime a) {
  for (final season in a.seasons.values) {
    if (season.language == 'vf') return 'VF';
    if (season.language == 'vostfr') return 'VOSTFR';
  }
  return '';
}

// ─── Progression ─────────────────────────────────────────────────────────

/// Progression effective 0-100 d'une carte.
///
/// Priorité : `progressPercent` API si > 0, sinon progression de
/// l'épisode courant (`currentEpisodeId`), sinon 0.
double effectiveCardProgress(Content c) {
  if (c.progressPercent != null && c.progressPercent! > 0) {
    return c.progressPercent!.clamp(0.0, 100.0);
  }
  final id = c.currentEpisodeId;
  if (id != null && id.isNotEmpty) {
    for (final ep in c.episodes) {
      if ('S${ep.season}E${ep.episode}' == id && (ep.progressPercent ?? 0) > 0) {
        return ep.progressPercent!.clamp(0.0, 100.0);
      }
    }
    for (final list in c.seasons.values) {
      for (final ep in list) {
        if ('S${ep.season}E${ep.episode}' == id && (ep.progressPercent ?? 0) > 0) {
          return ep.progressPercent!.clamp(0.0, 100.0);
        }
      }
    }
  }
  return 0;
}

/// Statistiques de visionnage d'une série : épisodes terminés (>= 95%),
/// total, pourcentage.
({int watched, int total, double percent}) seriesWatchStats(Content c) {
  final all = <String, double>{};
  for (final list in c.seasons.values) {
    for (final ep in list) {
      all['S${ep.season}E${ep.episode}'] = ep.progressPercent ?? 0;
    }
  }
  for (final ep in c.episodes) {
    all.putIfAbsent('S${ep.season}E${ep.episode}', () => ep.progressPercent ?? 0);
  }
  final total = all.isNotEmpty ? all.length : c.episodeCount;
  if (total <= 0) return (watched: 0, total: 0, percent: 0);
  final watched = all.values.where((p) => p >= 95).length;
  return (watched: watched, total: total, percent: watched / total * 100);
}

/// Statistiques de visionnage d'un anime.
({int watched, int total, double percent}) animeWatchStats(Anime a) {
  var total = 0;
  var watched = 0;
  for (final season in a.seasons.values) {
    for (final ep in season.episodes) {
      total++;
      if ((ep.progressPercent ?? 0) >= 95) watched++;
    }
  }
  if (total <= 0) total = a.totalEpisodes;
  final percent = total > 0 ? watched / total * 100 : 0.0;
  return (watched: watched, total: total, percent: percent);
}

/// Libellé "Vu à X% (reste …)" pour un film à partir d'une position/durée.
String filmProgressLabel(double percent, {double? remainingSeconds}) {
  final base = 'Vu à ${percent.round()}%';
  if (remainingSeconds == null || remainingSeconds <= 0) return base;
  final total = remainingSeconds.round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  if (h > 0) return '$base (reste ${h}h${m.toString().padLeft(2, '0')})';
  return '$base (reste ${m}min)';
}

/// Libellé "Progression : X/Y épisodes (Z%)" pour une série/anime.
String seriesProgressLabel(int watched, int total, double percent) {
  if (total <= 0) return 'Progression indisponible';
  return 'Progression : $watched/$total épisodes (${percent.round()}%)';
}

// ─── Progression locale (PlayerPrefs) ──────────────────────────────────

/// Clé PlayerPrefs pour un épisode de série/film.
/// Format aligné sur PlayerScreen._progressKey : `{contentId}_S{season}E{ep}`.
String localProgressKeyForContentEpisode(int contentId, int season, int episode) =>
    '${contentId}_S${season}E${episode}';

/// Clé PlayerPrefs pour un épisode d'anime.
/// Format aligné sur PlayerScreen._progressKey : `anime_{id}_{season}_{ep}`.
String localProgressKeyForAnimeEpisode(int animeId, int season, int episode) =>
    'anime_${animeId}_${season}_${episode}';

/// Pourcentage 0-100 depuis une position/durée locales (secondes).
double localProgressPercent(double position, double duration) {
  if (position <= 0) return 0;
  if (duration <= 0) return 0;
  return (position / duration * 100).clamp(0.0, 100.0);
}

/// Progression effective d'un épisode : max(API, locale).
double episodeEffectivePercent(double? apiPercent, double? localPercent) {
  final a = apiPercent ?? 0;
  final l = localPercent ?? 0;
  return (a > l ? a : l).clamp(0.0, 100.0);
}

/// Pill "Vu" (≥95%) ou "X%" (>0), null si rien à afficher.
PillData? episodeProgressPill(double effectivePercent) {
  if (effectivePercent >= 95) {
    return const PillData('Vu', tone: PillTone.watched);
  }
  if (effectivePercent > 0) {
    return PillData('${effectivePercent.round()}%', tone: PillTone.progress);
  }
  return null;
}

/// Pill de progression d'épisode avec fallback local.
///
/// Affiche "Vu" si la progression API ou locale ≥ 95%, "X%" si > 0,
/// rien sinon. Ne prend jamais le focus.
class EpisodeProgressPill extends StatelessWidget {
  final double? apiPercent;
  final String localKey;
  final double fontSize;
  final bool onPoster;

  const EpisodeProgressPill({
    super.key,
    required this.apiPercent,
    required this.localKey,
    this.fontSize = 9,
    this.onPoster = false,
  });

  @override
  Widget build(BuildContext context) {
    final api = apiPercent ?? 0;
    if (api >= 95) {
      return MetadataPill(
        const PillData('Vu', tone: PillTone.watched),
        fontSize: fontSize,
        onPoster: onPoster,
      );
    }
    if (api > 0) {
      return MetadataPill(
        PillData('${api.round()}%', tone: PillTone.progress),
        fontSize: fontSize,
        onPoster: onPoster,
      );
    }
    return FutureBuilder<({double position, double duration})?>(
      future: PlayerPrefs.loadLocalProgress(localKey),
      builder: (context, snapshot) {
        final local = snapshot.data;
        if (local == null) return const SizedBox.shrink();
        final effective = episodeEffectivePercent(
          api,
          localProgressPercent(local.position, local.duration),
        );
        final pill = episodeProgressPill(effective);
        if (pill == null) return const SizedBox.shrink();
        return MetadataPill(pill, fontSize: fontSize, onPoster: onPoster);
      },
    );
  }
}
