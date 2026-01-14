import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import cpasmieux_image removed
// import cpasmieux_image_loader removed
import '../widgets/app_image.dart';
import '../widgets/settings_button.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/series.dart';
import '../../data/models/stream_info.dart';
import '../../data/models/watch_progress.dart';
import '../../data/services/series_api_service.dart';
import '../../data/extractors/uqload_extractor.dart';
// import enhanced_video_player_screen removed
import '../screens/player/video_player_with_headers.dart';
import '../providers/watch_progress_provider.dart';
import '../providers/favorites_provider.dart';
import '../../main.dart';

class EnhancedSeriesDetailsScreen extends ConsumerStatefulWidget {
  final Series series;

  const EnhancedSeriesDetailsScreen({Key? key, required this.series})
      : super(key: key);

  @override
  ConsumerState<EnhancedSeriesDetailsScreen> createState() =>
      _EnhancedSeriesDetailsScreenState();
}

class _EnhancedSeriesDetailsScreenState
    extends ConsumerState<EnhancedSeriesDetailsScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _fabAnimationController;
  late TabController _tabController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _fabAnimation;

  final ScrollController _scrollController = ScrollController();
  late Series _series;
  bool _showAppBarTitle = false;
  bool _isFavorite = false;
  bool _isLoadingStream = false;
  int _selectedSeasonIndex = 0;
  WatchProgress? _lastWatchProgress;
  bool _hasRecentProgress = false;
  Map<String, WatchProgress> _episodeProgress = {};

  @override
  void initState() {
    super.initState();

    // Initialiser avec les données passées en argument
    _series = widget.series;

    _animationController = AnimationController(
      duration: AppConstants.mediumAnimation,
      vsync: this,
    );

    _fabAnimationController = AnimationController(
      duration: AppConstants.shortAnimation,
      vsync: this,
    );

    _tabController = TabController(
      length: (_series.seasons?.length ?? 0),
      vsync: this,
    );

    // Charger les vraies données avec watchLinks
    _loadFullSeriesDetails();

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
    _tabController.addListener(_onTabChanged);

    // Démarrer les animations
    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _fabAnimationController.forward();
    });

    // Vérifier si la série est en favoris
    _checkFavoriteStatus();

    // Charger la progression de lecture
    _loadWatchProgress();
  }

  Future<void> _loadFullSeriesDetails() async {
    try {
      print('EnhancedSeriesDetails: Loading full series details for ${_series.id}');
      final fullSeries = await SeriesApiService.getSeriesDetails(_series.id);

      if (mounted) {
        setState(() {
          // Mettre à jour la série avec les vraies données
          _series = fullSeries;
          // Recréer le TabController avec le bon nombre d'onglets
          _tabController.dispose();
          _tabController = TabController(
            length: (_series.seasons?.length ?? 0),
            vsync: this,
          );
          _tabController.addListener(_onTabChanged);
        });
        print('EnhancedSeriesDetails: ✅ Full series details loaded: ${fullSeries.watchLinks?.length ?? 0} watch links, ${fullSeries.totalEpisodes} episodes');
      }
    } catch (e) {
      print('EnhancedSeriesDetails: ❌ Error loading full series details: $e');
      // En cas d'erreur, garder les données actuelles
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fabAnimationController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShowTitle = _scrollController.offset > 200;
    if (shouldShowTitle != _showAppBarTitle) {
      setState(() => _showAppBarTitle = shouldShowTitle);
    }
  }

  void _onTabChanged() {
    setState(() => _selectedSeasonIndex = _tabController.index);
  }

  void _checkFavoriteStatus() async {
    final provider = ref.read(favoritesProvider);
    final itemId = _series.url.hashCode.toString();
    final isFav = await provider.isFavorite(itemId);
    if (mounted) {
      setState(() => _isFavorite = isFav);
    }
  }

  void _loadWatchProgress() async {
    final progressProvider = ref.read(watchProgressProvider);

    try {
      // Charger la progression de la série (dernier épisode regardé)
      final seriesProgressList =
          await progressProvider.getSeriesProgress(_series.id);

      if (seriesProgressList.isNotEmpty) {
        // Prendre le plus récent
        seriesProgressList
            .sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
        final seriesProgress = seriesProgressList.first;

        setState(() {
          _lastWatchProgress = seriesProgress;
          _hasRecentProgress = true;
        });
        print('📺 Progression trouvée: ${seriesProgress.toString()}');
      } else {
        setState(() {
          _hasRecentProgress = false;
        });
        print('📺 Aucune progression trouvée pour la série');
      }

      // Charger la progression de tous les épisodes
      await _loadAllEpisodesProgress();
    } catch (e) {
      print('❌ Erreur lors du chargement de la progression: $e');
      setState(() {
        _hasRecentProgress = false;
      });
    }
  }

  Future<void> _loadAllEpisodesProgress() async {
    final progressProvider = ref.read(watchProgressProvider);
    final episodeProgress = <String, WatchProgress>{};

    for (final season in _series.seasons ?? []) {
      for (final episode in season.episodes) {
        try {
          final progress = await progressProvider.getProgress(
            contentId: _series.id,
            contentType: 'series',
            seasonNumber: season.seasonNumber,
            episodeNumber: episode.episodeNumber,
          );

          if (progress != null) {
            final key = '${season.seasonNumber}_${episode.episodeNumber}';
            episodeProgress[key] = progress;
          }
        } catch (e) {
          print(
              '❌ Erreur lors du chargement de la progression de l\'épisode S${season.seasonNumber}E${episode.episodeNumber}: $e');
        }
      }
    }

    setState(() {
      _episodeProgress = episodeProgress;
    });

    print('📺 Progression chargée pour ${episodeProgress.length} épisodes');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          _buildSeriesInfo(),
          _buildSeriesDetails(),
          if ((_series.seasons?.isNotEmpty ?? false))
            _buildEpisodesSection(),
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
      backgroundColor: AppTheme.backgroundPrimary,
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
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : Colors.white,
            ),
            onPressed: _toggleFavorite,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: const SettingsButton(color: Colors.white),
        ),
      ],
      title: _showAppBarTitle
          ? FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                _series.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Backdrop Image
            if (_series.poster?.isNotEmpty ?? false)
              AppImage(
                _series.poster ?? '',
                fit: BoxFit.cover,
                placeholder: Container(
                  color: AppTheme.surface,
                ),
                errorWidget: Container(
                  color: AppTheme.surface,
                  child: const Icon(Icons.movie, color: Colors.white, size: 50),
                ),
              )
            else
              Container(color: AppTheme.surface),

            // Gradient Overlay
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                    Colors.transparent,
                    AppTheme.backgroundPrimary,
                  ],
                  stops: [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),

            // Series Title Overlay (only shown when not scrolled)
            if (!_showAppBarTitle)
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _series.title,
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
                    const SizedBox(height: 8),
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
        if (_series.rating != null && _series.rating != '0.0') ...[
          const Icon(Icons.star, color: Colors.amber, size: 16),
          const SizedBox(width: 4),
          Text(
            _series.rating.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (_series.year != null && _series.year != 0) ...[
          Text(
            _series.year.toString(),
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (_series.quality?.isNotEmpty ?? false) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _series.quality ?? 'N/A',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
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
              // Synopsis
              if (_series.synopsis != null && _series.synopsis!.isNotEmpty) ...[
                const Text(
                  'Synopsis',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _series.synopsis!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Genres
              if (_series.genres != null && _series.genres!.isNotEmpty) ...[
                SizedBox(
                  height: 32,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _series.genres!.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Text(
                          _series.genres![index],
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeriesDetails() {
    return SliverToBoxAdapter(
      child: SlideTransition(
        position: _slideAnimation.drive(
          Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_series.director != null && _series.director!.isNotEmpty)
                _buildDetailRow('Réalisateur', _series.director!),
              if (_series.actors != null && _series.actors!.isNotEmpty)
                _buildDetailRow('Acteurs', _series.actors!.join(', ')),
              if (_series.duration != null && _series.duration! > 0)
                _buildDetailRow('Durée', '${_series.duration} min'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesSection() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Épisodes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Material(
            color: AppTheme.backgroundPrimary,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppTheme.accentNeon,
              tabs: (_series.seasons ?? [])
                  .map((season) => Tab(text: 'Saison ${season.seasonNumber}'))
                  .toList(),
            ),
          ),
          SizedBox(
            height: 400,
            child: Material(
              color: AppTheme.backgroundPrimary,
              child: TabBarView(
                controller: _tabController,
                children: (_series.seasons ?? [])
                    .map((season) => _buildEpisodesList(season))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesList(Season season) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      itemCount: season.episodes.length,
      itemBuilder: (context, index) {
        final episode = season.episodes[index];
        final key = '${season.seasonNumber}_${episode.episodeNumber}';
        final progress = _episodeProgress[key];

        return Card(
          color: AppTheme.surface,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      'E${episode.episodeNumber}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (progress != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 3,
                      color: AppTheme.accentNeon.withOpacity(0.3),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress.progressPercentage,
                        child: Container(color: AppTheme.accentNeon),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              episode.title ?? 'Épisode ${episode.episodeNumber}',
              style: const TextStyle(color: Colors.white),
            ),
            trailing: const Icon(Icons.play_arrow, color: AppTheme.accentNeon),
            onTap: () => _playEpisode(episode, season.seasonNumber),
          ),
        );
      },
    );
  }

  Widget _buildPlayButton() {
    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton.extended(
        onPressed: _isLoadingStream ? null : _playLastEpisode,
        backgroundColor: AppTheme.accentNeon,
        icon: _isLoadingStream
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
              )
            : const Icon(Icons.play_arrow, color: Colors.black),
        label: Text(
          _isLoadingStream
              ? 'Chargement...'
              : (_hasRecentProgress ? 'Continuer' : 'Regarder'),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _playLastEpisode() {
    if (_hasRecentProgress && _lastWatchProgress != null) {
      // Trouver l'épisode correspondant dans la série
      final season = (_series.seasons ?? []).firstWhere(
        (s) => s.seasonNumber == _lastWatchProgress!.seasonNumber,
        orElse: () => _series.seasons!.first,
      );
      final episode = season.episodes.firstWhere(
        (e) => e.episodeNumber == _lastWatchProgress!.episodeNumber,
        orElse: () => season.episodes.first,
      );
      _playEpisode(episode, season.seasonNumber);
    } else if ((_series.seasons?.isNotEmpty ?? false) &&
        (_series.seasons!.first.episodes.isNotEmpty)) {
      _playEpisode(
          _series.seasons!.first.episodes.first, _series.seasons!.first.seasonNumber);
    }
  }

  Future<void> _playEpisode(Episode episode, int seasonNumber) async {
    // 1. Filtrer pour ne garder que les liens Uqload
    final uqloadLinks = (episode.watchLinks ?? <WatchLink>[]).where((link) => 
      UqloadExtractor.isUqloadUrl(link.url)
    ).toList();

    // 2. Si pas de lien Uqload pour l'épisode, chercher dans la série (parfois les liens sont globaux)
    WatchLink? actualLink;
    if (uqloadLinks.isNotEmpty) {
      actualLink = uqloadLinks.first;
    } else {
      print('⚠️ Aucun lien Uqload direct pour l\'épisode, recherche alternative...');
      final uqloadLink = (_series.watchLinks ?? []).firstWhere(
        (link) => UqloadExtractor.isUqloadUrl(link.url),
        orElse: () => WatchLink(server: '', url: ''),
      );
      
      if (uqloadLink.url.isEmpty) {
        print('❌ Aucun lien Uqload disponible pour cet épisode/série');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucun lien de streaming Uqload disponible pour cet épisode.'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      actualLink = uqloadLink;
      print('✅ Lien Uqload alternatif trouvé: ${actualLink.url}');
    }

    setState(() => _isLoadingStream = true);

    try {
      print('📺 Tentative de lecture de l\'épisode');
      print('📺 Série: ${_series.title}');
      print('📺 Saison: $seasonNumber');
      print('📺 Épisode: ${episode.episodeNumber}');

      late StreamInfo streamInfo;

      // Extraire les informations de stream depuis Uqload
      final extractedInfo = await UqloadExtractor.extractStreamInfo(actualLink.url);
      streamInfo = StreamInfo(
        url: extractedInfo.url,
        title: extractedInfo.title ??
            '${_series.title} - S${seasonNumber}E${episode.episodeNumber}',
        quality: extractedInfo.quality,
        headers: extractedInfo.headers,
      );

      if (streamInfo.url.isEmpty) {
        throw Exception('Échec de l\'extraction du flux Uqload');
      }

      // Vérifier s'il y a une progression existante pour déterminer la position de départ
      int startPosition = 0;
      final progressProvider = ref.read(watchProgressProvider);
      final existingProgress = await progressProvider.getProgress(
        contentId: _series.id,
        contentType: 'series',
        seasonNumber: seasonNumber,
        episodeNumber: episode.episodeNumber,
      );

      if (existingProgress != null && !existingProgress.isNearlyFinished) {
        startPosition = existingProgress.resumePosition;
        print(
            '🔄 Reprise à la position: ${existingProgress.formattedPosition}');
      }

      // Naviguer vers le lecteur vidéo via la route nommée
      if (mounted) {
        final result = await Navigator.pushNamed(
          context,
          '/video-player',
          arguments: {
            'streamInfo': streamInfo,
            'title':
                '${_series.title} - S${seasonNumber}E${episode.episodeNumber} - ${episode.title}',
            'series': widget.series,
            'seasonNumber': seasonNumber,
            'episodeNumber': episode.episodeNumber,
            'startPosition': startPosition,
          },
        );

        // Recharger la progression après le retour du lecteur
        if (result != null) {
          _loadWatchProgress();
        }
      }
    } catch (e) {
      print('📺 Erreur lors de l\'extraction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStream = false;
        });
      }
    }
  }

  /// Actualise les données des séries depuis l'API
  Future<void> _refreshSeriesData() async {
    try {
      setState(() {
        _isLoadingStream = true; // Réutiliser ce flag pour l'état de chargement
      });

      final success = await SeriesApiService.refreshSeriesData();

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Récupération des données déclenchée. Les informations s\'actualiseront automatiquement.'),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Échec du déclenchement de la récupération'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Erreur lors du déclenchement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStream = false;
        });
      }
    }
  }

  /// Bascule l'état favori de la série
  Future<void> _toggleFavorite() async {
    final provider = ref.read(favoritesProvider);

    try {
      final success =
          await provider.toggleSeriesFavorite(widget.series);

      if (success) {
        setState(() {
          _isFavorite = !_isFavorite;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFavorite
                ? 'Série ajoutée aux favoris'
                : 'Série retirée des favoris'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors de la modification des favoris'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
}


