import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/movies_provider.dart';
import '../providers/series_compact_provider.dart';
import '../widgets/animations/animated_card.dart';
import '../../core/design_system/animation_system.dart';
import '../../core/design_system/color_system.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/movie.dart';
import '../../data/models/series_compact.dart';
// import cpasmieux_image_loader removed

class HomeScreenEnhanced extends ConsumerStatefulWidget {
  const HomeScreenEnhanced({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreenEnhanced> createState() => _HomeScreenEnhancedState();
}

class _HomeScreenEnhancedState extends ConsumerState<HomeScreenEnhanced>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _headerController;
  late AnimationController _contentController;
  late AnimationController _particlesController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  double _parallaxOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadContent();
  }

  void _initializeAnimations() {
    // Main controller pour l'écran
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Controller pour le header
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Controller pour le contenu
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Controller pour les particules
    _particlesController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    // Animation de fade
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOut),
    );

    // Animation de slide
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
          parent: _mainController, curve: AnimationSystem.easeOutQuint),
    );

    // Animation de scale
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
          parent: _mainController, curve: AnimationSystem.easeOutQuint),
    );

    // Démarrer les animations en cascade
    _mainController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _headerController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _contentController.forward();
    });
  }

  void _loadContent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(moviesProvider).loadMovies();
        ref.read(seriesCompactProvider).loadSeries();
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _headerController.dispose();
    _contentController.dispose();
    _particlesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorSystem.backgroundPrimary,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: CustomScrollView(
              slivers: [
                // Header spectaculaire
                SliverAppBar(
                  expandedHeight: 300,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildSpectacularHeader(),
                    collapseMode: CollapseMode.parallax,
                  ),
                ),

                // Section Films populaires
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: _buildSectionTitle('Films Populaires'),
                  ),
                ),

                // Grille de films animée
                _buildMoviesGrid(),

                // Section Séries
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: _buildSectionTitle('Séries du moment'),
                  ),
                ),

                // Grille de séries animée
                _buildSeriesGrid(),

                // Espacement final
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 20),
                  sliver: SliverToBoxAdapter(
                    child: Container(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpectacularHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              // Mettre à jour les offsets de parallaxe
              setState(() {
                _parallaxOffset = notification.metrics.pixels * 0.5;
              });
            }
            return false;
          },
          child: Container(
            height: 300,
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
                // Fond avec pattern en parallaxe
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(0, _parallaxOffset * 0.3),
                    child: CustomPaint(
                      painter: NeonGridPainter(),
                    ),
                  ),
                ),

                // Particules flottantes en arrière-plan
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(_parallaxOffset * 0.1, _parallaxOffset * 0.2),
                    child: _buildFloatingParticles(),
                  ),
                ),

                // Cercles de lumière animés
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(-_parallaxOffset * 0.2, -_parallaxOffset * 0.1),
                    child: _buildLightOrbs(),
                  ),
                ),

                // Contenu du header avec effet de parallaxe inverse
                Transform.translate(
                  offset: Offset(0, -_parallaxOffset * 0.5),
                  child: FadeTransition(
                    opacity: _headerController,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Titre principal avec effet de glow
                          AnimatedNeonText(
                            'NEO-STREAM',
                            textStyle: const TextStyle(
                              color: ColorSystem.neonCyan,
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                              shadows: [
                                Shadow(
                                  color: ColorSystem.neonCyan,
                                  blurRadius: 20,
                                  offset: Offset(0, 0),
                                ),
                              ],
                            ),
                            duration: const Duration(milliseconds: 1000),
                          ),

                          const SizedBox(height: 12),

                          // Sous-titre avec effet de gradient animé
                          AnimatedBuilder(
                            animation: _headerController,
                            builder: (context, child) {
                              return ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    ColorSystem.neonPurple.withOpacity(_headerController.value),
                                    ColorSystem.neonPink.withOpacity(_headerController.value),
                                    ColorSystem.neonCyan.withOpacity(_headerController.value),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ).createShader(bounds),
                                child: Text(
                                  _getDynamicSubtitle(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 20),

                          // Boutons d'action avec animation d'entrée
                          Row(
                            children: [
                              AnimatedNeonButton(
                                label: 'EXPLORER',
                                onPressed: () {},
                                color: ColorSystem.neonCyan,
                                hoverColor: ColorSystem.neonGreen,
                                showGlow: true,
                              ),
                              const SizedBox(width: 12),
                              AnimatedNeonButton(
                                label: 'DÉCOUVRIR',
                                onPressed: () {},
                                color: ColorSystem.neonPurple,
                                hoverColor: ColorSystem.neonPink,
                                showGlow: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return FadeTransition(
      opacity: _contentController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-0.3, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                gradient: ColorSystem.cyanPurpleGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            ShaderMask(
              shaderCallback: (bounds) =>
                  ColorSystem.cyanPurpleGradient.createShader(bounds),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoviesGrid() {
    final provider = ref.watch(moviesProvider);
    
    if (provider.isLoading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: NeonLoadingIndicator(
              color: ColorSystem.neonCyan,
              size: 60,
            ),
          ),
        ),
      );
    }

    if (provider.movies.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              'Aucun film disponible',
              style: TextStyle(
                color: ColorSystem.textSecondary,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final movie = provider.movies[index];
            return _buildAnimatedMovieCard(movie, index);
          },
          childCount: provider.movies.take(6).length,
        ),
      ),
    );
  }

  Widget _buildSeriesGrid() {
    final provider = ref.watch(seriesCompactProvider);
    
    if (provider.isLoading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: NeonLoadingIndicator(
              color: ColorSystem.neonPurple,
              size: 60,
            ),
          ),
        ),
      );
    }

    if (provider.series.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              'Aucune série disponible',
              style: TextStyle(
                color: ColorSystem.textSecondary,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final series = provider.series[index];
            return _buildAnimatedSeriesCard(series, index);
          },
          childCount: provider.series.take(6).length,
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
            (delay / 500).clamp(0.0, 1.0),
            ((delay + 200) / 500).clamp(0.0, 1.0),
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
              (delay / 500).clamp(0.0, 1.0),
              ((delay + 200) / 500).clamp(0.0, 1.0),
              curve: AnimationSystem.easeOutQuint,
            ),
          ),
        ),
        child: AnimatedNeonCard(
          glowColor: ColorSystem.neonCyan,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/movie-detail',
              arguments: movie,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(movie.poster ?? ''),
                fit: BoxFit.cover,
                onError: (exception, stackTrace) {},
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
              child: Padding(
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
                        Icon(
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
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedSeriesCard(SeriesCompact series, int index) {
    final delay = index * 50;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _contentController,
          curve: Interval(
            (delay / 500).clamp(0.0, 1.0),
            ((delay + 200) / 500).clamp(0.0, 1.0),
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
              (delay / 500).clamp(0.0, 1.0),
              ((delay + 200) / 500).clamp(0.0, 1.0),
              curve: AnimationSystem.easeOutQuint,
            ),
          ),
        ),
        child: AnimatedNeonCard(
          glowColor: ColorSystem.neonPurple,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/series-compact-detail',
              arguments: series,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(series.poster),
                fit: BoxFit.cover,
                onError: (exception, stackTrace) {},
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      series.displayTitle,
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
                        Icon(
                          Icons.star,
                          color: ColorSystem.neonPurple,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          series.formattedRating,
                          style: const TextStyle(
                            color: ColorSystem.neonPurple,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingParticles() {
    return AnimatedBuilder(
      animation: _particlesController,
      builder: (context, child) {
        return CustomPaint(
          painter: FloatingParticlesPainter(
            progress: _particlesController.value,
            particleCount: 15,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildLightOrbs() {
    return AnimatedBuilder(
      animation: _particlesController,
      builder: (context, child) {
        return CustomPaint(
          painter: LightOrbsPainter(
            progress: _particlesController.value,
            orbCount: 8,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  String _getDynamicSubtitle() {
    // Pour l'instant, retourner un texte statique
    // Plus tard, on pourra récupérer les vraies statistiques de l'API
    return '+2000 films & séries disponibles';
  }
}

/// Custom painter pour un pattern de grille neon
class NeonGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ColorSystem.neonCyan.withOpacity(0.1)
      ..strokeWidth = 1;

    const spacing = 50.0;

    // Lignes verticales
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Lignes horizontales
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Points d'intersection
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

/// Peintre pour les particules flottantes
class FloatingParticlesPainter extends CustomPainter {
  final double progress;
  final int particleCount;

  FloatingParticlesPainter({
    required this.progress,
    this.particleCount = 15,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = 12345; // Seed fixe pour cohérence

    for (int i = 0; i < particleCount; i++) {
      final x = ((random * i * 7) % size.width.toInt()).toDouble();
      final y = ((random * i * 11) % size.height.toInt()).toDouble() +
                (progress * 50 * (i % 2 == 0 ? 1 : -1));
      final opacity = (0.3 + 0.4 * progress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = ColorSystem.neonCyan.withOpacity(opacity * 0.6)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 2 + progress, paint);
    }
  }

  @override
  bool shouldRepaint(FloatingParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Peintre pour les orbes de lumière animés
class LightOrbsPainter extends CustomPainter {
  final double progress;
  final int orbCount;

  LightOrbsPainter({
    required this.progress,
    this.orbCount = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < orbCount; i++) {
      final angle = (i / orbCount) * 2 * 3.14159 + progress * 2;
      final radius = 80 + i * 20.0;
      final x = size.width / 2 + radius * cos(angle);
      final y = size.height / 2 + radius * sin(angle) * 0.5;
      final opacity = (0.2 + 0.3 * (1 - progress)).clamp(0.0, 1.0);

      final gradient = RadialGradient(
        colors: [
          ColorSystem.neonPurple.withOpacity(opacity),
          Colors.transparent,
        ],
        radius: 0.3,
      );

      final paint = Paint()
        ..shader = gradient.createShader(Rect.fromCircle(
          center: Offset(x, y),
          radius: 30,
        ));

      canvas.drawCircle(Offset(x, y), 30, paint);
    }
  }

  @override
  bool shouldRepaint(LightOrbsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}


