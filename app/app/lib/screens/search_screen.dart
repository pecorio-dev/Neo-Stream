import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../config/theme.dart';
import '../config/neo.dart';
import '../models/anime.dart';
import '../models/content.dart';
import '../providers/providers.dart';
import '../services/api_service.dart';
import '../services/search_history.dart';
import '../widgets/content_card.dart';
import '../widgets/floating_search_bar.dart';
import '../widgets/satisfying_animations.dart';
import '../widgets/section_header.dart';
import 'anime_detail_screen.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  List<Content> _results = [];
  List<Anime> _animeResults = [];
  bool _loading = false;
  String _query = '';
  String? _error;
  int _searchId = 0;

  /// Panneau de prévisualisation des résultats affiché pendant la saisie
  /// (mobile uniquement — le mode TV conserve son dialogue dédié).
  bool _previewOpen = false;

  int _focusedResultIndex = 0;
  bool _autoFocusFirstResult = false;

  // ── Filtres de résultats ─────────────────────────────────────────────
  // '' = tous, 'film', 'serie', 'anime' ; note 7+ en option.
  String _typeFilter = '';
  bool _topRatedOnly = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocus);
    SearchHistory.instance.load();
    // Ne pas ouvrir automatiquement le dialogue - l'utilisateur doit cliquer explicitement
  }

  void _onFocus() { if (mounted) setState(() {}); }

  Future<void> _openSearchDialog() async {
    final controller = TextEditingController(text: _controller.text);
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _SearchDialog(controller: controller),
    );
    if (!mounted) return;
    if (result != null && result.trim().length >= 2) {
      _controller.text = result;
      _search(result.trim());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.removeListener(_onFocus);
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(Duration(milliseconds: 320), () {
      final q = v.trim();
      if (q.length >= 2 && q != _query) _search(q, openPreview: true);
      if (q.isEmpty) setState(() { _results = []; _animeResults = []; _query = ''; _error = null; _previewOpen = false; });
    });
  }

  /// Validation explicite (touche « recherche » du clavier) : referme la
  /// prévisualisation et épingle la grille complète des résultats.
  void _commitSearch(String q) {
    _debounce?.cancel();
    final query = q.trim();
    setState(() => _previewOpen = false);
    _focusNode.unfocus();
    if (query.length >= 2 && query != _query) {
      _search(query);
    }
  }

  void _closePreview() {
    if (!_previewOpen) return;
    setState(() => _previewOpen = false);
    _focusNode.unfocus();
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {
      _results = [];
      _animeResults = [];
      _query = '';
      _error = null;
      _previewOpen = false;
    });
    _focusNode.requestFocus();
  }

  /// Recherche lancée par la saisie ([openPreview] = true) : le panneau de
  /// prévisualisation s'ouvre dès l'arrivée des résultats. Les autres
  /// déclencheurs (historique, validation) épinglent directement la grille.
  Future<void> _search(String q, {bool openPreview = false}) async {
    final currentId = ++_searchId;
    setState(() { _loading = true; _query = q; _error = null; if (openPreview) _previewOpen = true; });
    try {
      final raw = await _api.searchContent(q);
      SearchHistory.instance.add(q);
      if (!mounted) return;
      final films = raw.where((c) => c.contentType != 'anime').toList();
      final animeAsContent = raw.where((c) => c.contentType == 'anime').toList();
      // Lancer aussi la recherche anime en parallèle
      List<Anime> animes = [];
      try {
        final animeData = await _api.searchAnime(q);
        animes = animeData.map((e) => Anime.fromJson(e)).toList();
      } catch (_) {}
      if (currentId != _searchId) return; // stale request
      // Fusionner : si un anime est dans les deux listes, garder fromJson
      final animeIds = {for (final a in animes) a.id};
      final extraAnimes = animeAsContent
          .where((c) => !animeIds.contains(c.id))
          .map((c) => Anime.fromJson({
                'id': c.id, 'anime_id': c.id.toString(), 'url': c.id.toString(),
                'title': c.title, 'genres': c.genres,
                'poster_url': c.poster, 'seasons': {}, 'total_seasons': 0,
                'total_episodes': 0,
              }))
          .toList();
      setState(() {
        _results = films;
        _animeResults = [...animes, ...extraAnimes];
        _loading = false;
        _previewOpen = openPreview && _previewOpen;
        _focusedResultIndex = 0;
        _autoFocusFirstResult = NeoTheme.isTV(context) &&
            (films.isNotEmpty || animes.isNotEmpty || extraAnimes.isNotEmpty);
      });
    } catch (e) {
      if (currentId != _searchId) return; // stale request
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); _previewOpen = false; });
    }
  }

  /// Aplatit films / séries / anime pour le panneau de prévisualisation.
  List<SearchPreviewItem> _previewItems() {
    final items = <SearchPreviewItem>[
      for (final c in _results)
        SearchPreviewItem(
          id: c.id,
          title: c.displayTitle,
          typeLabel: c.typeLabel,
          posterUrl: c.fullPosterUrl,
          year: c.releaseDate?.toString(),
          rating: c.rating,
          genres: c.genres,
          isAnime: false,
          source: c,
        ),
      for (final a in _animeResults)
        SearchPreviewItem(
          id: a.id,
          title: a.title,
          typeLabel: 'Anime',
          posterUrl: a.posterUrl,
          genres: a.genres,
          isAnime: true,
          source: a,
        ),
    ];
    return items.take(6).toList();
  }

  void _openPreviewItem(SearchPreviewItem item) {
    _closePreview();
    if (item.isAnime) {
      _openAnime(item.source as Anime);
    } else {
      _openDetail(item.source as Content);
    }
  }

  void _openDetail(Content c) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => DetailScreen(contentId: c.id)));

  void _openAnime(Anime a) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => AnimeDetailScreen(animeId: a.id)));

  /// Navigation depuis le rail « Tendances » (un [Content] peut être un anime).
  void _openTrending(Content c) {
    if (c.contentType == 'anime') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => AnimeDetailScreen(animeId: c.id)));
    } else {
      _openDetail(c);
    }
  }

  /// Hauteur occupée par la barre flottante : padding haut + capsule.
  static const double _searchBarSpace = 12 + FloatingSearchBar.barHeight;

  @override
  Widget build(BuildContext context) {
    final isTV = NeoTheme.isTV(context);
    final pad = NeoTheme.screenPadding(context);
    final total = _results.length + _animeResults.length;
    final showPreview = _previewOpen && !isTV && _query.isNotEmpty;

    return Scaffold(
      backgroundColor: Neo.bgBase(context),
      body: SafeArea(
        top: !isTV,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          child: Stack(
            children: [
              Column(
                children: [
                  // ── Barre de recherche flottante ─────────────────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(pad.left, 12, pad.right, 8),
                    child: isTV
                        ? _buildTVSearchButton(context)
                        : FloatingSearchBar(
                            controller: _controller,
                            focusNode: _focusNode,
                            loading: _loading,
                            onChanged: _onChanged,
                            onSubmitted: _commitSearch,
                            onClear: _clearSearch,
                          ),
                  ),

                  // ── Header résultats ─────────────────────────────────
                  if (_query.isNotEmpty && !showPreview)
                    Padding(
                      padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 8),
                      child: Row(
                        children: [
                          Text(
                            _loading ? 'Recherche...' : '$total résultat${total > 1 ? "s" : ""} pour "$_query"',
                            style: Neo.bodySmall(context).copyWith(color: Neo.textSecondary(context)),
                          ),
                          if (_loading) ...[
                            SizedBox(width: 8),
                            SizedBox(width: 12, height: 12,
                                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary, strokeWidth: 2)),
                          ],
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 220.ms, curve: Curves.easeOutCubic)
                        .slideY(begin: -0.3, end: 0, duration: 260.ms, curve: Curves.easeOutCubic),

                  // ── Filtres rapides ──────────────────────────────────
                  if (_query.isNotEmpty && !_loading && !showPreview)
                    Padding(
                      padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 4),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filterChip('', 'Tous'),
                            _filterChip('film', 'Films'),
                            _filterChip('serie', 'Séries'),
                            _filterChip('anime', 'Anime'),
                            _toggleChip('⭐ 7+', _topRatedOnly, (v) {
                              setState(() => _topRatedOnly = v);
                            }),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 240.ms).slideX(begin: 0.04, end: 0, duration: 280.ms, curve: Curves.easeOutCubic),

                  // ── Contenu ──────────────────────────────────────────
                  Expanded(child: _buildContent(context, pad, isTV)),
                ],
              ),

              // ── Prévisualisation des résultats (mobile) ────────────────
              if (showPreview) ...[
                // Voile flouté : tap = refermer la prévisualisation.
                Positioned(
                  top: _searchBarSpace,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closePreview,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          color: Theme.of(context).brightness == Brightness.light
                              ? Colors.white.withValues(alpha: 0.55)
                              : Colors.black.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 280.ms, curve: Curves.easeOut),
                ),
                Positioned(
                  top: _searchBarSpace + 6,
                  left: pad.left,
                  right: pad.right,
                  child: SearchPreviewPanel(
                    query: _query,
                    items: _previewItems(),
                    totalCount: total,
                    loading: _loading && _results.isEmpty && _animeResults.isEmpty,
                    onTapItem: _openPreviewItem,
                    onViewAll: _closePreview,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _typeFilter == value;
    return _toggleChip(label, selected, (v) {
      setState(() => _typeFilter = value);
    });
  }

  Widget _toggleChip(String label, bool selected, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!selected);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
                : Neo.bgOverlay(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Neo.bgBorder(context).withValues(alpha: 0.25),
              width: selected ? 1.5 : 0.5,
            ),
          ),
          child: Text(
            label,
            style: Neo.labelMedium(context).copyWith(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Neo.textSecondary(context),
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// État initial : historique de recherche + tendances en rail horizontal.
  Widget _buildInitial(BuildContext context, EdgeInsets pad) {
    final content = context.watch<ContentProvider>();
    // Tendances : Top du jour d'abord, complété par les recommandations.
    final trending = <Content>[
      ...content.dailyTop,
      ...content.recommended,
      ...content.popularFilms,
    ];
    final seenIds = <int>{};
    trending.retainWhere((item) => seenIds.add(item.id));
    final visibleTrending = trending.take(8).toList();
    final isTV = NeoTheme.isTV(context);

    return AnimatedBuilder(
      animation: SearchHistory.instance,
      builder: (context, _) {
        final recent = SearchHistory.instance.items;
        return ListView(
          padding: EdgeInsets.fromLTRB(0, 8, 0, isTV ? 32 : 132),
          children: [
            if (recent.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad.left),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Recherches récentes', style: Neo.titleMedium(context)),
                    ),
                    TextButton(
                      onPressed: () => SearchHistory.instance.clear(),
                      child: Text(
                        'Effacer',
                        style: Neo.labelMedium(context)
                            .copyWith(color: Neo.textTertiary(context)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad.left),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < recent.length; i++)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _controller.text = recent[i];
                          _search(recent[i]);
                        },
                        onLongPress: () {
                          HapticFeedback.mediumImpact();
                          SearchHistory.instance.remove(recent[i]);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: Neo.bgOverlay(context),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Neo.bgBorder(context).withValues(alpha: 0.25),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history_rounded,
                                  size: 15, color: Neo.textTertiary(context)),
                              const SizedBox(width: 6),
                              Text(recent[i], style: Neo.bodyMedium(context)),
                            ],
                          ),
                        ),
                      ).springPop(index: i),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (visibleTrending.isNotEmpty && !isTV) ...[
              SectionHeader(
                title: 'Tendances du moment',
                subtitle: 'Les contenus les plus recherchés sur Neo-Stream.',
                icon: Icons.trending_up_rounded,
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: NeoTheme.cardHeight(context) + 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: EdgeInsets.fromLTRB(pad.left, 20, pad.right, 20),
                  itemCount: visibleTrending.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: ContentCard(
                        content: visibleTrending[index],
                        variant: CardVariant.standard,
                        index: index,
                        onTap: () => _openTrending(visibleTrending[index]),
                      ),
                    ).staggeredFade(index: index);
                  },
                ),
              ),
              const SizedBox(height: 24),
            ] else
              _buildEmpty(context, false, compact: true),
          ],
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, EdgeInsets pad, bool isTV) {
    if (_query.isEmpty) return _buildInitial(context, pad);
    if (_loading && _results.isEmpty) return _buildShimmer(context, isTV, pad);
    if (_error != null) return _buildEmpty(context, true);
    if (_results.isEmpty && _animeResults.isEmpty) return _buildEmpty(context, false);

    var films = _results;
    var animes = _animeResults;
    if (_typeFilter == 'film') animes = [];
    if (_typeFilter == 'serie') {
      films = films.where((c) => c.contentType == 'serie').toList();
      animes = [];
    }
    if (_typeFilter == 'anime') films = [];
    if (_topRatedOnly) {
      films = films.where((c) => (c.rating ?? 0) >= 7).toList();
    }

    final all = <dynamic>[...films, ...animes];
    final cols = isTV ? 5 : (MediaQuery.of(context).size.width >= 900 ? 4 : 2);
    final useGrid = isTV || MediaQuery.of(context).size.width >= 600;

    if (useGrid) {
      final total = all.length;
      return Focus(
        canRequestFocus: false,
        onKeyEvent: isTV
            ? (node, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                    _focusedResultIndex % cols == 0) {
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  final posInRow = _focusedResultIndex % cols;
                  if (posInRow == cols - 1 ||
                      _focusedResultIndex == total - 1) {
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              }
            : null,
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, isTV ? 32 : 132),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              childAspectRatio: 2 / 3,
              crossAxisSpacing: NeoTheme.gridSpacing(context),
              mainAxisSpacing: NeoTheme.gridSpacing(context),
            ),
            itemCount: all.length,
            itemBuilder: (ctx, i) => _buildCard(ctx, all[i], i),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, isTV ? 32 : 132),
      itemCount: all.length,
      itemBuilder: (ctx, i) => Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: _buildCard(ctx, all[i], i),
      ),
    );
  }

  Widget _buildCard(BuildContext context, dynamic item, int index) {
    Content content;
    VoidCallback onTap;

    if (item is Anime) {
      content = Content(
        id: item.id, title: item.title, description: item.synopsis,
        contentType: 'anime', genres: item.genres, rating: 0,
        poster: item.posterUrl, keywords: [], watchLinks: [],
        releaseDate: null, createdAt: null,
      );
      onTap = () => _openAnime(item);
    } else {
      content = item as Content;
      onTap = () => _openDetail(content);
    }

    return ContentCard(
      content: content,
      variant: NeoTheme.isTV(context) ? CardVariant.standard : CardVariant.search,
      index: index,
      onTap: onTap,
      autofocus: index == 0 && _autoFocusFirstResult,
      onFocusChange: (focused) {
        if (focused) {
          _focusedResultIndex = index;
          if (_autoFocusFirstResult) {
            setState(() => _autoFocusFirstResult = false);
          }
        }
      },
    );
  }

  Widget _buildEmpty(BuildContext context, bool isError, {bool compact = false}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.wifi_off_rounded
                  : _query.isEmpty ? Icons.search_rounded
                  : Icons.search_off_rounded,
              size: 56, color: Neo.textDisabled(context),
            ),
            SizedBox(height: 16),
            Text(
              isError ? 'Erreur de recherche'
                  : _query.isEmpty ? 'Recherchez un film, série ou anime'
                  : 'Aucun résultat pour "$_query"',
              style: Neo.titleMedium(context),
              textAlign: TextAlign.center,
            ),
            if (_query.isEmpty) ...[
              SizedBox(height: 8),
              Text('Tapez au moins 2 caractères',
                  style: Neo.bodyMedium(context).copyWith(color: Neo.textSecondary(context)),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTVSearchButton(BuildContext context) {
    final hasQuery = _query.isNotEmpty;
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ElevatedButton.icon(
        autofocus: true,
        onPressed: _openSearchDialog,
        icon: Icon(Icons.search_rounded, size: 22),
        label: Text(
          hasQuery ? 'Modifier : "$_query"' : 'Appuyer OK pour rechercher',
          overflow: TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: hasQuery ? Theme.of(context).colorScheme.primary : Neo.bgOverlay(context),
          foregroundColor: hasQuery
              ? Neo.readableOnPrimary(context)
              : Neo.textPrimary(context),
          minimumSize: Size(double.infinity, 52),
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NeoTheme.radiusLg)),
          side: BorderSide(
            color: hasQuery ? Theme.of(context).colorScheme.primary : Neo.bgBorder(context).withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer(BuildContext context, bool isTV, EdgeInsets pad) {
    final cols = isTV ? 5 : 2;
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, isTV ? 32 : 132),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: NeoTheme.gridSpacing(context),
        mainAxisSpacing: NeoTheme.gridSpacing(context),
      ),
      itemCount: cols * 3,
      itemBuilder: (_1, _2) => Shimmer.fromColors(
        baseColor: Neo.bgElevated(context),
        highlightColor: Neo.bgBorder(context).withValues(alpha: 0.3),
        child: Container(
          decoration: BoxDecoration(
            color: Neo.bgElevated(context),
            borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
          ),
        ),
      ),
    );
  }
}

// ── Dialogue de recherche TV ─────────────────────────────────────────────────

class _SearchDialog extends StatefulWidget {
  final TextEditingController controller;
  _SearchDialog({required this.controller});

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.controller.text);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_ctrl.text);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Neo.bgOverlay(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rechercher', style: Neo.titleMedium(context)),
            SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              style: Neo.bodyLarge(context).copyWith(color: Neo.textPrimary(context)),
              decoration: InputDecoration(
                hintText: 'Titre, genre, acteur...',
                hintStyle: Neo.bodyMedium(context).copyWith(color: Neo.textDisabled(context)),
                prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.primary),
                filled: true,
                fillColor: Neo.bgOverlay(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Annuler'),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  autofocus: false,
                  onPressed: _submit,
                  icon: Icon(Icons.search_rounded),
                  label: Text('Rechercher'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Neo.readableOnPrimary(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
