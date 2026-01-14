import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/watch_progress.dart';
import '../../providers/watch_progress_provider.dart';
import '../../../core/services/watch_progress_service.dart';
import '../../widgets/loading_widgets.dart';

class WatchProgressScreen extends ConsumerStatefulWidget {
  const WatchProgressScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WatchProgressScreen> createState() => _WatchProgressScreenState();
}

class _WatchProgressScreenState extends ConsumerState<WatchProgressScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _sortBy = 'recent'; // recent, title, progress
  String _filterBy = 'all'; // all, movies, series

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            _buildFilterBar(),
            _buildProgressList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: AppTheme.backgroundPrimary,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Progression de visionnage',
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
          onSelected: (value) {
            setState(() {
              _sortBy = value;
            });
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'recent', child: Text('Plus récent')),
            const PopupMenuItem(value: 'title', child: Text('Titre')),
            const PopupMenuItem(value: 'progress', child: Text('Progression')),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.delete_sweep, color: AppTheme.textPrimary),
          onPressed: _confirmClearAll,
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return SliverToBoxAdapter(
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _buildFilterChip('Tous', 'all', Icons.all_inclusive),
            const SizedBox(width: 8),
            _buildFilterChip('Films', 'movies', Icons.movie_outlined),
            const SizedBox(width: 8),
            _buildFilterChip('Séries', 'series', Icons.tv_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _filterBy == value;
    return FilterChip(
      label: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? AppTheme.backgroundPrimary : AppTheme.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.backgroundPrimary : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          _filterBy = value;
        });
      },
      backgroundColor: AppTheme.surface,
      selectedColor: AppTheme.accentNeon,
      checkmarkColor: AppTheme.backgroundPrimary,
      side: BorderSide(
        color: isSelected ? AppTheme.accentNeon : AppTheme.textSecondary.withOpacity(0.3),
      ),
    );
  }

  Widget _buildProgressList() {
    final progressProvider = ref.watch(watchProgressProvider);
    
    // Use provider's progress list instead of service directly
    List<WatchProgress> allProgress = progressProvider.progress;
    
    // Apply filters
    if (_filterBy != 'all') {
      allProgress = allProgress.where((progress) {
        if (_filterBy == 'movies') return progress.contentType == 'movie';
        if (_filterBy == 'series') return progress.contentType == 'series';
        return true;
      }).toList();
    }
    
    // Apply sorting
    switch (_sortBy) {
      case 'recent':
        allProgress.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
        break;
      case 'title':
        allProgress.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'progress':
        allProgress.sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));
        break;
    }
    
    if (allProgress.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final progress = allProgress[index];
          return _buildProgressItem(progress, index);
        },
        childCount: allProgress.length,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune progression trouvée',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Commencez à regarder du contenu pour voir votre progression ici',
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(WatchProgress progress, int index) {
    return Dismissible(
      key: Key(progress.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppTheme.errorColor,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        ref.read(watchProgressProvider).removeProgress(progress.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Progression supprimée: ${progress.title}'),
            action: SnackBarAction(
              label: 'Annuler',
              onPressed: () {
                // Restoration logic would go here if needed
              },
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            width: 60,
            height: 90,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              progress.isEpisode ? Icons.tv : Icons.movie,
              color: AppTheme.textSecondary,
            ),
          ),
          title: Text(
            progress.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              if (progress.isEpisode)
                Text(
                  'S${progress.seasonNumber}E${progress.episodeNumber}: ${progress.episodeTitle}',
                  style: TextStyle(color: AppTheme.accentNeon.withOpacity(0.8), fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress.progressPercentage,
                        backgroundColor: AppTheme.textSecondary.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress.progressPercentage > 0.9 ? AppTheme.successColor : AppTheme.accentNeon,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(progress.progressPercentage * 100).toInt()}%',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Dernier visionnage: ${_formatDate(progress.lastWatched)}',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
              ),
            ],
          ),
          onTap: () => _playContent(progress),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes}m';
    if (difference.inHours < 24) return 'Il y a ${difference.inHours}h';
    if (difference.inDays < 7) return 'Il y a ${difference.inDays}j';
    
    return '${date.day}/${date.month}/${date.year}';
  }

  void _playContent(WatchProgress progress) {
    // Navigation logic here based on content type
    // Similar to other play actions in the app
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tout effacer ?'),
        content: const Text('Voulez-vous supprimer tout votre historique de visionnage ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              ref.read(watchProgressProvider).clearAllProgress();
              Navigator.pop(context);
            },
            child: const Text('Tout effacer', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}
