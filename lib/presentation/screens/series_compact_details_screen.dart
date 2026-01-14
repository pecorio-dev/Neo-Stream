import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/series_compact.dart';
import '../../data/models/stream_info.dart';
import '../../data/extractors/uqload_extractor.dart';
import '../widgets/tv_focusable_card.dart';
import '../widgets/focus_selector_wrapper.dart';
import '../../data/services/platform_service.dart';
// import cpasmieux_image_loader removed
import '../../data/services/series_api_service.dart';
import '../../data/services/dio_client.dart';
import '../../data/models/series.dart';

class SeriesCompactDetailsScreen extends StatefulWidget {
  final SeriesCompact series;

  const SeriesCompactDetailsScreen({
    Key? key,
    required this.series,
  }) : super(key: key);

  @override
  State<SeriesCompactDetailsScreen> createState() =>
      _SeriesCompactDetailsScreenState();
}

class _SeriesCompactDetailsScreenState extends State<SeriesCompactDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final ScrollController _scrollController = ScrollController();
  final FocusNode _backButtonFocus = FocusNode();
  final FocusNode _playButtonFocus = FocusNode();
  final FocusNode _favoriteButtonFocus = FocusNode();

  // Focus nodes pour les épisodes
  final List<FocusNode> _episodeFocusNodes = [];

  int _currentFocusIndex = 0; // 0: back, 1: play, 2: favorite, 3+: episodes
  int _totalFocusableItems = 3; // Sera mis à jour avec le nombre d'épisodes

  // État pour les données détaillées
  bool _isLoadingDetails = false;
  Series? _detailedSeries;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
    _loadSeriesDetails();

    // Auto-focus sur le bouton play après un délai
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _playButtonFocus.requestFocus();
        _currentFocusIndex = 1;
      }
    });
  }

  void _setupEpisodeFocusNodes() {
    // Compter le nombre total d'épisodes depuis les détails si disponibles
    int episodeCount = 0;
    if (_detailedSeries != null && _detailedSeries!.seasons != null) {
      for (final season in _detailedSeries!.seasons!) {
        episodeCount += season.episodes.length;
      }
    } else {
      // Fallback vers les données compactes
      for (final season in widget.series.seasons) {
        episodeCount += season.episodes.length;
      }
    }

    // Créer les focus nodes pour chaque épisode
    for (int i = 0; i < episodeCount; i++) {
      _episodeFocusNodes.add(FocusNode());
    }

    _totalFocusableItems = 3 + episodeCount; // 3 boutons + épisodes
  }

  /// Charge les détails complets de la série avec les épisodes
  Future<void> _loadSeriesDetails() async {
    if (widget.series.totalEpisodes == 0) {
      return; // Pas d'épisodes à charger
    }

    setState(() {
      _isLoadingDetails = true;
    });

    try {
      // Utiliser l'API service pour obtenir les détails complets
      final details = await SeriesApiService.getSeriesDetails(widget.series.id);
      setState(() {
        _detailedSeries = details;
        _isLoadingDetails = false;
      });

      // Mettre à jour les focus nodes après le chargement
      _setupEpisodeFocusNodes();
    } catch (e) {
      print('Error loading series details: $e');
      setState(() {
        _isLoadingDetails = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _backButtonFocus.dispose();
    _playButtonFocus.dispose();
    _favoriteButtonFocus.dispose();

    // Dispose episode focus nodes
    for (final node in _episodeFocusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
  }

  void _startAnimations() {
    _animationController.forward();
  }

  // Navigation TV
  void _navigateUp() {
    setState(() {
      if (_currentFocusIndex > 0) {
        _currentFocusIndex--;
      } else {
        _currentFocusIndex = _totalFocusableItems - 1; // Boucle vers le dernier
      }
    });
    _updateFocus();
    HapticFeedback.selectionClick();
  }

  void _navigateDown() {
    setState(() {
      if (_currentFocusIndex < _totalFocusableItems - 1) {
        _currentFocusIndex++;
      } else {
        _currentFocusIndex = 0; // Boucle vers le premier
      }
    });
    _updateFocus();
    HapticFeedback.selectionClick();
  }

  void _updateFocus() {
    if (_currentFocusIndex == 0) {
      _backButtonFocus.requestFocus();
    } else if (_currentFocusIndex == 1) {
      _playButtonFocus.requestFocus();
    } else if (_currentFocusIndex == 2) {
      _favoriteButtonFocus.requestFocus();
    } else {
      // Focus sur un épisode
      final episodeIndex = _currentFocusIndex - 3;
      if (episodeIndex >= 0 && episodeIndex < _episodeFocusNodes.length) {
        _episodeFocusNodes[episodeIndex].requestFocus();

        // Auto-scroll vers l'épisode focusé
        _scrollToEpisode(episodeIndex);
      }
    }
  }

  void _scrollToEpisode(int episodeIndex) {
    // Calculer la position approximative de l'épisode
    final episodeHeight = 80.0; // Hauteur approximative d'un épisode
    final headerHeight = 600.0; // Hauteur approximative du header
    final targetOffset = headerHeight + (episodeIndex * episodeHeight);

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _handleSelection() {
    if (_currentFocusIndex == 0) {
      _goBack();
    } else if (_currentFocusIndex == 1) {
      _playEpisode();
    } else if (_currentFocusIndex == 2) {
      _toggleFavorite();
    } else {
      // Sélection d'un épisode
      final episodeIndex = _currentFocusIndex - 3;
      _playSelectedEpisode(episodeIndex);
    }
    HapticFeedback.lightImpact();
  }

  void _playSelectedEpisode(int episodeIndex) {
    // Trouver l'épisode correspondant à l'index
    int currentIndex = 0;
    for (final season in widget.series.seasons) {
      for (final episode in season.episodes) {
        if (currentIndex == episodeIndex) {
          _playEpisode(episode, season);
          return;
        }
        currentIndex++;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = Scaffold(
      backgroundColor: AppColors.cyberBlack,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildSliverAppBar(),
              _buildSeriesInfo(),
              _buildActionButtons(),
              _buildEpisodesList(),
            ],
          ),
        ),
      ),
    );

    // Ajouter les raccourcis TV si en mode TV
    if (PlatformService.isTVMode) {
      child = Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.arrowUp): const _PreviousIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowDown): const _NextIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _PreviousIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowRight): const _NextIntent(),
          LogicalKeySet(LogicalKeyboardKey.enter): const _SelectIntent(),
          LogicalKeySet(LogicalKeyboardKey.space): const _SelectIntent(),
          LogicalKeySet(LogicalKeyboardKey.select): const _SelectIntent(),
          LogicalKeySet(LogicalKeyboardKey.escape): const _BackIntent(),
          LogicalKeySet(LogicalKeyboardKey.goBack): const _BackIntent(),
        },
        child: Actions(
          actions: {
            _PreviousIntent: CallbackAction<_PreviousIntent>(
              onInvoke: (intent) {
                _navigateUp();
                return null;
              },
            ),
            _NextIntent: CallbackAction<_NextIntent>(
              onInvoke: (intent) {
                _navigateDown();
                return null;
              },
            ),
            _SelectIntent: CallbackAction<_SelectIntent>(
              onInvoke: (intent) {
                _handleSelection();
                return null;
              },
            ),
            _BackIntent: CallbackAction<_BackIntent>(
              onInvoke: (intent) {
                _goBack();
                return null;
              },
            ),
          },
          child: child,
        ),
      );
    }

    return child;
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.cyberBlack,
      leading: TVFocusableCard(
        focusNode: _backButtonFocus,
        onPressed: _goBack,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.cyberGray.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Image de fond
            widget.series.poster.isNotEmpty
                ? Image(
                    image: NetworkImage(widget.series.poster),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.cyberGray,
                        child: const Icon(
                          Icons.tv,
                          size: 100,
                          color: AppColors.textSecondary,
                        ),
                      );
                    },
                  )
                : Container(
                    color: AppColors.cyberGray,
                    child: const Icon(
                      Icons.tv,
                      size: 100,
                      color: AppColors.textSecondary,
                    ),
                  ),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.cyberBlack.withOpacity(0.7),
                    AppColors.cyberBlack,
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeriesInfo() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            Text(
              widget.series.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            // Informations de base
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (widget.series.releaseDate.isNotEmpty)
                  _buildInfoChip(
                      Icons.calendar_today, widget.series.releaseDate),
                if (widget.series.genres.isNotEmpty)
                  _buildInfoChip(Icons.category, widget.series.genres.first),
                if (widget.series.rating.isNotEmpty)
                  _buildInfoChip(Icons.star, widget.series.rating),
              ],
            ),

            const SizedBox(height: 20),

            // Description
            if (widget.series.synopsis.isNotEmpty) ...[
              const Text(
                'Synopsis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.series.synopsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.neonBlue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.neonBlue.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.neonBlue,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Bouton Play
            Expanded(
              flex: 2,
              child: TVFocusableCard(
                focusNode: _playButtonFocus,
                onPressed: _playEpisode,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.neonBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_arrow,
                        color: AppColors.cyberBlack,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Regarder',
                        style: TextStyle(
                          color: AppColors.cyberBlack,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Bouton Favoris
            TVFocusableCard(
              focusNode: _favoriteButtonFocus,
              onPressed: _toggleFavorite,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cyberGray.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.textSecondary.withOpacity(0.3),
                  ),
                ),
                child: const Icon(
                  Icons.favorite_border,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodesList() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Saisons et Épisodes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (widget.series.totalSeasons > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.neonBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.neonBlue.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      '${widget.series.totalSeasons} saison${widget.series.totalSeasons > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppColors.neonBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

// Liste des saisons et épisodes
            if (_isLoadingDetails)
              _buildLoadingEpisodesPlaceholder()
            else if (_detailedSeries != null &&
                _detailedSeries!.seasons != null)
              ..._detailedSeries!.seasons!
                  .map((season) => _buildSeasonFromDetailed(season))
            else if (widget.series.seasons.isNotEmpty)
              ...widget.series.seasons
                  .map((season) => _buildSeasonSection(season))
            else
              _buildEmptyEpisodesPlaceholder(),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonSection(SeasonCompact season) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
          // En-tête de saison
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.playlist_play,
                  color: AppColors.neonBlue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        season.displayTitle,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        season.formattedInfo,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.neonBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'S${season.seasonNumber}',
                    style: const TextStyle(
                      color: AppColors.neonBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste des épisodes
          if (season.episodes.isNotEmpty)
            ...season.episodes
                .map((episode) => _buildEpisodeItem(episode, season))
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Aucun épisode disponible pour cette saison',
                  style: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeasonFromDetailed(Season season) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cyberBlack.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.cyberGray.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de saison
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.playlist_play,
                  color: AppColors.neonBlue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saison ${season.seasonNumber}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${season.episodes.length} épisode${season.episodes.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${season.episodes.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Liste des épisodes
          ...season.episodes
              .map((episode) => _buildEpisodeFromDetailed(episode, season)),
        ],
      ),
    );
  }

  Widget _buildEpisodeFromDetailed(Episode episode, Season season) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.cyberGray.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.neonBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${episode.episodeNumber}',
              style: TextStyle(
                color: AppColors.neonBlue,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          episode.title ?? 'Épisode ${episode.episodeNumber}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: episode.synopsis != null && episode.synopsis!.isNotEmpty
            ? Text(
                episode.synopsis!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              )
            : null,
        trailing: Icon(
          Icons.play_arrow,
          color: AppColors.neonGreen,
          size: 24,
        ),
        onTap: () => _playEpisodeFromDetailed(episode, season),
      ),
    );
  }

  Widget _buildEpisodeItem(EpisodeCompact episode, SeasonCompact season) {
    // Calculer l'index de cet épisode
    int episodeIndex = 0;
    bool found = false;

    for (final s in widget.series.seasons) {
      for (final e in s.episodes) {
        if (s.seasonNumber == season.seasonNumber &&
            e.episodeNumber == episode.episodeNumber) {
          found = true;
          break;
        }
        episodeIndex++;
      }
      if (found) break;
    }

    final focusNode = episodeIndex < _episodeFocusNodes.length
        ? _episodeFocusNodes[episodeIndex]
        : null;

    return TVFocusableCard(
      focusNode: focusNode,
      onPressed: () => _playEpisode(episode, season),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cyberDark.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.cyberGray.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            // Numéro d'épisode
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.neonBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.neonBlue.withOpacity(0.5),
                ),
              ),
              child: Center(
                child: Text(
                  '${episode.episodeNumber}',
                  style: const TextStyle(
                    color: AppColors.neonBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Informations de l'épisode
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.displayTitle,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (episode.synopsis.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      episode.synopsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    episode.formattedInfo,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Bouton play
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.neonBlue.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: AppColors.neonBlue,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingEpisodesPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.cyberGray.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.cyberGray.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonBlue),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement des épisodes...',
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonFromEpisodes(int seasonNumber, List<dynamic> episodes) {
    final seasonCompact = SeasonCompact(
      url: '',
      title: 'Saison $seasonNumber',
      seasonNumber: seasonNumber,
      episodes: episodes
          .map((e) => EpisodeCompact.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

    return _buildSeasonSection(seasonCompact);
  }

  Widget _buildEmptyEpisodesPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.cyberGray.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.cyberGray.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.tv_off,
            size: 60,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun épisode disponible',
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cette série n\'a pas encore d\'épisodes disponibles',
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    Navigator.pop(context);
  }

  Future<void> _playEpisodeFromDetailed(Episode episode, Season season) async {
    final title =
        '${_detailedSeries?.title ?? widget.series.title} - S${season.seasonNumber}E${episode.episodeNumber} - ${episode.title ?? 'Épisode ${episode.episodeNumber}'}';

    // Trouver le meilleur lien Uqload
    WatchLink? bestUqloadLink;
    if (episode.watchLinks != null) {
      for (final link in episode.watchLinks!) {
        if (UqloadExtractor.isUqloadUrl(link.url)) {
          bestUqloadLink = link;
          break;
        }
      }
    }

    if (bestUqloadLink == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun lien Uqload disponible pour cet épisode.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isLoadingDetails = true);

    // Extraire les informations de streaming pour l'épisode
    StreamInfo? streamInfo = await _extractEpisodeStreamInfoFromDetailed(bestUqloadLink);

    setState(() => _isLoadingDetails = false);

    if (streamInfo == null || streamInfo.url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Échec de l\'extraction du flux Uqload.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Naviguer vers le player vidéo
    Navigator.pushNamed(
      context,
      '/video-player',
      arguments: {
        'series': _detailedSeries ?? widget.series,
        'episode': episode,
        'season': season,
        'title': title,
        'streamInfo': streamInfo,
        'videoUrl': streamInfo.url,
      },
    );
  }

  Future<StreamInfo?> _extractEpisodeStreamInfoFromDetailed(
      WatchLink watchLink) async {
    if (watchLink.url.isEmpty || !watchLink.url.startsWith('http')) {
      return null;
    }

    // Vérifier que le lien est uqload - le lecteur ne supporte que uqload
    if (!UqloadExtractor.isUqloadUrl(watchLink.url)) {
      print(
          '⚠️ Serveur non supporté: ${watchLink.url} - Le lecteur ne supporte que uqload');
      return null;
    }

    print('🎬 Tentative d\'extraction épisode détaillé: ${watchLink.url}');

    try {
      print('🎬 Utilisation de l\'extracteur Uqload pour l\'épisode détaillé');
      final streamInfo = await UqloadExtractor.extractStreamInfo(watchLink.url);

      if (streamInfo != null &&
          streamInfo.url.isNotEmpty &&
          streamInfo.isUqloadUrl) {
        print('✅ Stream extrait avec succès: ${streamInfo.quality}');
        return streamInfo;
      } else {
        print('❌ Échec de l\'extraction du stream');
        return null;
      }
    } catch (e) {
      print('❌ Erreur lors de l\'extraction du stream: $e');
      return null;
    }
  }

  Future<void> _playEpisode(
      [EpisodeCompact? episode, SeasonCompact? season]) async {
    String title;
    StreamInfo? streamInfo;

    if (episode != null && season != null) {
      title =
          '${widget.series.title} - S${season.seasonNumber}E${episode.episodeNumber} - ${episode.displayTitle}';

      // Extraire les informations de streaming pour l'épisode
      if (episode.watchLinks.isNotEmpty) {
        streamInfo = await _extractEpisodeStreamInfo(episode.watchLinks.first);
      }
    } else {
      title = widget.series.title;
      // Si pas d'épisode spécifique, ne pas essayer d'extraire des liens de la série
      // car SeriesCompact n'a pas de watchLinks directement
    }

    // Naviguer vers le player vidéo
    Navigator.pushNamed(
      context,
      '/video-player',
      arguments: {
        'series': widget.series,
        'episode': episode,
        'season': season,
        'title': title,
        'streamInfo': streamInfo,
        'videoUrl': streamInfo?.url ??
            (episode != null
                ? (episode.watchLinks.isNotEmpty
                    ? episode.watchLinks.first.url
                    : null)
                : null),
      },
    );
  }

  /// Extrait les informations de streaming avec l'extracteur approprié pour un épisode
  Future<StreamInfo?> _extractEpisodeStreamInfo(WatchLinkCompact link) async {
    if (link.url.isEmpty || !link.url.startsWith('http')) {
      return null;
    }

    // Vérifier que le lien est uqload - le lecteur ne supporte que uqload
    if (!UqloadExtractor.isUqloadUrl(link.url)) {
      print(
          '⚠️ Serveur non supporté: ${link.server} (${link.url}) - Le lecteur ne supporte que uqload');
      return null;
    }

    print('🎬 Tentative d\'extraction épisode: ${link.server} - ${link.url}');

    try {
      print('🎬 Utilisation de l\'extracteur Uqload pour l\'épisode');
      final streamInfo = await UqloadExtractor.extractStreamInfo(link.url);

      if (streamInfo != null &&
          streamInfo.url.isNotEmpty &&
          streamInfo.isUqloadUrl) {
        print('✅ Extraction épisode réussie: ${streamInfo.url}');
        return streamInfo;
      }
    } catch (e) {
      print('❌ Erreur extraction épisode ${link.server}: $e');
    }

    print('❌ Aucune extraction épisode réussie');
    return null;
  }

  void _toggleFavorite() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Favoris en cours de développement'),
        backgroundColor: AppColors.neonBlue,
      ),
    );
  }
}

// Intent classes pour la navigation TV
class _PreviousIntent extends Intent {
  const _PreviousIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
}

class _SelectIntent extends Intent {
  const _SelectIntent();
}

class _BackIntent extends Intent {
  const _BackIntent();
}


