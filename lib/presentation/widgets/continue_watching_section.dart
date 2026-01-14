import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/watch_progress.dart';
import '../providers/watch_progress_provider.dart';
import '../screens/progress/watch_progress_screen.dart';

class ContinueWatchingSection extends ConsumerWidget {
  const ContinueWatchingSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressProviderValue = ref.watch(watchProgressProvider);
    final recentProgress = progressProviderValue.recentProgress.take(5).toList();
    
    if (recentProgress.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(
                Icons.history,
                color: AppTheme.accentNeon,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Continuer à regarder',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WatchProgressScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Voir tout',
                  style: TextStyle(
                    color: AppTheme.accentNeon,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recentProgress.length,
            itemBuilder: (context, index) {
              final progress = recentProgress[index];
              return _buildProgressCard(context, progress);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(BuildContext context, WatchProgress progress) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image avec barre de progression
          Expanded(
            child: Stack(
              children: [
                // Image de fond (placeholder pour l'instant)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.accentNeon.withOpacity(0.3),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Icon(
                      progress.contentType == 'movie' ? Icons.movie : Icons.tv,
                      color: AppTheme.textSecondary,
                      size: 48,
                    ),
                  ),
                ),
                
                // Badge de type de contenu
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: progress.contentType == 'movie' 
                          ? AppTheme.accentNeon 
                          : AppTheme.accentSecondary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      progress.contentType == 'movie' ? 'FILM' : 'SÉRIE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                // Barre de progression en bas
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.progressPercentage,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.accentNeon,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Bouton de lecture au centre
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _resumeWatching(context, progress),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_filled,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Titre
          Text(
            progress.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 4),
          
          // Informations de progression
          if (progress.contentType == 'series') ...[
            Text(
              'S${progress.seasonNumber}E${progress.episodeNumber}',
              style: const TextStyle(
                color: AppTheme.accentSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
          ],
          
          Text(
            progress.formattedPosition,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _resumeWatching(BuildContext context, WatchProgress progress) {
    // Navigate to video player with resume functionality
    if (progress.contentType == 'movie') {
      // For movies, navigate to video player directly
      Navigator.pushNamed(
        context,
        '/video-player',
        arguments: {
          'title': progress.title,
          'videoUrl': null, // Will be resolved by the player
          'movie': null, // Would need to fetch movie data
          'series': null,
          'resumePosition': progress.position,
        },
      );
      print('🎬 Reprendre le film: ${progress.title} à ${progress.formattedPosition}');
    } else {
      // For series, navigate to series details to select episode
      print('📺 Reprendre la série: ${progress.title} S${progress.seasonNumber}E${progress.episodeNumber} à ${progress.formattedPosition}');
      // Could navigate to series details with specific episode highlighted
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reprise de "${progress.title}" à ${progress.formattedPosition}'),
        backgroundColor: AppTheme.accentNeon,
        action: SnackBarAction(
          label: 'Annuler',
          textColor: AppTheme.backgroundPrimary,
          onPressed: () {},
        ),
      ),
    );
  }
}
