import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/movie.dart';
import '../../core/design_system/color_system.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import 'app_image.dart';

enum MovieCardSize {
  small, // 120x180
  medium, // 160x240
  large, // 200x300
  hero, // 280x420
}

class MovieCard extends StatelessWidget {
  final Movie movie;
  final MovieCardSize size;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showDetails;
  final bool showRating;
  final bool showGenres;
  final bool showYear;
  final bool showQuality;
  final bool showLanguage;
  final bool isSelected;
  final Widget? overlay;

  const MovieCard({
    Key? key,
    required this.movie,
    this.size = MovieCardSize.medium,
    this.onTap,
    this.onLongPress,
    this.showDetails = true,
    this.showRating = true,
    this.showGenres = false,
    this.showYear = true,
    this.showQuality = true,
    this.showLanguage = false,
    this.isSelected = false,
    this.overlay,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dimensions = _getDimensions();

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: dimensions.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? AppTheme.neonShadow : AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildPosterSection(dimensions),
            ),
            if (showDetails) _buildDetailsSection(),
          ],
        ),
      ),
    );
  }

  CardDimensions _getDimensions() {
    switch (size) {
      case MovieCardSize.small:
        return const CardDimensions(120, 180);
      case MovieCardSize.medium:
        return const CardDimensions(160, 240);
      case MovieCardSize.large:
        return const CardDimensions(200, 300);
      case MovieCardSize.hero:
        return const CardDimensions(280, 420);
    }
  }

  Widget _buildPosterSection(CardDimensions dimensions) {
    return Container(
      width: dimensions.width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: AppTheme.accentNeon, width: 2)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPosterImage(),
            _buildGradientOverlay(),
            _buildBadges(),
            if (overlay != null) overlay!,
            _buildRatingBadge(),
            _buildServersBadge(),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterImage() {
    return movie.hasValidPoster
        ? AppImage(
            movie.poster,
            fit: BoxFit.cover,
            placeholder: _buildPlaceholder(),
            errorWidget: _buildPlaceholder(),
          )
        : _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: ColorSystem.surface,
      constraints: const BoxConstraints.expand(),
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          color: ColorSystem.textSecondary,
          size: 48,
          semanticLabel: 'Aucune image disponible',
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.3),
            Colors.black.withOpacity(0.7),
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ),
      ),
    );
  }

  Widget _buildBadges() {
    return Positioned(
      top: 8,
      right: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showQuality && (movie.quality?.isNotEmpty ?? false))
            _buildBadge(movie.quality ?? '', _getQualityColor(movie.quality ?? '')),
          if (showLanguage && (movie.version?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _buildBadge(movie.version ?? '', _getVersionColor(movie.version ?? '')),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRatingBadge() {
    if (!showRating || movie.numericRating <= 0) return const SizedBox.shrink();

    final ratingColor = _getRatingColor();
    final ratingText = movie.ratingMax != null && movie.ratingMax! > 0
        ? '${movie.numericRating.toStringAsFixed(1)}/${movie.ratingMax}'
        : movie.numericRating.toStringAsFixed(1);

    return Positioned(
      bottom: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: ratingColor.withOpacity(0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: ratingColor.withOpacity(0.3),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: 10,
            ),
            const SizedBox(width: 2),
            Text(
              ratingText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServersBadge() {
    if (movie.watchLinksCount == null || movie.watchLinksCount! <= 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: ColorSystem.neonCyan.withOpacity(0.9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 10,
            ),
            const SizedBox(width: 2),
            Text(
              '${movie.watchLinksCount}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRatingColor() {
    final rating = movie.numericRating;
    if (rating >= 8.0) return Colors.green;
    if (rating >= 6.0) return Colors.orange;
    return Colors.red;
  }

  Color _getQualityColor(String quality) {
    switch (quality.toUpperCase()) {
      case '4K':
        return const Color(0xFFFF6B35); // Orange vif
      case 'HD':
        return const Color(0xFF00D4FF); // Cyan néon
      case 'SD':
        return const Color(0xFFFFA500); // Orange
      default:
        return AppTheme.accentNeon;
    }
  }

  Color _getVersionColor(String version) {
    switch (version.toLowerCase()) {
      case 'french':
      case 'truefrench':
        return const Color(0xFF2196F3); // Bleu français
      case 'english':
        return const Color(0xFF4CAF50); // Vert anglais
      case 'multi':
        return const Color(0xFF9C27B0); // Violet multi
      default:
        return AppTheme.accentSecondary;
    }
  }

  Widget _buildDetailsSection() {
    final dimensions = _getDimensions();

    return Container(
      width: dimensions.width,
      constraints: const BoxConstraints(
        minHeight: 40,
        maxHeight: 55,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              movie.displayTitle,
              style: const TextStyle(
                color: ColorSystem.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (showYear && movie.year.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: ColorSystem.surface.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        movie.year,
                        style: const TextStyle(
                          color: ColorSystem.textPrimary,
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (showGenres && movie.cleanGenres.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxWidth: 80),
                      child: Text(
                        movie.cleanGenres.take(2).join(', '),
                        style: const TextStyle(
                          color: ColorSystem.textSecondary,
                          fontSize: 8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CardDimensions {
  final double width;
  final double height;

  const CardDimensions(this.width, this.height);
}

// Widget pour une grille de films avec différentes tailles
class MovieGrid extends StatelessWidget {
  final List<Movie> movies;
  final MovieCardSize cardSize;
  final Function(Movie)? onMovieTap;
  final Function(Movie)? onMovieLongPress;
  final bool showDetails;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsets? padding;

  const MovieGrid({
    Key? key,
    required this.movies,
    this.cardSize = MovieCardSize.medium,
    this.onMovieTap,
    this.onMovieLongPress,
    this.showDetails = true,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = _getCardWidth();
    final crossAxisCount = (screenWidth / (cardWidth + 16)).floor().clamp(2, 6);

    return GridView.builder(
      padding: padding ?? const EdgeInsets.all(16),
      physics: physics,
      shrinkWrap: shrinkWrap,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: _getAspectRatio(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        return MovieCard(
          movie: movie,
          size: cardSize,
          onTap: () => onMovieTap?.call(movie),
          onLongPress: () => onMovieLongPress?.call(movie),
          showDetails: showDetails,
        );
      },
    );
  }

  double _getCardWidth() {
    switch (cardSize) {
      case MovieCardSize.small:
        return 110;
      case MovieCardSize.medium:
        return 150;
      case MovieCardSize.large:
        return 200;
      case MovieCardSize.hero:
        return 280;
    }
  }

  double _getAspectRatio() {
    final cardWidth = _getCardWidth();
    final cardHeight = cardWidth * 1.5;

    // Add extra space for title/year section
    final detailsHeight = showDetails ? 45 : 0;
    final totalHeight = cardHeight + detailsHeight;

    // Ensure minimum aspect ratio to avoid distorted cards
    final aspectRatio = cardWidth / totalHeight;
    return aspectRatio.clamp(0.55, 0.75);
  }
}
