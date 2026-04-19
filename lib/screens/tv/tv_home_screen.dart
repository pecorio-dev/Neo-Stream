import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/tv_config.dart';
import '../../providers/providers.dart';
import '../../widgets/tv_focusable_card.dart';
import '../../widgets/tv_focusable_card.dart' show TVScrollPhysics;
import 'tv_detail_screen.dart';
import 'tv_anime_detail_screen.dart';
import 'tv_anime_screen.dart';
import 'tv_search_screen.dart';
import 'tv_settings_screen.dart';
import 'tv_history_screen.dart';

class TVHomeScreen extends StatefulWidget {
  const TVHomeScreen({super.key});

  @override
  State<TVHomeScreen> createState() => _TVHomeScreenState();
}

class _TVHomeScreenState extends State<TVHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContentProvider>().loadHome();
    });
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
            _buildHeader(),
            Expanded(
              child: Consumer<ContentProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoadingHome && provider.hero.isEmpty) {
                    return const Center(child: CircularProgressIndicator(color: TVTheme.accentRed));
                  }

                  if (provider.homeError != null && provider.hero.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: TVTheme.accentRed, size: 48),
                          const SizedBox(height: 16),
                          Text('Impossible de charger le contenu', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: TVTheme.textPrimary)),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => provider.loadHome(),
                            style: FilledButton.styleFrom(backgroundColor: TVTheme.accentRed),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reessayer'),
                          ),
                        ],
                      ),
                    );
                  }

                  final sections = _getSections(provider);
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    physics: const TVScrollPhysics(),
                    itemCount: sections.length,
                    itemBuilder: (context, sectionIndex) {
                      final section = sections[sectionIndex];
                      return _buildSection(section);
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [TVTheme.backgroundDark, TVTheme.backgroundDark.withValues(alpha: 0.8), Colors.transparent],
        ),
      ),
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
          const Spacer(),
          _HeaderButton(icon: Icons.animation, label: 'Anime', onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TVAnimeScreen()));
          }),
          const SizedBox(width: 16),
          _HeaderButton(icon: Icons.search, label: 'Rechercher', onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TVSearchScreen()));
          }),
          const SizedBox(width: 16),
          _HeaderButton(icon: Icons.history, label: 'Historique', onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TVHistoryScreen()));
          }),
          const SizedBox(width: 16),
          _HeaderButton(icon: Icons.settings, label: 'Parametres', onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TVSettingsScreen()));
          }),
        ],
      ),
    );
  }

  List<_HomeSection> _getSections(ContentProvider provider) {
    final sections = <_HomeSection>[];
    if (provider.hero.isNotEmpty) sections.add(_HomeSection(title: 'A la une', items: provider.hero, isLarge: true));
    if (provider.addedToday.isNotEmpty) sections.add(_HomeSection(title: 'Ajoutes recemment', items: provider.addedToday));
    if (provider.dailyTop.isNotEmpty) sections.add(_HomeSection(title: 'Top du jour', items: provider.dailyTop));
    if (provider.continueWatching.isNotEmpty) sections.add(_HomeSection(title: 'Continuer la lecture', items: provider.continueWatching));
    if (provider.popularFilms.isNotEmpty) sections.add(_HomeSection(title: 'Films populaires', items: provider.popularFilms));
    if (provider.popularSeries.isNotEmpty) sections.add(_HomeSection(title: 'Series populaires', items: provider.popularSeries));
    return sections;
  }

  Widget _buildSection(_HomeSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          child: Text(section.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: TVTheme.textPrimary, fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: section.isLarge ? 320 : 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            physics: const TVScrollPhysics(),
            itemCount: section.items.length,
            itemBuilder: (context, itemIndex) {
              final item = section.items[itemIndex];
              return Padding(
                padding: EdgeInsets.only(right: section.isLarge ? 20 : 16),
                child: TVFocusableCard(
                  minWidth: section.isLarge ? 200 : 160,
                  maxWidth: section.isLarge ? 220 : 180,
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openContent(item),
                  child: _ContentCard(content: item),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _HomeSection {
  final String title;
  final List<dynamic> items;
  final bool isLarge;
  const _HomeSection({required this.title, required this.items, this.isLarge = false});
}

class _ContentCard extends StatelessWidget {
  final dynamic content;
  const _ContentCard({required this.content});

  @override
  Widget build(BuildContext context) {
    final posterUrl = content.fullPosterUrl as String? ?? '';
    final title = content.title as String? ?? content.displayTitle as String? ?? '';
    final rating = content.rating as double?;
    final genres = content.genres as List<dynamic>? ?? [];
    final progress = content.progressPercent as double?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: TVTheme.cardColor),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (posterUrl.isNotEmpty)
                  Image.network(posterUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                else
                  _placeholder(),
                if (rating != null && rating > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: TVTheme.accentGold, size: 12),
                          SizedBox(width: 2),
                          Text(rating.toStringAsFixed(1), style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                if (progress != null && progress > 0)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(value: progress / 100, backgroundColor: Colors.white24, valueColor: AlwaysStoppedAnimation(TVTheme.accentRed), minHeight: 3),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(title, style: TextStyle(color: TVTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (genres.isNotEmpty)
          Text(genres.take(2).join(' * '), style: TextStyle(color: TVTheme.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: TVTheme.cardColor,
      child: Center(child: Icon(Icons.movie_outlined, color: TVTheme.textDisabled, size: 40)),
    );
  }
}

class _HeaderButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.label, required this.onTap});

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: TVConfig.focusAnimationDuration,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _isFocused ? TVTheme.cardColor : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _isFocused ? TVTheme.accentRed : Colors.transparent, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: _isFocused ? TVTheme.accentRed : TVTheme.textSecondary, size: 20),
                const SizedBox(width: 8),
                Text(widget.label, style: TextStyle(color: _isFocused ? TVTheme.accentRed : TVTheme.textSecondary, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}