import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

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

class _DetailScreenState extends State<DetailScreen> {
  final ApiService _api = ApiService();
  Content? _content;
  bool _isLoading = true;
  String? _error;
  int _selectedSeason = 1;
  String? _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final content = await _api.getContentDetail(widget.contentId);
      final seasons = content.seasons.keys.toList()..sort();

      setState(() {
        _content = content;
        _isLoading = false;
        if (seasons.isNotEmpty) {
          _selectedSeason = seasons.first;
        }
        _selectedLanguage = WatchLinkUtils.defaultLanguage(
          content.availableLanguages,
        );
      });
    } catch (e) {
      setState(() {
        _error = 'Impossible de charger le contenu. Veuillez réessayer.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: NeoTheme.bgBase,
        body: Shimmer.fromColors(
          baseColor: NeoTheme.bgElevated,
          highlightColor: NeoTheme.bgBorder.withValues(alpha: 0.3),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.45,
                  color: NeoTheme.bgElevated,
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 220,
                        height: 28,
                        decoration: BoxDecoration(
                          color: NeoTheme.bgElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 160,
                        height: 16,
                        decoration: BoxDecoration(
                          color: NeoTheme.bgElevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...List.generate(3, (_) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          width: double.infinity,
                          height: 14,
                          decoration: BoxDecoration(
                            color: NeoTheme.bgElevated,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      )),
                      const SizedBox(height: 24),
                      Row(
                        children: List.generate(3, (_) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Container(
                            width: 90,
                            height: 40,
                            decoration: BoxDecoration(
                              color: NeoTheme.bgElevated,
                              borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                            ),
                          ),
                        )),
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

    if (_error != null || _content == null) {
      return Scaffold(
        backgroundColor: NeoTheme.bgBase,
        appBar: AppBar(backgroundColor: NeoTheme.bgBase),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: NeoTheme.errorRed,
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Contenu introuvable',
                style: NeoTheme.bodyMedium(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_error?.contains('Premium') == true)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: NeoTheme.prestigeGold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                    border: Border.all(
                      color: NeoTheme.prestigeGold.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.workspace_premium,
                        color: NeoTheme.prestigeGold,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Contenu Premium',
                        style: NeoTheme.titleLarge(
                          context,
                        ).copyWith(color: NeoTheme.prestigeGold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Passez Premium pour acceder a plus de 26 000 titres.',
                        style: NeoTheme.bodySmall(context),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
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
    final selectedSeasonEpisodes =
        content.seasons[_selectedSeason] ?? const <Episode>[];
    final languageSelector = _buildLanguageSelector(context, content);
    final canPlay = _primaryPlayableLinks(content).isNotEmpty;

    return Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack ||
              event.logicalKey == LogicalKeyboardKey.browserBack) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
      backgroundColor: NeoTheme.bgBase,
      body: SafeArea(
        top: !NeoTheme.isTV(
          context,
        ), // Sur TV on prend tout l'écran, sur mobile on respecte l'encoche
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 400,
              pinned: true,
              backgroundColor: NeoTheme.bgBase,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: NeoTheme.bgOverlay.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 0.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
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
                        placeholder: (_, _) => Container(color: NeoTheme.bgElevated),
                        errorWidget: (_, _, _) => Container(
                          color: NeoTheme.bgElevated,
                          child: const Center(
                            child: Icon(Icons.movie_rounded, color: NeoTheme.textDisabled, size: 48),
                          ),
                        ),
                      ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: NeoTheme.posterFadeGradient,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (content.genres.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: content.genres
                            .map(
                              (genre) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: NeoTheme.getGenreColor(
                                    genre,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: NeoTheme.getGenreColor(
                                      genre,
                                    ).withValues(alpha: 0.2),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  genre,
                                  style: NeoTheme.labelMedium(context).copyWith(
                                    color: NeoTheme.getGenreColor(genre),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        content.displayTitle,
                        maxLines: 1,
                        style: NeoTheme.displayMedium(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (content.rating > 0)
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xE61C1605),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: CircularProgressIndicator(
                                    value: content.rating / 10.0,
                                    strokeWidth: 3.5,
                                    backgroundColor: NeoTheme.prestigeGold
                                        .withValues(alpha: 0.15),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          NeoTheme.prestigeGold,
                                        ),
                                  ),
                                ),
                                Text(
                                  content.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: NeoTheme.prestigeGold,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (content.releaseDate != null)
                          Text(
                            '${content.releaseDate}',
                            style: NeoTheme.bodyMedium(context),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: NeoTheme.textTertiary.withValues(alpha: 0.12),
                            border: Border.all(
                              color: NeoTheme.textTertiary.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            content.typeLabel,
                            style: NeoTheme.labelSmall(context),
                          ),
                        ),
                        if (content.isSerie && content.seasonCount > 0)
                          Text(
                            '${content.seasonCount} saison${content.seasonCount > 1 ? 's' : ''} - ${content.episodeCount} episodes',
                            style: NeoTheme.bodySmall(context),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (languageSelector != null) ...[
                      languageSelector,
                      const SizedBox(height: 16),
                    ],
                    if (content.isSerie) ...[
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildStatCard(
                            context,
                            icon: Icons.layers_outlined,
                            label: 'Saisons',
                            value: '${content.seasonCount}',
                          ),
                          _buildStatCard(
                            context,
                            icon: Icons.movie_filter_outlined,
                            label: 'Episodes',
                            value: '${content.episodeCount}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (content.description != null)
                      Text(
                        content.description!,
                        style: NeoTheme.bodyLarge(context),
                      ),
                    if (!content.isSerie &&
                        content.userProgress != null &&
                        (double.tryParse(content.userProgress!['progress_percent']?.toString() ?? '0') ?? 0) > 0) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (double.tryParse(content.userProgress!['progress_percent']?.toString() ?? '0') ?? 0) / 100,
                          backgroundColor: Colors.white10,
                          valueColor:
                              const AlwaysStoppedAnimation(NeoTheme.primaryRed),
                          minHeight: 4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _FocusablePlayButton(
                            canPlay: canPlay,
                            label: content.isSerie
                                ? 'LANCER LA LECTURE'
                                : 'REGARDER',
                            onPlay: () => _playPrimaryAction(content),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: NeoTheme.bgOverlay.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: NeoTheme.bgBorder.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                if (content.inLibrary) {
                                  await _api.removeFromLibrary(content.id);
                                  if (!mounted) {
                                    return;
                                  }
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Retire de votre liste'),
                                      backgroundColor: NeoTheme.textSecondary,
                                    ),
                                  );
                                } else {
                                  await _api.addToLibrary(content.id);
                                  if (!mounted) {
                                    return;
                                  }
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Ajoute a votre liste'),
                                      backgroundColor: NeoTheme
                                          .primaryRed, // Changed from successGreen
                                    ),
                                  );
                                }
                                if (!mounted) {
                                  return;
                                }
                                setState(() {
                                  content.inLibrary = !content.inLibrary;
                                });
                              } catch (_) {
                                if (!mounted) {
                                  return;
                                }
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Erreur'),
                                    backgroundColor: NeoTheme.errorRed,
                                  ),
                                );
                              }
                            },
                            icon: Icon(
                              content.inLibrary ? Icons.check : Icons.add,
                              color: content.inLibrary
                                  ? NeoTheme
                                        .primaryRed // Changed to primaryRed instead of successGreen
                                  : NeoTheme.textPrimary,
                            ),
                            tooltip: content.inLibrary
                                ? 'Dans ma liste'
                                : 'Ajouter a ma liste',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (content.isSerie && content.seasons.isNotEmpty) ...[
                      Text('Episodes', style: NeoTheme.titleLarge(context)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: seasonNumbers.map((season) {
                            final isSelected = season == _selectedSeason;
                            final useFocus = NeoTheme.needsFocusNavigation(context);
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
                                          setState(() => _selectedSeason = season);
                                          return KeyEventResult.handled;
                                        }
                                        return KeyEventResult.ignored;
                                      }
                                    : null,
                                child: Builder(
                                  builder: (ctx) {
                                    final isFocused = Focus.of(ctx).hasFocus;
                                    return ChoiceChip(
                                      selected: isSelected,
                                      label: Text('Saison $season'),
                                      labelStyle: NeoTheme.labelMedium(context)
                                          .copyWith(
                                            color: isSelected || isFocused
                                                ? Colors.white
                                                : NeoTheme.textSecondary,
                                          ),
                                      selectedColor: NeoTheme.primaryRed.withValues(alpha: 0.18),
                                      backgroundColor: isFocused
                                          ? NeoTheme.primaryRed.withValues(alpha: 0.12)
                                          : NeoTheme.bgSurface,
                                      side: BorderSide(
                                        color: isFocused
                                            ? NeoTheme.primaryRed
                                            : isSelected
                                                ? NeoTheme.primaryRed.withValues(alpha: 0.4)
                                                : NeoTheme.bgBorder.withValues(alpha: 0.2),
                                        width: isFocused ? 2 : 0.5,
                                      ),
                                      onSelected: (_) =>
                                          setState(() => _selectedSeason = season),
                                    );
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.05),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          key: ValueKey<int>(_selectedSeason),
                          children: selectedSeasonEpisodes
                              .map(
                                (episode) => _buildEpisodeCard(
                                  context,
                                  content,
                                  episode,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (content.similar.isNotEmpty) ...[
                      Text(
                        'Vous aimerez aussi',
                        style: NeoTheme.titleLarge(context),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: NeoTheme.cardHeight(context),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: content.similar.length,
                          itemBuilder: (_, index) => Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ContentCard(
                              content: content.similar[index],
                              index: index,
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DetailScreen(
                                      contentId: content.similar[index].id,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    if (content.createdAt != null || content.updatedAt != null)
                      Text(
                        'Ajoute : ${content.createdAt?.split(' ').first ?? '-'} - Mis a jour : ${content.updatedAt?.split(' ').first ?? '-'}',
                        style: NeoTheme.labelSmall(context),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget? _buildLanguageSelector(BuildContext context, Content content) {
    final languages = WatchLinkUtils.sortLanguages(
      content.availableLanguages.where((language) => language != 'unknown'),
    );
    if (languages.isEmpty) {
      return null;
    }

    final currentLanguage =
        _selectedLanguage ?? WatchLinkUtils.defaultLanguage(languages);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: NeoTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(
          color: NeoTheme.bgBorder.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: NeoTheme.shadowLevel1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Langue prioritaire', style: NeoTheme.titleMedium(context)),
          const SizedBox(height: 6),
          Text(
            'La lecture essaie d abord la langue choisie puis bascule automatiquement vers une autre source si besoin.',
            style: NeoTheme.bodySmall(context),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: languages.map((language) {
              final isSelected = currentLanguage == language;
              final useFocus = NeoTheme.needsFocusNavigation(context);
              return Focus(
                canRequestFocus: useFocus,
                onKeyEvent: useFocus
                    ? (node, event) {
                        if (event is KeyDownEvent &&
                            (event.logicalKey == LogicalKeyboardKey.enter ||
                             event.logicalKey == LogicalKeyboardKey.select ||
                             event.logicalKey == LogicalKeyboardKey.space)) {
                          setState(() => _selectedLanguage = language);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      }
                    : null,
                child: Builder(
                  builder: (ctx) {
                    final isFocused = Focus.of(ctx).hasFocus;
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text(WatchLinkUtils.labelForLanguage(language)),
                      labelStyle: NeoTheme.labelMedium(context).copyWith(
                        color: isSelected || isFocused ? Colors.white : NeoTheme.textSecondary,
                      ),
                      selectedColor: NeoTheme.primaryRed.withValues(alpha: 0.18),
                      backgroundColor: isFocused 
                          ? NeoTheme.primaryRed.withValues(alpha: 0.15) 
                          : NeoTheme.bgSurface,
                      side: BorderSide(
                        color: isFocused
                            ? NeoTheme.primaryRed
                            : isSelected
                                ? NeoTheme.primaryRed.withValues(alpha: 0.4)
                                : NeoTheme.bgBorder.withValues(alpha: 0.2),
                        width: isFocused ? 2 : 0.5,
                      ),
                      onSelected: (_) => setState(() => _selectedLanguage = language),
                    );
                  }
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }



  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: NeoTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(
          color: NeoTheme.bgBorder.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: NeoTheme.shadowLevel1,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: NeoTheme.primaryRed),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: NeoTheme.titleMedium(context)),
              Text(label, style: NeoTheme.labelSmall(context)),
            ],
          ),
        ],
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
    final availableLanguages = WatchLinkUtils.sortLanguages(
      episode.availableLanguages,
    );
    final useFocus = NeoTheme.needsFocusNavigation(context);

    void playEpisode() {
      if (!isPlayable) return;
      _launchPlayer(
        content,
        preferredLinks,
        episodeId: 'S${episode.season}E${episode.episode}',
      );
    }

    return Focus(
      canRequestFocus: useFocus && isPlayable,
      onKeyEvent: useFocus
          ? (node, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.enter ||
                   event.logicalKey == LogicalKeyboardKey.select ||
                   event.logicalKey == LogicalKeyboardKey.space)) {
                playEpisode();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            }
          : null,
      child: Builder(
        builder: (ctx) {
          final isFocused = Focus.of(ctx).hasFocus;
          return GestureDetector(
            onTap: isPlayable ? playEpisode : null,
            child: AnimatedContainer(
              duration: NeoTheme.durationFast,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: NeoTheme.surfaceGradient,
                borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                border: Border.all(
                  color: isFocused
                      ? NeoTheme.primaryRed
                      : NeoTheme.bgBorder.withValues(alpha: 0.15),
                  width: isFocused ? 2 : 0.5,
                ),
                boxShadow: [
                  ...NeoTheme.shadowLevel1,
                  if (isFocused)
                    BoxShadow(
                      color: NeoTheme.primaryRed.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                ],
              ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: NeoTheme.primaryRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'E${episode.episode}',
                  style: NeoTheme.titleMedium(
                    context,
                  ).copyWith(color: NeoTheme.primaryRed),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.title,
                      style: NeoTheme.labelLarge(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(episode.label, style: NeoTheme.bodySmall(context)),
                    if (availableLanguages.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: availableLanguages.map((language) {
                          final isSelectedLanguage =
                              _selectedLanguage == language;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelectedLanguage
                                  ? NeoTheme.primaryRed.withValues(alpha: 0.12)
                                  : NeoTheme.bgSurface.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isSelectedLanguage
                                    ? NeoTheme.primaryRed.withValues(alpha: 0.2)
                                    : NeoTheme.bgBorder.withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              WatchLinkUtils.labelForLanguage(language),
                              style: NeoTheme.labelSmall(context).copyWith(
                                color: isSelectedLanguage
                                    ? NeoTheme.primaryRed
                                    : NeoTheme.textSecondary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: isPlayable
                    ? 'Lire ${episode.label}'
                    : 'Episode indisponible',
                onPressed: isPlayable
                    ? () => _launchPlayer(
                        content,
                        preferredLinks,
                        episodeId: 'S${episode.season}E${episode.episode}',
                      )
                    : null,
                icon: Icon(
                  isPlayable ? Icons.play_circle_fill : Icons.lock_outline,
                  color: isPlayable ? NeoTheme.primaryRed : NeoTheme.textDisabled,
                ),
              ),
            ],
          ),
          if (episode.progressPercent != null && episode.progressPercent! > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: episode.progressPercent! / 100,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation(NeoTheme.primaryRed),
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

  List<WatchLink> _rankLinks(List<WatchLink> watchLinks) {
    return WatchLinkUtils.prioritize(
      watchLinks,
      preferredLanguage: _selectedLanguage,
    );
  }

  List<WatchLink> _primaryPlayableLinks(Content content) {
    if (content.watchLinks.isNotEmpty) {
      return _rankLinks(content.watchLinks);
    }

    final firstEpisode = _firstPlayableEpisode(content);
    if (firstEpisode == null) {
      return const <WatchLink>[];
    }
    return _rankLinks(firstEpisode.watchLinks);
  }

  void _playPrimaryAction(Content content) {
    final rankedLinks = _rankLinks(content.watchLinks);
    if (rankedLinks.isNotEmpty) {
      _launchPlayer(content, rankedLinks);
      return;
    }

    final firstEpisode = _firstPlayableEpisode(content);
    if (firstEpisode != null) {
      _launchPlayer(
        content,
        _rankLinks(firstEpisode.watchLinks),
        episodeId: 'S${firstEpisode.season}E${firstEpisode.episode}',
      );
    }
  }

  Episode? _firstPlayableEpisode(Content content) {
    final seasons = content.seasons.keys.toList()..sort();
    for (final season in seasons) {
      final episodes = content.seasons[season] ?? const <Episode>[];
      for (final episode in episodes) {
        if (_rankLinks(episode.watchLinks).isNotEmpty) {
          return episode;
        }
      }
    }
    return null;
  }

  void _launchPlayer(
    Content content,
    List<WatchLink> candidateServers, {
    String? episodeId,
  }) {
    if (candidateServers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune source disponible pour cette lecture.'),
          backgroundColor: NeoTheme.errorRed,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          content: content,
          videoSourceUrl: candidateServers.first.url,
          candidateServers: candidateServers,
          preferredLanguage: _selectedLanguage,
          episodeId: episodeId,
        ),
      ),
    ).then((_) {
      if (mounted) _loadDetail();
    });
  }
}

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
        if (_focused == f) return;
        setState(() => _focused = f);
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
          cursor: widget.canPlay ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: AnimatedScale(
        scale: (_focused && useFocus) ? 1.04 : 1.0,
        duration: NeoTheme.durationFast,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
            border: (_focused && useFocus)
                ? Border.all(color: Colors.white, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: (_focused && useFocus)
                    ? Colors.white.withValues(alpha: 0.3)
                    : NeoTheme.primaryRedGlow,
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: widget.canPlay ? widget.onPlay : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(widget.label),
            style: ElevatedButton.styleFrom(
              backgroundColor: NeoTheme.primaryRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return Colors.white.withValues(alpha: 0.25);
                }
                if (states.contains(WidgetState.hovered)) {
                  return Colors.white.withValues(alpha: 0.12);
                }
                return Colors.white.withValues(alpha: 0.15);
              }),
            ),
          ),
        ),
      ),
    ),
  ),
  );
  }
}