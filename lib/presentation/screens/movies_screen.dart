import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../widgets/animations/animated_card.dart';
import '../widgets/app_image.dart';
import '../../core/design_system/animation_system.dart';
import '../../core/design_system/color_system.dart';
import '../../data/models/movie.dart';
import '../../data/services/platform_service.dart';
import '../widgets/account_switcher_button.dart';
import '../providers/movies_provider.dart';

class MoviesScreen extends ConsumerStatefulWidget {
  const MoviesScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends ConsumerState<MoviesScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _contentController;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(moviesProvider).loadMovies();
      }
    });
  }

  void _setupAnimations() {
    _headerController = AnimationController(
      duration: AnimationSystem.long,
      vsync: this,
    );

    _contentController = AnimationController(
      duration: AnimationSystem.veryLong,
      vsync: this,
    );

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _contentController.forward();
    });
  }

  void _setupScrollController() {
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollListener);
  }

  void _onScrollListener() {
    try {
      if (_scrollController.hasClients) {
        final position = _scrollController.position;
        if (position.pixels >= position.maxScrollExtent - 200) {
          final provider = ref.read(moviesProvider);
          if (!provider.isLoading && provider.hasMore) {
            provider.loadMoreMovies();
          }
        }
      }
    } catch (e) {
      debugPrint('Scroll listener error: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollListener);
    _scrollController.dispose();
    _headerController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorSystem.backgroundPrimary,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          _buildMoviesGrid(),
          _buildLoadingIndicator(),
        ],
      ),
      floatingActionButton: const AccountSwitcherFAB(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: _buildSpectacularHeader(),
        collapseMode: CollapseMode.parallax,
      ),
    );
  }

  Widget _buildSpectacularHeader() {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ColorSystem.neonCyan.withOpacity(0.1),
              ColorSystem.neonPurple.withOpacity(0.1),
              ColorSystem.neonPink.withOpacity(0.1),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: NeonGridPainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedNeonText(
                    'FILMS',
                    textStyle: const TextStyle(
                      color: ColorSystem.neonCyan,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                    duration: const Duration(milliseconds: 1000),
                  ),
                  const SizedBox(height: 12),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        ColorSystem.purplePinkGradient.createShader(bounds),
                    child: const Text(
                      'Découvrez nos films sélectionnés',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      AnimatedNeonButton(
                        label: 'EXPLORER',
                        onPressed: () {},
                        color: ColorSystem.neonCyan,
                        hoverColor: ColorSystem.neonGreen,
                      ),
                      const SizedBox(width: 12),
                      AnimatedNeonButton(
                        label: 'FAVORIS',
                        onPressed: () {},
                        color: ColorSystem.neonPink,
                        hoverColor: ColorSystem.neonPurple,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoviesGrid() {
    final provider = ref.watch(moviesProvider);
    
    if (provider.isLoading && provider.movies.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Center(
            child: NeonLoadingIndicator(
              color: ColorSystem.neonCyan,
              size: 70,
            ),
          ),
        ),
      );
    }

    if (provider.error != null && provider.movies.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: ColorSystem.neonPink,
                ),
                const SizedBox(height: 24),
                Text(
                  provider.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ColorSystem.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedNeonButton(
                  label: 'RÉESSAYER',
                  onPressed: () => ref.read(moviesProvider).loadMovies(),
                  color: ColorSystem.neonCyan,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (provider.movies.isEmpty) {
      return _buildEmptyState();
    }

    if (PlatformService.isTVMode) {
      return _buildTVGrid(provider.movies);
    }

    return _buildMobileGrid(provider.movies);
  }

  Widget _buildMobileGrid(List<Movie> movies) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 20,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final movie = movies[index];
            return _buildAnimatedMovieCard(movie, index);
          },
          childCount: movies.length,
        ),
      ),
    );
  }

  Widget _buildTVGrid(List<Movie> movies) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          crossAxisSpacing: 20,
          mainAxisSpacing: 25,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final movie = movies[index];
            return _buildAnimatedMovieCard(movie, index);
          },
          childCount: movies.length,
        ),
      ),
    );
  }

  Widget _buildAnimatedMovieCard(Movie movie, int index) {
    final delay = index * 50;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _contentController,
          curve: Interval(
            (delay / 800).clamp(0.0, 1.0),
            ((delay + 200) / 800).clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _contentController,
            curve: Interval(
              (delay / 800).clamp(0.0, 1.0),
              ((delay + 200) / 800).clamp(0.0, 1.0),
              curve: AnimationSystem.easeOutQuint,
            ),
          ),
        ),
        child: AnimatedNeonCard(
          glowColor: ColorSystem.neonCyan,
          onTap: () => _navigateToMovieDetails(movie),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImage(
                movie.poster,
                fit: BoxFit.cover,
                placeholder: Container(
                  color: ColorSystem.backgroundSecondary,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ColorSystem.neonCyan,
                      ),
                    ),
                  ),
                ),
                errorWidget: Container(
                  color: ColorSystem.backgroundSecondary,
                  child: const Icon(
                    Icons.movie,
                    color: ColorSystem.textSecondary,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: ColorSystem.neonCyan,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${movie.numericRating.toStringAsFixed(1)}/10',
                          style: const TextStyle(
                            color: ColorSystem.neonCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if ((movie.quality?.isNotEmpty ?? false))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: ColorSystem.neonPurple.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              movie.quality ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    final provider = ref.watch(moviesProvider);
    if (!provider.isLoading || provider.movies.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: NeonLoadingIndicator(
          color: ColorSystem.neonPurple,
          size: 50,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_outlined,
              size: 100,
              color: ColorSystem.neonCyan.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucun film disponible',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ColorSystem.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Utilisez l\'onglet Recherche pour trouver des films',
              style: TextStyle(
                fontSize: 14,
                color: ColorSystem.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AnimatedNeonButton(
              label: 'ALLER À LA RECHERCHE',
              onPressed: () => Navigator.pushNamed(context, '/search'),
              color: ColorSystem.neonPurple,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToMovieDetails(Movie movie) {
    Navigator.pushNamed(
      context,
      '/movie-detail',
      arguments: movie,
    );
  }
}

class NeonGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ColorSystem.neonCyan.withOpacity(0.1)
      ..strokeWidth = 1;

    const spacing = 50.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    final pointPaint = Paint()
      ..color = ColorSystem.neonPurple.withOpacity(0.2)
      ..strokeWidth = 3;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 2, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
