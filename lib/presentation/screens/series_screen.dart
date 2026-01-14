import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../widgets/animations/animated_card.dart';
// import neo_image removed
import '../../core/design_system/animation_system.dart';
import '../../core/design_system/color_system.dart';
import '../../data/models/series_compact.dart';
import '../providers/series_compact_provider.dart';
import '../widgets/app_image.dart';

class SeriesScreen extends ConsumerStatefulWidget {
  const SeriesScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends ConsumerState<SeriesScreen> with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _contentController;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _setupAnimations();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(seriesCompactProvider).loadSeries();
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

  void _onScroll() {
    final shouldShow = _scrollController.offset > 200;
    if (shouldShow != _showScrollToTop) {
      setState(() => _showScrollToTop = shouldShow);
    }
  }

  @override
  void dispose() {
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
          _buildSeriesGrid(),
          _buildLoadingIndicator(),
        ],
      ),
      floatingActionButton: _showScrollToTop
          ? ScaleTransition(
              scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: _contentController,
                  curve: AnimationSystem.elasticOut,
                ),
              ),
              child: FloatingActionButton(
                onPressed: _scrollToTop,
                backgroundColor: ColorSystem.neonPurple,
                child: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
              ),
            )
          : null,
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
              ColorSystem.neonPurple.withOpacity(0.1),
              ColorSystem.neonPink.withOpacity(0.1),
              ColorSystem.neonCyan.withOpacity(0.05),
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
                    'SÉRIES',
                    textStyle: const TextStyle(
                      color: ColorSystem.neonPurple,
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
                      'Les meilleures séries en streaming',
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
                        color: ColorSystem.neonPurple,
                        hoverColor: ColorSystem.neonPink,
                      ),
                      const SizedBox(width: 12),
                      AnimatedNeonButton(
                        label: 'TRENDING',
                        onPressed: () {},
                        color: ColorSystem.neonCyan,
                        hoverColor: ColorSystem.neonGreen,
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

  Widget _buildSeriesGrid() {
    final provider = ref.watch(seriesCompactProvider);
    
    if (provider.isLoading && provider.series.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Center(
            child: NeonLoadingIndicator(
              color: ColorSystem.neonPurple,
              size: 70,
            ),
          ),
        ),
      );
    }

    if (provider.hasError && provider.series.isEmpty) {
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
                  onPressed: () => ref.read(seriesCompactProvider).loadSeries(),
                  color: ColorSystem.neonPurple,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (provider.series.isEmpty) {
      return _buildEmptyState();
    }

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
            final series = provider.series[index];
            return _buildAnimatedSeriesCard(series, index);
          },
          childCount: provider.series.length,
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
          glowColor: ColorSystem.neonPurple,
          onTap: () => _onSeriesTap(series),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImage(
                series.poster,
                fit: BoxFit.cover,
                errorWidget: const Icon(Icons.tv),
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
                        const Icon(
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
                        if (series.genres.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              series.genres.first,
                              style: const TextStyle(
                                color: ColorSystem.textSecondary,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
    final provider = ref.watch(seriesCompactProvider);
    if (!provider.isLoading || provider.series.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: NeonLoadingIndicator(
            color: ColorSystem.neonCyan,
            size: 50,
          ),
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
              Icons.tv_off,
              size: 100,
              color: ColorSystem.neonPurple.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucune série disponible',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ColorSystem.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Utilisez l\'onglet Recherche pour trouver des séries',
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

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _onSeriesTap(SeriesCompact series) {
    Navigator.pushNamed(
      context,
      '/series-compact-detail',
      arguments: series,
    );
  }
}

class NeonGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ColorSystem.neonPurple.withOpacity(0.1)
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
      ..color = ColorSystem.neonCyan.withOpacity(0.2)
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



