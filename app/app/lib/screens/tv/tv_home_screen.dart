import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/tv_config.dart';
import '../../providers/providers.dart';
import '../../widgets/tv_focusable_card.dart';
import '../../widgets/tv_content_card.dart';
import 'tv_detail_screen.dart';
import 'tv_anime_detail_screen.dart';

class TVHomeScreen extends StatefulWidget {
  final bool embedded;
  const TVHomeScreen({super.key, this.embedded = false});

  @override
  State<TVHomeScreen> createState() => _TVHomeScreenState();
}

class _TVHomeScreenState extends State<TVHomeScreen> with TickerProviderStateMixin {
  late final AnimationController _heroController;
  int _heroIndex = 0;
  bool _heroReady = false;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          final provider = context.read<ContentProvider>();
          if (provider.hero.isNotEmpty) {
            setState(() {
              _heroIndex = (_heroIndex + 1) % provider.hero.length;
            });
            if (mounted) _heroController.forward(from: 0);
          }
        }
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContentProvider>().loadHome();
    });
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  void _openContent(dynamic item) {
    if (item.contentType == 'anime') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TVAnimeDetailScreen(animeId: item.id)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TVDetailScreen(contentId: item.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TVTheme.backgroundDark,
      body: Container(
        decoration: TVTheme.screenDecoration,
        child: Column(
          children: [
            if (!widget.embedded) _buildHeader() else const SizedBox(height: 16),
            Expanded(
              child: Consumer<ContentProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoadingHome && provider.hero.isEmpty) {
                    return _buildShimmerLoading();
                  }

                  if (provider.homeError != null && provider.hero.isEmpty) {
                    return _buildError(provider);
                  }

                  if (!_heroReady && provider.hero.isNotEmpty) {
                    _heroReady = true;
                    _heroController.forward();
                  }

                  final sections = _getSections(provider);
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 40),
                    physics: const TVScrollPhysics(),
                    itemCount: sections.length,
                    itemBuilder: (context, sectionIndex) {
                      final section = sections[sectionIndex];
                      return _buildSection(section, sectionIndex);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      children: [
        _ShimmerHero(),
        const SizedBox(height: 32),
        for (var i = 0; i < 3; i++) ...[
          _ShimmerSection(),
          const SizedBox(height: 28),
        ],
      ],
    );
  }

  Widget _buildError(ContentProvider provider) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: TVTheme.accentRed, size: 48)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 800.ms),
          const SizedBox(height: 16),
          Text('Impossible de charger le contenu',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: TVTheme.textPrimary)),
          const SizedBox(height: 24),
          TVFocusableCard(
            onTap: () => provider.loadHome(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Réessayer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: [
          Text(
            'NEO STREAM',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: TVTheme.accentRed,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  List<_HomeSection> _getSections(ContentProvider provider) {
    final sections = <_HomeSection>[];
    if (provider.hero.isNotEmpty) {
      sections.add(_HomeSection(
        title: 'A la une',
        items: provider.hero,
        style: _SectionStyle.hero,
      ));
    }
    if (provider.continueWatching.isNotEmpty) {
      sections.add(_HomeSection(
        title: 'Continuer la lecture',
        items: provider.continueWatching,
        style: _SectionStyle.continueWatching,
        icon: Icons.play_circle_outline_rounded,
      ));
    }
    if (provider.addedToday.isNotEmpty) {
      sections.add(_HomeSection(
        title: 'Ajoutés récemment',
        items: provider.addedToday,
        style: _SectionStyle.standard,
        icon: Icons.new_releases_outlined,
      ));
    }
    if (provider.dailyTop.isNotEmpty) {
      sections.add(_HomeSection(
        title: 'Top du jour',
        items: provider.dailyTop,
        style: _SectionStyle.ranked,
        icon: Icons.trending_up_rounded,
      ));
    }
    if (provider.popularFilms.isNotEmpty) {
      sections.add(_HomeSection(
        title: 'Films populaires',
        items: provider.popularFilms,
        style: _SectionStyle.standard,
        icon: Icons.movie_outlined,
      ));
    }
    if (provider.popularSeries.isNotEmpty) {
      sections.add(_HomeSection(
        title: 'Séries populaires',
        items: provider.popularSeries,
        style: _SectionStyle.wide,
        icon: Icons.tv_rounded,
      ));
    }
    return sections;
  }

  Widget _buildSection(_HomeSection section, int sectionIndex) {
    switch (section.style) {
      case _SectionStyle.hero:
        return _buildHeroSection(section);
      case _SectionStyle.continueWatching:
        return _buildContinueWatchingSection(section, sectionIndex);
      case _SectionStyle.ranked:
        return _buildRankedSection(section, sectionIndex);
      case _SectionStyle.wide:
        return _buildWideSection(section, sectionIndex);
      case _SectionStyle.standard:
        return _buildStandardSection(section, sectionIndex);
    }
  }

  Widget _buildSectionHeader(String title, IconData? icon, int sectionIndex) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: TVTheme.accentRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: TVTheme.accentRed, size: 18),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: TVTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: sectionIndex * 80))
     .slideX(begin: -0.02, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildHeroSection(_HomeSection section) {
    final items = section.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final safeLength = items.length;
    final currentItem = items[_heroIndex % safeLength];
    final posterUrl = currentItem.fullPosterUrl as String? ?? '';
    final title = currentItem.title as String? ?? currentItem.displayTitle as String? ?? '';
    final genres = currentItem.genres as List<dynamic>? ?? [];
    final rating = currentItem.rating as double?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
      child: TVFocusableCard(
        onTap: () => _openContent(currentItem),
        padding: EdgeInsets.zero,
        minWidth: double.infinity,
        maxWidth: double.infinity,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 280,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 800),
                child: Container(
                  key: ValueKey(_heroIndex),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: TVTheme.cardColor,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: posterUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorWidget: (_1, _2, _3) => Container(color: TVTheme.cardColor),
                        )
                      : Container(color: TVTheme.cardColor),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 0.8],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (rating != null && rating > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: TVTheme.accentGold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: TVTheme.accentGold.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: TVTheme.accentGold, size: 14),
                            const SizedBox(width: 4),
                            Text(rating.toStringAsFixed(1), style: const TextStyle(color: TVTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (genres.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: genres.take(3).map<Widget>((g) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Text(g.toString(), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        )).toList(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: TVTheme.heroGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 4),
                              Text('Regarder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (items.length > 1)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              items.length.clamp(0, 5),
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(right: 4),
                                width: i == _heroIndex % items.length.clamp(1, 5) ? 20 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: i == _heroIndex % items.length.clamp(1, 5)
                                      ? TVTheme.accentRed
                                      : Colors.white.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(3),
                                ),
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
    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.97, 0.97), duration: 600.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildContinueWatchingSection(_HomeSection section, int sectionIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(section.title, section.icon, sectionIndex),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            physics: const TVScrollPhysics(),
            itemCount: section.items.length,
            itemBuilder: (context, itemIndex) {
              final item = section.items[itemIndex];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: TVFocusableCard(
                  minWidth: 280,
                  maxWidth: 320,
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _openContent(item),
                  child: _ContinueWatchingCard(content: item),
                ),
              ).animate().fadeIn(
                duration: 350.ms,
                delay: Duration(milliseconds: itemIndex * 50),
              ).slideX(begin: 0.05, duration: 350.ms, curve: Curves.easeOutCubic);
            },
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildRankedSection(_HomeSection section, int sectionIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(section.title, section.icon, sectionIndex),
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            physics: const TVScrollPhysics(),
            itemCount: section.items.length.clamp(0, 10),
            itemBuilder: (context, itemIndex) {
              final item = section.items[itemIndex];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: TVFocusableCard(
                  minWidth: 160,
                  maxWidth: 180,
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openContent(item),
                  child: _RankedCard(content: item, rank: itemIndex + 1),
                ),
              ).animate().fadeIn(
                duration: 350.ms,
                delay: Duration(milliseconds: itemIndex * 60),
              ).slideY(begin: 0.08, duration: 350.ms, curve: Curves.easeOutCubic);
            },
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildWideSection(_HomeSection section, int sectionIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(section.title, section.icon, sectionIndex),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            physics: const TVScrollPhysics(),
            itemCount: section.items.length,
            itemBuilder: (context, itemIndex) {
              final item = section.items[itemIndex];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: TVFocusableCard(
                  minWidth: 280,
                  maxWidth: 320,
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _openContent(item),
                  child: _WideCard(content: item),
                ),
              ).animate().fadeIn(
                duration: 350.ms,
                delay: Duration(milliseconds: itemIndex * 50),
              ).slideX(begin: 0.04, duration: 350.ms, curve: Curves.easeOutCubic);
            },
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildStandardSection(_HomeSection section, int sectionIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(section.title, section.icon, sectionIndex),
        SizedBox(
          height: 270,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            physics: const TVScrollPhysics(),
            itemCount: section.items.length,
            itemBuilder: (context, itemIndex) {
              final item = section.items[itemIndex];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: TVFocusableCard(
                  minWidth: 155,
                  maxWidth: 175,
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openContent(item),
                  child: _StandardCard(content: item),
                ),
              ).animate().fadeIn(
                duration: 350.ms,
                delay: Duration(milliseconds: itemIndex * 45),
              ).scale(
                begin: const Offset(0.93, 0.93),
                duration: 350.ms,
                curve: Curves.easeOutBack,
                delay: Duration(milliseconds: itemIndex * 45),
              );
            },
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

enum _SectionStyle { hero, continueWatching, ranked, wide, standard }

class _HomeSection {
  final String title;
  final List<dynamic> items;
  final _SectionStyle style;
  final IconData? icon;
  const _HomeSection({
    required this.title,
    required this.items,
    this.style = _SectionStyle.standard,
    this.icon,
  });
}

class _StandardCard extends StatelessWidget {
  final dynamic content;
  const _StandardCard({required this.content});

  @override
  Widget build(BuildContext context) {
    final posterUrl = content.fullPosterUrl as String? ?? '';
    final title = content.title as String? ?? content.displayTitle as String? ?? '';
    final rating = content.rating as double?;
    final genres = content.genres as List<dynamic>? ?? [];

    return TVContentCard(
      posterUrl: posterUrl,
      title: title,
      subtitle: genres.isNotEmpty ? genres.take(2).join(' • ') : null,
      typeLabel: _contentTypeLabel(content),
      rating: rating,
    );
  }

  static String? _contentTypeLabel(dynamic c) {
    final type = c.contentType as String?;
    switch (type) {
      case 'movie': return 'Film';
      case 'serie': return 'Série';
      case 'anime': return 'Anime';
      default: return null;
    }
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  final dynamic content;
  const _ContinueWatchingCard({required this.content});

  @override
  Widget build(BuildContext context) {
    final posterUrl = content.fullPosterUrl as String? ?? '';
    final title = content.title as String? ?? content.displayTitle as String? ?? '';
    final progress = content.progressPercent as double?;
    final episodeId = content.currentEpisodeId as String?;

    return Row(
      children: [
        Container(
          width: 120,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
            color: TVTheme.cardColor,
          ),
          clipBehavior: Clip.antiAlias,
          child: posterUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: posterUrl,
                  fit: BoxFit.cover,
                  height: 180,
                  placeholder: (_, __) => Container(
                    height: 180,
                    color: TVTheme.cardColor,
                    child: const Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: TVTheme.accentRed),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 180,
                    color: TVTheme.cardColor,
                    child: const Icon(Icons.movie, color: TVTheme.textDisabled),
                  ),
                )
              : Container(
                  height: 180,
                  color: TVTheme.cardColor,
                  child: const Icon(Icons.movie, color: TVTheme.textDisabled),
                ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(color: TVTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (episodeId != null && episodeId.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(episodeId, style: const TextStyle(color: TVTheme.textSecondary, fontSize: 12)),
                ],
                const Spacer(),
                if (progress != null && progress > 0) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation(TVTheme.accentRed),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${progress.toInt()}%', style: const TextStyle(color: TVTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: TVTheme.heroGradient,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Reprendre', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RankedCard extends StatelessWidget {
  final dynamic content;
  final int rank;
  const _RankedCard({required this.content, required this.rank});

  @override
  Widget build(BuildContext context) {
    final posterUrl = content.fullPosterUrl as String? ?? '';
    final title = content.title as String? ?? content.displayTitle as String? ?? '';
    final rating = content.rating as double?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: TVTheme.cardColor,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (posterUrl.isNotEmpty)
                      CachedNetworkImage(imageUrl: posterUrl, fit: BoxFit.cover, errorWidget: (_1, _2, _3) => _placeholder())
                    else
                      _placeholder(),
                    // Gradient overlay bas
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: -4,
                left: -4,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: rank <= 3 ? TVTheme.heroGradient : null,
                    color: rank > 3 ? TVTheme.surfaceColor : null,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: rank <= 3 ? TVTheme.accentRed : TVTheme.defaultBorderColor, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        shadows: rank <= 3 ? [const Shadow(color: Colors.black54, blurRadius: 4)] : null,
                      ),
                    ),
                  ),
                ),
              ),
              if (rating != null && rating > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: TVTheme.accentGold, size: 11),
                        const SizedBox(width: 2),
                        Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(color: TVTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: TVTheme.cardColor,
      child: const Center(child: Icon(Icons.movie_outlined, color: TVTheme.textDisabled, size: 36)),
    );
  }
}

class _WideCard extends StatelessWidget {
  final dynamic content;
  const _WideCard({required this.content});

  @override
  Widget build(BuildContext context) {
    final posterUrl = content.fullPosterUrl as String? ?? '';
    final title = content.title as String? ?? content.displayTitle as String? ?? '';
    final rating = content.rating as double?;
    final genres = content.genres as List<dynamic>? ?? [];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Poster ──
          posterUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: posterUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_1, _2, _3) => Container(color: TVTheme.cardColor),
                )
              : Container(color: TVTheme.cardColor),

          // ── Gradient ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.3, 0.6, 1.0],
              ),
            ),
          ),

          // ── Badge type ──
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tv_rounded, color: Colors.white, size: 10),
                  SizedBox(width: 3),
                  Text('Série', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),

          // ── Rating ──
          if (rating != null && rating > 0)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: TVTheme.accentGold, size: 12),
                    const SizedBox(width: 2),
                    Text(rating.toStringAsFixed(1),
                        style: const TextStyle(color: TVTheme.accentGold, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

          // ── Title + genres ──
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (rating != null && rating > 0) ...[
                      const Icon(Icons.star_rounded, color: TVTheme.accentGold, size: 12),
                      const SizedBox(width: 3),
                      Text(rating.toStringAsFixed(1),
                          style: const TextStyle(color: TVTheme.accentGold, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                    ],
                    if (genres.isNotEmpty)
                      Expanded(
                        child: Text(genres.take(2).join(' • '),
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: TVTheme.cardColor,
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 32,
            left: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 200, height: 28, decoration: BoxDecoration(color: TVTheme.surfaceColor, borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 12),
                Container(width: 140, height: 14, decoration: BoxDecoration(color: TVTheme.surfaceColor, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
     .shimmer(duration: 1500.ms, color: Colors.white.withValues(alpha: 0.04));
  }
}

class _ShimmerSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 150, height: 20, decoration: BoxDecoration(color: TVTheme.cardColor, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: Row(
            children: List.generate(4, (i) => Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(color: TVTheme.cardColor, borderRadius: BorderRadius.circular(12)),
              ),
            )),
          ),
        ),
      ],
    ).animate(onPlay: (c) => c.repeat(reverse: true))
     .shimmer(duration: 1500.ms, color: Colors.white.withValues(alpha: 0.04));
  }
}
