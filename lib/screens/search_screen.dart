import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../config/theme.dart';
import '../models/content.dart';
import '../models/anime.dart';
import '../services/api_service.dart';
import '../widgets/content_card.dart';
import '../widgets/section_header.dart';
import 'detail_screen.dart';
import 'anime_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Content> _results = [];
  List<Anime> _animeResults = [];
  bool _isLoading = false;
  String _lastQuery = '';
  String _filterType = 'all';
  String? _errorMessage;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    setState(() {});

    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (query.trim().length >= 2 && query != _lastQuery) {
        _performSearch(query.trim());
      } else if (query.trim().isEmpty) {
        setState(() {
          _results = [];
          _animeResults = [];
          _lastQuery = '';
          _filterType = 'all';
          _errorMessage = null;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _lastQuery = query;
      _filterType = 'all';
      _errorMessage = null;
    });

    try {
      final results = await _api.searchContent(query);
      
      debugPrint('[SearchScreen] Résultats de recherche: ${results.length}');
      
      // Séparer les animes des autres contenus
      final contentResults = <Content>[];
      final animeResults = <Anime>[];
      
      for (final item in results) {
        debugPrint('[SearchScreen] Item: ${item.title} (${item.contentType})');
        
        if (item.contentType == 'anime') {
          // Convertir en Anime
          try {
            animeResults.add(Anime(
              id: item.id,
              animeId: item.id.toString(),
              url: '',
              title: item.title,
              titleAlt: null,
              synopsis: item.description,
              genres: item.genres,
              posterUrl: item.fullPosterUrl,
              seasons: {},
              totalSeasons: item.seasonCount,
              totalEpisodes: item.episodeCount,
            ));
          } catch (e) {
            debugPrint('[SearchScreen] Erreur conversion anime: $e');
          }
        } else {
          contentResults.add(item);
        }
      }
      
      debugPrint('[SearchScreen] Films/Séries: ${contentResults.length}, Animes: ${animeResults.length}');
      
      setState(() {
        _results = contentResults.where((c) => c.hasPoster).toList();
        _animeResults = animeResults.where((a) => a.hasPoster).toList();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      debugPrint('[SearchScreen] Erreur de recherche: $error');
      setState(() {
        _results = [];
        _animeResults = [];
        _isLoading = false;
        _errorMessage = humanizeApiError(error);
      });
    }
  }

  List<Content> get _filteredResults {
    if (_filterType == 'all') return _results;
    if (_filterType == 'film')
      return _results.where((content) => content.isFilm).toList();
    if (_filterType == 'serie')
      return _results.where((content) => content.isSerie).toList();
    return _results
        .where((content) => content.contentType == _filterType)
        .toList();
  }
  
  List<Anime> get _filteredAnimeResults {
    if (_filterType == 'all' || _filterType == 'anime') return _animeResults;
    return [];
  }

  void _navigateToDetail(Content content) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(contentId: content.id)),
    );
  }
  
  void _navigateToAnimeDetail(Anime anime) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnimeDetailScreen(animeId: anime.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredResults = _filteredResults;
    final filteredAnimeResults = _filteredAnimeResults;
    final filmCount = _results.where((content) => content.isFilm).length;
    final serieCount = _results.where((content) => content.isSerie).length;
    final animeCount = _animeResults.length;
    final useGrid = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: NeoTheme.bgBase,
      body: SafeArea(
        top: !NeoTheme.isTV(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                NeoTheme.screenPadding(context).left,
                8,
                NeoTheme.screenPadding(context).right,
                8,
              ),
              child: Semantics(
                label: 'Champ de recherche',
                hint: 'Entrez un titre, genre, acteur ou mot-clé',
                textField: true,
                child: Focus(
                  child: Builder(
                    builder: (context) {
                      final isFocused = Focus.of(context).hasFocus;
                      return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF16163A), Color(0xFF0A0A18)],
                        ),
                        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                        border: Border.all(
                          color: isFocused ? NeoTheme.primaryRed : NeoTheme.primaryRed.withValues(alpha: 0.15),
                          width: isFocused ? 2 : 0.5,
                        ),
                        boxShadow: isFocused ? [
                          BoxShadow(
                            color: NeoTheme.primaryRed.withValues(alpha: 0.3),
                            blurRadius: 12,
                          )
                        ] : NeoTheme.shadowLevel2,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: NeoTheme.primaryRed.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: NeoTheme.primaryRed,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              autofocus: !NeoTheme.isTV(context),
                              style: NeoTheme.bodyLarge(
                                context,
                              ).copyWith(color: NeoTheme.textPrimary),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Titre, genre, acteur, mot-cle...',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                hintStyle: NeoTheme.bodyMedium(
                                  context,
                                ).copyWith(color: NeoTheme.textDisabled),
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _results = [];
                                  _lastQuery = '';
                                  _filterType = 'all';
                                  _errorMessage = null;
                                });
                              },
                              icon: const Icon(Icons.close_rounded),
                              color: NeoTheme.textTertiary,
                            ),
                        ],
                      ),
                    );
                  }
                ),
              ),
            ),
            ),
            const SizedBox(height: 4),
            SectionHeader(
              title: _lastQuery.isEmpty
                  ? 'Recherche'
                  : 'Resultats pour "$_lastQuery"',
              subtitle: _lastQuery.isEmpty
                  ? 'Lancez une recherche pour explorer rapidement le catalogue.'
                  : '${filteredResults.length + filteredAnimeResults.length} contenu${(filteredResults.length + filteredAnimeResults.length) > 1 ? 's' : ''} affiches',
              icon: Icons.manage_search_rounded,
              padding: NeoTheme.screenPadding(context),
            ),
            if (_results.isNotEmpty || _animeResults.isNotEmpty) ...[
              const SizedBox(height: 4),
              SizedBox(
                height: NeoTheme.chipHeight(context),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: NeoTheme.screenPadding(context),
                  children: [
                    _buildFilterChip('Tous', 'all', _results.length + _animeResults.length),
                    const SizedBox(width: 8),
                    _buildFilterChip('Films', 'film', filmCount),
                    const SizedBox(width: 8),
                    _buildFilterChip('Séries', 'serie', serieCount),
                    if (animeCount > 0) ...[
                      const SizedBox(width: 8),
                      _buildFilterChip('Anime', 'anime', animeCount),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Expanded(
              child: _isLoading
                  ? _buildSearchShimmer(context)
                  : (filteredResults.isEmpty && filteredAnimeResults.isEmpty)
                  ? _buildEmptyState(context)
                  : (useGrid || NeoTheme.isTV(context))
                  ? GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                        NeoTheme.screenPadding(context).left,
                        20,
                        NeoTheme.screenPadding(context).right,
                        100,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: NeoTheme.gridColumns(context),
                        childAspectRatio: NeoTheme.isMobile(context) ? 2.5 : 0.65,
                        crossAxisSpacing: NeoTheme.gridSpacing(context),
                        mainAxisSpacing: NeoTheme.gridSpacing(context),
                      ),
                      itemCount: filteredResults.length + filteredAnimeResults.length,
                      itemBuilder: (context, index) {
                        // Afficher d'abord les contenus normaux, puis les animes
                        if (index < filteredResults.length) {
                          final content = filteredResults[index];
                          return Semantics(
                            label: '${content.displayTitle}, ${content.isSerie ? 'Série' : 'Film'}',
                            hint: 'Appuyez pour voir les détails',
                            button: true,
                            enabled: true,
                            child: ContentCard(
                              content: content,
                              variant: NeoTheme.isTV(context)
                                  ? CardVariant.standard
                                  : CardVariant.search,
                              index: index,
                              onTap: () => _navigateToDetail(content),
                            ),
                          );
                        } else {
                          final animeIndex = index - filteredResults.length;
                          final anime = filteredAnimeResults[animeIndex];
                          // Convertir Anime en Content pour utiliser ContentCard
                          final content = Content(
                            id: anime.id,
                            title: anime.title,
                            description: anime.synopsis,
                            contentType: 'anime',
                            genres: anime.genres,
                            rating: 0,
                            releaseDate: null,
                            poster: anime.posterUrl,
                            keywords: [],
                            watchLinks: [],
                            createdAt: null,
                          );
                          return Semantics(
                            label: '${anime.title}, Anime',
                            hint: 'Appuyez pour voir les détails',
                            button: true,
                            enabled: true,
                            child: ContentCard(
                              content: content,
                              variant: NeoTheme.isTV(context)
                                  ? CardVariant.standard
                                  : CardVariant.search,
                              index: index,
                              onTap: () => _navigateToAnimeDetail(anime),
                            ),
                          );
                        }
                      },
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        NeoTheme.screenPadding(context).left,
                        0,
                        NeoTheme.screenPadding(context).right,
                        100,
                      ),
                      itemCount: filteredResults.length + filteredAnimeResults.length,
                      itemBuilder: (context, index) {
                        if (index < filteredResults.length) {
                          final content = filteredResults[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Semantics(
                              label: '${content.displayTitle}, ${content.isSerie ? 'Série' : 'Film'}',
                              hint: 'Appuyez pour voir les détails',
                              button: true,
                              enabled: true,
                              child: ContentCard(
                                content: content,
                                variant: CardVariant.search,
                                index: index,
                                onTap: () => _navigateToDetail(content),
                              ),
                            ),
                          );
                        } else {
                          final animeIndex = index - filteredResults.length;
                          final anime = filteredAnimeResults[animeIndex];
                          final content = Content(
                            id: anime.id,
                            title: anime.title,
                            description: anime.synopsis,
                            contentType: 'anime',
                            genres: anime.genres,
                            rating: 0,
                            releaseDate: null,
                            poster: anime.posterUrl,
                            keywords: [],
                            watchLinks: [],
                            createdAt: null,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Semantics(
                              label: '${anime.title}, Anime',
                              hint: 'Appuyez pour voir les détails',
                              button: true,
                              enabled: true,
                              child: ContentCard(
                                content: content,
                                variant: CardVariant.search,
                                index: index,
                                onTap: () => _navigateToAnimeDetail(anime),
                              ),
                            ),
                          );
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String type, int count) {
    final selected = _filterType == type;

    return Semantics(
      label: '$label, $count résultats',
      hint: 'Appuyez pour filtrer',
      button: true,
      selected: selected,
      child: Focus(
        child: Builder(
          builder: (context) {
            final isFocused = Focus.of(context).hasFocus;
            return ChoiceChip(
              label: Text('$label ($count)'),
              selected: selected,
              onSelected: (_) => setState(() => _filterType = type),
              selectedColor: NeoTheme.primaryRed,
              backgroundColor: isFocused
                  ? NeoTheme.primaryRed.withValues(alpha: 0.18)
                  : NeoTheme.bgElevated.withValues(alpha: 0.7),
              labelStyle: NeoTheme.labelMedium(context).copyWith(
                color: selected || isFocused
                    ? Colors.white
                    : NeoTheme.textSecondary,
              ),
              side: BorderSide(
                color: isFocused
                    ? Colors.white
                    : (selected
                          ? NeoTheme.primaryRed.withValues(alpha: 0.6)
                          : NeoTheme.bgBorder.withValues(alpha: 0.12)),
                width: isFocused ? 2 : 0.5,
              ),
              showCheckmark: false,
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchShimmer(BuildContext context) {
    final columns = NeoTheme.gridColumns(context);
    final useGrid = MediaQuery.of(context).size.width >= 900 || NeoTheme.isTV(context);

    if (useGrid) {
      return GridView.builder(
        padding: EdgeInsets.fromLTRB(
          NeoTheme.screenPadding(context).left,
          0,
          NeoTheme.screenPadding(context).right,
          100,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: NeoTheme.isMobile(context) ? 2.5 : 0.65,
          crossAxisSpacing: NeoTheme.gridSpacing(context),
          mainAxisSpacing: NeoTheme.gridSpacing(context),
        ),
        itemCount: columns * 3,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: NeoTheme.bgElevated,
          highlightColor: NeoTheme.bgBorder.withValues(alpha: 0.3),
          child: Container(
            decoration: BoxDecoration(
              color: NeoTheme.bgElevated,
              borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        NeoTheme.screenPadding(context).left,
        0,
        NeoTheme.screenPadding(context).right,
        100,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Shimmer.fromColors(
          baseColor: NeoTheme.bgElevated,
          highlightColor: NeoTheme.bgBorder.withValues(alpha: 0.3),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: NeoTheme.bgElevated,
              borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final hasQuery = _lastQuery.isNotEmpty;

    return SingleChildScrollView(
      child: Padding(
        padding: NeoTheme.screenPadding(context).copyWith(top: 32, bottom: 32),
        child: Center(
          child: Container(
            padding: NeoTheme.contentPadding(context),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF16163A), Color(0xFF0A0A18)],
              ),
              borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
              border: Border.all(
                color: NeoTheme.textTertiary.withValues(alpha: 0.15),
                width: 0.5,
              ),
              boxShadow: NeoTheme.shadowLevel2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasQuery
                      ? Icons.search_off_rounded
                      : Icons.travel_explore_rounded,
                  size: 56 * NeoTheme.scaleFactor(context),
                  color: NeoTheme.textDisabled,
                ),
                const SizedBox(height: 18),
                Text(
                  hasQuery
                      ? (_errorMessage != null
                            ? 'Recherche indisponible'
                            : 'Aucun resultat pour "$_lastQuery"')
                      : 'Rechercher un film ou une serie',
                  style: NeoTheme.titleLarge(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ??
                      (hasQuery
                          ? 'Essayez une autre orthographe ou un mot-cle plus large.'
                          : 'Exemple: thriller, animation, serie coreenne...'),
                  style: NeoTheme.bodyMedium(context),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
