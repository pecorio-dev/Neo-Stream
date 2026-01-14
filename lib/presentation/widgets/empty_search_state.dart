import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';

class EmptySearchState extends StatelessWidget {
  final String query;
  final VoidCallback? onRetry;
  final List<String>? suggestions;

  const EmptySearchState({
    super.key,
    required this.query,
    this.onRetry,
    this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildEmptyIcon(),
          const SizedBox(height: 24),
          _buildEmptyMessage(context),
          const SizedBox(height: 16),
          _buildSuggestions(context),
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            _buildRetryButton(context),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.neonBlue.withOpacity(0.1),
            AppColors.neonPurple.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: AppColors.neonBlue.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Icon(
        Icons.search_off,
        size: 60,
        color: AppColors.neonBlue.withOpacity(0.6),
      ),
    ).animate(
      effects: [
        const FadeEffect(
          duration: Duration(milliseconds: 600),
          begin: 0.0,
          end: 1.0,
        ),
        const ScaleEffect(
          duration: Duration(milliseconds: 600),
          begin: Offset(0.8, 0.8),
          end: Offset(1.0, 1.0),
          curve: Curves.easeOutBack,
        ),
        const ShimmerEffect(
          duration: Duration(seconds: 2),
          color: AppColors.neonBlue,
        ),
      ],
    );
  }

  Widget _buildEmptyMessage(BuildContext context) {
    return Column(
      children: [
        Text(
          'Aucun résultat trouvé',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ).animate(
          effects: [
            const FadeEffect(
              duration: Duration(milliseconds: 400),
              begin: 0.0,
              end: 1.0,
            ),
            const SlideEffect(
              duration: Duration(milliseconds: 400),
              begin: Offset(0.0, 0.3),
              end: Offset.zero,
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            children: [
              const TextSpan(text: 'Aucun résultat pour "'),
              TextSpan(
                text: query,
                style: TextStyle(
                  color: AppColors.neonBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(text: '"'),
            ],
          ),
        ).animate(
          delay: const Duration(milliseconds: 200),
          effects: [
            const FadeEffect(
              duration: Duration(milliseconds: 400),
              begin: 0.0,
              end: 1.0,
            ),
            const SlideEffect(
              duration: Duration(milliseconds: 400),
              begin: Offset(0.0, 0.3),
              end: Offset.zero,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    final defaultSuggestions = [
      'Vérifiez l\'orthographe',
      'Essayez des mots-clés plus généraux',
      'Utilisez moins de mots-clés',
      'Recherchez par genre ou acteur',
    ];

    final suggestionList = suggestions ?? defaultSuggestions;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cyberGray.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.neonPurple.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: AppColors.neonYellow,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Suggestions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...suggestionList.asMap().entries.map((entry) {
            final index = entry.key;
            final suggestion = entry.value;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6, right: 12),
                    decoration: BoxDecoration(
                      color: AppColors.neonPurple,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate(
              delay: Duration(milliseconds: 400 + (index * 100)),
              effects: [
                const FadeEffect(
                  duration: Duration(milliseconds: 300),
                  begin: 0.0,
                  end: 1.0,
                ),
                const SlideEffect(
                  duration: Duration(milliseconds: 300),
                  begin: Offset(-0.3, 0.0),
                  end: Offset.zero,
                ),
              ],
            );
          }).toList(),
        ],
      ),
    ).animate(
      delay: const Duration(milliseconds: 300),
      effects: [
        const FadeEffect(
          duration: Duration(milliseconds: 500),
          begin: 0.0,
          end: 1.0,
        ),
        const SlideEffect(
          duration: Duration(milliseconds: 500),
          begin: Offset(0.0, 0.3),
          end: Offset.zero,
        ),
      ],
    );
  }

  Widget _buildRetryButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onRetry,
      icon: Icon(
        Icons.refresh,
        color: AppColors.cyberBlack,
      ),
      label: Text(
        'Réessayer',
        style: TextStyle(
          color: AppColors.cyberBlack,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.neonBlue,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 8,
        shadowColor: AppColors.neonBlue.withOpacity(0.4),
      ),
    ).animate(
      delay: const Duration(milliseconds: 600),
      effects: [
        const FadeEffect(
          duration: Duration(milliseconds: 400),
          begin: 0.0,
          end: 1.0,
        ),
        const ScaleEffect(
          duration: Duration(milliseconds: 400),
          begin: Offset(0.8, 0.8),
          end: Offset(1.0, 1.0),
          curve: Curves.easeOutBack,
        ),
      ],
    );
  }
}

class EmptyFavoritesState extends StatelessWidget {
  final VoidCallback? onExplore;

  const EmptyFavoritesState({
    super.key,
    this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: AppColors.neonPink.withOpacity(0.6),
          ).animate(
            effects: [
              const FadeEffect(duration: Duration(milliseconds: 600)),
              const ScaleEffect(
                duration: Duration(milliseconds: 600),
                begin: Offset(0.8, 0.8),
                end: Offset(1.0, 1.0),
                curve: Curves.easeOutBack,
              ),
              const ShimmerEffect(
                duration: Duration(seconds: 2),
                color: AppColors.neonPink,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Aucun favori',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Ajoutez des films et séries à vos favoris pour les retrouver facilement',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          
          if (onExplore != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onExplore,
              icon: Icon(
                Icons.explore,
                color: AppColors.cyberBlack,
              ),
              label: Text(
                'Explorer',
                style: TextStyle(
                  color: AppColors.cyberBlack,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonPink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyWatchlistState extends StatelessWidget {
  final VoidCallback? onExplore;

  const EmptyWatchlistState({
    super.key,
    this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.playlist_add,
            size: 80,
            color: AppColors.neonGreen.withOpacity(0.6),
          ).animate(
            effects: [
              const FadeEffect(duration: Duration(milliseconds: 600)),
              const ScaleEffect(
                duration: Duration(milliseconds: 600),
                begin: Offset(0.8, 0.8),
                end: Offset(1.0, 1.0),
                curve: Curves.easeOutBack,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Liste vide',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Ajoutez des contenus à votre liste pour les regarder plus tard',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          
          if (onExplore != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onExplore,
              icon: Icon(
                Icons.add,
                color: AppColors.cyberBlack,
              ),
              label: Text(
                'Ajouter du contenu',
                style: TextStyle(
                  color: AppColors.cyberBlack,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}