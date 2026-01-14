import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/favorites_provider.dart';
import '../widgets/series_card.dart';
import '../../core/theme/app_colors.dart';

class SeriesFavoritesScreen extends ConsumerStatefulWidget {
  const SeriesFavoritesScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SeriesFavoritesScreen> createState() =>
      _SeriesFavoritesScreenState();
}

class _SeriesFavoritesScreenState extends ConsumerState<SeriesFavoritesScreen> {
  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favProvider = ref.read(favoritesProvider);
    await favProvider.loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final favProvider = ref.watch(favoritesProvider);

    // Filter only series
    final seriesFavorites = favProvider.favorites
        .where((item) => item.type == 'series')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Séries Favorites'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.cyberBlack,
      ),
      backgroundColor: AppColors.cyberBlack,
      body: RefreshIndicator(
        onRefresh: _loadFavorites,
        child: _buildContent(context, favProvider, seriesFavorites),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    FavoritesProvider favProvider,
    List favorites,
  ) {
    if (favProvider.isLoading && favorites.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonBlue),
        ),
      );
    }

    if (favProvider.hasError && favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Erreur: ${favProvider.errorMessage}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFavorites,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_outline,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune série favorite',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.explore),
              label: const Text('Explorer les séries'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.6,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final favorite = favorites[index];
        // Convert FavoriteItem to Series-like object for display
        // You may need to create a helper method or use the data as-is
        return _buildFavoriteSeriesCard(context, favorite);
      },
    );
  }

  Widget _buildFavoriteSeriesCard(BuildContext context, favorite) {
    return GestureDetector(
      onTap: () {
        // Navigate to series details
        print('Navigate to series: ${favorite.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Poster image
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.cyberGray,
              ),
              child: Image.network(
                favorite.poster,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.cyberGray,
                  child: const Icon(Icons.image_not_supported,
                      color: Colors.white, size: 50),
                ),
              ),
            ),
            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),
            // Title and info
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    favorite.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        favorite.rating,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Favorite heart icon
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.5),
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
