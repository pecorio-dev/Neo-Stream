import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/tv_config.dart';
import '../../models/content.dart';
import '../../models/anime.dart';
import '../../services/api_service.dart';
import '../../widgets/tv_wrapper.dart';
import '../../widgets/tv_focusable_card.dart';
import '../../widgets/tv_content_card.dart';
import '../../widgets/metadata_pill.dart';
import '../../widgets/shimmer_loading.dart';
import 'tv_detail_screen.dart';
import 'tv_anime_detail_screen.dart';

class TVSearchScreen extends StatefulWidget {
  final String? query;
  const TVSearchScreen({super.key, this.query});

  @override
  State<TVSearchScreen> createState() => _TVSearchScreenState();
}

class _TVSearchScreenState extends State<TVSearchScreen> {
  static const int _crossAxisCount = 4;
  static const int _filmsPerPage = 20;
  static const int _seriesPerPage = 20;
  static const int _animePerPage = 10;

  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _gridCtrl = ScrollController();
  Timer? _debounce;
  List<Content> _filmResults = [];
  List<Content> _serieResults = [];
  List<Anime> _animeResults = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String _lastQuery = '';
  String? _error;
  bool _hasText = false;
  String _filterType = 'all';
  int _searchId = 0;
  int _focusedIndex = 0;

  int _pageFilms = 1;
  int _pageSeries = 1;
  int _pageAnime = 1;
  bool _hasMoreFilms = true;
  bool _hasMoreSeries = true;
  bool _hasMoreAnime = true;

  List<Content> get _allContent => [..._filmResults, ..._serieResults];

  @override
  void initState() {
    super.initState();
    _gridCtrl.addListener(_onGridScroll);
    if (widget.query != null && widget.query!.isNotEmpty) {
      _searchController.text = widget.query!;
      _hasText = true;
      _performSearch(widget.query!);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(TVSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      if (widget.query != null && widget.query!.isNotEmpty) {
        _searchController.text = widget.query!;
        _hasText = true;
        _performSearch(widget.query!);
      } else {
        _searchController.clear();
        _hasText = false;
        _resetResults();
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _gridCtrl.removeListener(_onGridScroll);
    _gridCtrl.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _resetResults() {
    setState(() {
      _filmResults = [];
      _serieResults = [];
      _animeResults = [];
      _lastQuery = '';
      _error = null;
      _pageFilms = 1;
      _pageSeries = 1;
      _pageAnime = 1;
      _hasMoreFilms = true;
      _hasMoreSeries = true;
      _hasMoreAnime = true;
      _isLoadingMore = false;
      _focusedIndex = 0;
    });
  }

  void _onGridScroll() {
    if (!_gridCtrl.hasClients || _isLoading || _isLoadingMore) return;
    if (_gridCtrl.position.pixels > _gridCtrl.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  void _onSearchChanged(String query) {
    // Le bouton clear dépend de l'état vide : rebuild léger uniquement
    // quand cet état bascule, pas à chaque frappe.
    final hasText = query.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      // Requête identique ignorée (anti-refetch) ; anti-race via _searchId.
      if (query.trim().length >= 2 && query.trim() != _lastQuery) {
        _performSearch(query.trim());
      } else if (query.trim().isEmpty) {
        _resetResults();
      }
    });
  }

  Future<void> _performSearch(String query, {bool force = false}) async {
    final q = query.trim();
    if (q.length < 2) return;
    // Pas de refetch inutile : même requête déjà affichée.
    if (!force &&
        q == _lastQuery &&
        !_isLoading &&
        (_filmResults.isNotEmpty ||
            _serieResults.isNotEmpty ||
            _animeResults.isNotEmpty)) {
      return;
    }
    final id = ++_searchId;
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _error = null;
      _lastQuery = q;
      _filmResults = [];
      _serieResults = [];
      _animeResults = [];
      _pageFilms = 1;
      _pageSeries = 1;
      _pageAnime = 1;
      _hasMoreFilms = true;
      _hasMoreSeries = true;
      _hasMoreAnime = true;
      _focusedIndex = 0;
    });
    try {
      final results = await Future.wait([
        _api.searchContentPaged(query,
            page: 1, type: 'film', perPage: _filmsPerPage),
        _api.searchContentPaged(query,
            page: 1, type: 'serie', perPage: _seriesPerPage),
        _api.searchAnimePaged(query, page: 1, limit: _animePerPage),
      ]);
      if (!mounted || id != _searchId) return;
      final films = results[0] as PagedContentResult;
      final series = results[1] as PagedContentResult;
      final animes = results[2] as PagedAnimeResult;
      setState(() {
        _filmResults = films.items;
        _serieResults = series.items;
        _animeResults = animes.items
            .map((e) {
              try {
                return Anime.fromJson(e);
              } catch (_) {
                return null;
              }
            })
            .whereType<Anime>()
            .where((a) => a.hasPoster)
            .toList();
        _hasMoreFilms = films.hasMore;
        _hasMoreSeries = series.hasMore;
        _hasMoreAnime = animes.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || id != _searchId) return;
      setState(() {
        _filmResults = [];
        _serieResults = [];
        _animeResults = [];
        _isLoading = false;
        _error = humanizeApiError(e);
      });
    }
  }

  /// Charge la page suivante selon le filtre actif.
  /// 'all' => films + séries + anime en parallèle ; sinon un seul type.
  /// Anti-race via [_searchId] : les réponses obsolètes sont ignorées.
  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || _lastQuery.isEmpty) return;
    final wantsFilms = _filterType == 'all' || _filterType == 'film';
    final wantsSeries = _filterType == 'all' || _filterType == 'serie';
    final wantsAnime = _filterType == 'all' || _filterType == 'anime';
    if ((wantsFilms && _hasMoreFilms) ||
        (wantsSeries && _hasMoreSeries) ||
        (wantsAnime && _hasMoreAnime)) {
      // au moins un type à charger
    } else {
      return;
    }
    final id = _searchId;
    final query = _lastQuery;
    setState(() => _isLoadingMore = true);
    try {
      final futures = <Future>[];
      if (wantsFilms && _hasMoreFilms) {
        futures.add(_api.searchContentPaged(query,
            page: _pageFilms + 1, type: 'film', perPage: _filmsPerPage));
      }
      if (wantsSeries && _hasMoreSeries) {
        futures.add(_api.searchContentPaged(query,
            page: _pageSeries + 1, type: 'serie', perPage: _seriesPerPage));
      }
      if (wantsAnime && _hasMoreAnime) {
        futures.add(
            _api.searchAnimePaged(query, page: _pageAnime + 1, limit: _animePerPage));
      }
      if (futures.isEmpty) {
        setState(() => _isLoadingMore = false);
        return;
      }
      final results = await Future.wait(futures);
      if (!mounted || id != _searchId) return;
      int cursor = 0;
      setState(() {
        if (wantsFilms && _hasMoreFilms) {
          final r = results[cursor++] as PagedContentResult;
          _filmResults = [..._filmResults, ...r.items];
          _pageFilms += 1;
          _hasMoreFilms = r.hasMore;
        }
        if (wantsSeries && _hasMoreSeries) {
          final r = results[cursor++] as PagedContentResult;
          _serieResults = [..._serieResults, ...r.items];
          _pageSeries += 1;
          _hasMoreSeries = r.hasMore;
        }
        if (wantsAnime && _hasMoreAnime) {
          final r = results[cursor++] as PagedAnimeResult;
          final more = r.items
              .map((e) {
                try {
                  return Anime.fromJson(e);
                } catch (_) {
                  return null;
                }
              })
              .whereType<Anime>()
              .where((a) => a.hasPoster)
              .toList();
          _animeResults = [..._animeResults, ...more];
          _pageAnime += 1;
          _hasMoreAnime = r.hasMore;
        }
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || id != _searchId) return;
      setState(() => _isLoadingMore = false);
    }
  }

  bool get _hasMoreForFilter {
    switch (_filterType) {
      case 'film':
        return _hasMoreFilms;
      case 'serie':
        return _hasMoreSeries;
      case 'anime':
        return _hasMoreAnime;
      default:
        return _hasMoreFilms || _hasMoreSeries || _hasMoreAnime;
    }
  }

  List<Content> get _filteredResults {
    if (_filterType == 'all') return _allContent;
    if (_filterType == 'film') return _filmResults;
    if (_filterType == 'serie') return _serieResults;
    return _allContent.where((c) => c.contentType == _filterType).toList();
  }

  List<Anime> get _filteredAnimeResults {
    if (_filterType == 'all' || _filterType == 'anime') return _animeResults;
    return [];
  }

  bool get _isEmbedded => widget.query != null;

  /// État d'erreur réseau soigné avec bouton Réessayer focusable (D-pad OK).
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 64, color: TVTheme.textDisabled),
          const SizedBox(height: 16),
          const Text('Connexion impossible',
              style: TextStyle(color: TVTheme.textPrimary, fontSize: 20)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 64),
            child: Text(
              _error ?? 'Vérifiez votre réseau puis réessayez.',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: TVTheme.textSecondary, fontSize: 15),
            ),
          ),
          const SizedBox(height: 24),
          _TVRetryButton(
            label: 'Réessayer',
            onSelected: () => _performSearch(_lastQuery, force: true),
          ),
        ],
      ),
    );
  }

  /// Empty-state soigné : invite initiale vs. zéro résultat.
  Widget _buildEmptyState() {
    final isInitial = _lastQuery.isEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isInitial ? Icons.search : Icons.search_off,
              size: 64, color: TVTheme.textDisabled),
          const SizedBox(height: 16),
          Text(
            isInitial
                ? 'Rechercher un film, une série ou un anime'
                : 'Aucun résultat pour "$_lastQuery"',
            textAlign: TextAlign.center,
            style: const TextStyle(color: TVTheme.textSecondary, fontSize: 18),
          ),
          if (!isInitial) ...[
            const SizedBox(height: 8),
            const Text(
              'Essayez un autre titre ou une autre orthographe.',
              style:
                  TextStyle(color: TVTheme.textDisabled, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contents = _filteredResults;
    final animes = _filteredAnimeResults;
    final total = contents.length + animes.length;
    final hasResults = _filmResults.isNotEmpty ||
        _serieResults.isNotEmpty ||
        _animeResults.isNotEmpty;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isEmbedded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: TVTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TVTheme.accentRed.withValues(alpha: 0.5), width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: TVTheme.accentRed),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: _onSearchChanged,
                      // Le TextField garde son propre FocusNode : le Focus
                      // autour de la grille a canRequestFocus:false, il ne
                      // vole donc jamais le focus de la saisie.
                      style: const TextStyle(color: TVTheme.textPrimary, fontSize: 18),
                      decoration: const InputDecoration(
                        hintText: 'Titre, genre, acteur...',
                        hintStyle: TextStyle(color: TVTheme.textSecondary),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_hasText)
                    IconButton(
                      icon: const Icon(Icons.close, color: TVTheme.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _hasText = false);
                        _resetResults();
                        _searchFocusNode.requestFocus();
                      },
                    ),
                ],
              ),
            ),
          ),
        if (hasResults)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Wrap(
                spacing: 12,
                children: [
                  _FilterChip(label: 'Tous', type: 'all', count: _filmResults.length + _serieResults.length + _animeResults.length, currentType: _filterType, onSelected: (t) => setState(() => _filterType = t)),
                  _FilterChip(label: 'Films', type: 'film', count: _filmResults.length, currentType: _filterType, onSelected: (t) => setState(() => _filterType = t)),
                  _FilterChip(label: 'Séries', type: 'serie', count: _serieResults.length, currentType: _filterType, onSelected: (t) => setState(() => _filterType = t)),
                  _FilterChip(label: 'Anime', type: 'anime', count: _animeResults.length, currentType: _filterType, onSelected: (t) => setState(() => _filterType = t)),
                ],
              ),
            ),
          ),
        if (_lastQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
            child: Text(
              _isLoading
                  ? 'Recherche en cours…'
                  : _error != null
                      ? 'Échec de la recherche pour "$_lastQuery"'
                      : '$total résultat${total > 1 ? 's' : ''} pour "$_lastQuery"'
                          ' — ${_filmResults.length} film${_filmResults.length > 1 ? 's' : ''}'
                          ' · ${_serieResults.length} série${_serieResults.length > 1 ? 's' : ''}'
                          ' · ${_animeResults.length} anime${_animeResults.length > 1 ? 's' : ''}',
              style: const TextStyle(color: TVTheme.textSecondary, fontSize: 14),
            ),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading
              // Skeleton élégant (même gabarit que la grille, pas de
              // spinner brut) — dimensionnement stable, sans saut.
              ? const ShimmerSearchGrid(
                  crossAxisCount: _crossAxisCount,
                  isTV: true,
                  itemCount: 8,
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  childAspectRatio: 0.55,
                )
              : _error != null
                  ? _buildErrorState()
                  : total == 0
                  ? _buildEmptyState()
                  // Garde focus :
                  // - canRequestFocus:false => ce Focus ne vole jamais le
                  //   focus (la saisie TextField le garde).
                  // - Flèche gauche sur la 1ère colonne => handled (bloqué)
                  //   pour ne pas être éjecté vers la navbar à chaque appui.
                  //   Retour navbar : touche Retour du shell (déjà gérée) ou
                  //   navigation haut vers le champ/filtres.
                  // - Flèche droite laissée au traversal (aller OK).
                  : Focus(
                      canRequestFocus: false,
                      skipTraversal: true,
                      onKeyEvent: (node, event) {
                        if (event is! KeyDownEvent) return KeyEventResult.ignored;
                        if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                            _focusedIndex % _crossAxisCount == 0) {
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: FocusTraversalGroup(
                        policy: ReadingOrderTraversalPolicy(),
                        child: GridView.builder(
                          controller: _gridCtrl,
                          // Grille stable : cache étendu, pas de keep-alive
                          // coûteux, clés stables par carte.
                          // ignore: deprecated_member_use
                          cacheExtent: 800,
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _crossAxisCount,
                            childAspectRatio: 0.55,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 20,
                          ),
                          itemCount: total + (_hasMoreForFilter ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Loader de fin discret, pas de gros spinner.
                            if (index >= total) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: TVTheme.accentRed,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            }
                            if (index < contents.length) {
                              final c = contents[index];
                              return _SearchResultCard(
                                key: ValueKey('tv_${c.contentType}_${c.id}'),
                                content: c,
                                onFocus: () => _focusedIndex = index,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TVDetailScreen(contentId: c.id, titleHint: c.title))),
                              );
                            } else {
                              final anime = animes[index - contents.length];
                              return _SearchResultCard(
                                key: ValueKey('tv_anime_${anime.id}'),
                                anime: anime,
                                onFocus: () => _focusedIndex = index,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TVAnimeDetailScreen(animeId: anime.id))),
                              );
                            }
                          },
                        ),
                      ),
                    ),
        ),
      ],
    );

    if (_isEmbedded) {
      return body;
    }

    return TVWrapper(
      title: 'Recherche',
      showBackButton: true,
      autofocusRoot: false,
      onBack: () => Navigator.pop(context),
      child: body,
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final String type;
  final int count;
  final String currentType;
  final ValueChanged<String> onSelected;

  const _FilterChip({required this.label, required this.type, required this.count, required this.currentType, required this.onSelected});

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.type == widget.currentType;
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onSelected(widget.type);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => widget.onSelected(widget.type),
        child: AnimatedContainer(
          duration: TVConfig.focusAnimationDuration,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? TVTheme.accentRed.withValues(alpha: 0.2) : (_isFocused ? TVTheme.surfaceColor : TVTheme.cardColor),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? TVTheme.accentRed : (_isFocused ? TVTheme.accentRed : TVTheme.defaultBorderColor),
              width: _isFocused ? 2.5 : 1,
            ),
            boxShadow: _isFocused
                ? [BoxShadow(color: TVTheme.accentRed.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2)]
                : null,
          ),
          child: Text('${widget.label} (${widget.count})', style: TextStyle(
            color: isSelected || _isFocused ? TVTheme.accentRed : TVTheme.textSecondary,
            fontWeight: isSelected || _isFocused ? FontWeight.bold : FontWeight.normal,
          )),
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final Content? content;
  final Anime? anime;
  final VoidCallback onTap;
  final VoidCallback? onFocus;

  const _SearchResultCard(
      {super.key, this.content, this.anime, required this.onTap, this.onFocus});

  @override
  Widget build(BuildContext context) {
    final title = content?.title ?? anime?.title ?? '';
    final posterUrl = content?.fullPosterUrl ?? anime?.posterUrl ?? '';
    final typeLabel = content?.typeLabel ?? 'Anime';
    final rating = content?.rating;
    final progress = content != null ? effectiveCardProgress(content!) : null;

    final pills = content != null
        ? pillsFromContent(content!, short: true)
        : (anime != null ? pillsFromAnime(anime!, short: true) : const <PillData>[]);

    return TVFocusableCard(
      onTap: onTap,
      onFocus: onFocus,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(12),
      child: RepaintBoundary(
        child: TVContentCard(
          posterUrl: posterUrl,
          title: title,
          pills: pills,
          typeLabel: typeLabel,
          typeIcon: typeLabel == 'Anime' ? Icons.animation : Icons.play_arrow_rounded,
          rating: rating,
          progressPercent: (progress != null && progress > 0) ? progress : null,
        ),
      ),
    );
  }
}

/// Bouton Réessayer focusable D-pad (Entrée/OK), style cohérent TV.
class _TVRetryButton extends StatefulWidget {
  final String label;
  final VoidCallback onSelected;

  const _TVRetryButton({required this.label, required this.onSelected});

  @override
  State<_TVRetryButton> createState() => _TVRetryButtonState();
}

class _TVRetryButtonState extends State<_TVRetryButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onFocusChange: (f) => setState(() => _isFocused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onSelected();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onSelected,
        child: AnimatedContainer(
          duration: TVConfig.focusAnimationDuration,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            color: _isFocused
                ? TVTheme.accentRed
                : TVTheme.accentRed.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TVTheme.accentRed, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
