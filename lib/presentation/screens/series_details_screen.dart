import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/app_image.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/favorites_provider.dart';
import '../providers/user_profile_provider.dart';
import '../widgets/settings_button.dart';
import '../widgets/sync_status_indicator.dart';
import '../screens/resume_watch_section.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/series.dart';
import '../../data/models/series_compact.dart';
import '../../data/models/movie.dart' as movie_model;
// import cpasmieux_image_loader removed
import '../../data/models/stream_info.dart';
import '../../data/extractors/uqload_extractor.dart';
import '../../data/services/stream_resolver.dart';
import '../../data/models/watch_progress.dart';
import '../../core/services/watch_progress_service.dart';
import '../../data/services/series_api_service.dart';
import '../../data/services/recommendation_service.dart';
import '../widgets/movie_card.dart';
import '../../main.dart';

class SeriesDetailsScreen extends ConsumerStatefulWidget {
  final Series series;

  const SeriesDetailsScreen({Key? key, required this.series}) : super(key: key);

  @override
  ConsumerState<SeriesDetailsScreen> createState() => _SeriesDetailsScreenState();
}

class _SeriesDetailsScreenState extends ConsumerState<SeriesDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _fabAnimationController;
  late Series _fullSeries;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _fabAnimation;

  final ScrollController _scrollController = ScrollController();
  bool _showAppBarTitle = false;
  bool _isFavorite = false;
  bool _isLoadingStream = false;

  // State for seasons and episodes
  Map<int, bool> _expandedSeasons = {};
  Map<String, WatchProgress?> _episodeProgress = {};
  Map<int, List<Episode>> _seasonEpisodes = {}; // Cache pour les épisodes chargés
  Map<int, bool> _loadingSeasons = {}; // Indicateur de chargement par saison

  // Recommandations
  List<Series> _recommendations = [];
  bool _isLoadingRecommendations = false;

  @override
  void initState() {
    super.initState();
    // Initialize with widget series, will be updated with full details
    _fullSeries = widget.series;

    _animationController = AnimationController(
      duration: AppConstants.mediumAnimation,
      vsync: this,
    );

    _fabAnimationController = AnimationController(
      duration: AppConstants.shortAnimation,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _fabAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    ));

    _scrollController.addListener(_onScroll);

    // Démarrer les animations
    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _fabAnimationController.forward();
    });

    // Vérifier si la série est en favoris
    _checkFavoriteStatus();

    // Charger les détails complets de la série d'abord, puis les autres données
    _initializeSeriesData();
  }

  /// Initialize series data with proper sequencing
  Future<void> _initializeSeriesData() async {
    // First, load full series details
    await _loadFullSeriesDetails();
    
    // Then parallelize the loading of episode progress and recommendations
    await Future.wait([
      _loadEpisodeProgress(),
      _loadRecommendations(),
    ]);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    // Arrêter les animations avant de les disposer
    if (_animationController.isAnimating) {
      _animationController.stop();
    }
    if (_fabAnimationController.isAnimating) {
      _fabAnimationController.stop();
    }

    _animationController.dispose();
    _fabAnimationController.dispose();

    super.dispose();
  }

  /// Load episode progress for the series
  Future<void> _loadEpisodeProgress() async {
    final progressFutures = <Future<MapEntry<String, WatchProgress?>>>[];

    for (int i = 0; i < (_fullSeries.seasons?.length ?? 0); i++) {
      final season = _fullSeries.seasons?[i];
      if (season == null) continue;
      
      for (int j = 0; j < season.episodes.length; j++) {
        final episode = season.episodes[j];
        progressFutures.add(
          WatchProgressService.getProgress(
            contentId: _fullSeries.id ?? '',
            contentType: 'series',
            seasonNumber: season.seasonNumber,
            episodeNumber: episode.episodeNumber,
          ).then((progress) {
            final key =
                '${_fullSeries.id}_${season.seasonNumber}_${episode.episodeNumber}';
            return MapEntry(key, progress);
          }),
        );
      }
    }

    // Attendre toutes les requêtes en parallèle
    if (progressFutures.isNotEmpty) {
      final results = await Future.wait(progressFutures);
      if (mounted) {
        setState(() {
          for (final entry in results) {
            _episodeProgress[entry.key] = entry.value;
          }
        });
      }
    }
  }

  /// Vérifie si la série est en favoris
  Future<void> _checkFavoriteStatus() async {
    final provider = ref.read(favoritesProvider);
    final itemId =
        widget.series.url?.hashCode.toString() ?? widget.series.id ?? '';
    final isFav = await provider.isFavorite(itemId);
    if (mounted) {
      setState(() => _isFavorite = isFav);
    }
  }

  void _onScroll() {
    final shouldShowTitle = _scrollController.offset > 200;
    if (shouldShowTitle != _showAppBarTitle) {
      setState(() => _showAppBarTitle = shouldShowTitle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cyberBlack,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          _buildSeriesInfo(),
          _buildResumeSection(),
          _buildSeasonsEpisodes(),
          _buildRecommendationsSection(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: _buildPlayButton(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 400,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.cyberBlack,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? AppColors.neonPink : Colors.white,
            ),
          ),
          onPressed: _toggleFavorite,
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share, color: Colors.white),
          ),
          onPressed: _shareSeries,
        ),
        const SizedBox(width: 8),
      ],
      title: AnimatedOpacity(
        opacity: _showAppBarTitle ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Text(
          widget.series.title ?? 'Détails de la série',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Backdrop Image
            if (widget.series.poster?.isNotEmpty == true)
              AppImage(
                widget.series.poster!,
                fit: BoxFit.cover,
                placeholder: Container(
                  color: AppColors.cyberGray,
                ),
                errorWidget: Container(
                  color: AppColors.cyberGray,
                  child: const Icon(Icons.movie, color: Colors.white, size: 50),
                ),
              )
            else
              Container(color: AppColors.cyberGray),

            // Gradient Overlays
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                    Colors.transparent,
                    AppColors.cyberBlack,
                  ],
                  stops: [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),

            // Series Info Overlay
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.series.title?.isNotEmpty == true)
                    Text(
                      widget.series.title!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(0, 2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  _buildQuickInfoRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickInfoRow() {
    return Row(
      children: [
        // Note
        if (widget.series.rating != null && (widget.series.rating is num) && (widget.series.rating as num) > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getRatingColor((widget.series.rating as num).toDouble())
                  .withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _getRatingColor((widget.series.rating as num).toDouble())
                    .withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star,
                  color:
                      _getRatingColor((widget.series.rating as num).toDouble()),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  (widget.series.rating as num).toStringAsFixed(1),
                  style: TextStyle(
                    color: _getRatingColor(
                        (widget.series.rating as num).toDouble()),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],

        // Année
        if (widget.series.year != null && int.tryParse(widget.series.year)! > 0) ...[
          Text(
            widget.series.year.toString(),
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
        ],

        // Saisons count
        if (widget.series.seasonsCount != null && widget.series.seasonsCount! > 0) ...[
          const Icon(Icons.layers_outlined, color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Text(
            '${widget.series.seasonsCount} Saisons',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
        ],

        // Qualité
        if (widget.series.quality?.isNotEmpty == true) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              widget.series.quality!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSeriesInfo() {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Genres
              if (widget.series.genres?.isNotEmpty == true) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.series.genres!.take(5).map((genre) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cyberGray,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.neonBlue.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        genre,
                        style: const TextStyle(
                          color: AppColors.neonBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],

              // Synopsis
              if (widget.series.synopsis?.isNotEmpty == true) ...[
                const Text(
                  'Synopsis',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.series.synopsis!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumeSection() {
    return FutureBuilder<List<WatchProgress>>(
      future: WatchProgressService.getAllSeriesProgress(_fullSeries.id ?? ''),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        final lastProgress = snapshot.data!.first;

        return SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ResumeWatchSection(
                contentId: _fullSeries.id ?? '',
                contentType: 'series',
                title: 'S${lastProgress.seasonNumber}E${lastProgress.episodeNumber}: ${lastProgress.episodeTitle}',
                duration: Duration(seconds: lastProgress.duration),
                seasonNumber: lastProgress.seasonNumber,
                episodeNumber: lastProgress.episodeNumber,
                onResumePressed: () async {
                  final season = _fullSeries.seasons?.firstWhere(
                    (s) => s.seasonNumber == lastProgress.seasonNumber,
                  );
                  final episode = season?.episodes.firstWhere(
                    (e) => e.episodeNumber == lastProgress.episodeNumber,
                  );
                  if (season != null && episode != null) {
                    await _playEpisodeWithResume(episode, season, fromResume: true);
                  }
                },
                onRestartPressed: () async {
                  final season = _fullSeries.seasons?.firstWhere(
                    (s) => s.seasonNumber == lastProgress.seasonNumber,
                  );
                  final episode = season?.episodes.firstWhere(
                    (e) => e.episodeNumber == lastProgress.episodeNumber,
                  );
                  if (season != null && episode != null) {
                    await _playEpisodeWithResume(episode, season, fromRestart: true);
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeasonsEpisodes() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= (_fullSeries.seasons?.length ?? 0)) {
            return const SizedBox.shrink();
          }

          final season = _fullSeries.seasons?[index];
          if (season == null) return const SizedBox.shrink();
          return _buildSeasonCard(season, index);
        },
        childCount: (_fullSeries.seasons?.length ?? 0),
      ),
    );
  }

  Widget _buildSeasonCard(Season season, int seasonIndex) {
    final isExpanded = _expandedSeasons[seasonIndex] ?? false;
    final isLoading = _loadingSeasons[seasonIndex] ?? false;
    
    return Card(
      color: AppColors.cyberGray,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      child: Column(
        children: [
          ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Saison ${season.seasonNumber}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${(_seasonEpisodes[seasonIndex]?.length ?? season.episodes.length)})',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '${(_seasonEpisodes[seasonIndex]?.length ?? season.episodes.length)} épisodes',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            trailing: isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.neonBlue),
                    ),
                  )
                : Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textPrimary,
                  ),
            onTap: () async {
              if (isExpanded) {
                // Fermer la saison
                setState(() {
                  _expandedSeasons[seasonIndex] = false;
                });
              } else {
                // Ouvrir la saison et charger les épisodes si nécessaire
                setState(() {
                  _expandedSeasons[seasonIndex] = true;
                });
                
                // Charger les épisodes si pas déjà en cache OU si la saison n'a pas d'épisodes
                if (!_seasonEpisodes.containsKey(seasonIndex)) {
                  // Toujours essayer de charger depuis l'API
                  await _loadSeasonEpisodes(seasonIndex, season);
                } else if (season.episodes.isEmpty && _seasonEpisodes[seasonIndex]?.isEmpty != false) {
                  // Recharger si les épisodes locaux et en cache sont vides
                  await _loadSeasonEpisodes(seasonIndex, season);
                }
              }
            },
          ),
          if (isExpanded)
            _buildEpisodesList(season, seasonIndex),
        ],
      ),
    );
  }

  /// Charge les épisodes d'une saison depuis l'API
  Future<void> _loadSeasonEpisodes(int seasonIndex, Season season) async {
    setState(() {
      _loadingSeasons[seasonIndex] = true;
    });

    try {
      print('🔍 Chargement des épisodes pour saison ${season.seasonNumber} de la série ${_fullSeries.id}');
      
      final episodes = await SeriesApiService.getSeasonEpisodes(
        _fullSeries.id ?? '',
        season.seasonNumber,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⚠️ Timeout lors du chargement des épisodes');
          return [];
        },
      );

      print('✅ ${episodes.length} épisodes chargés pour saison ${season.seasonNumber}');

      if (mounted) {
        setState(() {
          _seasonEpisodes[seasonIndex] = episodes;
          _loadingSeasons[seasonIndex] = false;
        });

        // Charger la progression pour tous les épisodes en parallèle
        if (episodes.isNotEmpty) {
          final progressFutures = episodes.map((episode) async {
            final progress = await WatchProgressService.getProgress(
              contentId: '${_fullSeries.id}_${season.seasonNumber}_${episode.episodeNumber}',
              contentType: 'episode',
            );
            return MapEntry(
              '${_fullSeries.id}_${season.seasonNumber}_${episode.episodeNumber}',
              progress,
            );
          }).toList();

          final progressResults = await Future.wait(progressFutures);
          
          if (mounted) {
            setState(() {
              for (final entry in progressResults) {
                _episodeProgress[entry.key] = entry.value;
              }
            });
          }
        }
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des épisodes: $e');
      if (mounted) {
        setState(() {
          _loadingSeasons[seasonIndex] = false;
        });
        
        // Afficher un message à l'utilisateur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des épisodes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Construit la liste des épisodes avec fallback aux données locales
  Widget _buildEpisodesList(Season season, int seasonIndex) {
    // Utiliser les épisodes en cache s'ils existent, sinon utiliser les données de la saison
    final episodes = _seasonEpisodes[seasonIndex] ?? season.episodes;

    if (episodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Aucun épisode disponible',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: episodes.length,
      itemBuilder: (context, episodeIndex) {
        final episode = episodes[episodeIndex];
        final progress = _episodeProgress[
            '${_fullSeries.id}_${season.seasonNumber}_${episode.episodeNumber}'];
        return _buildEpisodeTile(episode, season, progress);
      },
    );
  }

  Widget _buildEpisodeTile(
      Episode episode, Season season, WatchProgress? progress) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.cyberGray,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: progress != null && !progress.isCompleted
                ? AppColors.neonBlue
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            'S${season.seasonNumber}E${episode.episodeNumber}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
      title: Text(
        'Épisode ${episode.episodeNumber}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: progress != null && !progress.isCompleted
              ? AppColors.neonBlue
              : AppColors.textPrimary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (episode.title?.isNotEmpty == true) ...[
            Text(
              episode.title!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (progress.isCompleted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Terminé',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (progress.progressPercentage > 0.05)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.neonYellow,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Reprise à ${progress.formattedPosition}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      trailing: progress != null && progress.progressPercentage > 0.05
          ? IconButton(
              icon:
                  const Icon(Icons.play_circle_fill, color: AppColors.neonBlue),
              onPressed: () => _playEpisode(episode, season),
            )
          : IconButton(
              icon: const Icon(Icons.play_arrow, color: AppColors.neonBlue),
              onPressed: () => _playEpisode(episode, season),
            ),
      onTap: () => _playEpisode(episode, season),
    );
  }

  Widget _buildRecommendationsSection() {
    if (_recommendations.isEmpty && !_isLoadingRecommendations) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            const Text(
              'Séries similaires',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Liste des recommandations
            if (_isLoadingRecommendations)
              SizedBox(
                height: 220,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.neonBlue),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Chargement des recommandations...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_recommendations.isNotEmpty)
              SizedBox(
                height: 240,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recommendations.length,
                  itemBuilder: (context, index) {
                    final series = _recommendations[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index < _recommendations.length - 1 ? 12 : 0,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SeriesDetailsScreen(series: series),
                            ),
                          );
                        },
                        child: MovieCard(
                          movie: movie_model.Movie(
                            id: series.id,
                            title: series.title,
                            originalTitle: series.originalTitle,
                            type: series.type,
                            year: series.year,
                            poster: series.poster,
                            url: series.url,
                            genres: series.genres,
                            rating: series.rating,
                            ratingMax: series.ratingMax,
                            quality: series.quality,
                            version: series.version,
                            actors: series.actors,
                            directors: series.directors,
                            synopsis: series.synopsis,
                            description: series.description,
                            watchLinksCount: series.watchLinksCount,
                            language: series.language,
                            watchLinks: _convertWatchLinks(series.watchLinks),
                            duration: series.duration,
                            releaseDate: series.releaseDateString,
                          ),
                          size: MovieCardSize.small,
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'Aucune recommandation disponible',
                    style: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton.extended(
        onPressed: _isLoadingStream ? null : _playSeries,
        backgroundColor: AppColors.neonBlue,
        foregroundColor: AppColors.cyberBlack,
        icon: _isLoadingStream
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : const Icon(Icons.play_arrow),
        label: Text(_isLoadingStream ? 'Chargement...' : 'Regarder'),
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

  Future<void> _playEpisode(Episode episode, Season season) async {
    await _playEpisodeWithResume(episode, season);
  }

  Future<void> _playEpisodeWithResume(Episode episode, Season season, {bool? fromResume, bool? fromRestart}) async {
    setState(() => _isLoadingStream = true);

    try {
      if (episode.watchLinks == null || episode.watchLinks!.isEmpty) {
        throw Exception('Aucun lien de streaming disponible pour cet épisode.');
      }

      // Utiliser StreamResolver pour tester tous les serveurs
      print('🎬 Résolution du flux pour épisode: S${season.seasonNumber}E${episode.episodeNumber}');
      final streamInfo = await StreamResolver.resolveSeriesStream(episode.watchLinks!);

      if (streamInfo == null) {
        throw Exception('Impossible d\'extraire un flux valide. Tous les serveurs ont échoué.');
      }

      // Formater le titre
      final finalStreamInfo = StreamInfo(
        url: streamInfo.url,
        title: streamInfo.title ?? '${_fullSeries.title} - S${season.seasonNumber}E${episode.episodeNumber}',
        quality: streamInfo.quality,
        headers: streamInfo.headers,
      );
      
      print('✅ Flux épisode résolu: ${finalStreamInfo.url}');

      if (mounted) {
        // Check for existing progress
        final progress = await WatchProgressService.getProgress(
          contentId:
              '${_fullSeries.id ?? ''}_${season.seasonNumber}_${episode.episodeNumber}',
          contentType: 'episode',
        );

        // Convert the Series to SeriesCompact for the video player
        final seriesCompact = SeriesCompact(
          url: _fullSeries.url ?? '',
          title: _fullSeries.title,
          type: 'series',
          mainTitle: _fullSeries.title,
          originalTitle: _fullSeries.originalTitle ?? '',
          genres: _fullSeries.genres,
          director: _fullSeries.director ?? '',
          actors: _fullSeries.actors,
          synopsis: _fullSeries.synopsis ?? '',
          rating: (_fullSeries.rating is num)
              ? (_fullSeries.rating as num).toString()
              : '0.0',
          releaseDate: _fullSeries.releaseDate ?? '',
          poster: _fullSeries.poster ?? '',
          seasons: [], // Empty seasons since this is for direct series playback
        );

        // Navigate to video player with stream info
        Navigator.pushNamed(
          context,
          '/video-player',
          arguments: {
            'series': seriesCompact,
            'season': season,
            'episode': episode,
            'streamInfo': finalStreamInfo,
            'title':
                '${_fullSeries.title} - S${season.seasonNumber}E${episode.episodeNumber} - ${episode.title ?? ''}',
            'startPosition': (fromResume == true) ? progress?.resumePosition : 0,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erreur: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingStream = false);
      }
    }
  }

  Future<void> _playSeries() async {
    // If there's progress, offer to resume
    final allProgress = await WatchProgressService.getAllProgress();
    final seriesProgress = allProgress
        .where((p) => p.contentId == (_fullSeries.id ?? '') && p.isEpisode)
        .toList();

    if (seriesProgress.isNotEmpty) {
      // Find the latest uncompleted episode
      final uncompleted = seriesProgress
          .where((p) => !p.isCompleted)
          .toList();
      
      uncompleted.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
      
      final latestProgress = uncompleted.isNotEmpty ? uncompleted.first : null;

      if (latestProgress != null &&
          (_fullSeries.seasons?.isNotEmpty ?? false)) {
        final season = _fullSeries.seasons!.firstWhere(
          (s) => s.seasonNumber == latestProgress.seasonNumber,
          orElse: () => _fullSeries.seasons!.first,
        );

        final episode = season.episodes.firstWhere(
          (e) => e.episodeNumber == latestProgress.episodeNumber,
          orElse: () => season.episodes.first,
        );

        // Ask user if they want to resume
        final shouldResume = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Reprendre la lecture'),
                content: Text(
                  'Vous avez commencé à regarder ${_fullSeries.title} - '
                  'S${latestProgress.seasonNumber}E${latestProgress.episodeNumber}. '
                  'Voulez-vous reprendre là où vous vous êtes arrêté ?\n\n'
                  'Position: ${Duration(seconds: latestProgress.resumePosition).inMinutes}m ${latestProgress.resumePosition % 60}s',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Non, recommencer'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Oui, reprendre'),
                  ),
                ],
              ),
            ) ??
            false;

        if (shouldResume) {
          await _playEpisode(episode, season);
          return;
        }
      }
    }

    // If no progress or user chose not to resume, play first episode
    if ((_fullSeries.seasons?.isNotEmpty ?? false) &&
        (_fullSeries.seasons?.first.episodes.isNotEmpty ?? false)) {
      await _playEpisode(_fullSeries.seasons!.first.episodes.first, _fullSeries.seasons!.first);
    }
  }

  Future<void> _loadRecommendations() async {
    if (!mounted) return;

    setState(() {
      _isLoadingRecommendations = true;
    });

    try {
      final recommendations = await RecommendationService.getSeriesRecommendations(
        _fullSeries,
        limit: 15,
        verbose: false,
      );

      if (mounted) {
        setState(() {
          _recommendations = recommendations;
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des recommandations: $e');
      if (mounted) {
        setState(() {
          _isLoadingRecommendations = false;
        });
      }
    }
  }

  Future<void> _loadFullSeriesDetails() async {
    try {
      print('📺 SeriesDetailsScreen._loadFullSeriesDetails - Series ID: "${widget.series.id}", Title: "${widget.series.title}"');
      print('📺 Series data keys: ${widget.series.toJson().keys.toList()}');
      
      if (widget.series.id.isEmpty) {
        print('⚠️ Series ID is empty! Using widget.series data only');
        _fullSeries = widget.series;
        if (mounted) {
          setState(() {});
        }
        return;
      }
      
      print('📺 Calling SeriesApiService.getSeriesDetails for ID: ${widget.series.id}');
      final fullSeries = await SeriesApiService.getSeriesDetails(widget.series.id);
      
      print('📺 Full series received:');
      print('   - Title: ${fullSeries.title}');
      print('   - Seasons count: ${fullSeries.seasonsCount}');
      print('   - Episodes count: ${fullSeries.episodesCount}');
      print('   - Seasons list length: ${fullSeries.seasons?.length ?? 0}');
      
      if (fullSeries.seasons != null) {
        for (int i = 0; i < fullSeries.seasons!.length; i++) {
          final season = fullSeries.seasons![i];
          print('   - Season ${season.seasonNumber}: ${season.episodes.length} episodes');
        }
      }
      
      _fullSeries = fullSeries;
      print('📺 Successfully loaded full series details: ${fullSeries.title}, seasons: ${fullSeries.seasons?.length ?? 0}');
      if (mounted) {
        setState(() {
          _fullSeries = fullSeries;
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des détails de la série: $e');
      // En cas d'erreur, utiliser la série de la grille
      if (mounted) {
        setState(() {
          _fullSeries = widget.series;
        });
      }
    }
  }

  /// Bascule l'état favori de la série
  Future<void> _toggleFavorite() async {
    final provider = ref.read(favoritesProvider);

    try {
      final itemId =
          widget.series.url?.hashCode.toString() ?? widget.series.id ?? '';
      // For now, just toggle the local state since we don't have a series-specific favorite method
      setState(() {
        _isFavorite = !_isFavorite;
      });
      final success = true; // Simulate success

      if (success) {
        _showSnackBar(
          _isFavorite
              ? 'Série ajoutée aux favoris'
              : 'Série retirée des favoris',
          isError: false,
        );
      } else {
        _showSnackBar(
          'Erreur lors de la modification des favoris',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar(
        'Erreur: ${e.toString()}',
        isError: true,
      );
    }
  }

  void _shareSeries() async {
    try {
      String shareText =
          'Découvrez "${widget.series.title ?? 'cette série'}" sur NEO STREAM ! 📺\n\n';

      if (widget.series.synopsis?.isNotEmpty == true) {
        final synopsis = widget.series.synopsis!.length > 150
            ? '${widget.series.synopsis!.substring(0, 150)}...'
            : widget.series.synopsis!;
        shareText += '$synopsis\n\n';
      }

      shareText += 'Streaming gratuit sur NEO STREAM !\n';
      shareText += '#NeoStream #Series #Streaming';

      await Share.share(
        shareText,
        subject: 'NEO STREAM - ${widget.series.title ?? 'Série'}',
      );
    } catch (e) {
      debugPrint('Erreur lors du partage: $e');
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  List<movie_model.WatchLink> _convertWatchLinks(List<WatchLink>? links) {
    if (links == null) return [];
    return links.map((l) => movie_model.WatchLink(
      server: l.server,
      url: l.url,
      quality: l.quality,
      type: l.type,
    )).toList();
  }
}

