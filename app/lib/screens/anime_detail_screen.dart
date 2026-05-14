import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/anime.dart';
import '../services/api_service.dart';
import 'anime_player_screen.dart';

class AnimeDetailScreen extends StatefulWidget {
  final int animeId;

  const AnimeDetailScreen({super.key, required this.animeId});

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();

  Anime? _anime;
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedSeason = 1;
  String _selectedLanguage = 'vostfr';
  bool _inLibrary = false;
  late final AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadAnime();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAnime() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _api.getAnimeDetail(widget.animeId);
      if (data['anime'] == null) throw Exception('Données anime non disponibles');
      final anime = Anime.fromJson(data['anime'] as Map<String, dynamic>);

      bool inLibrary = false;
      try {
        inLibrary = await _api.checkAnimeInLibrary(anime.id);
      } catch (_) {}

      if (!mounted) return;

      // Determine available languages from seasons
      final languages = <String>{};
      for (final s in anime.seasons.values) {
        languages.add(s.language);
      }
      final defaultLang = languages.contains('vf') ? 'vf' : 'vostfr';

      // First valid season for default language
      final firstKey = _firstSeasonForLanguage(anime, defaultLang);

      setState(() {
        _anime = anime;
        _inLibrary = inLibrary;
        _selectedLanguage = defaultLang;
        _selectedSeason = firstKey ?? 1;
        _isLoading = false;
      });
      _fadeCtrl.forward(from: 0);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = humanizeApiError(error);
        _isLoading = false;
      });
    }
  }

  int? _firstSeasonForLanguage(Anime anime, String lang) {
    final keys = anime.seasons.entries
        .where((e) => e.value.language == lang && e.value.episodes.isNotEmpty)
        .map((e) => e.key)
        .toList()
      ..sort();
    return keys.isNotEmpty ? keys.first : null;
  }

  List<int> _seasonsForLanguage(String lang) {
    final anime = _anime;
    if (anime == null) return [];
    final keys = anime.seasons.entries
        .where((e) => e.value.language == lang && e.value.episodes.isNotEmpty)
        .map((e) => e.key)
        .toList()
      ..sort();
    return keys;
  }

  Set<String> get _availableLanguages {
    final anime = _anime;
    if (anime == null) return {};
    final langs = <String>{};
    for (final s in anime.seasons.values) {
      if (s.episodes.isNotEmpty) langs.add(s.language);
    }
    return langs;
  }

  void _selectLanguage(String lang) {
    final first = _firstSeasonForLanguage(_anime!, lang);
    setState(() {
      _selectedLanguage = lang;
      _selectedSeason = first ?? _selectedSeason;
    });
  }

  void _playEpisode(
    int seasonNumber,
    AnimeEpisode episode,
    List<Map<String, String>> sources,
  ) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => AnimePlayerScreen(
            anime: _anime!,
            seasonNumber: seasonNumber,
            episode: episode,
            sources: sources,
          ),
        ))
        .then((_) {
      if (mounted) _loadAnime();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: NeoTheme.bgBase,
        appBar: AppBar(backgroundColor: NeoTheme.bgBase, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: NeoTheme.errorRed),
                const SizedBox(height: 16),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _loadAnime, child: const Text('Réessayer')),
              ],
            ),
          ),
        ),
      );
    }

    final anime = _anime!;
    final seasonKeys = _seasonsForLanguage(_selectedLanguage);
    final season = anime.seasons[_selectedSeason];

    return Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.goBack ||
                event.logicalKey == LogicalKeyboardKey.browserBack)) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: NeoTheme.bgBase,
        body: FadeTransition(
          opacity: _fadeCtrl,
          child: CustomScrollView(
            slivers: [
              _buildHero(anime),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleSection(anime),
                      const SizedBox(height: 20),
                      _buildActionRow(anime),
                      const SizedBox(height: 24),
                      if (_availableLanguages.length > 1) ...[
                        _buildLanguageTabs(),
                        const SizedBox(height: 16),
                      ],
                      if (seasonKeys.isNotEmpty) ...[
                        _buildSeasonSelector(seasonKeys),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
              if (season != null && season.episodes.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) =>
                          _buildEpisodeCard(season.episodes[i], _selectedSeason),
                      childCount: season.episodes.length,
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: NeoTheme.bgElevated,
                        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                        border: Border.all(
                            color: NeoTheme.bgBorder.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: NeoTheme.textSecondary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _availableLanguages.isEmpty
                                  ? 'Les épisodes ne sont pas encore disponibles.'
                                  : 'Aucun épisode pour cette langue / saison.',
                              style: NeoTheme.bodySmall(context)
                                  .copyWith(color: NeoTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HERO ──────────────────────────────────────────────────────────────

  Widget _buildHero(Anime anime) {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: NeoTheme.bgBase,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12, width: 0.5),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Blurred background
            if (anime.hasPoster)
              CachedNetworkImage(
                imageUrl: anime.posterUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: NeoTheme.bgElevated),
                errorWidget: (_, _, _) =>
                    Container(color: NeoTheme.bgElevated),
              ),
            // Dark gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.6),
                    NeoTheme.bgBase,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
            // Poster + info at bottom
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (anime.hasPoster)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                      child: CachedNetworkImage(
                        imageUrl: anime.posterUrl!,
                        width: 90,
                        height: 130,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (anime.genres.isNotEmpty)
                          Text(
                            anime.genres.first
                                .split(' - ')
                                .take(3)
                                .join(' · '),
                            style: NeoTheme.labelSmall(context).copyWith(
                              color: NeoTheme.primaryRed,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          anime.title,
                          style: NeoTheme.headlineLarge(context).copyWith(
                            fontWeight: FontWeight.w800,
                            shadows: [
                              const Shadow(
                                  color: Colors.black87, blurRadius: 8)
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (anime.titleAlt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            anime.titleAlt!,
                            style: NeoTheme.bodySmall(context).copyWith(
                              color: Colors.white60,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TITLE SECTION ─────────────────────────────────────────────────────

  Widget _buildTitleSection(Anime anime) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(
              '${anime.totalSeasons} saison${anime.totalSeasons > 1 ? 's' : ''}',
              Icons.tv_rounded,
            ),
            _chip(
              '${anime.totalEpisodes} épisodes',
              Icons.play_circle_outline_rounded,
            ),
            if (_availableLanguages.isNotEmpty)
              _chip(
                _availableLanguages.map((l) => l.toUpperCase()).join(' · '),
                Icons.language_rounded,
                accent: true,
              ),
          ],
        ),
        if (anime.synopsis != null) ...[
          const SizedBox(height: 14),
          _ExpandableSynopsis(synopsis: anime.synopsis!),
        ],
      ],
    );
  }

  Widget _chip(String label, IconData icon, {bool accent = false}) {
    final color = accent ? NeoTheme.primaryRed : NeoTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: accent ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(NeoTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: NeoTheme.labelSmall(context).copyWith(color: color),
          ),
        ],
      ),
    );
  }

  // ── ACTION ROW ────────────────────────────────────────────────────────

  Widget _buildActionRow(Anime anime) {
    final firstEpisode = _firstEpisodeForLanguage(_selectedLanguage);

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: firstEpisode == null
                ? null
                : () => _playEpisode(
                      firstEpisode.$1,
                      firstEpisode.$2,
                      firstEpisode.$2.players,
                    ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: firstEpisode != null
                    ? NeoTheme.heroGradient
                    : null,
                color: firstEpisode == null ? NeoTheme.bgElevated : null,
                borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                boxShadow: firstEpisode != null
                    ? [
                        BoxShadow(
                          color: NeoTheme.primaryRed.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    color: firstEpisode != null
                        ? Colors.white
                        : NeoTheme.textDisabled,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LANCER LA LECTURE',
                    style: NeoTheme.labelLarge(context).copyWith(
                      color: firstEpisode != null
                          ? Colors.white
                          : NeoTheme.textDisabled,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _LibraryButton(
          inLibrary: _inLibrary,
          onToggle: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              if (_inLibrary) {
                await _api.removeAnimeFromLibrary(anime.id);
                if (!mounted) return;
                messenger.showSnackBar(const SnackBar(
                  content: Text('Retiré de votre liste'),
                  backgroundColor: NeoTheme.textSecondary,
                ));
              } else {
                await _api.addAnimeToLibrary(anime.id);
                if (!mounted) return;
                messenger.showSnackBar(const SnackBar(
                  content: Text('Ajouté à votre liste'),
                  backgroundColor: NeoTheme.primaryRed,
                ));
              }
              if (!mounted) return;
              setState(() => _inLibrary = !_inLibrary);
            } catch (_) {
              if (!mounted) return;
              messenger.showSnackBar(const SnackBar(
                content: Text('Erreur'),
                backgroundColor: NeoTheme.errorRed,
              ));
            }
          },
        ),
      ],
    );
  }

  (int, AnimeEpisode)? _firstEpisodeForLanguage(String lang) {
    final keys = _seasonsForLanguage(lang);
    for (final k in keys) {
      final season = _anime!.seasons[k];
      if (season != null && season.episodes.isNotEmpty) {
        return (k, season.episodes.first);
      }
    }
    return null;
  }

  // ── LANGUAGE TABS ─────────────────────────────────────────────────────

  Widget _buildLanguageTabs() {
    final langs = _availableLanguages.toList()
      ..sort((a, b) {
        if (a == 'vf') return -1;
        if (b == 'vf') return 1;
        return 0;
      });

    return Container(
      decoration: BoxDecoration(
        color: NeoTheme.bgElevated,
        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
        border: Border.all(
            color: NeoTheme.bgBorder.withValues(alpha: 0.15), width: 0.5),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: langs.map((lang) {
          final isSelected = _selectedLanguage == lang;
          return Expanded(
            child: GestureDetector(
              onTap: () => _selectLanguage(lang),
              child: AnimatedContainer(
                duration: NeoTheme.durationFast,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected ? NeoTheme.heroGradient : null,
                  borderRadius: BorderRadius.circular(NeoTheme.radiusSm),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: NeoTheme.primaryRed.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Text(
                  lang.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: NeoTheme.labelMedium(context).copyWith(
                    color: isSelected ? Colors.white : NeoTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── SEASON SELECTOR ───────────────────────────────────────────────────

  Widget _buildSeasonSelector(List<int> keys) {
    final useFocus = NeoTheme.needsFocusNavigation(context);
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: keys.length,
        itemBuilder: (context, i) {
          final num = keys[i];
          final season = _anime!.seasons[num];
          final isSelected = _selectedSeason == num;
          final label = (season != null && season.name.isNotEmpty)
              ? season.name
              : 'Saison $num';

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Focus(
              canRequestFocus: useFocus,
              onKeyEvent: useFocus
                  ? (node, event) {
                      if (event is KeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.enter ||
                              event.logicalKey == LogicalKeyboardKey.select ||
                              event.logicalKey == LogicalKeyboardKey.space)) {
                        setState(() => _selectedSeason = num);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    }
                  : null,
              child: Builder(
                builder: (ctx) {
                  final isFocused = Focus.of(ctx).hasFocus;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSeason = num),
                    child: AnimatedContainer(
                      duration: NeoTheme.durationFast,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected ? NeoTheme.heroGradient : null,
                        color: isSelected ? null : NeoTheme.bgElevated,
                        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                        border: Border.all(
                          color: (isFocused || isSelected)
                              ? NeoTheme.primaryRed
                              : NeoTheme.bgBorder.withValues(alpha: 0.2),
                          width: isFocused ? 2 : 1,
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color:
                                      NeoTheme.primaryRed.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        label,
                        style: NeoTheme.labelMedium(context).copyWith(
                          color: (isSelected || isFocused)
                              ? Colors.white
                              : NeoTheme.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ── EPISODE CARD ──────────────────────────────────────────────────────

  Widget _buildEpisodeCard(AnimeEpisode episode, int seasonNumber) {
    final useFocus = NeoTheme.needsFocusNavigation(context);
    final sources = episode.players;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Focus(
        canRequestFocus: useFocus,
        onKeyEvent: useFocus
            ? (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.select ||
                        event.logicalKey == LogicalKeyboardKey.space)) {
                  _playEpisode(seasonNumber, episode, sources);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              }
            : null,
        child: Builder(
          builder: (ctx) {
            final isFocused = Focus.of(ctx).hasFocus;
            return GestureDetector(
              onTap: () => _playEpisode(seasonNumber, episode, sources),
              child: AnimatedContainer(
                duration: NeoTheme.durationFast,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: isFocused
                      ? LinearGradient(
                          colors: [
                            NeoTheme.primaryRed.withValues(alpha: 0.15),
                            NeoTheme.bgElevated,
                          ],
                        )
                      : NeoTheme.surfaceGradient,
                  borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                  border: Border.all(
                    color: isFocused
                        ? NeoTheme.primaryRed
                        : NeoTheme.bgBorder.withValues(alpha: 0.12),
                    width: isFocused ? 1.5 : 0.5,
                  ),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: NeoTheme.primaryRed.withValues(alpha: 0.25),
                            blurRadius: 16,
                            spreadRadius: 1,
                          )
                        ]
                      : NeoTheme.shadowLevel1,
                ),
                child: Row(
                  children: [
                    // Episode number badge
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: NeoTheme.heroGradient,
                        borderRadius: BorderRadius.circular(NeoTheme.radiusSm),
                      ),
                      child: Center(
                        child: Text(
                          '${episode.episodeNumber}',
                          style: NeoTheme.titleMedium(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title + meta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            episode.title.isNotEmpty
                                ? episode.title
                                : 'Épisode ${episode.episodeNumber}',
                            style: NeoTheme.labelLarge(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: NeoTheme.primaryRed
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _selectedLanguage.toUpperCase(),
                                  style: NeoTheme.labelSmall(context).copyWith(
                                    color: NeoTheme.primaryRed,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${sources.length} source${sources.length > 1 ? 's' : ''}',
                                style: NeoTheme.labelSmall(context)
                                    .copyWith(color: NeoTheme.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Play icon
                    Icon(
                      Icons.play_circle_fill_rounded,
                      color: isFocused
                          ? NeoTheme.primaryRed
                          : NeoTheme.primaryRed.withValues(alpha: 0.6),
                      size: 34,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── SKELETON ──────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return Scaffold(
      backgroundColor: NeoTheme.bgBase,
      body: Column(
        children: [
          Container(height: 320, color: NeoTheme.bgElevated),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBox(200, 28),
                const SizedBox(height: 10),
                _skeletonBox(140, 16),
                const SizedBox(height: 20),
                _skeletonBox(double.infinity, 48),
                const SizedBox(height: 16),
                ...List.generate(
                    4,
                    (_) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _skeletonBox(double.infinity, 72),
                        )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonBox(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: NeoTheme.bgElevated,
        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
      ),
    );
  }
}

// ── EXPANDABLE SYNOPSIS ───────────────────────────────────────────────────────

class _ExpandableSynopsis extends StatefulWidget {
  final String synopsis;
  const _ExpandableSynopsis({required this.synopsis});

  @override
  State<_ExpandableSynopsis> createState() => _ExpandableSynopsisState();
}

class _ExpandableSynopsisState extends State<_ExpandableSynopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.synopsis,
          style: NeoTheme.bodyMedium(context)
              .copyWith(color: NeoTheme.textSecondary, height: 1.55),
          maxLines: _expanded ? null : 3,
          overflow: _expanded ? null : TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? 'Voir moins' : 'Voir plus',
            style: NeoTheme.labelSmall(context).copyWith(
              color: NeoTheme.primaryRed,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── LIBRARY BUTTON ────────────────────────────────────────────────────────────

class _LibraryButton extends StatelessWidget {
  final bool inLibrary;
  final VoidCallback onToggle;

  const _LibraryButton({required this.inLibrary, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NeoTheme.bgElevated,
        shape: BoxShape.circle,
        border: Border.all(
            color: NeoTheme.bgBorder.withValues(alpha: 0.15), width: 0.5),
      ),
      child: IconButton(
        onPressed: onToggle,
        icon: Icon(
          inLibrary ? Icons.check_rounded : Icons.add_rounded,
          color: inLibrary ? NeoTheme.primaryRed : NeoTheme.textPrimary,
        ),
        tooltip: inLibrary ? 'Dans ma liste' : 'Ajouter à ma liste',
      ),
    );
  }
}
