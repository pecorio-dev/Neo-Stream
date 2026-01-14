import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';
import '../../widgets/movie_card.dart';
import '../../widgets/loading_widgets.dart';
import '../../widgets/enhanced_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/favorite_item.dart';
import '../../widgets/account_switcher_button.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with TickerProviderStateMixin {
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  
  final ScrollController _scrollController = ScrollController();
  bool _showFab = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    
    _fabAnimationController = AnimationController(
      duration: AppConstants.mediumAnimation,
      vsync: this,
    );
    
    _fabAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    ));

    _scrollController.addListener(_onScroll);
    
    // Charger les favoris au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesProvider).loadFavorites();
    });
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShowFab = _scrollController.offset > 200;
    if (shouldShowFab != _showFab) {
      setState(() => _showFab = shouldShowFab);
      if (_showFab) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(favoritesProvider);
    
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(provider),
          _buildSearchSection(),
          _buildFiltersSection(provider),
          _buildStatsSection(provider),
          _buildFavoritesGrid(provider),
        ],
      ),
      floatingActionButton: _buildScrollToTopFab(),
    );
  }

  Widget _buildAppBar(FavoritesProvider provider) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: AppTheme.backgroundPrimary,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Favoris',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.accentNeon, AppTheme.accentSecondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppTheme.backgroundPrimary.withOpacity(0.8),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort, color: AppTheme.textPrimary),
          color: AppTheme.surface,
          onSelected: (value) => _handleSortSelection(provider, value),
          itemBuilder: (context) => [
            _buildPopupMenuItem('date', 'Date d\'ajout', Icons.access_time),
            _buildPopupMenuItem('title', 'Titre', Icons.sort_by_alpha),
            _buildPopupMenuItem('rating', 'Note', Icons.star),
            _buildPopupMenuItem('year', 'Année', Icons.calendar_today),
            const PopupMenuDivider(),
            _buildPopupMenuItem('clear', 'Effacer tout', Icons.clear_all),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: AppTheme.textPrimary),
          onPressed: () => ref.read(favoritesProvider).loadFavorites(),
        ),
        const Padding(
          padding: EdgeInsets.only(right: 8),
          child: AccountSwitcherButton(
            isCompact: true,
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(String value, String text, IconData icon) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  void _handleSortSelection(FavoritesProvider provider, String value) {
    switch (value) {
      case 'date':
        provider.setSortBy(FavoritesSortBy.dateAdded);
        break;
      case 'title':
        provider.setSortBy(FavoritesSortBy.title);
        break;
      case 'rating':
        provider.setSortBy(FavoritesSortBy.rating);
        break;
      case 'year':
        provider.setSortBy(FavoritesSortBy.year);
        break;
      case 'clear':
        _showClearAllDialog();
        break;
    }
  }

  Widget _buildSearchSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.accentNeon.withOpacity(0.3),
            ),
          ),
          child: TextField(
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Rechercher dans les favoris...',
              hintStyle: TextStyle(color: AppTheme.textSecondary),
              prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (query) {
              setState(() => _searchQuery = query);
              ref.read(favoritesProvider).setSearchQuery(query);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersSection(FavoritesProvider provider) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          _buildQuickFilters(provider),
          if (provider.searchQuery.isNotEmpty ||
              provider.selectedGenre.isNotEmpty ||
              provider.selectedType.isNotEmpty)
            _buildActiveFilters(provider),
        ],
      ),
    );
  }

  Widget _buildQuickFilters(FavoritesProvider provider) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildTypeFilter(provider),
          const SizedBox(width: 8),
          _buildGenreFilter(provider),
          const SizedBox(width: 8),
          if (provider.searchQuery.isNotEmpty ||
              provider.selectedGenre.isNotEmpty ||
              provider.selectedType.isNotEmpty)
            _buildClearFiltersButton(provider),
        ],
      ),
    );
  }

  Widget _buildTypeFilter(FavoritesProvider provider) {
    return DropdownButton<String>(
      value: provider.selectedType.isEmpty ? 'Tous' : 
             provider.selectedType == 'movie' ? 'Films' : 'Séries',
      dropdownColor: AppTheme.surface,
      style: const TextStyle(color: AppTheme.textPrimary),
      underline: Container(),
      items: const [
        DropdownMenuItem(value: 'Tous', child: Text('Tous')),
        DropdownMenuItem(value: 'Films', child: Text('Films')),
        DropdownMenuItem(value: 'Séries', child: Text('Séries')),
      ],
      onChanged: (value) {
        String type = '';
        if (value == 'Films') type = 'movie';
        if (value == 'Séries') type = 'series';
        provider.setTypeFilter(type);
      },
    );
  }

  Widget _buildGenreFilter(FavoritesProvider provider) {
    return DropdownButton<String>(
      value: provider.selectedGenre.isEmpty ? 'Tous les genres' : provider.selectedGenre,
      dropdownColor: AppTheme.surface,
      style: const TextStyle(color: AppTheme.textPrimary),
      underline: Container(),
      items: provider.availableGenres.map((genre) {
        return DropdownMenuItem<String>(
          value: genre == 'Tous' ? 'Tous les genres' : genre,
          child: Text(genre == 'Tous' ? 'Tous les genres' : genre),
        );
      }).toList(),
      onChanged: (value) {
        provider.setGenreFilter(value == 'Tous les genres' ? '' : value ?? '');
      },
    );
  }

  Widget _buildClearFiltersButton(FavoritesProvider provider) {
    return ElevatedButton.icon(
      onPressed: provider.clearFilters,
      icon: const Icon(Icons.clear_all, size: 16),
      label: const Text('Effacer', style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.errorColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildActiveFilters(FavoritesProvider provider) {
    final activeFilters = <String>[];
    
    if (provider.searchQuery.isNotEmpty) {
      activeFilters.add('Recherche: "${provider.searchQuery}"');
    }
    if (provider.selectedGenre.isNotEmpty) {
      activeFilters.add('Genre: ${provider.selectedGenre}');
    }
    if (provider.selectedType.isNotEmpty) {
      activeFilters.add('Type: ${provider.selectedType == 'movie' ? 'Films' : 'Séries'}');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: activeFilters.map((filter) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accentNeon.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accentNeon.withOpacity(0.5)),
            ),
            child: Text(
              filter,
              style: const TextStyle(
                color: AppTheme.accentNeon,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsSection(FavoritesProvider provider) {
    if (!provider.hasFavorites && !provider.isLoading) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${provider.favorites.length} favori${provider.favorites.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            if (provider.totalCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${provider.movieCount} films',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${provider.seriesCount} séries',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesGrid(FavoritesProvider provider) {
    if (provider.isLoading) {
      return const SliverFillRemaining(
        child: Center(child: NeonLoadingIndicator()),
      );
    }

    if (provider.hasError) {
      return SliverFillRemaining(
        child: _buildErrorWidget(provider),
      );
    }

    if (provider.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyWidget(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final favorite = provider.favorites[index];
            return _buildFavoriteCard(favorite, provider);
          },
          childCount: provider.favorites.length,
        ),
      ),
    );
  }

  Widget _buildFavoriteCard(FavoriteItem favorite, FavoritesProvider provider) {
    return GestureDetector(
      onTap: () => _onFavoriteTap(favorite),
      onLongPress: () => _showFavoriteOptions(favorite, provider),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Stack(
                  children: [
                    // Image de fond
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: favorite.hasValidPoster
                          ? EnhancedNetworkImage(
                              imageUrl: favorite.poster,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: Container(
                                color: AppTheme.surface,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentNeon),
                                  ),
                                ),
                              ),
                              errorWidget: Container(
                                color: AppTheme.surface,
                                child: const Center(
                                  child: Icon(
                                    Icons.movie,
                                    color: AppTheme.textSecondary,
                                    size: 40,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: AppTheme.surface,
                              child: const Center(
                                child: Icon(
                                  Icons.movie,
                                  color: AppTheme.textSecondary,
                                  size: 40,
                                ),
                              ),
                            ),
                    ),
                    // Badge type
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: favorite.type == 'movie' 
                              ? AppTheme.accentNeon.withOpacity(0.9)
                              : AppTheme.accentSecondary.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          favorite.type == 'movie' ? 'Film' : 'Série',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // Badge note
                    if (favorite.numericRating > 0)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getRatingColor(favorite.numericRating).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Colors.white, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                favorite.numericRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
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
            // Informations
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    favorite.displayTitle,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (favorite.releaseYear > 0) ...[
                        Text(
                          favorite.releaseYear.toString(),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (favorite.genres.isNotEmpty) ...[
                          const Text(
                            ' • ',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                      if (favorite.genres.isNotEmpty)
                        Expanded(
                          child: Text(
                            favorite.formattedGenres,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 8.0) return Colors.green;
    if (rating >= 6.0) return Colors.orange;
    return Colors.red;
  }

  Widget _buildErrorWidget(FavoritesProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: AppTheme.errorColor,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Erreur de chargement',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            provider.errorMessage,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: provider.retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            color: AppTheme.textSecondary.withOpacity(0.5),
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun favori',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ajoutez des films et séries à vos favoris\npour les retrouver ici',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Naviguer vers l'écran des films
              DefaultTabController.of(context)?.animateTo(0);
            },
            icon: const Icon(Icons.explore),
            label: const Text('Découvrir des films'),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToTopFab() {
    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton(
        onPressed: () {
          _scrollController.animateTo(
            0,
            duration: AppConstants.mediumAnimation,
            curve: Curves.easeInOut,
          );
        },
        backgroundColor: AppTheme.accentNeon,
        child: const Icon(
          Icons.keyboard_arrow_up,
          color: AppTheme.backgroundPrimary,
        ),
      ),
    );
  }

  void _onFavoriteTap(FavoriteItem favorite) {
    if (favorite.movieData != null) {
      // Naviguer vers les détails du film
      Navigator.pushNamed(
        context,
        '/movie-detail',
        arguments: favorite.movieData,
      );
    } else if (favorite.seriesData != null) {
      // Naviguer vers les détails de la série
      Navigator.pushNamed(
        context,
        '/series-detail',
        arguments: favorite.seriesData,
      );
    }
  }

  void _showFavoriteOptions(FavoriteItem favorite, FavoritesProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FavoriteOptionsBottomSheet(
        favorite: favorite,
        provider: provider,
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Effacer tous les favoris',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer tous vos favoris ? Cette action est irréversible.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(favoritesProvider).clearAllFavorites();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Effacer tout'),
          ),
        ],
      ),
    );
  }
  
  static void _shareContent(BuildContext context, FavoriteItem favorite) {
    final String shareText = favorite.type == 'movie'
        ? 'Découvre ce film: ${favorite.displayTitle} (${favorite.releaseYear})\n\nNote: ${favorite.numericRating}/10\nGenres: ${favorite.formattedGenres}\n\nPartagé depuis NeoStream'
        : 'Découvre cette série: ${favorite.displayTitle} (${favorite.releaseYear})\n\nNote: ${favorite.numericRating}/10\nGenres: ${favorite.formattedGenres}\n\nPartagé depuis NeoStream';
    
    Share.share(
      shareText,
      subject: 'Recommandation NeoStream: ${favorite.displayTitle}',
    );
  }
}

class _FavoriteOptionsBottomSheet extends StatelessWidget {
  final FavoriteItem favorite;
  final FavoritesProvider provider;

  const _FavoriteOptionsBottomSheet({
    required this.favorite,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 90,
                  child: favorite.hasValidPoster
                    ? EnhancedNetworkImage(
                        imageUrl: favorite.poster,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          color: AppTheme.backgroundSecondary,
                          child: const Icon(Icons.movie, color: AppTheme.textSecondary),
                        ),
                      )
                    : Container(
                        color: AppTheme.backgroundSecondary,
                        child: const Icon(Icons.movie, color: AppTheme.textSecondary),
                      ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      favorite.displayTitle,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${favorite.releaseYear} • ${favorite.formattedGenres}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ajouté le ${_formatDate(favorite.addedAt)}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (favorite.movieData != null)
            _buildOption(
              icon: Icons.play_arrow,
              title: 'Regarder',
              onTap: () {
                Navigator.pop(context);
                // Navigate to video player
                Navigator.pushNamed(
                  context,
                  '/video-player',
                  arguments: {
                    'title': favorite.displayTitle,
                    'movie': favorite.movieData,
                    'series': null,
                    'videoUrl': null, // Will be resolved by the player
                  },
                );
              },
            ),
          _buildOption(
            icon: Icons.info_outline,
            title: 'Voir les détails',
            onTap: () {
              Navigator.pop(context);
              if (favorite.movieData != null) {
                Navigator.pushNamed(context, '/movie-detail', arguments: favorite.movieData);
              }
            },
          ),
          _buildOption(
            icon: Icons.favorite,
            title: 'Retirer des favoris',
            color: AppTheme.errorColor,
            onTap: () {
              Navigator.pop(context);
              provider.removeFromFavorites(favorite.id);
            },
          ),
          _buildOption(
            icon: Icons.share,
            title: 'Partager',
            onTap: () {
              Navigator.pop(context);
              _FavoritesScreenState._shareContent(context, favorite);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.accentNeon),
      title: Text(
        title,
        style: TextStyle(color: color ?? AppTheme.textPrimary),
      ),
      onTap: onTap,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'aujourd\'hui';
    } else if (difference.inDays == 1) {
      return 'hier';
    } else if (difference.inDays < 7) {
      return 'il y a ${difference.inDays} jours';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'il y a $weeks semaine${weeks > 1 ? 's' : ''}';
    } else {
      final months = (difference.inDays / 30).floor();
      return 'il y a $months mois';
    }
  }
}
