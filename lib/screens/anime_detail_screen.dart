import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/anime.dart';
import '../services/api_service.dart';
import '../widgets/shimmer_loading.dart';
import 'anime_player_screen.dart';

class AnimeDetailScreen extends StatefulWidget {
  final int animeId;

  const AnimeDetailScreen({super.key, required this.animeId});

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen> {
  final ApiService _api = ApiService();
  
  Anime? _anime;
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedSeason = 1;
  bool _inLibrary = false;
  List<int> _validSeasonKeys = [];

  @override
  void initState() {
    super.initState();
    _loadAnime();
  }

  Future<void> _loadAnime() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _api.getAnimeDetail(widget.animeId);
      
      // Vérifier que la réponse contient bien les données anime
      if (data == null || data['anime'] == null) {
        throw Exception('Données anime non disponibles');
      }
      
      final animeData = data['anime'];
      if (animeData is! Map<String, dynamic>) {
        throw Exception('Format de données anime invalide');
      }
      
      final anime = Anime.fromJson(animeData);
      
      // Vérifier si l'anime est dans la bibliothèque
      bool inLibrary = false;
      try {
        final libraryStatus = await _api.checkAnimeInLibrary(anime.id);
        inLibrary = libraryStatus;
      } catch (e) {
        debugPrint('[AnimeDetailScreen] Erreur vérification bibliothèque: $e');
      }

      if (!mounted) return;

      // Build list of season keys that have episodes
      final validKeys = anime.seasons.entries
          .where((e) => e.value.episodes.isNotEmpty)
          .map((e) => e.key)
          .toList();
      validKeys.sort();

      setState(() {
        _anime = anime;
        _inLibrary = inLibrary;
        _validSeasonKeys = validKeys;
        _selectedSeason = validKeys.isNotEmpty ? validKeys.first : 1;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('[AnimeDetailScreen] Erreur: $error');
      
      if (!mounted) return;
      
      setState(() {
        _errorMessage = humanizeApiError(error);
        _isLoading = false;
      });
    }
  }

  void _playEpisode(int seasonNumber, AnimeEpisode episode, List<Map<String, String>> sources) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnimePlayerScreen(
          anime: _anime!,
          seasonNumber: seasonNumber,
          episode: episode,
          sources: sources,
        ),
      ),
    ).then((_) {
      if (mounted) _loadAnime();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: NeoTheme.bgBase,
        body: const Center(child: ShimmerHomeLoading()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: NeoTheme.bgBase,
        appBar: AppBar(
          backgroundColor: NeoTheme.bgBase,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: NeoTheme.errorRed),
                const SizedBox(height: 16),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadAnime,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final anime = _anime!;
    final season = anime.seasons[_selectedSeason];

    return Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack ||
              event.logicalKey == LogicalKeyboardKey.browserBack) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
      backgroundColor: NeoTheme.bgBase,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: NeoTheme.bgBase,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (anime.posterUrl != null)
                    Image.network(
                      anime.posterUrl!,
                      fit: BoxFit.cover,
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          NeoTheme.bgBase,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: NeoTheme.screenPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime.title,
                    style: NeoTheme.displayLarge(context),
                  ),
                  if (anime.titleAlt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      anime.titleAlt!,
                      style: NeoTheme.bodyMedium(context)
                          .copyWith(color: NeoTheme.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Afficher les genres séparés par des virgules
                  if (anime.genres.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip(
                          '${anime.totalEpisodes} épisodes',
                          Icons.play_circle_outline,
                        ),
                        _buildInfoChip(
                          '${anime.totalSeasons} saisons',
                          Icons.tv,
                        ),
                        _buildInfoChip(
                          anime.genres.join(', '),
                          Icons.category_outlined,
                        ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip(
                          '${anime.totalEpisodes} épisodes',
                          Icons.play_circle_outline,
                        ),
                        _buildInfoChip(
                          '${anime.totalSeasons} saisons',
                          Icons.tv,
                        ),
                      ],
                    ),
                  if (anime.synopsis != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Synopsis',
                      style: NeoTheme.titleMedium(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      anime.synopsis!,
                      style: NeoTheme.bodyMedium(context)
                          .copyWith(color: NeoTheme.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Bouton favoris
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: NeoTheme.heroGradient,
                            borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                            boxShadow: [
                              BoxShadow(
                                color: NeoTheme.primaryRed.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                // Action pour lancer la lecture du premier épisode
                                if (anime.seasons.isNotEmpty) {
                                  final firstSeason = anime.seasons[1];
                                  if (firstSeason != null && firstSeason.episodes.isNotEmpty) {
                                    _playEpisode(1, firstSeason.episodes[0], firstSeason.episodes[0].players);
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                                    const SizedBox(width: 8),
                                    Text(
                                      'LANCER LA LECTURE',
                                      style: NeoTheme.labelLarge(context).copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: NeoTheme.bgOverlay.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: NeoTheme.bgBorder.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                        child: IconButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              if (_inLibrary) {
                                await _api.removeAnimeFromLibrary(anime.id);
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Retiré de votre liste'),
                                    backgroundColor: NeoTheme.textSecondary,
                                  ),
                                );
                              } else {
                                await _api.addAnimeToLibrary(anime.id);
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Ajouté à votre liste'),
                                    backgroundColor: NeoTheme.primaryRed,
                                  ),
                                );
                              }
                              if (!mounted) return;
                              setState(() {
                                _inLibrary = !_inLibrary;
                              });
                            } catch (_) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Erreur'),
                                  backgroundColor: NeoTheme.errorRed,
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            _inLibrary ? Icons.check : Icons.add,
                            color: _inLibrary ? NeoTheme.primaryRed : NeoTheme.textPrimary,
                          ),
                          tooltip: _inLibrary ? 'Dans ma liste' : 'Ajouter à ma liste',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_validSeasonKeys.isNotEmpty) ...[
                    _buildSeasonSelector(),
                    const SizedBox(height: 16),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NeoTheme.warningOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                        border: Border.all(
                          color: NeoTheme.warningOrange.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: NeoTheme.warningOrange, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Les épisodes de cet anime ne sont pas encore disponibles.',
                              style: NeoTheme.bodySmall(context)
                                  .copyWith(color: NeoTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
          if (season != null && season.episodes.isNotEmpty)
            SliverPadding(
              padding: NeoTheme.screenPadding(context),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final episode = season.episodes[index];
                    return _buildEpisodeCard(episode, _selectedSeason);
                  },
                  childCount: season.episodes.length,
                ),
              ),
            )
          else if (season != null && season.episodes.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: NeoTheme.screenPadding(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: NeoTheme.warningOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                    border: Border.all(
                      color: NeoTheme.warningOrange.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: NeoTheme.warningOrange, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Aucun épisode disponible pour cette saison.',
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
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: NeoTheme.bgElevated,
        borderRadius: BorderRadius.circular(NeoTheme.radiusSm),
        border: Border.all(
          color: NeoTheme.bgBorder.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: NeoTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: NeoTheme.labelSmall(context)
                .copyWith(color: NeoTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonSelector() {
    final useFocus = NeoTheme.needsFocusNavigation(context);
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _validSeasonKeys.length,
        itemBuilder: (context, index) {
          final seasonNum = _validSeasonKeys[index];
          final season = _anime!.seasons[seasonNum];
          final isSelected = _selectedSeason == seasonNum;
          final seasonLabel = (season != null && season.name.isNotEmpty)
              ? season.name
              : 'Saison $seasonNum';
          
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Focus(
              canRequestFocus: useFocus,
              onKeyEvent: useFocus
                  ? (node, event) {
                      if (event is KeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.enter ||
                           event.logicalKey == LogicalKeyboardKey.select ||
                           event.logicalKey == LogicalKeyboardKey.space)) {
                        setState(() => _selectedSeason = seasonNum);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    }
                  : null,
              child: Builder(
                builder: (ctx) {
                  final isFocused = Focus.of(ctx).hasFocus;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSeason = seasonNum),
                    child: AnimatedContainer(
                      duration: NeoTheme.durationFast,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: isSelected ? NeoTheme.heroGradient : null,
                        color: isSelected ? null : NeoTheme.bgElevated,
                        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                        border: Border.all(
                          color: isFocused
                              ? NeoTheme.primaryRed
                              : (isSelected
                                  ? NeoTheme.primaryRed
                                  : NeoTheme.bgBorder.withValues(alpha: 0.3)),
                          width: isFocused ? 2.5 : (isSelected ? 2 : 1),
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: NeoTheme.primaryRed.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          seasonLabel,
                          style: NeoTheme.labelMedium(context).copyWith(
                            color: (isFocused || isSelected) ? Colors.white : NeoTheme.textSecondary,
                            fontWeight: (isFocused || isSelected) ? FontWeight.bold : FontWeight.normal,
                          ),
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

  Widget _buildEpisodeCard(AnimeEpisode episode, int seasonNumber) {
    final useFocus = NeoTheme.needsFocusNavigation(context);
    final sources = episode.players;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: NeoTheme.surfaceGradient,
                  borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                  border: Border.all(
                    color: isFocused
                        ? NeoTheme.primaryRed
                        : NeoTheme.bgBorder.withValues(alpha: 0.15),
                    width: isFocused ? 2 : 0.5,
                  ),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: NeoTheme.primaryRed.withValues(alpha: 0.35),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: NeoTheme.heroGradient,
                        borderRadius: BorderRadius.circular(NeoTheme.radiusSm),
                      ),
                      child: Center(
                        child: Text(
                          '${episode.episodeNumber}',
                          style: NeoTheme.titleMedium(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
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
                          Text(
                            '${_anime?.seasons[seasonNumber]?.name ?? 'Saison $seasonNumber'} • ${sources.length} source${sources.length > 1 ? 's' : ''}',
                            style: NeoTheme.labelSmall(context)
                                .copyWith(color: NeoTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.play_circle_filled,
                      color: NeoTheme.primaryRed,
                      size: 32,
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
}
