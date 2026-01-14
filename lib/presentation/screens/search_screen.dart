import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../widgets/animations/animated_card.dart';
// import neo_image removed
import '../../core/design_system/animation_system.dart';
import '../../core/design_system/color_system.dart';
import '../../data/models/movie.dart';
import '../../data/models/series.dart';
import '../../data/services/search_service.dart';
import '../../data/services/dio_client.dart' as dio_client;
import '../widgets/app_image.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;

  const SearchScreen({Key? key, this.initialQuery}) : super(key: key);

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _headerController;
  late AnimationController _contentController;

  String _currentQuery = '';
  List<Movie> _movieResults = [];
  List<Series> _seriesResults = [];
  bool _isLoading = false;

  bool _showMovies = true;

  final Map<String, UnifiedSearchResponse> _searchCache = {};
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    if (widget.initialQuery?.isNotEmpty == true) {
      _searchController.text = widget.initialQuery!;
      _currentQuery = widget.initialQuery!;
      _performSearch();
    }
  }

  void _setupAnimations() {
    _headerController = AnimationController(
      duration: AnimationSystem.long,
      vsync: this,
    );

    _contentController = AnimationController(
      duration: AnimationSystem.veryLong,
      vsync: this,
    );

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _contentController.forward();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _headerController.dispose();
    _contentController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _cleanCacheIfNeeded() {
    if (_searchCache.length > 20) {
      final keysToKeep = _searchCache.keys.take(10).toList();
      _searchCache.removeWhere((key, _) => !keysToKeep.contains(key));
    }
  }

  void _performSearch() {
    if (_currentQuery.isEmpty) {
      setState(() {
        _movieResults = [];
        _seriesResults = [];
        _isLoading = false;
      });
      return;
    }

    _debounceTimer?.cancel();

    if (_searchCache.containsKey(_currentQuery)) {
      final cachedResponse = _searchCache[_currentQuery]!;
      setState(() {
        _movieResults = cachedResponse.movies;
        _seriesResults = cachedResponse.series;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final searchService = SearchService(dio_client.DioClient.instance);
        final response = await searchService.search(query: _currentQuery);

        _searchCache[_currentQuery] = response;
        _cleanCacheIfNeeded();

        if (mounted) {
          setState(() {
            _movieResults = response.movies;
            _seriesResults = response.series;
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Erreur de recherche: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorSystem.backgroundPrimary,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          _buildSearchContent(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: _buildSearchHeader(),
        collapseMode: CollapseMode.parallax,
      ),
    );
  }

  Widget _buildSearchHeader() {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ColorSystem.neonCyan.withOpacity(0.1),
              ColorSystem.neonPink.withOpacity(0.1),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedNeonText(
                'RECHERCHE',
                textStyle: const TextStyle(
                  color: ColorSystem.neonCyan,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                duration: const Duration(milliseconds: 800),
              ),
              const SizedBox(height: 16),
              _buildSearchBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColorSystem.neonCyan.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: ColorSystem.neonCyan.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: ColorSystem.textPrimary,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: 'Rechercher des films, séries...',
          hintStyle: TextStyle(
            color: ColorSystem.textSecondary.withOpacity(0.6),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: ColorSystem.neonCyan,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _currentQuery = '';
                      _movieResults = [];
                      _seriesResults = [];
                    });
                  },
                )
              : null,
          prefixIcon: const Icon(
            Icons.search,
            color: ColorSystem.neonCyan,
          ),
        ),
        onChanged: (value) {
          setState(() => _currentQuery = value);
          if (value.isNotEmpty) {
            _performSearch();
          }
        },
        onSubmitted: (_) => _performSearch(),
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_currentQuery.isEmpty) {
      return _buildSearchSuggestions();
    }

    if (_isLoading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Center(
            child: NeonLoadingIndicator(
              color: ColorSystem.neonCyan,
              size: 70,
            ),
          ),
        ),
      );
    }

    if (_movieResults.isEmpty && _seriesResults.isEmpty) {
      return _buildEmptySearchResults();
    }

    return _buildSearchResults();
  }

  Widget _buildSearchSuggestions() {
    final suggestions = [
      {'title': 'Action', 'icon': Icons.local_fire_department},
      {'title': 'Comédie', 'icon': Icons.emoji_emotions},
      {'title': 'Drame', 'icon': Icons.theater_comedy},
      {'title': 'Science-fiction', 'icon': Icons.science},
      {'title': 'Thriller', 'icon': Icons.psychology},
      {'title': 'Animation', 'icon': Icons.animation},
    ];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Parcourir par catégorie',
              style: TextStyle(
                color: ColorSystem.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
              children: List.generate(
                suggestions.length,
                (index) {
                  final suggestion = suggestions[index];
                  return _buildSuggestionCard(
                    suggestion['title'] as String,
                    suggestion['icon'] as IconData,
                    index,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(String title, IconData icon, int index) {
    final delay = index * 50;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _contentController,
          curve: Interval(
            (delay / 600).clamp(0.0, 1.0),
            ((delay + 150) / 600).clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(
            parent: _contentController,
            curve: Interval(
              (delay / 600).clamp(0.0, 1.0),
              ((delay + 150) / 600).clamp(0.0, 1.0),
              curve: AnimationSystem.easeOutQuint,
            ),
          ),
        ),
        child: GestureDetector(
          onTap: () {
            _searchController.text = title;
            _currentQuery = title;
            _performSearch();
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ColorSystem.neonPurple.withOpacity(0.15),
                  ColorSystem.neonPink.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ColorSystem.neonPurple.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: ColorSystem.neonPurple.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: ColorSystem.neonPurple,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: ColorSystem.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildEmptySearchResults() {
    return SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 100,
                color: ColorSystem.neonCyan.withOpacity(0.3),
              ),
              const SizedBox(height: 24),
              Text(
                'Aucun résultat pour "$_currentQuery"',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ColorSystem.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Essayez une autre recherche',
                style: TextStyle(
                  fontSize: 14,
                  color: ColorSystem.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: ColorSystem.surface,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: ColorSystem.neonCyan.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showMovies = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _showMovies ? ColorSystem.neonCyan : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        'Films (${_movieResults.length})',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _showMovies ? ColorSystem.surface : ColorSystem.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showMovies = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_showMovies ? ColorSystem.neonCyan : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        'Séries (${_seriesResults.length})',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: !_showMovies ? ColorSystem.surface : ColorSystem.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: _showMovies ? _buildMoviesGrid() : _buildSeriesGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildMoviesGrid() {
    if (_movieResults.isEmpty) {
      return const Center(
        child: Text(
          'Aucun film trouvé',
          style: TextStyle(color: ColorSystem.textSecondary),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
      ),
      itemCount: _movieResults.length,
      itemBuilder: (context, index) {
        final movie = _movieResults[index];
        return _buildMovieResultCard(movie, index);
      },
    );
  }

  Widget _buildSeriesGrid() {
    if (_seriesResults.isEmpty) {
      return const Center(
        child: Text(
          'Aucune série trouvée',
          style: TextStyle(color: ColorSystem.textSecondary),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
      ),
      itemCount: _seriesResults.length,
      itemBuilder: (context, index) {
        final series = _seriesResults[index];
        return _buildSeriesResultCard(series, index);
      },
    );
  }

  Widget _buildMovieResultCard(Movie movie, int index) {
    final delay = index * 50;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _contentController,
          curve: Interval(
            (delay / 800).clamp(0.0, 1.0),
            ((delay + 200) / 800).clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _contentController,
            curve: Interval(
              (delay / 800).clamp(0.0, 1.0),
              ((delay + 200) / 800).clamp(0.0, 1.0),
              curve: AnimationSystem.easeOutQuint,
            ),
          ),
        ),
        child: AnimatedNeonCard(
          glowColor: ColorSystem.neonCyan,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/movie-detail',
              arguments: movie,
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImage(movie.poster, fit: BoxFit.cover),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: ColorSystem.neonCyan,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${movie.numericRating.toStringAsFixed(1)}/10',
                          style: const TextStyle(
                            color: ColorSystem.neonCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeriesResultCard(Series series, int index) {
    final delay = index * 50;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _contentController,
          curve: Interval(
            (delay / 800).clamp(0.0, 1.0),
            ((delay + 200) / 800).clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _contentController,
            curve: Interval(
              (delay / 800).clamp(0.0, 1.0),
              ((delay + 200) / 800).clamp(0.0, 1.0),
              curve: AnimationSystem.easeOutQuint,
            ),
          ),
        ),
        child: AnimatedNeonCard(
          glowColor: ColorSystem.neonPurple,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/series-detail',
              arguments: series,
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImage(series.poster, fit: BoxFit.cover, errorWidget: const Icon(Icons.tv)),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      series.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.tv,
                          color: ColorSystem.neonPurple,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (series.seasons?.isNotEmpty ?? false) ? '${series.seasons!.length} saisons' : 'Série',
                          style: const TextStyle(
                            color: ColorSystem.neonPurple,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


