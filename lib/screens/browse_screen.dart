import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../config/theme.dart';
import '../models/content.dart';
import '../services/api_service.dart';
import '../widgets/content_card.dart';
import '../widgets/section_header.dart';
import 'detail_screen.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();

  String _selectedType = 'all';
  String _selectedGenre = 'all';
  String _sortBy = 'recent';
  int _page = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  int _totalResults = 0;
  int _visibleTotal = 0;
  int _filmsTotal = 0;
  int _seriesTotal = 0;
  int _recentTotal = 0;
  double _averageRating = 0;
  List<Content> _items = [];
  List<Map<String, dynamic>> _genreFacets = [];
  String? _errorMessage;
  
  // GlobalKey pour le premier élément focusable du contenu
  final GlobalKey _firstContentKey = GlobalKey();

  final List<String> _types = ['all', 'film', 'serie'];
  final Map<String, String> _typeLabels = {
    'all': 'Tout',
    'film': 'Films',
    'serie': 'Series',
  };
  final Map<String, String> _sortLabels = {
    'recent': 'Recents',
    'rating': 'Note',
    'title': 'Titre',
    'year': 'Annee',
  };
  final Map<String, IconData> _typeIcons = {
    'all': Icons.dashboard_customize_outlined,
    'film': Icons.movie_outlined,
    'serie': Icons.tv_outlined,
  };
  final Map<String, IconData> _sortIcons = {
    'recent': Icons.schedule_rounded,
    'rating': Icons.star_border_rounded,
    'title': Icons.sort_by_alpha_rounded,
    'year': Icons.calendar_today_outlined,
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

  int _safeInt(dynamic value, [int fallback = 1]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _safeDouble(dynamic value, [double fallback = 0]) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void _applyMeta(
    Map<String, dynamic>? meta,
    Map<String, dynamic>? pagination,
  ) {
    final rawGenres = (meta?['genres'] as List?) ?? const [];
    _genreFacets = rawGenres
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    final fallbackVisible = _safeInt(pagination?['total'], _items.length);
    final visibleFromApi = _safeInt(meta?['visible_total'], 0);
    _visibleTotal = visibleFromApi > 0 ? visibleFromApi : fallbackVisible;

    final filmsFromApi = _safeInt(meta?['films_total'], 0);
    final seriesFromApi = _safeInt(meta?['series_total'], 0);
    final localFilms = _items.where((item) => item.isFilm).length;
    final localSeries = _items.where((item) => item.isSerie).length;

    _filmsTotal = filmsFromApi > 0 ? filmsFromApi : localFilms;
    _seriesTotal = seriesFromApi > 0 ? seriesFromApi : localSeries;
    _recentTotal = _safeInt(meta?['recent_total'], 0);
    _averageRating = _safeDouble(meta?['average_rating'], 0);
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _page = 1;
      _errorMessage = null;
    });

    try {
      final data = await _api.getContentList(
        type: _selectedType == 'all' ? null : _selectedType,
        genre: _selectedGenre == 'all' ? null : _selectedGenre,
        sort: _sortBy,
        page: 1,
      );
      final items = (data['items'] as List? ?? [])
          .map((item) => Content.fromJson(item as Map<String, dynamic>))
          .where((c) => c.hasPoster)
          .toList();
      final pagination = data['pagination'] as Map<String, dynamic>?;
      final meta = data['meta'] as Map<String, dynamic>?;

      setState(() {
        _items = items;
        _totalResults = _safeInt(
          pagination?['total'] ?? pagination?['total_items'],
          items.length,
        );
        _hasMore = _page < _safeInt(pagination?['total_pages'], 1);
        _applyMeta(meta, pagination);
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = humanizeApiError(error);
        _visibleTotal = _items.isNotEmpty ? _items.length : 0;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoading = true);
    _page++;

    try {
      final data = await _api.getContentList(
        type: _selectedType == 'all' ? null : _selectedType,
        genre: _selectedGenre == 'all' ? null : _selectedGenre,
        sort: _sortBy,
        page: _page,
      );
      final items = (data['items'] as List? ?? [])
          .map((item) => Content.fromJson(item as Map<String, dynamic>))
          .where((c) => c.hasPoster)
          .toList();
      final pagination = data['pagination'] as Map<String, dynamic>?;
      final meta = data['meta'] as Map<String, dynamic>?;

      setState(() {
        _items.addAll(items);
        _hasMore = _page < _safeInt(pagination?['total_pages'], 1);
        if (meta != null) {
          _applyMeta(meta, pagination);
        }
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

  void _navigateToDetail(Content content) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(contentId: content.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resultCount = _visibleTotal > 0
        ? _visibleTotal
        : (_totalResults > 0 ? _totalResults : _items.length);

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
                title: Text(
                  'Catalogue',
                  style: NeoTheme.titleLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(
                      child: Text(
                        '$resultCount disponibles',
                        style: NeoTheme.labelMedium(
                          context,
                        ).copyWith(color: NeoTheme.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: _buildHeroSummary(context, resultCount: resultCount),
              ),
              SliverToBoxAdapter(child: _buildInsightRail(context)),
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
                        boxShadow: NeoTheme.shadowLevel2,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: NeoTheme.warningOrange,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: NeoTheme.bodySmall(
                                context,
                              ).copyWith(color: NeoTheme.textSecondary),
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
                      (_, __) => Shimmer.fromColors(
                        baseColor: NeoTheme.bgElevated,
                        highlightColor: NeoTheme.bgBorder.withValues(alpha: 0.3),
                        child: Container(
                          decoration: BoxDecoration(
                            color: NeoTheme.bgElevated,
                            borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                          ),
                        ),
                      ),
                      childCount: _gridColumns(context) * 3,
                    ),
                  ),
                )
              else if (_items.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: NeoTheme.screenPadding(context).copyWith(top: 24),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: NeoTheme.surfaceGradient,
                        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                        border: Border.all(
                          color: NeoTheme.bgBorder.withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                        boxShadow: NeoTheme.shadowLevel2,
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
                                : 'Aucun contenu pour ce filtre',
                            style: NeoTheme.titleMedium(context),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage ??
                                'Essayez un autre genre ou revenez a l ensemble du catalogue.',
                            style: NeoTheme.bodyMedium(
                              context,
                            ).copyWith(color: NeoTheme.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.05),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: SectionHeader(
                      key: ValueKey<String>('header_$_selectedGenre'),
                      title: _selectedGenre == 'all'
                          ? 'Selection visible'
                          : 'Genre: $_selectedGenre',
                      subtitle: _selectedGenre == 'all'
                          ? 'Une presentation plus claire des films et series disponibles.'
                          : '$_visibleTotal contenu${_visibleTotal > 1 ? 's' : ''} disponible${_visibleTotal > 1 ? 's' : ''} dans ce genre.',
                      icon: Icons.grid_view_rounded,
                      padding: EdgeInsets.fromLTRB(
                        NeoTheme.screenPadding(context).left,
                        18,
                        NeoTheme.screenPadding(context).right,
                        0,
                      ),
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
                  sliver: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _gridColumns(context),
                        childAspectRatio: _gridAspect(context),
                        crossAxisSpacing: NeoTheme.gridSpacing(context),
                        mainAxisSpacing: NeoTheme.gridSpacing(context),
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= _items.length) {
                            return Container(decoration: NeoTheme.cardDecoration);
                          }

                          final content = _items[index];
                          // Animation d'entrée pour chaque carte
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(
                              milliseconds: 200 + (index % 10) * 50,
                            ),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: 0.95 + (0.05 * value),
                                child: Opacity(opacity: value, child: child),
                              );
                            },
                            child: Semantics(
                              label: '${content.displayTitle}, ${content.isSerie ? 'Série' : 'Film'}',
                              hint: 'Appuyez pour voir les détails',
                              button: true,
                              enabled: true,
                              child: ContentCard(
                                key: ValueKey('content_${content.id}_$_sortBy'),
                                content: content,
                                index: index,
                                onTap: () => _navigateToDetail(content),
                              ),
                            ),
                          );
                        },
                        childCount:
                            _items.length + (_isLoading && _hasMore ? 6 : 0),
                      ),
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

  Widget _buildHeroSummary(BuildContext context, {required int resultCount}) {
    final topGenres = _genreFacets.take(3).toList();
    final heroAccent = _selectedType == 'serie'
        ? NeoTheme.infoCyan
        : (_selectedType == 'film'
              ? NeoTheme.primaryRed
              : NeoTheme.prestigeGold);

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
          gradient: NeoTheme.surfaceGradient,
          borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
          border: Border.all(
            color: heroAccent.withValues(alpha: 0.15),
            width: 0.5,
          ),
          boxShadow: NeoTheme.shadowLevel2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildHeroChip(
                  context,
                  _typeLabels[_selectedType] ?? 'Catalogue',
                  color: _selectedType == 'serie'
                      ? NeoTheme.infoCyan
                      : (_selectedType == 'film'
                            ? NeoTheme.primaryRed
                            : NeoTheme.prestigeGold),
                ),
                _buildHeroChip(
                  context,
                  'Tri: ${_sortLabels[_sortBy]}',
                  color: NeoTheme.textSecondary,
                ),
                if (_selectedGenre != 'all')
                  _buildHeroChip(
                    context,
                    _selectedGenre,
                    color: NeoTheme.getGenreColor(_selectedGenre),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Un catalogue plus lisible, plus fluide et mieux edite.',
              style: NeoTheme.displayLarge(context).copyWith(
                fontSize: NeoTheme.isTV(context) ? 34 : 28,
                height: 1.04,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Affinez par type, explorez les genres dominants et parcourez la selection avec une presentation proche d une vraie plateforme de streaming.',
              style: NeoTheme.bodyMedium(
                context,
              ).copyWith(color: NeoTheme.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatPill(
                  context,
                  icon: Icons.grid_view_rounded,
                  label: '$resultCount titres',
                ),
                _buildStatPill(
                  context,
                  icon: Icons.visibility_outlined,
                  label: '${_items.length} charges',
                  color: NeoTheme.infoCyan,
                ),
                _buildStatPill(
                  context,
                  icon: Icons.star_rounded,
                  label: _averageRating > 0
                      ? _averageRating.toStringAsFixed(1)
                      : 'n/a',
                  color: NeoTheme.prestigeGold,
                ),
                _buildStatPill(
                  context,
                  icon: Icons.new_releases_outlined,
                  label: '$_recentTotal recents',
                  color: NeoTheme.successGreen,
                ),
              ],
            ),
            if (topGenres.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: topGenres.map((entry) {
                  final name = (entry['name'] ?? '').toString();
                  final count = _safeInt(entry['count'], 0);
                  if (name.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return _buildHeroChip(
                    context,
                    '$name $count',
                    color: NeoTheme.getGenreColor(name),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInsightRail(BuildContext context) {
    final insights = [
      (
        'Films',
        _filmsTotal > 0 ? '$_filmsTotal disponibles' : 'Aucun',
        Icons.movie_outlined,
        NeoTheme.primaryRed,
      ),
      (
        'Series',
        _seriesTotal > 0 ? '$_seriesTotal disponibles' : 'Aucune',
        Icons.tv_outlined,
        NeoTheme.infoCyan,
      ),
      (
        'Note moyenne',
        _averageRating > 0 ? _averageRating.toStringAsFixed(1) : 'n/a',
        Icons.star_rounded,
        NeoTheme.prestigeGold,
      ),
      (
        'Nouveautes',
        '$_recentTotal recentes',
        Icons.auto_awesome_outlined,
        NeoTheme.successGreen,
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        NeoTheme.screenPadding(context).left,
        14,
        NeoTheme.screenPadding(context).right,
        0,
      ),
      child: SizedBox(
        height: 94,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: insights.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final insight = insights[index];
            return Container(
              width: NeoTheme.isTV(context) ? 240 : 210,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: NeoTheme.surfaceGradient,
                borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                border: Border.all(
                  color: insight.$4.withValues(alpha: 0.15),
                  width: 0.5,
                ),
                boxShadow: NeoTheme.shadowLevel2,
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: insight.$4.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: insight.$4.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Icon(insight.$3, color: insight.$4, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(insight.$1, style: NeoTheme.labelSmall(context)),
                        const SizedBox(height: 4),
                        Text(
                          insight.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NeoTheme.titleMedium(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFiltersPanel(BuildContext context) {
    final genreEntries = _genreFacets;

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
          boxShadow: NeoTheme.shadowLevel2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtres intelligents',
              style: NeoTheme.titleMedium(
                context,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Type, tri et genres dominants pour organiser le catalogue plus vite.',
              style: NeoTheme.bodySmall(
                context,
              ).copyWith(color: NeoTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            _buildChipRow(
              context,
              items: _types,
              selectedValue: _selectedType,
              iconForItem: (type) => _typeIcons[type],
              labelForItem: (type) => _typeLabels[type] ?? type,
              selectedColorForItem: (type) => type == 'serie'
                  ? NeoTheme.infoCyan
                  : (type == 'film'
                        ? NeoTheme.primaryRed
                        : NeoTheme.prestigeGold),
              onTap: (type) {
                setState(() {
                  _selectedType = type;
                  _selectedGenre = 'all';
                });
                _loadContent();
              },
            ),
            const SizedBox(height: 10),
            _buildChipRow(
              context,
              items: _sortLabels.keys.toList(),
              selectedValue: _sortBy,
              iconForItem: (sort) => _sortIcons[sort],
              labelForItem: (sort) => _sortLabels[sort] ?? sort,
              selectedColorForItem: (_) => NeoTheme.prestigeGold,
              onTap: (sort) {
                setState(() {
                  _sortBy = sort;
                });
                _loadContent();
              },
            ),
            if (genreEntries.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildChipRow(
                context,
                items: [
                  'all',
                  ...genreEntries
                      .map((entry) => (entry['name'] ?? '').toString())
                      .where((genre) => genre.isNotEmpty),
                ],
                selectedValue: _selectedGenre,
                iconForItem: (_) => Icons.local_offer_outlined,
                labelForItem: (genre) {
                  if (genre == 'all') {
                    return 'Tous les genres';
                  }
                  final count = _safeInt(
                    genreEntries.firstWhere(
                      (entry) => (entry['name'] ?? '').toString() == genre,
                      orElse: () => const {'count': 0},
                    )['count'],
                    0,
                  );
                  return '$genre $count';
                },
                selectedColorForItem: (genre) => genre == 'all'
                    ? NeoTheme.textSecondary
                    : NeoTheme.getGenreColor(genre),
                onTap: (genre) {
                  setState(() {
                    _selectedGenre = genre;
                  });
                  _loadContent();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChipRow(
    BuildContext context, {
    required List<String> items,
    required String selectedValue,
    required IconData? Function(String item) iconForItem,
    required String Function(String item) labelForItem,
    required Color Function(String item) selectedColorForItem,
    required void Function(String item) onTap,
  }) {
    final useFocus = NeoTheme.needsFocusNavigation(context);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = selectedValue == item;
          final selectedColor = selectedColorForItem(item);
          return Focus(
            canRequestFocus: useFocus,
            onKeyEvent: useFocus
                ? (node, event) {
                    if (event is KeyDownEvent &&
                        (event.logicalKey == LogicalKeyboardKey.enter ||
                         event.logicalKey == LogicalKeyboardKey.select ||
                         event.logicalKey == LogicalKeyboardKey.space)) {
                      onTap(item);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  }
                : null,
            child: Builder(
              builder: (ctx) {
                final isFocused = Focus.of(ctx).hasFocus;
                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onTap(item),
                  child: AnimatedContainer(
                    duration: NeoTheme.durationNormal,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isFocused
                          ? selectedColor.withValues(alpha: 0.25)
                          : (selected
                              ? selectedColor.withValues(alpha: 0.12)
                              : NeoTheme.bgSurface),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isFocused
                            ? selectedColor
                            : (selected
                                ? selectedColor.withValues(alpha: 0.2)
                                : NeoTheme.bgBorder.withValues(alpha: 0.2)),
                        width: isFocused ? 2 : 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (iconForItem(item) != null) ...[
                          Icon(
                            iconForItem(item),
                            size: 16,
                            color: (selected || isFocused) ? selectedColor : NeoTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          labelForItem(item),
                          style: NeoTheme.labelMedium(context).copyWith(
                            color: (selected || isFocused) ? (isFocused ? Colors.white : selectedColor) : NeoTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroChip(
    BuildContext context,
    String label, {
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Text(
        label,
        style: NeoTheme.labelMedium(
          context,
        ).copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildStatPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final accent = color ?? NeoTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: NeoTheme.labelMedium(
              context,
            ).copyWith(color: NeoTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}
