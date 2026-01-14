import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/series_compact.dart';
import '../../data/models/series.dart';
import 'app_image.dart';
import 'focus_selector_wrapper.dart';
import 'series_favorite_button.dart';
import '../../data/services/platform_service.dart';

class SeriesCard extends ConsumerWidget {
  final SeriesCompact series;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showGenres;
  final bool showRating;
  final FocusNode? focusNode;
  final bool autofocus;

  const SeriesCard({
    Key? key,
    required this.series,
    this.onTap,
    this.onLongPress,
    this.showGenres = true,
    this.showRating = true,
    this.focusNode,
    this.autofocus = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FocusSelectorWrapper(
      focusNode: focusNode,
      autofocus: autofocus,
      onPressed: onTap,
      onLongPress: onLongPress,
      semanticLabel: 'Série ${series.displayTitle}',
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cyberGray.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.cyberGray.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 180,
              child: _buildPoster(),
            ),
            Expanded(
              child: _buildInfo(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoster() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: series.poster.isNotEmpty
                ? AppImage(
                    series.poster,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: AppColors.cyberGray,
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonBlue),
                        ),
                      ),
                    ),
                    errorWidget: _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
        ),
        // Favorite button
        Positioned(
          top: 8,
          right: 8,
          child: _buildFavoriteButton(),
        ),
      ],
    );
  }

  Widget _buildFavoriteButton() {
    // Create a minimal Series object for the favorite button
    final minimalSeries = Series(
      id: series.id,
      title: series.title,
      originalTitle: series.originalTitle,
      poster: series.poster,
      url: series.url,
      type: 'series',
      year: '0',
      genres: series.genres,
      rating: 0.0,
      actors: [],
      directors: [],
      seasonsCount: 0,
      episodesCount: 0,
    );
    
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.5),
      ),
      padding: const EdgeInsets.all(8),
      child: SeriesFavoriteButton(
        minimalSeries,
        size: 18,
        color: Colors.white,
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.cyberGray,
      child: const Center(
        child: Icon(
          Icons.tv,
          color: AppColors.textSecondary,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Container(
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(
        minHeight: 60,
        maxHeight: 80,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titre
          Flexible(
            flex: 2,
            child: Text(
              series.displayTitle,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 2),

          // Rating et info
          Flexible(
            child: Row(
              children: [
                if (showRating && series.numericRating > 0) ...[
                  Icon(
                    Icons.star,
                    color: _getRatingColor(series.numericRating),
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    series.formattedRating,
                    style: TextStyle(
                      color: _getRatingColor(series.numericRating),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                Expanded(
                  child: Text(
                    series.formattedInfo,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Genres
          if (showGenres && series.genres.isNotEmpty) ...[
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                series.genres.take(1).join(', '),
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 9,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 8.0) return AppColors.neonGreen;
    if (rating >= 7.0) return AppColors.neonBlue;
    if (rating >= 6.0) return AppColors.neonYellow;
    if (rating >= 5.0) return AppColors.neonOrange;
    return AppColors.laserRed;
  }
}
