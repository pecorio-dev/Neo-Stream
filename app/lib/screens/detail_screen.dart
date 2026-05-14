import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/content.dart';
import '../services/api_service.dart';
import '../utils/watch_link_utils.dart';
import '../widgets/content_card.dart';
import 'player_screen.dart';

class DetailScreen extends StatefulWidget {
  final int contentId;

  const DetailScreen({super.key, required this.contentId});

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
      duration: const Duration(milliseconds: 400),
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
        backgroundColor: NeoTheme.bgBase,
        appBar: AppBar(backgroundColor: NeoTheme.bgBase),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: NeoTheme.errorRed),
              const SizedBox(height: 16),
              Text(_error ?? 'Contenu introuvable',
                  style: NeoTheme.bodyMedium(context),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              if (_error?.contains('Premium') == true)
                _buildPremiumBlock(),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour'),
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
        backgroundColor: NeoTheme.bgBase,
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
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetaRow(context, content),
                        const SizedBox(height: 14),
                        if (content.description != null)
                          _ExpandableText(text: content.description!),
                        const SizedBox(height: 20),

                        // Language tabs
                        if (content.availableLanguages
                            .where((l) => l != 'unknown')
                            .length >
                            1) ...[
                          _buildLanguageTabs(context, content),
                          const SizedBox(height: 16),
                        ],

                        // Progress bar (film)
                        if (!content.isSerie &&
                            _filmProgress(content) > 0) ...[
                          _buildProgressBar(_filmProgress(content)),
                          const SizedBox(height: 16),
                        ],

                        // Action row
                        _buildActionRow(context, content, canPlay),
                        const SizedBox(height: 28),

                        // Episodes (series)
                        if (content.isSerie &&
                            content.seasons.isNotEmpty) ...[
                          _buildEpisodesSection(
                              context, content, seasonNumbers, selectedEpisodes),
                        ],

                        // Similar
                        if (content.similar.isNotEmpty) ...[
                          Text('Vous aimerez aussi',
                              style: NeoTheme.titleLarge(context)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: NeoTheme.cardHeight(context),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: content.similar.length,
                              itemBuilder: (_, i) => Padding(
                                padding: const EdgeInsets.only(right: 12),
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
                          const SizedBox(height: 24),
                        ],
                        const SizedBox(height: 60),
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
      backgroundColor: NeoTheme.bgBase,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12, width: 0.5),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (content.fullPosterUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: content.fullPosterUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: NeoTheme.bgElevated),
                errorWidget: (_, _, _) => Container(
                  color: NeoTheme.bgElevated,
                  child: const Center(
                    child: Icon(Icons.movie_rounded,
                        color: NeoTheme.textDisabled, size: 48),
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.55),
                    NeoTheme.bgBase,
                  ],
                  stops: const [0.0, 0.55, 1.0],
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                      child: CachedNetworkImage(
                        imageUrl: content.fullPosterUrl,
                        width: 88,
                        height: 126,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (content.genres.isNotEmpty)
                          Text(
                            content.genres.take(3).join(' · '),
                            style: NeoTheme.labelSmall(context).copyWith(
                              color: NeoTheme.primaryRed,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            content.displayTitle,
                            style: NeoTheme.headlineLarge(context).copyWith(
                              fontWeight: FontWeight.w800,
                              shadows: [
                                const Shadow(
                                    color: Colors.black87, blurRadius: 8)
                              ],
                            ),
                            maxLines: 2,
                          ),
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
          _metaChip(context, '${content.releaseDate}'),
        _metaChip(context, content.typeLabel),
        if (content.isSerie && content.seasonCount > 0)
          _metaChip(
            context,
            '${content.seasonCount} saison${content.seasonCount > 1 ? 's' : ''}'
            ' · ${content.episodeCount} épisodes',
          ),
        if (content.languageTag.isNotEmpty)
          _metaChip(context, content.languageTag, accent: true),
      ],
    );
  }

  Widget _metaChip(BuildContext context, String label,
      {bool accent = false}) {
    final color = accent ? NeoTheme.primaryRed : NeoTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: accent ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Text(
        label,
        style: NeoTheme.labelSmall(context).copyWith(color: color),
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
        color: NeoTheme.bgElevated,
        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
        border: Border.all(
            color: NeoTheme.bgBorder.withValues(alpha: 0.15), width: 0.5),
      ),
      padding: const EdgeInsets.all(4),
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
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected ? NeoTheme.heroGradient : null,
                    borderRadius: BorderRadius.circular(NeoTheme.radiusSm),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color:
                                  NeoTheme.primaryRed.withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    WatchLinkUtils.labelForLanguage(lang),
                    textAlign: TextAlign.center,
                    style: NeoTheme.labelMedium(context).copyWith(
                      color: isSelected ? Colors.white : NeoTheme.textSecondary,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Progression',
                style: NeoTheme.labelSmall(context)
                    .copyWith(color: NeoTheme.textSecondary)),
            Text('${(value * 100).round()}%',
                style: NeoTheme.labelSmall(context)
                    .copyWith(color: NeoTheme.primaryRed)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.white10,
            valueColor:
                const AlwaysStoppedAnimation(NeoTheme.primaryRed),
            minHeight: 5,
          ),
        ),
      ],
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
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: NeoTheme.bgElevated,
            shape: BoxShape.circle,
            border: Border.all(
                color: NeoTheme.bgBorder.withValues(alpha: 0.15), width: 0.5),
          ),
          child: IconButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                if (content.inLibrary) {
                  await _api.removeFromLibrary(content.id);
                  if (!mounted) return;
                  messenger.showSnackBar(const SnackBar(
                    content: Text('Retiré de votre liste'),
                    backgroundColor: NeoTheme.textSecondary,
                  ));
                } else {
                  await _api.addToLibrary(content.id);
                  if (!mounted) return;
                  messenger.showSnackBar(const SnackBar(
                    content: Text('Ajouté à votre liste'),
                    backgroundColor: NeoTheme.primaryRed,
                  ));
                }
                if (!mounted) return;
                setState(() => content.inLibrary = !content.inLibrary);
              } catch (_) {
                if (!mounted) return;
                messenger.showSnackBar(const SnackBar(
                  content: Text('Erreur'),
                  backgroundColor: NeoTheme.errorRed,
                ));
              }
            },
            icon: Icon(
              content.inLibrary ? Icons.check_rounded : Icons.add_rounded,
              color: content.inLibrary
                  ? NeoTheme.primaryRed
                  : NeoTheme.textPrimary,
            ),
            tooltip: content.inLibrary
                ? 'Dans ma liste'
                : 'Ajouter à ma liste',
          ),
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
        Text('Épisodes', style: NeoTheme.titleLarge(context)),
        const SizedBox(height: 10),
        if (seasonNumbers.length > 1) ...[
          _buildSeasonSelector(context, seasonNumbers),
          const SizedBox(height: 14),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
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
        const SizedBox(height: 24),
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
            padding: const EdgeInsets.only(right: 8),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected ? NeoTheme.heroGradient : null,
                        color: isSelected ? null : NeoTheme.bgElevated,
                        borderRadius:
                            BorderRadius.circular(NeoTheme.radiusMd),
                        border: Border.all(
                          color: (isFocused || isSelected)
                              ? NeoTheme.primaryRed
                              : NeoTheme.bgBorder.withValues(alpha: 0.2),
                          width: isFocused ? 2 : 1,
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: NeoTheme.primaryRed
                                      .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        'Saison $num',
                        style: NeoTheme.labelMedium(context).copyWith(
                          color: (isSelected || isFocused)
                              ? Colors.white
                              : NeoTheme.textSecondary,
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
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: isFocused
                    ? LinearGradient(colors: [
                        NeoTheme.primaryRed.withValues(alpha: 0.12),
                        NeoTheme.bgElevated,
                      ])
                    : NeoTheme.surfaceGradient,
                borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                border: Border.all(
                  color: isFocused
                      ? NeoTheme.primaryRed
                      : NeoTheme.bgBorder.withValues(alpha: 0.12),
                  width: isFocused ? 1.5 : 0.5,
                ),
                boxShadow: [
                  ...NeoTheme.shadowLevel1,
                  if (isFocused)
                    BoxShadow(
                      color: NeoTheme.primaryRed.withValues(alpha: 0.25),
                      blurRadius: 14,
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
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: NeoTheme.primaryRed.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(NeoTheme.radiusSm),
                        ),
                        child: Center(
                          child: Text(
                            'E${episode.episode}',
                            style: NeoTheme.titleMedium(context)
                                .copyWith(color: NeoTheme.primaryRed),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title + meta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              episode.title.isNotEmpty
                                  ? episode.title
                                  : episode.label,
                              style: NeoTheme.labelLarge(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(episode.label,
                                    style: NeoTheme.bodySmall(context)),
                                if (langs.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  ...langs.map((l) => Padding(
                                        padding:
                                            const EdgeInsets.only(right: 4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (_selectedLanguage == l)
                                                ? NeoTheme.primaryRed
                                                    .withValues(alpha: 0.15)
                                                : NeoTheme.bgSurface
                                                    .withValues(alpha: 0.6),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                              color: (_selectedLanguage == l)
                                                  ? NeoTheme.primaryRed
                                                      .withValues(alpha: 0.3)
                                                  : NeoTheme.bgBorder
                                                      .withValues(alpha: 0.2),
                                              width: 0.5,
                                            ),
                                          ),
                                          child: Text(
                                            WatchLinkUtils.labelForLanguage(l),
                                            style: NeoTheme.labelSmall(context)
                                                .copyWith(
                                              fontSize: 10,
                                              color: (_selectedLanguage == l)
                                                  ? NeoTheme.primaryRed
                                                  : NeoTheme.textSecondary,
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
                      const SizedBox(width: 8),
                      Icon(
                        isPlayable
                            ? Icons.play_circle_fill_rounded
                            : Icons.lock_outline_rounded,
                        color: isPlayable
                            ? (isFocused
                                ? NeoTheme.primaryRed
                                : NeoTheme.primaryRed.withValues(alpha: 0.6))
                            : NeoTheme.textDisabled,
                        size: 32,
                      ),
                    ],
                  ),
                  if (episode.progressPercent != null &&
                      episode.progressPercent! > 0) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: episode.progressPercent! / 100,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation(
                            NeoTheme.primaryRed),
                        minHeight: 3,
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
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: NeoTheme.prestigeGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
        border: Border.all(
            color: NeoTheme.prestigeGold.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium,
              color: NeoTheme.prestigeGold, size: 40),
          const SizedBox(height: 8),
          Text('Contenu Premium',
              style: NeoTheme.titleLarge(context)
                  .copyWith(color: NeoTheme.prestigeGold)),
          const SizedBox(height: 4),
          Text('Passez Premium pour accéder à plus de 26 000 titres.',
              style: NeoTheme.bodySmall(context), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ── SKELETON ─────────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return Scaffold(
      backgroundColor: NeoTheme.bgBase,
      body: Column(
        children: [
          Container(height: 380, color: NeoTheme.bgElevated),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skBox(180, 24),
                const SizedBox(height: 10),
                _skBox(double.infinity, 16),
                const SizedBox(height: 6),
                _skBox(double.infinity, 16),
                const SizedBox(height: 20),
                _skBox(double.infinity, 52),
                const SizedBox(height: 16),
                ...List.generate(
                    3,
                    (_) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
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
          color: NeoTheme.bgElevated,
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
    final links = _rankLinks(content.watchLinks);
    if (links.isNotEmpty) {
      _launchPlayer(content, links);
      return;
    }
    final ep = _firstPlayableEpisode(content);
    if (ep != null) {
      _launchPlayer(content, _rankLinks(ep.watchLinks),
          episodeId: 'S${ep.season}E${ep.episode}');
    }
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
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
  const _ExpandableText({required this.text});

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
          style: NeoTheme.bodyLarge(context)
              .copyWith(color: NeoTheme.textSecondary, height: 1.55),
          maxLines: _expanded ? null : 3,
          overflow: _expanded ? null : TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? 'Voir moins' : 'Voir plus',
            style: NeoTheme.labelSmall(context).copyWith(
              color: NeoTheme.primaryRed,
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
  const _RatingBadge({required this.rating});

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
            style: const TextStyle(
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

  const _FocusablePlayButton({
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
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient:
                    widget.canPlay ? NeoTheme.heroGradient : null,
                color: widget.canPlay ? null : NeoTheme.bgElevated,
                borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                border: (_focused && useFocus)
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
                boxShadow: widget.canPlay
                    ? [
                        BoxShadow(
                          color: (_focused && useFocus)
                              ? Colors.white.withValues(alpha: 0.3)
                              : NeoTheme.primaryRed.withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
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
                        : NeoTheme.textDisabled,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: NeoTheme.labelLarge(context).copyWith(
                      color: widget.canPlay
                          ? Colors.white
                          : NeoTheme.textDisabled,
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
