import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/anime.dart';
import '../services/api_service.dart';
import '../widgets/content_card.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_loading.dart';
import 'anime_detail_screen.dart';

class AnimeScreen extends StatefulWidget {
  const AnimeScreen({super.key});

  @override
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();

  String _selectedGenre = 'all';
  String _sortBy = 'recent';
  int _page = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  int _totalResults = 0;
  List<Anime> _items = [];
  List<Map<String, dynamic>> _genreFacets = [];
  String? _errorMessage;

  final Map<String, String> _sortLabels = {
    'recent': 'Récents',
    'title': 'Titre',
    'episodes': 'Épisodes',
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadContent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 320 &&
        !_isLoading &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _page = 1;
      _errorMessage = null;
    });

    try {
      final data = await _api.getAnimeList(
        page: 1,
        limit: 20,
        genre: _selectedGenre == 'all' ? null : _selectedGenre,
        sort: _sortBy,
      );

      final items = (data['items'] as List? ?? [])
          .map((item) => Anime.fromJson(item as Map<String, dynamic>))
          .where((a) => a.hasPoster)
          .toList();

      final pagination = data['pagination'] as Map<String, dynamic>?;
      final meta = data['meta'] as Map<String, dynamic>?;

      setState(() {
        _items = items;
        _totalResults = pagination?['total'] as int? ?? items.length;
        _hasMore = _page < (pagination?['total_pages'] as int? ?? 1);
        _genreFacets = (meta?['genres'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = humanizeApiError(error);
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoading = true);
    _page++;

    try {
      final data = await _api.getAnimeList(
        page: _page,
        limit: 20,
        genre: _selectedGenre == 'all' ? null : _selectedGenre,
        sort: _sortBy,
      );

      final items = (data['items'] as List? ?? [])
          .map((item) => Anime.fromJson(item as Map<String, dynamic>))
          .where((a) => a.hasPoster)
          .toList();

      final pagination = data['pagination'] as Map<String, dynamic>?;

      setState(() {
        _items.addAll(items);
        _hasMore = _page < (pagination?['total_pages'] as int? ?? 1);
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      setState(() {
        _page = (_page - 1).clamp(1, 1 << 20);
        _isLoading = false;
        _errorMessage = humanizeApiError(error);
      });
    }
  }

  int _gridColumns(BuildContext context) => NeoTheme.gridColumns(context);

  double _gridAspect(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1400) return 0.63;
    if (width >= 1100) return 0.62;
    if (width >= 900) return 0.61;
    if (width >= 700) return 0.6;
    return 0.61;
  }

  void _navigateToDetail(Anime anime) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnimeDetailScreen(animeId: anime.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeoTheme.bgBase,
      body: SafeArea(
        top: !NeoTheme.isTV(context),
        child: RefreshIndicator(
          onRefresh: _loadContent,
          color: NeoTheme.primaryRed,
          backgroundColor: NeoTheme.bgElevated,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                elevation: 0,
                backgroundColor: NeoTheme.bgBase.withValues(alpha: 0.94),
                title: Row(
                  children: [
                    Icon(Icons.animation, color: NeoTheme.primaryRed, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Anime',
                      style: NeoTheme.titleLarge(context)
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(
                      child: Text(
                        '$_totalResults animes',
                        style: NeoTheme.labelMedium(context)
                            .copyWith(color: NeoTheme.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(child: _buildHeroSection(context)),
              SliverToBoxAdapter(child: _buildFiltersPanel(context)),
              if (_errorMessage != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      NeoTheme.screenPadding(context).left,
                      12,
                      NeoTheme.screenPadding(context).right,
                      0,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: NeoTheme.warningOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                        border: Border.all(
                          color: NeoTheme.warningOrange.withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: NeoTheme.warningOrange),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: NeoTheme.bodySmall(context)
                                  .copyWith(color: NeoTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_items.isEmpty && _isLoading)
                SliverPadding(
                  padding: NeoTheme.screenPadding(context),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridColumns(context),
                      childAspectRatio: _gridAspect(context),
                      crossAxisSpacing: NeoTheme.gridSpacing(context),
                      mainAxisSpacing: NeoTheme.gridSpacing(context),
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const ShimmerHomeLoading(),
                      childCount: _gridColumns(context) * 3,
                    ),
                  ),
                )
              else if (_items.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: NeoTheme.screenPadding(context).copyWith(top: 24),
                    child: _buildEmptyState(context),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: _selectedGenre == 'all'
                        ? 'Tous les animes'
                        : 'Genre: $_selectedGenre',
                    subtitle: '$_totalResults anime${_totalResults > 1 ? 's' : ''} disponible${_totalResults > 1 ? 's' : ''}',
                    icon: Icons.grid_view_rounded,
                    padding: EdgeInsets.fromLTRB(
                      NeoTheme.screenPadding(context).left,
                      18,
                      NeoTheme.screenPadding(context).right,
                      0,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    NeoTheme.screenPadding(context).left,
                    0,
                    NeoTheme.screenPadding(context).right,
                    100,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridColumns(context),
                      childAspectRatio: _gridAspect(context),
                      crossAxisSpacing: NeoTheme.gridSpacing(context),
                      mainAxisSpacing: NeoTheme.gridSpacing(context),
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= _items.length) {
                          return const ShimmerHomeLoading();
                        }

                        final anime = _items[index];
                        return _buildAnimeCard(context, anime, index);
                      },
                      childCount: _items.length + (_isLoading && _hasMore ? 6 : 0),
                    ),
                  ),
                ),
                if (_isLoading && _items.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: NeoTheme.primaryRed.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        NeoTheme.screenPadding(context).left,
        12,
        NeoTheme.screenPadding(context).right,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              NeoTheme.primaryRed.withValues(alpha: 0.15),
              NeoTheme.infoCyan.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
          border: Border.all(
            color: NeoTheme.primaryRed.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Découvrez notre collection d\'animes',
              style: NeoTheme.displayLarge(context).copyWith(
                fontSize: NeoTheme.isTV(context) ? 34 : 28,
                height: 1.04,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Plus de 2000 animes avec des milliers d\'épisodes en VF et VOSTFR',
              style: NeoTheme.bodyMedium(context).copyWith(
                color: NeoTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersPanel(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        NeoTheme.screenPadding(context).left,
        18,
        NeoTheme.screenPadding(context).right,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: NeoTheme.surfaceGradient,
          borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
          border: Border.all(
            color: NeoTheme.bgBorder.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtres',
              style: NeoTheme.titleMedium(context)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            _buildSortRow(context),
            if (_genreFacets.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildGenreRow(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSortRow(BuildContext context) {
    final useFocus = NeoTheme.needsFocusNavigation(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _sortLabels.keys.map((sort) {
        final isSelected = _sortBy == sort;
        return Focus(
          canRequestFocus: useFocus,
          onKeyEvent: useFocus
              ? (node, event) {
                  if (event is KeyDownEvent &&
                      (event.logicalKey == LogicalKeyboardKey.enter ||
                       event.logicalKey == LogicalKeyboardKey.select ||
                       event.logicalKey == LogicalKeyboardKey.space)) {
                    setState(() => _sortBy = sort);
                    _loadContent();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                }
              : null,
          child: Builder(
            builder: (ctx) {
              final isFocused = Focus.of(ctx).hasFocus;
              return GestureDetector(
                onTap: () {
                  setState(() => _sortBy = sort);
                  _loadContent();
                },
                child: AnimatedContainer(
                  duration: NeoTheme.durationFast,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? NeoTheme.prestigeGold.withValues(alpha: 0.25)
                        : (isSelected
                            ? NeoTheme.prestigeGold.withValues(alpha: 0.15)
                            : NeoTheme.bgElevated.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                    border: Border.all(
                      color: isFocused
                          ? NeoTheme.prestigeGold
                          : (isSelected
                              ? NeoTheme.prestigeGold
                              : NeoTheme.bgBorder.withValues(alpha: 0.3)),
                      width: isFocused ? 2.5 : (isSelected ? 2 : 1),
                    ),
                    boxShadow: isFocused
                        ? [
                            BoxShadow(
                              color: NeoTheme.prestigeGold.withValues(alpha: 0.3),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _sortLabels[sort]!,
                    style: NeoTheme.labelMedium(context).copyWith(
                      color: (isFocused || isSelected)
                          ? NeoTheme.prestigeGold
                          : NeoTheme.textSecondary,
                      fontWeight: (isFocused || isSelected) ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGenreRow(BuildContext context) {
    final useFocus = NeoTheme.needsFocusNavigation(context);
    final genres = ['all', ..._genreFacets.map((g) => g['name'].toString())];
    
    // Problem #30: Wrap au lieu de Row pour meilleure gestion du focus sur les boutons
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: genres.take(15).map((genre) {
        final isSelected = _selectedGenre == genre;
        final genreColor = NeoTheme.getGenreColor(genre);
        final count = genre == 'all'
            ? null
            : _genreFacets
                .firstWhere((g) => g['name'] == genre, orElse: () => {})['count'];
        
        // Problem #28: Genre buttons always focalisable when TV navigation
        return Focus(
          canRequestFocus: useFocus,
          onKeyEvent: useFocus
              ? (node, event) {
                  if (event is KeyDownEvent &&
                      (event.logicalKey == LogicalKeyboardKey.enter ||
                       event.logicalKey == LogicalKeyboardKey.select ||
                       event.logicalKey == LogicalKeyboardKey.space)) {
                    setState(() => _selectedGenre = genre);
                    _loadContent();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                }
              : null,
          child: Builder(
            builder: (ctx) {
              final isFocused = Focus.of(ctx).hasFocus;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedGenre = genre);
                  _loadContent();
                },
                child: AnimatedContainer(
                  duration: NeoTheme.durationFast,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? genreColor.withValues(alpha: 0.25)
                        : (isSelected
                            ? genreColor.withValues(alpha: 0.15)
                            : NeoTheme.bgElevated.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(NeoTheme.radiusSm),
                    border: Border.all(
                      color: isFocused
                          ? genreColor
                          : (isSelected
                              ? genreColor
                              : NeoTheme.bgBorder.withValues(alpha: 0.3)),
                      width: isFocused ? 2.5 : (isSelected ? 1.5 : 0.5),
                    ),
                    boxShadow: isFocused
                        ? [
                            BoxShadow(
                              color: genreColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    genre == 'all' ? 'Tous' : (count != null ? '$genre ($count)' : genre),
                    style: NeoTheme.labelSmall(context).copyWith(
                      color: (isFocused || isSelected)
                          ? genreColor
                          : NeoTheme.textSecondary,
                      fontWeight: (isFocused || isSelected) ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnimeCard(BuildContext context, Anime anime, int index) {
    final useFocus = NeoTheme.needsFocusNavigation(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 200 + (index % 10) * 50),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Focus(
        canRequestFocus: useFocus,
        onKeyEvent: useFocus
            ? (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.enter ||
                     event.logicalKey == LogicalKeyboardKey.select ||
                     event.logicalKey == LogicalKeyboardKey.space)) {
                  _navigateToDetail(anime);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              }
            : null,
        child: Builder(
          builder: (ctx) {
            final isFocused = Focus.of(ctx).hasFocus;
            return GestureDetector(
              onTap: () => _navigateToDetail(anime),
              child: AnimatedScale(
                scale: isFocused ? NeoTheme.focusedCardScale(context) : 1.0,
                duration: NeoTheme.durationFast,
                child: AnimatedContainer(
                  duration: NeoTheme.durationFast,
                  decoration: isFocused
                      ? NeoTheme.cardFocusedDecoration
                      : NeoTheme.cardDecoration,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (anime.posterUrl != null)
                          Image.network(
                            anime.posterUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          )
                        else
                          _buildPlaceholder(),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.9),
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  anime.title,
                                  style: NeoTheme.labelMedium(context).copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${anime.totalEpisodes} épisodes • ${anime.totalSeasons} saisons',
                                  style: NeoTheme.labelSmall(context).copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: NeoTheme.bgElevated,
      child: Center(
        child: Icon(
          Icons.animation,
          size: 48,
          color: NeoTheme.textTertiary,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: NeoTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(
          color: NeoTheme.bgBorder.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.filter_alt_off_rounded,
            size: 42,
            color: NeoTheme.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage != null
                ? 'Catalogue indisponible'
                : 'Aucun anime pour ce filtre',
            style: NeoTheme.titleMedium(context),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ??
                'Essayez un autre genre ou revenez à l\'ensemble du catalogue.',
            style: NeoTheme.bodyMedium(context)
                .copyWith(color: NeoTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
