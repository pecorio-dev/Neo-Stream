import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/tv_config.dart';
import '../../models/content.dart';
import '../../models/anime.dart';
import '../../services/api_service.dart';
import '../../widgets/tv_wrapper.dart';
import '../../widgets/tv_focusable_card.dart';
import 'tv_detail_screen.dart';
import 'tv_anime_detail_screen.dart';

class TVSearchScreen extends StatefulWidget {
  const TVSearchScreen({super.key});

  @override
  State<TVSearchScreen> createState() => _TVSearchScreenState();
}

class _TVSearchScreenState extends State<TVSearchScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  List<Content> _results = [];
  List<Anime> _animeResults = [];
  bool _isLoading = false;
  String _lastQuery = '';
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (query.trim().length >= 2 && query != _lastQuery) {
        _performSearch(query.trim());
      } else if (query.trim().isEmpty) {
        setState(() {
          _results = [];
          _animeResults = [];
          _lastQuery = '';
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() { _isLoading = true; _lastQuery = query; });
    try {
      final results = await _api.searchContent(query);
      final contentResults = <Content>[];
      final animeResults = <Anime>[];
      for (final item in results) {
        if (item.contentType == 'anime') {
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
        } else {
          contentResults.add(item);
        }
      }
      if (!mounted) return;
      setState(() {
        _results = contentResults.where((c) => c.hasPoster).toList();
        _animeResults = animeResults.where((a) => a.hasPoster).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _results = []; _animeResults = []; _isLoading = false; });
    }
  }

  List<Content> get _filteredResults {
    if (_filterType == 'all') return _results;
    if (_filterType == 'film') return _results.where((c) => c.isFilm).toList();
    if (_filterType == 'serie') return _results.where((c) => c.isSerie).toList();
    return _results.where((c) => c.contentType == _filterType).toList();
  }

  List<Anime> get _filteredAnimeResults {
    if (_filterType == 'all' || _filterType == 'anime') return _animeResults;
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final contents = _filteredResults;
    final animes = _filteredAnimeResults;
    final total = contents.length + animes.length;

    return TVWrapper(
      title: 'Recherche',
      showBackButton: true,
      onBack: () => Navigator.pop(context),
      child: Column(
        children: [
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
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, color: TVTheme.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        setState(() { _results = []; _animeResults = []; _lastQuery = ''; });
                        _searchFocusNode.requestFocus();
                      },
                    ),
                ],
              ),
            ),
          ),
          if (_results.isNotEmpty || _animeResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Wrap(
                spacing: 12,
                children: [
                  _FilterChip(label: 'Tous', type: 'all', count: _results.length + _animeResults.length, currentType: _filterType, onSelected: (t) => setState(() => _filterType = t)),
                  _FilterChip(label: 'Films', type: 'film', count: _results.where((c) => c.isFilm).length, currentType: _filterType, onSelected: (t) => setState(() => _filterType = t)),
                  _FilterChip(label: 'Series', type: 'serie', count: _results.where((c) => c.isSerie).length, currentType: _filterType, onSelected: (t) => setState(() => _filterType = t)),
                  if (_animeResults.isNotEmpty)
                    _FilterChip(label: 'Anime', type: 'anime', count: _animeResults.length, currentType: _filterType, onSelected: (t) => setState(() => _filterType = t)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: TVTheme.accentRed))
                : total == 0
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_lastQuery.isEmpty ? Icons.search : Icons.search_off, size: 64, color: TVTheme.textDisabled),
                            const SizedBox(height: 16),
                            Text(
                              _lastQuery.isEmpty ? 'Rechercher un film ou une serie' : 'Aucun resultat pour "$_lastQuery"',
                              style: const TextStyle(color: TVTheme.textSecondary, fontSize: 18),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 0.55,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                        ),
                        itemCount: total,
                        itemBuilder: (context, index) {
                          if (index < contents.length) {
                            return _SearchResultCard(
                              content: contents[index],
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TVDetailScreen(contentId: contents[index].id))),
                            );
                          } else {
                            final anime = animes[index - contents.length];
                            return _SearchResultCard(
                              anime: anime,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TVAnimeDetailScreen(animeId: anime.id))),
                            );
                          }
                        },
                      ),
          ),
        ],
      ),
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

  const _SearchResultCard({this.content, this.anime, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = content?.title ?? anime?.title ?? '';
    final posterUrl = content?.fullPosterUrl ?? anime?.posterUrl ?? '';
    final typeLabel = content?.typeLabel ?? 'Anime';

    return TVFocusableCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: TVTheme.cardColor),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (posterUrl.isNotEmpty)
                    CachedNetworkImage(imageUrl: posterUrl, fit: BoxFit.cover, errorWidget: (_, __, ___) => _placeholder())
                  else
                    _placeholder(),
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                      child: Text(typeLabel, style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TVTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(color: TVTheme.cardColor, child: const Center(child: Icon(Icons.movie_outlined, color: TVTheme.textDisabled, size: 40)));
}