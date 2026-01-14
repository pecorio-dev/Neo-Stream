import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/movie.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import 'network_image_with_proxy.dart';
import '../../data/services/image_url_resolver.dart';

enum DynamicCardType {
  featured, // Grande carte mise en avant
  standard, // Carte normale
  compact, // Carte compacte
  mini, // Mini carte
}

class DynamicMovieCard extends StatelessWidget {
  final Movie movie;
  final DynamicCardType cardType;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final Widget? overlay;
  final int index; // Pour déterminer la taille dynamique

  const DynamicMovieCard({
    Key? key,
    required this.movie,
    required this.cardType,
    required this.index,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.overlay,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dimensions = _getDynamicDimensions(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: dimensions.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_getBorderRadius()),
          boxShadow: isSelected ? AppTheme.neonShadow : _getCardShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPosterSection(dimensions),
            _buildDetailsSection(dimensions),
          ],
        ),
      ),
    );
  }

  DynamicCardDimensions _getDynamicDimensions(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    switch (cardType) {
      case DynamicCardType.featured:
        return DynamicCardDimensions(
          width: screenWidth * 0.7,
          height: screenWidth * 0.7 * 1.4,
          titleSize: 16,
          subtitleSize: 13,
          badgeSize: 11,
          padding: 12,
        );
      case DynamicCardType.standard:
        // Taille variable basée sur l'index
        final baseWidth = screenWidth * 0.4;
        final variation = (index % 3) * 0.05; // Variation de 0%, 5%, 10%
        final width = baseWidth + (baseWidth * variation);

        return DynamicCardDimensions(
          width: width,
          height: width * 1.5,
          titleSize: 14,
          subtitleSize: 12,
          badgeSize: 10,
          padding: 10,
        );
      case DynamicCardType.compact:
        final baseWidth = screenWidth * 0.3;
        final variation = (index % 4) * 0.03; // Variation plus subtile
        final width = baseWidth + (baseWidth * variation);

        return DynamicCardDimensions(
          width: width,
          height: width * 1.6,
          titleSize: 13,
          subtitleSize: 11,
          badgeSize: 9,
          padding: 8,
        );
      case DynamicCardType.mini:
        final baseWidth = screenWidth * 0.25;
        final variation = (index % 5) * 0.02;
        final width = baseWidth + (baseWidth * variation);

        return DynamicCardDimensions(
          width: width,
          height: width * 1.7,
          titleSize: 12,
          subtitleSize: 10,
          badgeSize: 8,
          padding: 6,
        );
    }
  }

  double _getBorderRadius() {
    switch (cardType) {
      case DynamicCardType.featured:
        return 16;
      case DynamicCardType.standard:
        return 12;
      case DynamicCardType.compact:
        return 10;
      case DynamicCardType.mini:
        return 8;
    }
  }

  List<BoxShadow> _getCardShadow() {
    switch (cardType) {
      case DynamicCardType.featured:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ];
      case DynamicCardType.standard:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ];
      case DynamicCardType.compact:
      case DynamicCardType.mini:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ];
    }
  }

  Widget _buildPosterSection(DynamicCardDimensions dimensions) {
    return Container(
      width: dimensions.width,
      height: dimensions.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_getBorderRadius()),
        border: isSelected
            ? Border.all(color: AppTheme.accentNeon, width: 2)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_getBorderRadius()),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPosterImage(),
            _buildGradientOverlay(),
            _buildBadges(dimensions),
            if (overlay != null) overlay!,
            _buildRatingBadge(dimensions),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterImage() {
    return movie.hasValidPoster
        ? Image(
            image: NetworkImageWithProxy(ImageUrlResolver.resolve(movie.poster ?? '')),
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildPlaceholder();
            },
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          )
        : _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.surface,
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          color: AppTheme.textSecondary,
          size: _getIconSize(),
        ),
      ),
    );
  }

  double _getIconSize() {
    switch (cardType) {
      case DynamicCardType.featured:
        return 64;
      case DynamicCardType.standard:
        return 48;
      case DynamicCardType.compact:
        return 36;
      case DynamicCardType.mini:
        return 24;
    }
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

  Widget _buildBadges(DynamicCardDimensions dimensions) {
    if (cardType == DynamicCardType.mini) {
      return const SizedBox.shrink(); // Pas de badges pour les mini cartes
    }

    return Positioned(
      top: dimensions.padding,
      right: dimensions.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if ((movie.quality?.isNotEmpty ?? false))
            _buildBadge(movie.quality ?? '', AppTheme.accentNeon, dimensions),
          if ((movie.version?.isNotEmpty ?? false) &&
              cardType != DynamicCardType.compact)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _buildBadge(
                  movie.version ?? '', AppTheme.accentSecondary, dimensions),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(
      String text, Color color, DynamicCardDimensions dimensions) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dimensions.padding * 0.5,
        vertical: dimensions.padding * 0.25,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: dimensions.badgeSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRatingBadge(DynamicCardDimensions dimensions) {
    if (movie.numericRating <= 0 || cardType == DynamicCardType.mini) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: dimensions.padding,
      right: dimensions.padding,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dimensions.padding * 0.5,
          vertical: dimensions.padding * 0.25,
        ),
        decoration: BoxDecoration(
          color: _getRatingColor().withOpacity(0.9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star,
              color: Colors.white,
              size: dimensions.badgeSize,
            ),
            const SizedBox(width: 2),
            Text(
              movie.numericRating.toStringAsFixed(1),
              style: TextStyle(
                color: Colors.white,
                fontSize: dimensions.badgeSize,
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

  Widget _buildDetailsSection(DynamicCardDimensions dimensions) {
    return Padding(
      padding: EdgeInsets.all(dimensions.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(dimensions),
          const SizedBox(height: 4),
          _buildSubtitle(dimensions),
        ],
      ),
    );
  }

  Widget _buildTitle(DynamicCardDimensions dimensions) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: movie.displayTitle,
            style: TextStyle(
              fontSize: dimensions.titleSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          maxLines: 2,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout(maxWidth: constraints.maxWidth);

        // Ajuster la taille du texte si nécessaire
        double fontSize = dimensions.titleSize;
        if (textPainter.didExceedMaxLines) {
          fontSize = dimensions.titleSize * 0.9;
        }

        return Text(
          movie.displayTitle,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
          maxLines: cardType == DynamicCardType.mini ? 1 : 2,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  Widget _buildSubtitle(DynamicCardDimensions dimensions) {
    if (cardType == DynamicCardType.mini) {
      return const SizedBox.shrink();
    }

    final subtitleParts = <String>[];

    if (movie.releaseYear > 0) {
      subtitleParts.add(movie.releaseYear.toString());
    }

    if (movie.cleanGenres.isNotEmpty && cardType != DynamicCardType.compact) {
      final genreCount = cardType == DynamicCardType.featured ? 2 : 1;
      subtitleParts.add(movie.cleanGenres.take(genreCount).join(', '));
    }

    if (subtitleParts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      subtitleParts.join(' • '),
      style: TextStyle(
        color: AppTheme.textSecondary,
        fontSize: dimensions.subtitleSize,
        height: 1.2,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class DynamicCardDimensions {
  final double width;
  final double height;
  final double titleSize;
  final double subtitleSize;
  final double badgeSize;
  final double padding;

  const DynamicCardDimensions({
    required this.width,
    required this.height,
    required this.titleSize,
    required this.subtitleSize,
    required this.badgeSize,
    required this.padding,
  });
}

// Widget pour une grille dynamique avec des tailles variables
class DynamicMovieGrid extends StatelessWidget {
  final List<Movie> movies;
  final Function(Movie)? onMovieTap;
  final Function(Movie)? onMovieLongPress;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsets? padding;
  final DynamicCardType cardType;

  const DynamicMovieGrid({
    Key? key,
    required this.movies,
    this.onMovieTap,
    this.onMovieLongPress,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.cardType = DynamicCardType.standard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildStaggeredGrid(context, constraints);
      },
    );
  }

  Widget _buildStaggeredGrid(BuildContext context, BoxConstraints constraints) {
    final screenWidth = constraints.maxWidth;
    final crossAxisCount = _getCrossAxisCount(screenWidth);

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
        return DynamicMovieCard(
          movie: movie,
          cardType: cardType,
          index: index,
          onTap: () => onMovieTap?.call(movie),
          onLongPress: () => onMovieLongPress?.call(movie),
        );
      },
    );
  }

  int _getCrossAxisCount(double screenWidth) {
    switch (cardType) {
      case DynamicCardType.featured:
        return screenWidth > 800 ? 2 : 1;
      case DynamicCardType.standard:
        if (screenWidth > 1200) return 4;
        if (screenWidth > 800) return 3;
        return 2;
      case DynamicCardType.compact:
        if (screenWidth > 1200) return 5;
        if (screenWidth > 800) return 4;
        if (screenWidth > 600) return 3;
        return 2;
      case DynamicCardType.mini:
        if (screenWidth > 1200) return 6;
        if (screenWidth > 800) return 5;
        if (screenWidth > 600) return 4;
        return 3;
    }
  }

  double _getAspectRatio() {
    switch (cardType) {
      case DynamicCardType.featured:
        return 0.6; // Plus large
      case DynamicCardType.standard:
        return 0.55;
      case DynamicCardType.compact:
        return 0.5;
      case DynamicCardType.mini:
        return 0.45; // Plus étroit
    }
  }
}

// Widget pour un layout en mosaïque avec différentes tailles
class MosaicMovieLayout extends StatelessWidget {
  final List<Movie> movies;
  final Function(Movie)? onMovieTap;
  final Function(Movie)? onMovieLongPress;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsets? padding;

  const MosaicMovieLayout({
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
    if (movies.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      physics: physics,
      padding: padding ?? const EdgeInsets.all(16),
      child: Column(
        children: _buildMosaicSections(),
      ),
    );
  }

  List<Widget> _buildMosaicSections() {
    final sections = <Widget>[];
    int index = 0;

    while (index < movies.length) {
      // Section avec une carte featured et des cartes standard
      if (index < movies.length) {
        sections.add(_buildFeaturedSection(index));
        index++;
      }

      // Section avec des cartes standard
      if (index < movies.length) {
        final standardMovies = movies.skip(index).take(4).toList();
        sections.add(_buildStandardSection(standardMovies, index));
        index += standardMovies.length;
      }

      // Section avec des cartes compactes
      if (index < movies.length) {
        final compactMovies = movies.skip(index).take(6).toList();
        sections.add(_buildCompactSection(compactMovies, index));
        index += compactMovies.length;
      }

      // Espacement entre les sections
      if (index < movies.length) {
        sections.add(const SizedBox(height: 24));
      }
    }

    return sections;
  }

  Widget _buildFeaturedSection(int startIndex) {
    if (startIndex >= movies.length) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: DynamicMovieCard(
          movie: movies[startIndex],
          cardType: DynamicCardType.featured,
          index: startIndex,
          onTap: () => onMovieTap?.call(movies[startIndex]),
          onLongPress: () => onMovieLongPress?.call(movies[startIndex]),
        ),
      ),
    );
  }

  Widget _buildStandardSection(List<Movie> sectionMovies, int startIndex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.55,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: sectionMovies.length,
            itemBuilder: (context, index) {
              final movie = sectionMovies[index];
              return DynamicMovieCard(
                movie: movie,
                cardType: DynamicCardType.standard,
                index: startIndex + index,
                onTap: () => onMovieTap?.call(movie),
                onLongPress: () => onMovieLongPress?.call(movie),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCompactSection(List<Movie> sectionMovies, int startIndex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount;
          if (constraints.maxWidth > 1200) {
            crossAxisCount = 4;
          } else if (constraints.maxWidth > 800) {
            crossAxisCount = 3;
          } else {
            crossAxisCount = 2;
          }

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: sectionMovies.length,
            itemBuilder: (context, index) {
              final movie = sectionMovies[index];
              return DynamicMovieCard(
                movie: movie,
                cardType: DynamicCardType.compact,
                index: startIndex + index,
                onTap: () => onMovieTap?.call(movie),
                onLongPress: () => onMovieLongPress?.call(movie),
              );
            },
          );
        },
      ),
    );
  }
}


