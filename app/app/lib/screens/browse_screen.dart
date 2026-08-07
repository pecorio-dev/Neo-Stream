import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../config/theme.dart';
import '../config/neo.dart';
import '../models/content.dart';
import '../services/api_service.dart';
import '../widgets/content_card.dart';
import '../widgets/section_header.dart';
import 'detail_screen.dart';

class BrowseScreen extends StatefulWidget {
  BrowseScreen({super.key});

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
  List<Content> _items = [];
  List<Map<String, dynamic>> _genreFacets = [];
  String? _errorMessage;


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

  void _applyMeta(
    Map<String, dynamic>? meta,
    Map<String, dynamic>? pagination,
  ) {
    final rawGenres = (meta?['genres'] as List?) ?? const [];
    final parsed = rawGenres
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    if (parsed.isNotEmpty) {
      _genreFacets = parsed;
    }
    final fallbackVisible = _safeInt(pagination?['total'], _items.length);
    final visibleFromApi = _safeInt(meta?['visible_total'], 0);
    _visibleTotal = visibleFromApi > 0 ? visibleFromApi : fallbackVisible;
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
      backgroundColor: Neo.bgBase(context),
      body: SafeArea(
        top: !NeoTheme.isTV(context),
        child: RefreshIndicator(
          onRefresh: _loadContent,
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: Neo.bgElevated(context),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                elevation: 0,
                backgroundColor: Neo.bgBase(context).withValues(alpha: 0.94),
                title: Text(
                  'Catalogue',
                  style: NeoTheme.titleLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                actions: [
                  Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Center(
                      child: Text(
                        '$resultCount disponibles',
                        style: NeoTheme.labelMedium(
                          context,
                        ).copyWith(color: Neo.textSecondary(context)),
                      ),
                    ),
                  ),
                ],
              ),
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
                      padding: EdgeInsets.all(14),
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
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: NeoTheme.bodySmall(
                                context,
                              ).copyWith(color: Neo.textSecondary(context)),
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
                      (_1, _2) => Shimmer.fromColors(
                        baseColor: Neo.bgElevated(context),
                        highlightColor: Neo.bgBorder(context).withValues(alpha: 0.3),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Neo.bgElevated(context),
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
                      padding: EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: Neo.surfaceGradient(context),
                        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                        border: Border.all(
                          color: Neo.bgBorder(context).withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                        boxShadow: NeoTheme.shadowLevel2,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_alt_off_rounded,
                            size: 42,
                            color: Neo.textTertiary(context),
                          ),
                          SizedBox(height: 12),
                          Text(
                            _errorMessage != null
                                ? 'Catalogue indisponible'
                                : 'Aucun contenu pour ce filtre',
                            style: Neo.titleMedium(context),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _errorMessage ??
                                'Essayez un autre genre ou revenez a l ensemble du catalogue.',
                            style: NeoTheme.bodyMedium(
                              context,
                            ).copyWith(color: Neo.textSecondary(context)),
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
                    duration: Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(0, 0.05),
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
                SliverToBoxAdapter(child: SizedBox(height: 14)),
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
                            return Container(decoration: Neo.cardDecoration(context));
                          }

                          final content = _items[index];
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
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
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

  Widget _buildFiltersPanel(BuildContext context) {
    final genreEntries = _genreFacets;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        NeoTheme.screenPadding(context).left,
        12,
        NeoTheme.screenPadding(context).right,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            _buildChipRow(
              context,
              items: _types,
              selectedValue: _selectedType,
              iconForItem: (type) => _typeIcons[type],
              labelForItem: (type) => _typeLabels[type] ?? type,
              selectedColorForItem: (type) => type == 'serie'
                  ? NeoTheme.infoCyan
                  : (type == 'film'
                        ? Theme.of(context).colorScheme.primary
                        : NeoTheme.prestigeGold),
              onTap: (type) {
                setState(() {
                  _selectedType = type;
                  _selectedGenre = 'all';
                });
                _loadContent();
              },
            ),
            SizedBox(height: 10),
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
              SizedBox(height: 10),
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
                    ? Neo.textSecondary(context)
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
        separatorBuilder: (_1, _2) => SizedBox(width: 8),
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
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isFocused
                          ? selectedColor.withValues(alpha: 0.25)
                          : (selected
                              ? selectedColor.withValues(alpha: 0.12)
                              : Neo.bgSurface(context)),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isFocused
                            ? selectedColor
                            : (selected
                                ? selectedColor.withValues(alpha: 0.2)
                                : Neo.bgBorder(context).withValues(alpha: 0.2)),
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
                            color: (selected || isFocused) ? selectedColor : Neo.textSecondary(context),
                          ),
                          SizedBox(width: 8),
                        ],
                        Text(
                          labelForItem(item),
                          style: Neo.labelMedium(context).copyWith(
                            color: (selected || isFocused) ? (isFocused ? Neo.textPrimary(context) : selectedColor) : Neo.textSecondary(context),
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

}
