import 'dart:ui' show ImageFilter;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../config/neo.dart';
import '../models/content.dart';
import '../services/api_service.dart';
import '../utils/watch_link_utils.dart';
import '../widgets/content_card.dart';
import 'player_screen.dart';

class DetailScreen extends StatefulWidget {
  final int contentId;

  DetailScreen({super.key, required this.contentId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  Content? _content;
  bool _isLoading = true;
  String? _error;
  int _selectedSeason = 1;
  String? _selectedLanguage;
  late final AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );
    _loadDetail();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    try {
      final content = await _api.getContentDetail(widget.contentId);
      final seasons = content.seasons.keys.toList()..sort();

      if (!mounted) return;
      setState(() {
        _content = content;
        _isLoading = false;
        if (seasons.isNotEmpty) _selectedSeason = seasons.first;
        _selectedLanguage = WatchLinkUtils.defaultLanguage(
          content.availableLanguages,
        );
      });
      _fadeCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger le contenu. Veuillez réessayer.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();

    if (_error != null || _content == null) {
      return Scaffold(
        backgroundColor: Neo.bgBase(context),
        appBar: AppBar(backgroundColor: Neo.bgBase(context)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: NeoTheme.errorRed),
              SizedBox(height: 16),
              Text(_error ?? 'Contenu introuvable',
                  style: Neo.bodyMedium(context),
                  textAlign: TextAlign.center),
              SizedBox(height: 16),
              if (_error?.contains('Premium') == true)
                _buildPremiumBlock(),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    final content = _content!;
    final seasonNumbers = content.seasons.keys.toList()..sort();
    final selectedEpisodes =
        content.seasons[_selectedSeason] ?? const <Episode>[];
    final canPlay = _primaryPlayableLinks(content).isNotEmpty;

    return Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.goBack ||
                event.logicalKey == LogicalKeyboardKey.browserBack)) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Neo.bgBase(context),
        body: SafeArea(
          top: !NeoTheme.isTV(context),
          child: FadeTransition(
            opacity: _fadeCtrl,
            child: CustomScrollView(
              slivers: [
                // ── HERO ─────────────────────────────────────────────
                _buildHero(content),

                // ── INFO ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetaRow(context, content),
                        SizedBox(height: 16),
                        if (content.genres.isNotEmpty) ...[
                          _buildGenreChips(context, content.genres),
                          SizedBox(height: 16),
                        ],
                        if (content.description != null) ...[
                          _ExpandableText(text: content.description!),
                          SizedBox(height: 20),
                        ],

                        // Language tabs
                        if (content.availableLanguages
                            .where((l) => l != 'unknown')
                            .length >
                            1) ...[
                          _buildLanguageTabs(context, content),
                          SizedBox(height: 20),
                        ],

                        // Progress bar (film)
                        if (!content.isSerie &&
                            _filmProgress(content) > 0) ...[
                          _buildProgressBar(_filmProgress(content)),
                          SizedBox(height: 20),
                        ],

                        // Action row
                        _buildActionRow(context, content, canPlay),
                        SizedBox(height: 32),

                        // Episodes (series)
                        if (content.isSerie &&
                            content.seasons.isNotEmpty) ...[
                          _buildEpisodesSection(
                              context, content, seasonNumbers, selectedEpisodes),
                        ],

                        // Similar
                        if (content.similar.isNotEmpty) ...[
                          Text('Vous aimerez aussi',
                              style: Neo.titleLarge(context)),
                          SizedBox(height: 12),
                          SizedBox(
                            height: NeoTheme.cardHeight(context),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: content.similar.length,
                              itemBuilder: (_, i) => Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: ContentCard(
                                  content: content.similar[i],
                                  index: i,
                                  onTap: () => Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DetailScreen(
                                          contentId: content.similar[i].id),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                        ],
                        SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── HERO ─────────────────────────────────────────────────────────────────

  Widget _buildHero(Content content) {
    return SliverAppBar(
      expandedHeight: 380,
      pinned: true,
      backgroundColor: Neo.bgBase(context),
      elevation: 0,
      leading: Padding(
        padding: EdgeInsets.all(8),
        child: IconButton(
          icon: Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12, width: 0.5),
            ),
            child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (content.fullPosterUrl.isNotEmpty)
              ClipRect(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: CachedNetworkImage(
                    imageUrl: content.fullPosterUrl,
                    fit: BoxFit.cover,
                    placeholder: (_1, _2) => Container(color: Neo.bgElevated(context)),
                    errorWidget: (_1, _2, _3) => Container(color: Neo.bgElevated(context)),
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.65),
                    Neo.bgBase(context),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
            // Info overlay at bottom
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (content.fullPosterUrl.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                        border: Border.all(color: Colors.white24, width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(NeoTheme.radiusMd - 1.0),
                        child: CachedNetworkImage(
                          imageUrl: content.fullPosterUrl,
                          width: 92,
                          height: 132,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (content.genres.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              content.genres.first.toUpperCase(),
                              style: Neo.labelSmall(context).copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        SizedBox(height: 8),
                        Text(
                          content.displayTitle,
                          style: Neo.headlineLarge(context).copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                            shadows: [
                              Shadow(
                                  color: Colors.black, blurRadius: 10, offset: Offset(0, 2))
                            ],
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── META ROW ─────────────────────────────────────────────────────────────

  Widget _buildMetaRow(BuildContext context, Content content) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (content.rating > 0)
          _RatingBadge(rating: content.rating),
        if (content.releaseDate != null)
          _metaChip(context, '${content.releaseDate}', icon: Icons.calendar_today_rounded),
        _metaChip(context, content.typeLabel, icon: content.isSerie ? Icons.tv_rounded : Icons.local_movies_rounded),
        if (content.isSerie && content.seasonCount > 0)
          _metaChip(
            context,
            '${content.seasonCount} s. · ${content.episodeCount} ép.',
            icon: Icons.video_library_rounded,
          ),
        if (content.languageTag.isNotEmpty)
          _metaChip(context, content.languageTag, accent: true, icon: Icons.g_translate_rounded),
      ],
    );
  }

  Widget _metaChip(BuildContext context, String label,
      {bool accent = false, IconData? icon}) {
    final color = accent ? Theme.of(context).colorScheme.primary : Neo.textSecondary(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: accent ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            SizedBox(width: 5),
          ],
          Text(
            label,
            style: Neo.labelSmall(context).copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreChips(BuildContext context, List<String> genres) {
    return SizedBox(
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: BouncingScrollPhysics(),
        itemCount: genres.length,
        itemBuilder: (context, index) {
          final genre = genres[index];
          final color = NeoTheme.getGenreColor(genre);
          return Container(
            margin: EdgeInsets.only(right: 8),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
            ),
            child: Center(
              child: Text(
                genre,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── LANGUAGE TABS ────────────────────────────────────────────────────────

  Widget _buildLanguageTabs(BuildContext context, Content content) {
    final langs = WatchLinkUtils.sortLanguages(
      content.availableLanguages.where((l) => l != 'unknown'),
    );
    final current = _selectedLanguage ?? WatchLinkUtils.defaultLanguage(langs);

    return Container(
      decoration: BoxDecoration(
        color: Neo.bgElevated(context),
        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
        border: Border.all(
            color: Neo.bgBorder(context).withValues(alpha: 0.15), width: 0.5),
      ),
      padding: EdgeInsets.all(4),
      child: Row(
        children: langs.map((lang) {
          final isSelected = current == lang;
          return Expanded(
            child: Focus(
              canRequestFocus: NeoTheme.needsFocusNavigation(context),
              onKeyEvent: NeoTheme.needsFocusNavigation(context)
                  ? (node, event) {
                      if (event is KeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.enter ||
                              event.logicalKey == LogicalKeyboardKey.select ||
                              event.logicalKey == LogicalKeyboardKey.space)) {
                        setState(() => _selectedLanguage = lang);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    }
                  : null,
              child: GestureDetector(
                onTap: () => setState(() => _selectedLanguage = lang),
                child: AnimatedContainer(
                  duration: NeoTheme.durationFast,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected ? NeoTheme.heroGradient : null,
                    borderRadius: BorderRadius.circular(NeoTheme.radiusSm),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color:
                                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    WatchLinkUtils.labelForLanguage(lang),
                    textAlign: TextAlign.center,
                    style: Neo.labelMedium(context).copyWith(
                      color: isSelected ? Colors.white : Neo.textSecondary(context),
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w500,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── PROGRESS BAR ─────────────────────────────────────────────────────────

  double _filmProgress(Content content) {
    return (double.tryParse(
              content.userProgress?['progress_percent']?.toString() ?? '0',
            ) ??
            0) /
        100;
  }

  Widget _buildProgressBar(double value) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.play_circle_outline_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                  SizedBox(width: 6),
                  Text(
                    'Continuer la lecture',
                    style: Neo.labelSmall(context).copyWith(
                      color: Neo.textPrimary(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '${(value * 100).round()}%',
                style: Neo.labelSmall(context).copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ── ACTION ROW ───────────────────────────────────────────────────────────

  Widget _buildActionRow(
      BuildContext context, Content content, bool canPlay) {
    return Row(
      children: [
        Expanded(
          child: _FocusablePlayButton(
            canPlay: canPlay,
            label: content.isSerie ? 'LANCER LA LECTURE' : 'REGARDER',
            onPlay: () => _playPrimaryAction(content),
          ),
        ),
        SizedBox(width: 12),
        _FocusableActionIconButton(
          isActive: content.inLibrary,
          activeIcon: Icons.check_rounded,
          inactiveIcon: Icons.add_rounded,
          activeColor: Theme.of(context).colorScheme.primary,
          tooltip: content.inLibrary ? 'Dans ma liste' : 'Ajouter à ma liste',
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              if (content.inLibrary) {
                await _api.removeFromLibrary(content.id);
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(
                  content: Text('Retiré de votre liste'),
                  backgroundColor: Neo.textSecondary(context),
                ));
              } else {
                await _api.addToLibrary(content.id);
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(
                  content: Text('Ajouté à votre liste'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ));
              }
              if (!mounted) return;
              setState(() => content.inLibrary = !content.inLibrary);
            } catch (_) {
              if (!mounted) return;
              messenger.showSnackBar(SnackBar(
                content: Text('Erreur'),
                backgroundColor: NeoTheme.errorRed,
              ));
            }
          },
        ),
      ],
    );
  }

  // ── EPISODES SECTION ─────────────────────────────────────────────────────

  Widget _buildEpisodesSection(
    BuildContext context,
    Content content,
    List<int> seasonNumbers,
    List<Episode> selectedEpisodes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Épisodes', style: Neo.titleLarge(context)),
        SizedBox(height: 10),
        if (seasonNumbers.length > 1) ...[
          _buildSeasonSelector(context, seasonNumbers),
          SizedBox(height: 14),
        ],
        AnimatedSwitcher(
          duration: Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, 0.04),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Column(
            key: ValueKey<int>(_selectedSeason),
            children: selectedEpisodes
                .map((ep) => _buildEpisodeCard(context, content, ep))
                .toList(),
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSeasonSelector(BuildContext context, List<int> seasons) {
    final useFocus = NeoTheme.needsFocusNavigation(context);
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: seasons.length,
        itemBuilder: (_, i) {
          final num = seasons[i];
          final isSelected = num == _selectedSeason;
          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: Focus(
              canRequestFocus: useFocus,
              onKeyEvent: useFocus
                  ? (node, event) {
                      if (event is KeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.enter ||
                              event.logicalKey == LogicalKeyboardKey.select ||
                              event.logicalKey == LogicalKeyboardKey.space)) {
                        setState(() => _selectedSeason = num);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    }
                  : null,
              child: Builder(
                builder: (ctx) {
                  final isFocused = Focus.of(ctx).hasFocus;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSeason = num),
                    child: AnimatedContainer(
                      duration: NeoTheme.durationFast,
                      padding: EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected ? NeoTheme.heroGradient : null,
                        color: isSelected ? null : Neo.bgElevated(context),
                        borderRadius:
                            BorderRadius.circular(NeoTheme.radiusMd),
                        border: Border.all(
                          color: (isFocused || isSelected)
                              ? Theme.of(context).colorScheme.primary
                              : Neo.bgBorder(context).withValues(alpha: 0.2),
                          width: isFocused ? 2 : 1,
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary
                                      .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        'Saison $num',
                        style: Neo.labelMedium(context).copyWith(
                          color: (isSelected || isFocused)
                              ? Colors.white
                              : Neo.textSecondary(context),
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEpisodeCard(
    BuildContext context,
    Content content,
    Episode episode,
  ) {
    final preferredLinks = _rankLinks(episode.watchLinks);
    final isPlayable = preferredLinks.isNotEmpty;
    final langs = WatchLinkUtils.sortLanguages(episode.availableLanguages);
    final useFocus = NeoTheme.needsFocusNavigation(context);

    void play() {
      if (!isPlayable) return;
      _launchPlayer(content, preferredLinks,
          episodeId: 'S${episode.season}E${episode.episode}');
    }

    return Focus(
      canRequestFocus: useFocus && isPlayable,
      onKeyEvent: useFocus
          ? (node, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.space)) {
                play();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            }
          : null,
      child: Builder(
        builder: (ctx) {
          final isFocused = Focus.of(ctx).hasFocus;
          return GestureDetector(
            onTap: isPlayable ? play : null,
            child: AnimatedContainer(
              duration: NeoTheme.durationFast,
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: isFocused
                    ? LinearGradient(colors: [
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        Neo.bgElevated(context),
                      ])
                    : Neo.surfaceGradient,
                borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                border: Border.all(
                  color: isFocused
                      ? Theme.of(context).colorScheme.primary
                      : Neo.bgBorder(context).withValues(alpha: 0.15),
                  width: isFocused ? 1.5 : 0.8,
                ),
                boxShadow: [
                  ...NeoTheme.shadowLevel1,
                  if (isFocused)
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Episode number
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                              Neo.bgElevated(context),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'E${episode.episode}',
                            style: Neo.titleMedium(context).copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 14),
                      // Title + meta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              episode.title.isNotEmpty
                                  ? episode.title
                                  : episode.label,
                              style: Neo.labelLarge(context).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  episode.label,
                                  style: Neo.bodySmall(context).copyWith(
                                    color: Neo.textTertiary(context),
                                  ),
                                ),
                                if (langs.isNotEmpty) ...[
                                  SizedBox(width: 10),
                                  ...langs.map((l) => Padding(
                                        padding: EdgeInsets.only(right: 5),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (_selectedLanguage == l)
                                                ? Theme.of(context).colorScheme.primary
                                                    .withValues(alpha: 0.15)
                                                : Neo.bgActive(context),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: (_selectedLanguage == l)
                                                  ? Theme.of(context).colorScheme.primary
                                                      .withValues(alpha: 0.35)
                                                  : Neo.bgBorder(context)
                                                      .withValues(alpha: 0.2),
                                              width: 0.5,
                                            ),
                                          ),
                                          child: Text(
                                            WatchLinkUtils.labelForLanguage(l),
                                            style: Neo.labelSmall(context)
                                                .copyWith(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: (_selectedLanguage == l)
                                                  ? Theme.of(context).colorScheme.primary
                                                  : Neo.textSecondary(context),
                                            ),
                                          ),
                                        ),
                                      )),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        isPlayable
                            ? Icons.play_circle_fill_rounded
                            : Icons.lock_outline_rounded,
                        color: isPlayable
                            ? (isFocused
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.75))
                            : Neo.textDisabled(context),
                        size: 34,
                      ),
                    ],
                  ),
                  if (episode.progressPercent != null &&
                      episode.progressPercent! > 0) ...[
                    SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: episode.progressPercent! / 100,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation(
                            Theme.of(context).colorScheme.primary),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── PREMIUM BLOCK ─────────────────────────────────────────────────────────

  Widget _buildPremiumBlock() {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: NeoTheme.prestigeGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
        border: Border.all(
            color: NeoTheme.prestigeGold.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium,
              color: NeoTheme.prestigeGold, size: 40),
          SizedBox(height: 8),
          Text('Contenu Premium',
              style: Neo.titleLarge(context)
                  .copyWith(color: NeoTheme.prestigeGold)),
          SizedBox(height: 4),
          Text('Passez Premium pour accéder à plus de 26 000 titres.',
              style: Neo.bodySmall(context), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ── SKELETON ─────────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return Scaffold(
      backgroundColor: Neo.bgBase(context),
      body: Column(
        children: [
          Container(height: 380, color: Neo.bgElevated(context)),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skBox(180, 24),
                SizedBox(height: 10),
                _skBox(double.infinity, 16),
                SizedBox(height: 6),
                _skBox(double.infinity, 16),
                SizedBox(height: 20),
                _skBox(double.infinity, 52),
                SizedBox(height: 16),
                ...List.generate(
                    3,
                    (_) => Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: _skBox(double.infinity, 72),
                        )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skBox(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Neo.bgElevated(context),
          borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
        ),
      );

  // ── HELPERS ───────────────────────────────────────────────────────────────

  List<WatchLink> _rankLinks(List<WatchLink> watchLinks) =>
      WatchLinkUtils.prioritize(watchLinks, preferredLanguage: _selectedLanguage);

  List<WatchLink> _primaryPlayableLinks(Content content) {
    if (content.watchLinks.isNotEmpty) return _rankLinks(content.watchLinks);
    final ep = _firstPlayableEpisode(content);
    return ep != null ? _rankLinks(ep.watchLinks) : const [];
  }

  void _playPrimaryAction(Content content) {
    if (content.isSerie) {
      final episode = _resumeEpisode(content) ?? _firstPlayableEpisode(content);
      if (episode != null) {
        _launchPlayer(
          content,
          _rankLinks(episode.watchLinks),
          episodeId: 'S${episode.season}E${episode.episode}',
        );
        return;
      }
    }
    final links = _rankLinks(content.watchLinks);
    if (links.isNotEmpty) {
      _launchPlayer(content, links);
      return;
    }
    // Reprendre l'épisode mémorisé avant de retomber sur le premier épisode.
    // PlayerScreen utilise ensuite la position locale puis celle du serveur.
    final ep = _resumeEpisode(content) ?? _firstPlayableEpisode(content);
    if (ep != null) {
      _launchPlayer(content, _rankLinks(ep.watchLinks),
          episodeId: 'S${ep.season}E${ep.episode}');
    }
  }

  Episode? _resumeEpisode(Content content) {
    final rememberedId = content.currentEpisodeId;
    final episodes = content.seasons.values.expand((items) => items);
    if (rememberedId != null && rememberedId.isNotEmpty) {
      for (final episode in episodes) {
        if ('S${episode.season}E${episode.episode}' == rememberedId &&
            _rankLinks(episode.watchLinks).isNotEmpty) {
          return episode;
        }
      }
    }
    // Fallback pour les réponses API sans episode_id mais avec une progression.
    for (final episode in content.seasons.values.expand((items) => items)) {
      final progress = episode.progressPercent ?? 0;
      if (progress > 0 && progress < 95 &&
          _rankLinks(episode.watchLinks).isNotEmpty) {
        return episode;
      }
    }
    return null;
  }

  Episode? _firstPlayableEpisode(Content content) {
    for (final season in (content.seasons.keys.toList()..sort())) {
      for (final ep in content.seasons[season] ?? const <Episode>[]) {
        if (_rankLinks(ep.watchLinks).isNotEmpty) return ep;
      }
    }
    return null;
  }

  void _launchPlayer(Content content, List<WatchLink> candidates,
      {String? episodeId}) {
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Aucune source disponible.'),
        backgroundColor: NeoTheme.errorRed,
      ));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          content: content,
          videoSourceUrl: candidates.first.url,
          candidateServers: candidates,
          preferredLanguage: _selectedLanguage,
          episodeId: episodeId,
        ),
      ),
    ).then((_) {
      if (mounted) _loadDetail();
    });
  }
}

// ── EXPANDABLE TEXT ───────────────────────────────────────────────────────────

class _ExpandableText extends StatefulWidget {
  final String text;
  _ExpandableText({required this.text});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: Neo.bodyLarge(context)
              .copyWith(color: Neo.textSecondary(context), height: 1.55),
          maxLines: _expanded ? null : 3,
          overflow: _expanded ? null : TextOverflow.ellipsis,
        ),
        SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? 'Voir moins' : 'Voir plus',
            style: Neo.labelSmall(context).copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── RATING BADGE ─────────────────────────────────────────────────────────────

class _RatingBadge extends StatelessWidget {
  final double rating;
  _RatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: rating / 10.0,
            strokeWidth: 3.5,
            backgroundColor:
                NeoTheme.prestigeGold.withValues(alpha: 0.15),
            valueColor:
                const AlwaysStoppedAnimation<Color>(NeoTheme.prestigeGold),
          ),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: NeoTheme.prestigeGold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ── FOCUSABLE PLAY BUTTON ─────────────────────────────────────────────────────

class _FocusablePlayButton extends StatefulWidget {
  final bool canPlay;
  final String label;
  final VoidCallback onPlay;

  _FocusablePlayButton({
    required this.canPlay,
    required this.label,
    required this.onPlay,
  });

  @override
  State<_FocusablePlayButton> createState() => _FocusablePlayButtonState();
}

class _FocusablePlayButtonState extends State<_FocusablePlayButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final useFocus = NeoTheme.needsFocusNavigation(context);
    return Focus(
      autofocus: false,
      canRequestFocus: useFocus,
      onFocusChange: (f) {
        if (_focused != f) setState(() => _focused = f);
      },
      onKeyEvent: useFocus
          ? (node, event) {
              if (widget.canPlay &&
                  event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.space)) {
                widget.onPlay();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            }
          : null,
      child: GestureDetector(
        onTap: widget.canPlay ? widget.onPlay : null,
        child: MouseRegion(
          cursor: widget.canPlay
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: AnimatedScale(
            scale: (_focused && useFocus) ? 1.04 : 1.0,
            duration: NeoTheme.durationFast,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient:
                    widget.canPlay ? NeoTheme.heroGradient : null,
                color: widget.canPlay ? null : Neo.bgElevated(context),
                borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                border: (_focused && useFocus)
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
                boxShadow: widget.canPlay
                    ? [
                        BoxShadow(
                          color: (_focused && useFocus)
                              ? Colors.white.withValues(alpha: 0.3)
                              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    color: widget.canPlay
                        ? Colors.white
                        : Neo.textDisabled(context),
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: Neo.labelLarge(context).copyWith(
                      color: widget.canPlay
                          ? Colors.white
                          : Neo.textDisabled(context),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── FOCUSABLE ACTION ICON BUTTON ─────────────────────────────────────────────

class _FocusableActionIconButton extends StatefulWidget {
  final bool isActive;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final Color activeColor;
  final String tooltip;
  final VoidCallback onTap;

  _FocusableActionIconButton({
    required this.isActive,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.activeColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_FocusableActionIconButton> createState() => _FocusableActionIconButtonState();
}

class _FocusableActionIconButtonState extends State<_FocusableActionIconButton> {
  bool _isFocused = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final useFocus = NeoTheme.needsFocusNavigation(context);
    return Focus(
      canRequestFocus: useFocus,
      onFocusChange: (f) => setState(() => _isFocused = f),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.92 : (_isFocused ? 1.08 : 1.0),
          duration: NeoTheme.durationFast,
          child: AnimatedContainer(
            duration: NeoTheme.durationNormal,
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: widget.isActive 
                  ? widget.activeColor.withValues(alpha: 0.12)
                  : (_isFocused ? Neo.bgActive(context) : Neo.bgElevated(context)),
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.isActive 
                    ? widget.activeColor.withValues(alpha: 0.5)
                    : (_isFocused ? widget.activeColor : Neo.bgBorder(context).withValues(alpha: 0.25)),
                width: _isFocused ? 2.0 : 1.0,
              ),
              boxShadow: [
                if (widget.isActive || _isFocused)
                  BoxShadow(
                    color: widget.activeColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
              ],
            ),
            child: Center(
              child: AnimatedRotation(
                turns: widget.isActive ? 1.0 : 0.0,
                duration: NeoTheme.durationNormal,
                child: Icon(
                  widget.isActive ? widget.activeIcon : widget.inactiveIcon,
                  color: widget.isActive ? widget.activeColor : Neo.textPrimary(context),
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

