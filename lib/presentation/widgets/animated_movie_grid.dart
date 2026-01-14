import 'package:flutter/material.dart';
import 'network_image_with_proxy.dart';
import '../../data/services/image_url_resolver.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../data/models/movie.dart';
import 'movie_card.dart';
import 'dynamic_movie_card.dart';
import '../../core/constants/app_constants.dart';
// import cpasmieux_image_loader removed

class AnimatedMovieGrid extends StatelessWidget {
  final List<Movie> movies;
  final MovieCardSize cardSize;
  final Function(Movie)? onMovieTap;
  final Function(Movie)? onMovieLongPress;
  final bool showDetails;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsets? padding;
  final int crossAxisCount;
  final double childAspectRatio;

  const AnimatedMovieGrid({
    Key? key,
    required this.movies,
    this.cardSize = MovieCardSize.medium,
    this.onMovieTap,
    this.onMovieLongPress,
    this.showDetails = true,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.6,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: GridView.builder(
        padding: padding ?? const EdgeInsets.all(16),
        physics: physics,
        shrinkWrap: shrinkWrap,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];

          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: AppConstants.mediumAnimation,
            columnCount: crossAxisCount,
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: ScaleAnimation(
                  scale: 0.8,
                  child: MovieCard(
                    movie: movie,
                    size: cardSize,
                    onTap: () => onMovieTap?.call(movie),
                    onLongPress: () => onMovieLongPress?.call(movie),
                    showDetails: showDetails,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AnimatedMovieList extends StatelessWidget {
  final List<Movie> movies;
  final Function(Movie)? onMovieTap;
  final Function(Movie)? onMovieLongPress;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsets? padding;

  const AnimatedMovieList({
    Key? key,
    required this.movies,
    this.onMovieTap,
    this.onMovieLongPress,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: padding ?? const EdgeInsets.all(16),
        physics: physics,
        shrinkWrap: shrinkWrap,
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: AppConstants.mediumAnimation,
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _buildMovieListItem(movie, index),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMovieListItem(Movie movie, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.05),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 60,
            height: 90,
            child: movie.hasValidPoster
                ? Image(
                    image: NetworkImageWithProxy(ImageUrlResolver.resolve(movie.poster ?? '')),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.movie,
                          color: Colors.grey,
                        ),
                      );
                    },
                  )
                : Container(
                    color: Colors.grey[800],
                    child: const Icon(
                      Icons.movie,
                      color: Colors.grey,
                    ),
                  ),
          ),
        ),
        title: Text(
          movie.displayTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${movie.releaseYear} • ${movie.cleanGenres.take(2).join(', ')}',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  movie.numericRating.toStringAsFixed(1),
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                if ((movie.quality?.isNotEmpty ?? false)) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.blue,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      movie.quality ?? '',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.grey,
        ),
        onTap: () => onMovieTap?.call(movie),
        onLongPress: () => onMovieLongPress?.call(movie),
      ),
    );
  }
}

class AnimatedMovieCarousel extends StatelessWidget {
  final List<Movie> movies;
  final String title;
  final Function(Movie)? onMovieTap;
  final Function(Movie)? onMovieLongPress;
  final VoidCallback? onSeeAll;
  final MovieCardSize cardSize;

  const AnimatedMovieCarousel({
    Key? key,
    required this.movies,
    required this.title,
    this.onMovieTap,
    this.onMovieLongPress,
    this.onSeeAll,
    this.cardSize = MovieCardSize.medium,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text(
                    'Voir tout',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _getCarouselHeight(),
          child: AnimationLimiter(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: movies.length,
              itemBuilder: (context, index) {
                final movie = movies[index];

                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: AppConstants.mediumAnimation,
                  child: SlideAnimation(
                    horizontalOffset: 50.0,
                    child: FadeInAnimation(
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: MovieCard(
                          movie: movie,
                          size: cardSize,
                          onTap: () => onMovieTap?.call(movie),
                          onLongPress: () => onMovieLongPress?.call(movie),
                          showDetails: true,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  double _getCarouselHeight() {
    switch (cardSize) {
      case MovieCardSize.small:
        return 240; // 180 + 60 for details
      case MovieCardSize.medium:
        return 300; // 240 + 60 for details
      case MovieCardSize.large:
        return 360; // 300 + 60 for details
      case MovieCardSize.hero:
        return 480; // 420 + 60 for details
    }
  }
}

class AnimatedSearchResults extends StatelessWidget {
  final List<Movie> movies;
  final String query;
  final Function(Movie)? onMovieTap;
  final Function(Movie)? onMovieLongPress;

  const AnimatedSearchResults({
    Key? key,
    required this.movies,
    required this.query,
    this.onMovieTap,
    this.onMovieLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: AnimationConfiguration.synchronized(
              duration: AppConstants.shortAnimation,
              child: FadeInAnimation(
                child: Text(
                  '${movies.length} résultat${movies.length > 1 ? 's' : ''} pour "$query"',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedMovieGrid(
              movies: movies,
              onMovieTap: onMovieTap,
              onMovieLongPress: onMovieLongPress,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }
}


