import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/tv_config.dart';
import '../../models/anime.dart';
import '../../services/api_service.dart';
import '../../widgets/tv_wrapper.dart';
import '../../widgets/tv_focusable_card.dart';
import 'tv_anime_detail_screen.dart';

class TVAnimeScreen extends StatefulWidget {
  const TVAnimeScreen({super.key});

  @override
  State<TVAnimeScreen> createState() => _TVAnimeScreenState();
}

class _TVAnimeScreenState extends State<TVAnimeScreen> {
  final ApiService _api = ApiService();
  List<Anime> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedGenre = 'all';
  String _sortBy = 'recent';
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _totalResults = 0;
  List<Map<String, dynamic>> _genreFacets = [];

  final Map<String, String> _sortLabels = {
    'recent': 'Recents',
    'title': 'Titre',
    'episodes': 'Episodes',
  };

  @override
  void initState() {
    super.initState();
    _loadContent();
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
        _genreFacets = (meta?['genres'] as List? ?? []).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = _humanizeError(error);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
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
        _isLoadingMore = false;
      });
    } catch (_) {
      setState(() {
        _page--;
        _isLoadingMore = false;
      });
    }
  }

  String _humanizeError(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('socket') || msg.contains('network') || msg.contains('connection')) {
      return 'Erreur de connexion. Verifiez votre reseau.';
    }
    return 'Erreur de chargement. Reessayez.';
  }

  void _navigateToDetail(Anime anime) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TVAnimeDetailScreen(animeId: anime.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TVWrapper(
      title: 'Anime',
      showBackButton: true,
      onBack: () => Navigator.pop(context),
      child: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: TVTheme.accentRed))
                : _errorMessage != null
                    ? _buildError()
                    : _buildGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            children: _sortLabels.keys.map((sort) {
              final isSelected = _sortBy == sort;
              return _TVFocusableChip(
                label: _sortLabels[sort]!,
                isSelected: isSelected,
                onTap: () {
                  if (_sortBy != sort) {
                    setState(() => _sortBy = sort);
                    _loadContent();
                  }
                },
              );
            }).toList(),
          ),
          if (_genreFacets.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const TVScrollPhysics(),
                children: [
                  _TVGenreChip(
                    label: 'Tous',
                    isSelected: _selectedGenre == 'all',
                    onTap: () {
                      if (_selectedGenre != 'all') {
                        setState(() => _selectedGenre = 'all');
                        _loadContent();
                      }
                    },
                  ),
                  ..._genreFacets.take(20).map((genreData) {
                    final name = genreData['name'].toString();
                    return _TVGenreChip(
                      label: name,
                      isSelected: _selectedGenre == name,
                      onTap: () {
                        if (_selectedGenre != name) {
                          setState(() => _selectedGenre = name);
                          _loadContent();
                        }
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 64, color: TVTheme.errorRed),
          const SizedBox(height: 16),
          Text(_errorMessage ?? 'Erreur', style: const TextStyle(color: TVTheme.textPrimary, fontSize: 18)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadContent,
            style: FilledButton.styleFrom(backgroundColor: TVTheme.accentRed),
            icon: const Icon(Icons.refresh),
            label: const Text('Reessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.animation_outlined, size: 64, color: TVTheme.textDisabled),
            const SizedBox(height: 16),
            const Text('Aucun anime trouve', style: TextStyle(color: TVTheme.textSecondary, fontSize: 18)),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification && notification.metrics.pixels >= notification.metrics.maxScrollExtent - 400) {
          _loadMore();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        physics: const TVScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          childAspectRatio: 0.55,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
        ),
        itemCount: _items.length + (_isLoadingMore ? 5 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Center(child: CircularProgressIndicator(color: TVTheme.accentRed));
          }
          final anime = _items[index];
          return TVFocusableCard(
            onTap: () => _navigateToDetail(anime),
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(12),
            minWidth: 160,
            maxWidth: 220,
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
                        if (anime.posterUrl != null && anime.posterUrl!.isNotEmpty)
                          Image.network(anime.posterUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                        else
                          _placeholder(),
                        Positioned(
                          top: 6, left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.animation, color: TVTheme.accentRed, size: 10),
                              const SizedBox(width: 3),
                              const Text('Anime', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                        Positioned(
                          bottom: 6, right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                            child: Text('${anime.totalEpisodes}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(anime.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TVTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                Text('${anime.totalSeasons} saison${anime.totalSeasons > 1 ? 's' : ''}', style: const TextStyle(color: TVTheme.textSecondary, fontSize: 10)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: TVTheme.cardColor,
      child: Center(child: Icon(Icons.animation, color: TVTheme.textDisabled, size: 40)),
    );
  }
}

class _TVFocusableChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TVFocusableChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TVFocusableChip> createState() => _TVFocusableChipState();
}

class _TVFocusableChipState extends State<_TVFocusableChip> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: TVConfig.focusAnimationDuration,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: widget.isSelected ? TVTheme.heroGradient : null,
            color: widget.isSelected ? null : (_isFocused ? TVTheme.surfaceColor : TVTheme.cardColor),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? TVTheme.accentRed
                  : (_isFocused ? TVTheme.accentRed : TVTheme.defaultBorderColor),
              width: _isFocused ? 2.5 : 1,
            ),
            boxShadow: _isFocused
                ? [BoxShadow(color: TVTheme.accentRed.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2)]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isSelected || _isFocused ? Colors.white : TVTheme.textSecondary,
              fontWeight: widget.isSelected || _isFocused ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _TVGenreChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TVGenreChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TVGenreChip> createState() => _TVGenreChipState();
}

class _TVGenreChipState extends State<_TVGenreChip> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final genreColor = TVTheme.getGenreColor(widget.label);
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: TVConfig.focusAnimationDuration,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? genreColor.withValues(alpha: 0.2)
                : (_isFocused ? genreColor.withValues(alpha: 0.15) : TVTheme.cardColor),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? genreColor
                  : (_isFocused ? genreColor : TVTheme.defaultBorderColor),
              width: _isFocused ? 2.5 : 1,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isSelected || _isFocused ? genreColor : TVTheme.textSecondary,
              fontWeight: widget.isSelected || _isFocused ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}