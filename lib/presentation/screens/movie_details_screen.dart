import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/favorites_provider.dart';
import '../widgets/settings_button.dart';
import '../widgets/movie_card.dart';
import '../widgets/focus_selector_wrapper.dart';
import '../widgets/sync_status_indicator.dart';
import '../widgets/app_image.dart';
import '../screens/resume_watch_section.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/movie.dart';
import '../../data/models/stream_info.dart';
import '../../data/extractors/uqload_extractor.dart';
import '../../data/services/stream_resolver.dart';
import '../../data/services/platform_service.dart';
import '../../data/services/movies_api_service.dart';
import '../../data/services/recommendation_service.dart';
import '../../data/models/watch_progress.dart';
import '../../core/services/watch_progress_service.dart';
import '../../main.dart';

class MovieDetailsScreen extends ConsumerStatefulWidget {
  final Movie movie;

  const MovieDetailsScreen({Key? key, required this.movie}) : super(key: key);

  @override
  ConsumerState<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends ConsumerState<MovieDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _fabAnimation;

  final ScrollController _scrollController = ScrollController();
  bool _showAppBarTitle = false;
  bool _isFavorite = false;
  bool _isLoadingStream = false;
  bool _isLoadingRecommendations = false;
  late Movie _fullMovie;
  List<Movie> _recommendations = [];

  // TV Navigation
  final FocusNode _backButtonFocus = FocusNode();
  final FocusNode _favoriteButtonFocus = FocusNode();
  final FocusNode _shareButtonFocus = FocusNode();
  final FocusNode _playButtonFocus = FocusNode();
  int _currentFocusIndex = 0;

  @override
  void initState() {
    super.initState();

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

    // Vérifier si le film est en favoris
    _checkFavoriteStatus();

    // Charger les détails complets du film (avec les liens de streaming)
    _loadFullMovieDetails();

    // Charger les recommandations
    _loadRecommendations();

    // Auto-focus sur le bouton play en mode TV
    if (PlatformService.isTVMode) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _playButtonFocus.requestFocus();
        }
      });
    }
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

    // Dispose focus nodes
    _backButtonFocus.dispose();
    _favoriteButtonFocus.dispose();
    _shareButtonFocus.dispose();
    _playButtonFocus.dispose();

    super.dispose();
  }

  /// Vérifie si le film est en favoris
  Future<void> _checkFavoriteStatus() async {
    final provider = ref.read(favoritesProvider);
    final itemId =
        widget.movie.url?.hashCode.toString() ?? widget.movie.id ?? '';
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
    Widget child = Scaffold(
      backgroundColor: AppColors.cyberBlack,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildSliverAppBar(),
              _buildMovieInfo(),
              _buildResumeSection(),
              _buildMovieDetails(),
              _buildRecommendationsSection(),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // Position indicator for TV
          if (PlatformService.isTVMode)
            FocusPositionIndicator(
              currentIndex: _currentFocusIndex,
              totalItems: 4,
              label: 'Contrôle',
            ),
        ],
      ),
      floatingActionButton: _buildPlayButton(),
    );

    // Add TV shortcuts if in TV mode
    if (PlatformService.isTVMode) {
      child = Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.arrowUp): const _PreviousIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowDown): const _NextIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _PreviousIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowRight): const _NextIntent(),
          LogicalKeySet(LogicalKeyboardKey.enter): const _SelectIntent(),
          LogicalKeySet(LogicalKeyboardKey.space): const _SelectIntent(),
          LogicalKeySet(LogicalKeyboardKey.escape): const _BackIntent(),
        },
        child: Actions(
          actions: {
            _PreviousIntent: CallbackAction<_PreviousIntent>(
              onInvoke: (intent) {
                _navigateFocus(false);
                return null;
              },
            ),
            _NextIntent: CallbackAction<_NextIntent>(
              onInvoke: (intent) {
                _navigateFocus(true);
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
                Navigator.pop(context);
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
      expandedHeight: 400,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.cyberBlack,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: FocusSelectorWrapper(
        focusNode: _backButtonFocus,
        onPressed: () => Navigator.pop(context),
        semanticLabel: 'Retour',
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      actions: [
        FocusSelectorWrapper(
          focusNode: _favoriteButtonFocus,
          onPressed: _toggleFavorite,
          semanticLabel:
              _isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
          borderRadius: BorderRadius.circular(20),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
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
        ),
        FocusSelectorWrapper(
          focusNode: _shareButtonFocus,
          onPressed: _shareMovie,
          semanticLabel: 'Partager',
          borderRadius: BorderRadius.circular(20),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share, color: Colors.white),
          ),
        ),
        SizedBox(
          width: 32,
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: AppColors.cyberGray,
            onSelected: (value) {
              if (value == 'refresh') {
                _loadFullMovieDetails();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: AppColors.neonBlue, size: 20),
                    SizedBox(width: 8),
                    Text('Actualiser', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
      title: AnimatedOpacity(
        opacity: _showAppBarTitle ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Text(
          widget.movie.title ?? 'Détails du film',
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
            if (widget.movie.poster?.isNotEmpty == true)
              AppImage(
                widget.movie.poster!,
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

            // Movie Info Overlay
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.movie.title?.isNotEmpty == true)
                    Text(
                      widget.movie.title!,
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
        if (widget.movie.rating != null && (widget.movie.rating as num) > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getRatingColor((widget.movie.rating as num).toDouble())
                  .withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _getRatingColor((widget.movie.rating as num).toDouble())
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
                      _getRatingColor((widget.movie.rating as num).toDouble()),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  (widget.movie.rating as num).toStringAsFixed(1),
                  style: TextStyle(
                    color: _getRatingColor(
                        (widget.movie.rating as num).toDouble()),
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
        if (widget.movie.releaseYear != null &&
            widget.movie.releaseYear! > 0) ...[
          Text(
            widget.movie.releaseYear.toString(),
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
        ],

        // Durée
        if (widget.movie.duration != null && widget.movie.duration! > 0) ...[
          const Icon(Icons.timer_outlined, color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Text(
            _formatDuration(widget.movie.duration!),
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
        ],

        // Version & Langue
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.movie.version?.isNotEmpty == true) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.neonBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.movie.version!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (widget.movie.language?.isNotEmpty == true) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.neonPurple,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.movie.language!.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMovieInfo() {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Genres
              if (widget.movie.genres?.isNotEmpty == true) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.movie.genres!.take(5).map((genre) {
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

              // Informations détaillées
              const Text(
                'Informations détaillées',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              
              if (widget.movie.synopsis?.isNotEmpty == true) ...[
                const Text(
                  'Synopsis',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.movie.synopsis!,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
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
    return SliverToBoxAdapter(
      child: ResumeWatchSection(
        contentId: widget.movie.id ?? '',
        contentType: 'movie',
        title: widget.movie.title ?? 'Untitled',
        duration: widget.movie.duration != null && widget.movie.duration is String
          ? Duration(minutes: int.tryParse(widget.movie.duration.toString()) ?? 0)
          : null,
        onResumePressed: () => _playMovie(fromResume: true),
        onRestartPressed: () => _playMovie(fromResume: false),
      ),
    );
  }

  Widget _buildMovieDetails() {
    return SliverToBoxAdapter(
      child: SlideTransition(
        position: _slideAnimation.drive(
          Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cyberGray.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.movie.quality?.isNotEmpty == true) ...[
                  _buildDetailRow('Qualité', widget.movie.quality!),
                  const Divider(color: Colors.white10, height: 24),
                ],
                if (widget.movie.version?.isNotEmpty == true) ...[
                  _buildDetailRow('Version', widget.movie.version!),
                  const Divider(color: Colors.white10, height: 24),
                ],
                if (widget.movie.language?.isNotEmpty == true) ...[
                  _buildDetailRow('Langue', widget.movie.language!),
                  const Divider(color: Colors.white10, height: 24),
                ],
                if (widget.movie.releaseYear != null &&
                    widget.movie.releaseYear! > 0) ...[
                  _buildDetailRow('Année', widget.movie.releaseYear.toString()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  'Recommandations',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                if (_isLoadingRecommendations)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonBlue),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_recommendations.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recommendations.length,
                  itemBuilder: (context, index) {
                    final movie = _recommendations[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(
                            context,
                            '/movie-detail',
                            arguments: movie,
                          );
                        },
                        child: MovieCard(
                          movie: movie,
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              const Center(
                child: Text(
                  'Aucune recommandation disponible',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
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
      child: FocusSelectorWrapper(
        focusNode: _playButtonFocus,
        onPressed: _isLoadingStream ? null : () => _playMovie(),
        semanticLabel: _isLoadingStream ? 'Chargement...' : 'Regarder le film',
        borderRadius: BorderRadius.circular(28),
        child: FloatingActionButton.extended(
          onPressed: null, // Handled by wrapper
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

  Color _getQualityColor(String quality) {
    switch (quality.toUpperCase()) {
      case '4K':
        return const Color(0xFFFF6B35); // Orange vif
      case 'HD':
        return const Color(0xFF00D4FF); // Cyan néon
      case 'SD':
        return const Color(0xFFFFA500); // Orange
      default:
        return AppColors.neonBlue;
    }
  }

  Color _getVersionColor(String version) {
    switch (version.toLowerCase()) {
      case 'french':
      case 'truefrench':
        return const Color(0xFF2196F3); // Bleu français
      case 'english':
        return const Color(0xFF4CAF50); // Vert anglais
      case 'multi':
        return const Color(0xFF9C27B0); // Violet multi
      default:
        return AppColors.neonPurple;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            '$label :',
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours > 0) {
      return '${hours}h ${mins.toString().padLeft(2, '0')}min';
    } else {
      return '${mins}min';
    }
  }

  Future<void> _playMovie({bool? fromResume, bool? fromRestart}) async {
    setState(() => _isLoadingStream = true);

    try {
      // Check if there's existing progress for this movie
      final progress = await WatchProgressService.getProgress(
        contentId: widget.movie.id ?? '',
        contentType: 'movie',
      );

      bool shouldResume = false;
      
      // Si l'utilisateur a cliqué sur "Continuer" ou "Recommencer" depuis ResumeWatchSection
      if (fromResume == true) {
        shouldResume = true;
      } else if (fromRestart == true) {
        shouldResume = false;
      } else if (progress != null &&
          progress.progressPercentage > 0.05 &&
          progress.progressPercentage < 0.95) {
        // Ask user if they want to resume
        shouldResume = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Reprendre la lecture'),
                content: Text(
                  'Vous avez commencé à regarder ${widget.movie.title ?? 'ce film'}. '
                  'Voulez-vous reprendre là où vous vous êtes arrêté ?\n\n'
                  'Position: ${Duration(seconds: progress.resumePosition).inMinutes}m ${progress.resumePosition % 60}s',
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
      }

      // Extraire les informations de streaming
      StreamInfo? streamInfo = await _extractStreamInfo();

      if (streamInfo == null) {
        throw Exception('Aucun lien de streaming disponible');
      }

      if (mounted) {
        // Naviguer vers le player vidéo avec les informations de stream
        Navigator.pushNamed(
          context,
          '/video-player',
          arguments: {
            'movie': widget.movie,
            'title': widget.movie.title ?? 'Film',
            'streamInfo': streamInfo,
            'startPosition': shouldResume ? progress?.resumePosition : 0,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erreur lors du chargement: ${e.toString()}',
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingStream = false);
      }
    }
  }

  /// Extrait les informations de streaming avec l'extracteur approprié
  Future<StreamInfo?> _extractStreamInfo() async {
    if ((_fullMovie.watchLinks?.isEmpty ?? true)) {
      print('⚠️ Aucun lien de visionnage trouvé pour ce film');
      return null;
    }

    // Utiliser le StreamResolver pour tester tous les serveurs disponibles
    print('🎬 Résolution du flux pour: ${widget.movie.title}');
    final streamInfo = await StreamResolver.resolveMovieStream(_fullMovie.watchLinks!);

    if (streamInfo == null) {
      print('❌ Impossible de résoudre le flux vidéo');
      if (mounted) {
        _showSnackBar(
          'Aucun lien de streaming disponible pour ce film. Tous les serveurs ont échoué.',
          isError: true,
        );
      }
      return null;
    }

    // Ajouter le titre et la qualité
    final finalStreamInfo = StreamInfo(
      url: streamInfo.url,
      title: streamInfo.title ?? widget.movie.title ?? 'Film',
      quality: streamInfo.quality,
      headers: streamInfo.headers,
    );
    
    print('✅ Flux résolu avec succès: ${finalStreamInfo.url}');
    return finalStreamInfo;
  }
  
  // Ancienne méthode conservée pour compatibilité (peut être supprimée plus tard)
  Future<StreamInfo?> _extractStreamInfoOld() async {
    if ((_fullMovie.watchLinks?.isEmpty ?? true)) {
      print('⚠️ Aucun lien de visionnage trouvé pour ce film');
      return null;
    }

    final uqloadLinks = (_fullMovie.watchLinks ?? []).where((link) => 
      UqloadExtractor.isUqloadUrl(link.url)
    ).toList();

    if (uqloadLinks.isEmpty) {
      print('⚠️ Aucun lien Uqload disponible pour ce film');
      return null;
    }

    for (final link in uqloadLinks) {
      if (link.url.isEmpty || !link.url.startsWith('http')) {
        continue;
      }

      print('🎬 Tentative d\'extraction Uqload: ${link.server} - ${link.url}');

      try {
        final extractedInfo = await UqloadExtractor.extractStreamInfo(link.url);
        
        if (extractedInfo.url.isNotEmpty) {
          final streamInfo = StreamInfo(
            url: extractedInfo.url,
            title: extractedInfo.title ?? widget.movie.title ?? 'Film',
            quality: extractedInfo.quality,
            headers: extractedInfo.headers,
          );
          
          print('✅ Extraction réussie: ${streamInfo.url}');
          return streamInfo;
        }
      } catch (e) {
        print('❌ Erreur extraction ${link.server}: $e');
        continue;
      }
    }

    if (mounted) {
      _showSnackBar(
        'Impossible d\'extraire un flux valide depuis les liens Uqload disponibles.',
        isError: true,
      );
    }
    return null;
  }

  /// Charge les détails complets du film avec les liens de streaming
  Future<void> _loadFullMovieDetails() async {
    try {
      print('🎬 MovieDetailsScreen._loadFullMovieDetails - Movie ID: "${widget.movie.id}", Title: "${widget.movie.title}"');
      print('🎬 Movie data keys: ${widget.movie.toJson().keys.toList()}');
      
      if (widget.movie.id.isEmpty) {
        print('⚠️ Movie ID is empty! Using widget.movie data only');
        _fullMovie = widget.movie;
        return;
      }
      
      final fullMovie = await MoviesApiService.getMovieDetails(widget.movie.id);
      print('🎬 Successfully loaded full movie details: ${fullMovie.title}');
      if (mounted) {
        setState(() {
          _fullMovie = fullMovie;
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des détails du film: $e');
      // En cas d'erreur, utiliser le film de la grille
      _fullMovie = widget.movie;
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// Charge les recommandations depuis l'API
  Future<void> _loadRecommendations() async {
    if (!mounted) return;

    setState(() {
      _isLoadingRecommendations = true;
    });

    try {
      final recommendations =
          await RecommendationService.getMovieRecommendations(
        widget.movie,
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

  /// Bascule l'état favori du film
  Future<void> _toggleFavorite() async {
    final provider = ref.read(favoritesProvider);

    try {
      final itemId =
          widget.movie.url?.hashCode.toString() ?? widget.movie.id ?? '';
      final success = await provider.toggleMovieFavorite(widget.movie);

      if (success) {
        setState(() {
          _isFavorite = !_isFavorite;
        });

        _showSnackBar(
          _isFavorite ? 'Film ajouté aux favoris' : 'Film retiré des favoris',
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

  void _shareMovie() async {
    try {
      String shareText =
          'Découvrez "${widget.movie.title ?? 'ce film'}" sur NEO STREAM ! 🎬\n\n';

      if (widget.movie.synopsis?.isNotEmpty == true) {
        final synopsis = widget.movie.synopsis!.length > 150
            ? '${widget.movie.synopsis!.substring(0, 150)}...'
            : widget.movie.synopsis!;
        shareText += '$synopsis\n\n';
      }

      if (widget.movie.genres?.isNotEmpty == true) {
        shareText += 'Genre: ${widget.movie.genres!.join(', ')}\n';
      }

      if (widget.movie.releaseYear != null && widget.movie.releaseYear! > 0) {
        shareText += 'Année: ${widget.movie.releaseYear}\n';
      }

      if (widget.movie.rating != null &&
          (widget.movie.rating is num) &&
          (widget.movie.rating as num) > 0) {
        shareText +=
            'Note: ${(widget.movie.rating as num).toStringAsFixed(1)}/10\n';
      }

      shareText += '\nStreaming gratuit sur NEO STREAM !\n';
      shareText += '#NeoStream #Cinema #Film #Streaming';

      await Share.share(
        shareText,
        subject: 'NEO STREAM - ${widget.movie.title ?? 'Film'}',
      );
    } catch (e) {
      debugPrint('Erreur lors du partage: $e');
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Erreur lors de l\'affichage du SnackBar: $e');
    }
  }

  // TV Navigation methods
  void _navigateFocus(bool isNext) {
    final focusNodes = [
      _backButtonFocus,
      _favoriteButtonFocus,
      _shareButtonFocus,
      _playButtonFocus
    ];

    if (isNext) {
      _currentFocusIndex = (_currentFocusIndex + 1) % focusNodes.length;
    } else {
      _currentFocusIndex =
          (_currentFocusIndex - 1 + focusNodes.length) % focusNodes.length;
    }

    focusNodes[_currentFocusIndex].requestFocus();
    HapticFeedback.selectionClick();
  }

  void _handleSelection() {
    switch (_currentFocusIndex) {
      case 0:
        Navigator.pop(context);
        break;
      case 1:
        _toggleFavorite();
        break;
      case 2:
        _shareMovie();
        break;
      case 3:
        if (!_isLoadingStream) _playMovie();
        break;
    }
    HapticFeedback.lightImpact();
  }
}

// Intent classes for TV navigation
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
