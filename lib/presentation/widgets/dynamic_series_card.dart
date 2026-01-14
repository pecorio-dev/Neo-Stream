import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/series.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import 'network_image_with_proxy.dart';
import '../../data/services/image_url_resolver.dart';

enum DynamicSeriesCardType {
  featured, // Grande carte mise en avant
  standard, // Carte normale
  compact, // Carte compacte
  mini, // Mini carte
}

class DynamicSeriesCard extends StatelessWidget {
  final Series series;
  final DynamicSeriesCardType cardType;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final Widget? overlay;
  final int index; // Pour déterminer la taille dynamique

  const DynamicSeriesCard({
    Key? key,
    required this.series,
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

  DynamicSeriesCardDimensions _getDynamicDimensions(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    switch (cardType) {
      case DynamicSeriesCardType.featured:
        return DynamicSeriesCardDimensions(
          width: screenWidth * 0.7,
          height: screenWidth * 0.7 * 1.4,
          titleSize: 16,
          subtitleSize: 13,
          badgeSize: 11,
          padding: 12,
        );
      case DynamicSeriesCardType.standard:
        // Taille variable basée sur l'index
        final baseWidth = screenWidth * 0.4;
        final variation = (index % 3) * 0.05; // Variation de 0%, 5%, 10%
        final width = baseWidth + (baseWidth * variation);

        return DynamicSeriesCardDimensions(
          width: width,
          height: width * 1.5,
          titleSize: 14,
          subtitleSize: 12,
          badgeSize: 10,
          padding: 10,
        );
      case DynamicSeriesCardType.compact:
        final baseWidth = screenWidth * 0.3;
        final variation = (index % 4) * 0.03; // Variation plus subtile
        final width = baseWidth + (baseWidth * variation);

        return DynamicSeriesCardDimensions(
          width: width,
          height: width * 1.6,
          titleSize: 13,
          subtitleSize: 11,
          badgeSize: 9,
          padding: 8,
        );
      case DynamicSeriesCardType.mini:
        final baseWidth = screenWidth * 0.25;
        final variation = (index % 5) * 0.02;
        final width = baseWidth + (baseWidth * variation);

        return DynamicSeriesCardDimensions(
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
      case DynamicSeriesCardType.featured:
        return 16;
      case DynamicSeriesCardType.standard:
        return 12;
      case DynamicSeriesCardType.compact:
        return 10;
      case DynamicSeriesCardType.mini:
        return 8;
    }
  }

  List<BoxShadow> _getCardShadow() {
    switch (cardType) {
      case DynamicSeriesCardType.featured:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ];
      case DynamicSeriesCardType.standard:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ];
      case DynamicSeriesCardType.compact:
      case DynamicSeriesCardType.mini:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ];
    }
  }

  Widget _buildPosterSection(DynamicSeriesCardDimensions dimensions) {
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
            _buildSeasonsBadge(dimensions),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterImage() {
    return series.hasValidPoster
        ? Image(
            image: NetworkImageWithProxy(ImageUrlResolver.resolve(series.poster ?? '')),
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
          Icons.tv,
          color: AppTheme.textSecondary,
          size: _getIconSize(),
        ),
      ),
    );
  }

  double _getIconSize() {
    switch (cardType) {
      case DynamicSeriesCardType.featured:
        return 64;
      case DynamicSeriesCardType.standard:
        return 48;
      case DynamicSeriesCardType.compact:
        return 36;
      case DynamicSeriesCardType.mini:
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

  Widget _buildBadges(DynamicSeriesCardDimensions dimensions) {
    if (cardType == DynamicSeriesCardType.mini) {
      return const SizedBox.shrink(); // Pas de badges pour les mini cartes
    }

    return Positioned(
      top: dimensions.padding,
      right: dimensions.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if ((series.quality?.isNotEmpty ?? false))
            _buildBadge(series.quality ?? '', AppTheme.accentNeon, dimensions),
          if ((series.version?.isNotEmpty ?? false) &&
              cardType != DynamicSeriesCardType.compact)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _buildBadge(
                  series.version ?? '', AppTheme.accentSecondary, dimensions),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(
      String text, Color color, DynamicSeriesCardDimensions dimensions) {
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

  Widget _buildRatingBadge(DynamicSeriesCardDimensions dimensions) {
    if (series.numericRating <= 0 || cardType == DynamicSeriesCardType.mini) {
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
              series.numericRating.toStringAsFixed(1),
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

  Widget _buildSeasonsBadge(DynamicSeriesCardDimensions dimensions) {
    if (series.totalSeasons <= 0 || cardType == DynamicSeriesCardType.mini) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: dimensions.padding,
      left: dimensions.padding,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dimensions.padding * 0.5,
          vertical: dimensions.padding * 0.25,
        ),
        decoration: BoxDecoration(
          color: AppTheme.accentSecondary.withOpacity(0.9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          series.formattedInfo,
          style: TextStyle(
            color: Colors.white,
            fontSize: dimensions.badgeSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Color _getRatingColor() {
    final rating = series.numericRating;
    if (rating >= 8.0) return Colors.green;
    if (rating >= 6.0) return Colors.orange;
    return Colors.red;
  }

  Widget _buildDetailsSection(DynamicSeriesCardDimensions dimensions) {
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

  Widget _buildTitle(DynamicSeriesCardDimensions dimensions) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: series.displayTitle,
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
          series.displayTitle,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
          maxLines: cardType == DynamicSeriesCardType.mini ? 1 : 2,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  Widget _buildSubtitle(DynamicSeriesCardDimensions dimensions) {
    if (cardType == DynamicSeriesCardType.mini) {
      return const SizedBox.shrink();
    }

    final subtitleParts = <String>[];

    if (series.releaseYear > 0) {
      subtitleParts.add(series.releaseYear.toString());
    }

    if (series.cleanGenres.isNotEmpty &&
        cardType != DynamicSeriesCardType.compact) {
      final genreCount = cardType == DynamicSeriesCardType.featured ? 2 : 1;
      subtitleParts.add(series.cleanGenres.take(genreCount).join(', '));
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

class DynamicSeriesCardDimensions {
  final double width;
  final double height;
  final double titleSize;
  final double subtitleSize;
  final double badgeSize;
  final double padding;

  const DynamicSeriesCardDimensions({
    required this.width,
    required this.height,
    required this.titleSize,
    required this.subtitleSize,
    required this.badgeSize,
    required this.padding,
  });
}


