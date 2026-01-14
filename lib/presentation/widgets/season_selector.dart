import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/series_compact.dart';

/// Widget pour sélectionner une saison
class SeasonSelector extends StatelessWidget {
  final List<SeasonCompact> seasons;
  final int selectedSeasonIndex;
  final Function(int) onSeasonSelected;

  const SeasonSelector({
    super.key,
    required this.seasons,
    required this.selectedSeasonIndex,
    required this.onSeasonSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (seasons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Saisons',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: seasons.length,
              itemBuilder: (context, index) {
                return _buildSeasonCard(index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonCard(int index) {
    final season = seasons[index];
    final isSelected = index == selectedSeasonIndex;

    return GestureDetector(
      onTap: () => onSeasonSelected(index),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.neonBlue.withOpacity(0.2)
              : AppColors.cyberDark.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? AppColors.neonBlue
                : AppColors.neonBlue.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.neonBlue.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ] : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tv,
                    color: isSelected ? AppColors.neonBlue : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'S${season.seasonNumber}',
                      style: TextStyle(
                        color: isSelected ? AppColors.neonBlue : AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                season.displayTitle,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppColors.neonBlue
                      : AppColors.cyberGray.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${season.episodeCount} ép.',
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}