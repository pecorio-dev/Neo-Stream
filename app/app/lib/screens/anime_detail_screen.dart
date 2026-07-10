import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../config/neo.dart';
import '../models/anime.dart';
import '../services/api_service.dart';
import 'anime_player_screen.dart';

class AnimeDetailScreen extends StatefulWidget {
  final int animeId;

  AnimeDetailScreen({super.key, required this.animeId});

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
      duration: Duration(milliseconds: 400),
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
        backgroundColor: Neo.bgBase(context),
        appBar: AppBar(backgroundColor: Neo.bgBase(context), elevation: 0),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: NeoTheme.errorRed),
                SizedBox(height: 16),
                Text(_errorMessage!, textAlign: TextAlign.center),
                SizedBox(height: 24),
                ElevatedButton(onPressed: _loadAnime, child: Text('Réessayer')),
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
        backgroundColor: Neo.bgBase(context),
        body: FadeTransition(
          opacity: _fadeCtrl,
          child: CustomScrollView(
            physics: BouncingScrollPhysics(),
            slivers: [
              _buildHero(anime),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleSection(anime),
                      SizedBox(height: 24),
                      _buildActionRow(anime),
                      SizedBox(height: 28),
                      if (_availableLanguages.length > 1) ...[
                        _buildLanguageTabs(),
                        SizedBox(height: 20),
                      ],
                      if (seasonKeys.isNotEmpty) ...[
                        _buildSeasonSelector(seasonKeys),
                        SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ),
              if (season != null && season.episodes.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 40),
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
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Neo.bgElevated(context),
                        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                        border: Border.all(
                            color: Neo.bgBorder(context).withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Neo.textSecondary(context), size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _availableLanguages.isEmpty
                                  ? 'Les épisodes ne sont pas encore disponibles.'
                                  : 'Aucun épisode pour cette langue / saison.',
                              style: Neo.bodySmall(context)
                                  .copyWith(color: Neo.textSecondary(context)),
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
      expandedHeight: 380,
      pinned: true,
      backgroundColor: Neo.bgBase(context),
      elevation: 0,
      leading: Padding(
        padding: EdgeInsets.all(8),
        child: IconButton(
          icon: Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12, width: 0.5),
            ),
            child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
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
              ClipRect(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: CachedNetworkImage(
                    imageUrl: anime.posterUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: Neo.bgElevated(context)),
                    errorWidget: (_, _, _) => Container(color: Neo.bgElevated(context)),
                  ),
                ),
              ),
            // Dark gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.65),
                    Neo.bgBase(context),
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
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                        border: Border.all(color: Colors.white24, width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(NeoTheme.radiusMd - 1.0),
                        child: CachedNetworkImage(
                          imageUrl: anime.posterUrl!,
                          width: 92,
                          height: 132,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (anime.genres.isNotEmpty) ...[
                          Builder(
                            builder: (context) {
                              final primaryGenre = anime.genres.first;
                              final genreColor = NeoTheme.getGenreColor(primaryGenre);
                              return Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: genreColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: genreColor.withValues(alpha: 0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  primaryGenre.toUpperCase(),
                                  style: Neo.labelSmall(context).copyWith(
                                    color: genreColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 9,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 8),
                        ],
                        Text(
                          anime.title,
                          style: Neo.headlineLarge(context).copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                            shadows: [
                              Shadow(
                                  color: Colors.black, blurRadius: 10, offset: Offset(0, 2))
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (anime.titleAlt != null && anime.titleAlt!.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            anime.titleAlt!,
                            style: Neo.bodySmall(context).copyWith(
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
        if (anime.genres.isNotEmpty) ...[
          SizedBox(height: 14),
          _buildGenreChips(context, anime.genres),
        ],
        if (anime.synopsis != null && anime.synopsis!.isNotEmpty) ...[
          SizedBox(height: 16),
          _ExpandableSynopsis(synopsis: anime.synopsis!),
        ],
      ],
    );
  }

  Widget _buildGenreChips(BuildContext context, List<String> genres) {
    return SizedBox(
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: BouncingScrollPhysics(),
        itemCount: genres.length,
        itemBuilder: (context, index) {
          final genre = genres[index];
          final color = NeoTheme.getGenreColor(genre);
          return Container(
            margin: EdgeInsets.only(right: 8),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
            ),
            child: Center(
              child: Text(
                genre,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String label, IconData icon, {bool accent = false}) {
    final color = accent ? NeoTheme.primaryRed : Neo.textSecondary(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: accent ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(NeoTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 5),
          Text(
            label,
            style: Neo.labelSmall(context).copyWith(color: color),
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
          child: _FocusablePlayButton(
            canPlay: firstEpisode != null,
            label: 'LANCER LA LECTURE',
            onPlay: () {
              if (firstEpisode != null) {
                _playEpisode(
                  firstEpisode.$1,
                  firstEpisode.$2,
                  firstEpisode.$2.players,
                );
              }
            },
          ),
        ),
        SizedBox(width: 12),
        _FocusableActionIconButton(
          isActive: _inLibrary,
          activeIcon: Icons.check_rounded,
          inactiveIcon: Icons.add_rounded,
          activeColor: NeoTheme.primaryRed,
          tooltip: _inLibrary ? 'Dans ma liste' : 'Ajouter à ma liste',
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              if (_inLibrary) {
                await _api.removeAnimeFromLibrary(anime.id);
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(
                  content: Text('Retiré de votre liste'),
                  backgroundColor: Neo.textSecondary(context),
                ));
              } else {
                await _api.addAnimeToLibrary(anime.id);
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(
                  content: Text('Ajouté à votre liste'),
                  backgroundColor: NeoTheme.primaryRed,
                ));
              }
              if (!mounted) return;
              setState(() => _inLibrary = !_inLibrary);
            } catch (_) {
              if (!mounted) return;
              messenger.showSnackBar(SnackBar(
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
        color: Neo.bgElevated(context),
        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
        border: Border.all(
            color: Neo.bgBorder(context).withValues(alpha: 0.15), width: 0.5),
      ),
      padding: EdgeInsets.all(4),
      child: Row(
        children: langs.map((lang) {
          final isSelected = _selectedLanguage == lang;
          return Expanded(
            child: GestureDetector(
              onTap: () => _selectLanguage(lang),
              child: AnimatedContainer(
                duration: NeoTheme.durationFast,
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected ? NeoTheme.heroGradient : null,
                  borderRadius: BorderRadius.circular(NeoTheme.radiusSm),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: NeoTheme.primaryRed.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Text(
                  lang.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: Neo.labelMedium(context).copyWith(
                    color: isSelected ? Colors.white : Neo.textSecondary(context),
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
            padding: EdgeInsets.only(right: 10),
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
                      padding: EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected ? NeoTheme.heroGradient : null,
                        color: isSelected ? null : Neo.bgElevated(context),
                        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                        border: Border.all(
                          color: (isFocused || isSelected)
                              ? NeoTheme.primaryRed
                              : Neo.bgBorder(context).withValues(alpha: 0.2),
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
                        style: Neo.labelMedium(context).copyWith(
                          color: (isSelected || isFocused)
                              ? Colors.white
                              : Neo.textSecondary(context),
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

    return Focus(
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
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: isFocused
                    ? LinearGradient(
                        colors: [
                          NeoTheme.primaryRed.withValues(alpha: 0.15),
                          Neo.bgElevated(context),
                        ],
                      )
                    : Neo.surfaceGradient,
                borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                border: Border.all(
                  color: isFocused
                      ? NeoTheme.primaryRed
                      : Neo.bgBorder(context).withValues(alpha: 0.15),
                  width: isFocused ? 1.5 : 0.8,
                ),
                boxShadow: [
                  ...NeoTheme.shadowLevel1,
                  if (isFocused)
                    BoxShadow(
                      color: NeoTheme.primaryRed.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 1,
                    )
                ],
              ),
              child: Row(
                children: [
                  // Episode number badge
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          NeoTheme.primaryRed.withValues(alpha: 0.15),
                          Neo.bgElevated(context),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                      border: Border.all(
                        color: NeoTheme.primaryRed.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'E${episode.episodeNumber}',
                        style: Neo.titleMedium(context).copyWith(
                          color: NeoTheme.primaryRed,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 14),
                  // Title + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode.title.isNotEmpty
                              ? episode.title
                              : 'Épisode ${episode.episodeNumber}',
                          style: Neo.labelLarge(context).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: NeoTheme.primaryRed
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _selectedLanguage.toUpperCase(),
                                style: Neo.labelSmall(context).copyWith(
                                  color: NeoTheme.primaryRed,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '${sources.length} source${sources.length > 1 ? 's' : ''}',
                              style: Neo.bodySmall(context)
                                  .copyWith(color: Neo.textSecondary(context)),
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
    );
  }

  // ── SKELETON ──────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return Scaffold(
      backgroundColor: Neo.bgBase(context),
      body: Column(
        children: [
          Container(height: 320, color: Neo.bgElevated(context)),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBox(200, 28),
                SizedBox(height: 10),
                _skeletonBox(140, 16),
                SizedBox(height: 20),
                _skeletonBox(double.infinity, 48),
                SizedBox(height: 16),
                ...List.generate(
                    4,
                    (_) => Padding(
                          padding: EdgeInsets.only(bottom: 10),
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
        color: Neo.bgElevated(context),
        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
      ),
    );
  }
}

// ── EXPANDABLE SYNOPSIS ───────────────────────────────────────────────────────

class _ExpandableSynopsis extends StatefulWidget {
  final String synopsis;
  _ExpandableSynopsis({required this.synopsis});

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
          style: Neo.bodyLarge(context)
              .copyWith(color: Neo.textSecondary(context), height: 1.55),
          maxLines: _expanded ? null : 3,
          overflow: _expanded ? null : TextOverflow.ellipsis,
        ),
        SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? 'Voir moins' : 'Voir plus',
            style: Neo.labelSmall(context).copyWith(
              color: NeoTheme.primaryRed,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── FOCUSABLE PLAY BUTTON ─────────────────────────────────────────────────────

class _FocusablePlayButton extends StatefulWidget {
  final bool canPlay;
  final String label;
  final VoidCallback onPlay;

  _FocusablePlayButton({
    required this.canPlay,
    required this.label,
    required this.onPlay,
  });

  @override
  State<_FocusablePlayButton> createState() => _FocusablePlayButtonState();
}

class _FocusablePlayButtonState extends State<_FocusablePlayButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final useFocus = NeoTheme.needsFocusNavigation(context);
    return Focus(
      autofocus: false,
      canRequestFocus: useFocus,
      onFocusChange: (f) {
        if (_focused != f) setState(() => _focused = f);
      },
      onKeyEvent: useFocus
          ? (node, event) {
              if (widget.canPlay &&
                  event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.space)) {
                widget.onPlay();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            }
          : null,
      child: GestureDetector(
        onTap: widget.canPlay ? widget.onPlay : null,
        child: MouseRegion(
          cursor: widget.canPlay
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: AnimatedScale(
            scale: (_focused && useFocus) ? 1.04 : 1.0,
            duration: NeoTheme.durationFast,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient:
                    widget.canPlay ? NeoTheme.heroGradient : null,
                color: widget.canPlay ? null : Neo.bgElevated(context),
                borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                border: (_focused && useFocus)
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
                boxShadow: widget.canPlay
                    ? [
                        BoxShadow(
                          color: (_focused && useFocus)
                              ? Colors.white.withValues(alpha: 0.3)
                              : NeoTheme.primaryRed.withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    color: widget.canPlay
                        ? Colors.white
                        : Neo.textDisabled(context),
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: Neo.labelLarge(context).copyWith(
                      color: widget.canPlay
                          ? Colors.white
                          : Neo.textDisabled(context),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── FOCUSABLE ACTION ICON BUTTON ─────────────────────────────────────────────

class _FocusableActionIconButton extends StatefulWidget {
  final bool isActive;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final Color activeColor;
  final String tooltip;
  final VoidCallback onTap;

  _FocusableActionIconButton({
    required this.isActive,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.activeColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_FocusableActionIconButton> createState() => _FocusableActionIconButtonState();
}

class _FocusableActionIconButtonState extends State<_FocusableActionIconButton> {
  bool _isFocused = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final useFocus = NeoTheme.needsFocusNavigation(context);
    return Focus(
      canRequestFocus: useFocus,
      onFocusChange: (f) => setState(() => _isFocused = f),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.92 : (_isFocused ? 1.08 : 1.0),
          duration: NeoTheme.durationFast,
          child: AnimatedContainer(
            duration: NeoTheme.durationNormal,
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: widget.isActive 
                  ? widget.activeColor.withValues(alpha: 0.12)
                  : (_isFocused ? Neo.bgActive(context) : Neo.bgElevated(context)),
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.isActive 
                    ? widget.activeColor.withValues(alpha: 0.5)
                    : (_isFocused ? widget.activeColor : Neo.bgBorder(context).withValues(alpha: 0.25)),
                width: _isFocused ? 2.0 : 1.0,
              ),
              boxShadow: [
                if (widget.isActive || _isFocused)
                  BoxShadow(
                    color: widget.activeColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
              ],
            ),
            child: Center(
              child: AnimatedRotation(
                turns: widget.isActive ? 1.0 : 0.0,
                duration: NeoTheme.durationNormal,
                child: Icon(
                  widget.isActive ? widget.activeIcon : widget.inactiveIcon,
                  color: widget.isActive ? widget.activeColor : Neo.textPrimary(context),
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
