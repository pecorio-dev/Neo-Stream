import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/tv_config.dart';
import '../../models/content.dart';
import '../../services/api_service.dart';
import '../../widgets/tv_wrapper.dart';
import '../../widgets/tv_focusable_card.dart';
import '../../utils/watch_link_utils.dart';
import '../player_screen.dart';

class TVDetailScreen extends StatefulWidget {
  final int contentId;

  const TVDetailScreen({super.key, required this.contentId});

  @override
  State<TVDetailScreen> createState() => _TVDetailScreenState();
}

class _TVDetailScreenState extends State<TVDetailScreen> {
  final ApiService _api = ApiService();
  Content? _content;
  bool _isLoading = true;
  String? _error;
  int _selectedSeason = 1;
  String? _selectedLanguage;
  bool _isNavigating = false;

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
        if (seasons.isNotEmpty) _selectedSeason = seasons.first;
        _selectedLanguage = WatchLinkUtils.defaultLanguage(content.availableLanguages);
      });
    } catch (e) {
      setState(() {
        _error = 'Impossible de charger le contenu';
        _isLoading = false;
      });
    }
  }

  void _playContent() {
    if (_isNavigating) return;
    final content = _content;
    if (content == null) return;

    final rankedLinks = _rankLinks(content.watchLinks);
    if (rankedLinks.isEmpty) return;

    _isNavigating = true;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          content: content,
          videoSourceUrl: rankedLinks.first.url,
          candidateServers: rankedLinks,
          preferredLanguage: _selectedLanguage,
        ),
      ),
    ).then((_) {
      if (mounted) {
        _isNavigating = false;
        _loadDetail();
      }
    });
  }

  List<WatchLink> _rankLinks(List<WatchLink> watchLinks) {
    return WatchLinkUtils.prioritize(watchLinks, preferredLanguage: _selectedLanguage);
  }

  @override
  Widget build(BuildContext context) {
    return TVWrapper(
      showBackButton: true,
      onBack: () => Navigator.pop(context),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: TVTheme.accentRed))
          : _error != null || _content == null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 64, color: TVTheme.errorRed),
          const SizedBox(height: 16),
          Text(_error ?? 'Contenu introuvable', style: const TextStyle(color: TVTheme.textPrimary, fontSize: 18)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: TVTheme.accentRed),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Retour'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final content = _content!;
    final seasonNumbers = content.seasons.keys.toList()..sort();
    final selectedSeasonEpisodes = content.seasons[_selectedSeason] ?? const <Episode>[];
    final canPlay = _rankLinks(content.watchLinks).isNotEmpty;
    final languages = WatchLinkUtils.sortLanguages(content.availableLanguages.where((l) => l != 'unknown').toList());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 180,
                height: 270,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20)],
                ),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: content.fullPosterUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: TVTheme.cardColor, child: const Icon(Icons.movie, color: TVTheme.textDisabled, size: 48)),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(content.displayTitle, style: const TextStyle(color: TVTheme.textPrimary, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (content.rating > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: TVTheme.accentGold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.star, color: TVTheme.accentGold, size: 16),
                              const SizedBox(width: 4),
                              Text('${content.rating.toStringAsFixed(1)}', style: const TextStyle(color: TVTheme.accentGold, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: TVTheme.accentRed.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                          child: Text(content.typeLabel, style: const TextStyle(color: TVTheme.accentRed)),
                        ),
                        if (content.releaseDate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: TVTheme.cardColor, borderRadius: BorderRadius.circular(20)),
                            child: Text('${content.releaseDate}', style: const TextStyle(color: TVTheme.textSecondary)),
                          ),
                        if (content.isSerie && content.seasonCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: TVTheme.cardColor, borderRadius: BorderRadius.circular(20)),
                            child: Text('${content.seasonCount} saison${content.seasonCount > 1 ? 's' : ''} - ${content.episodeCount} episodes', style: const TextStyle(color: TVTheme.textSecondary)),
                          ),
                        if (content.rank != null && content.rank! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: TVTheme.infoCyan.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.emoji_events, color: TVTheme.infoCyan, size: 14),
                              const SizedBox(width: 4),
                              Text('#${content.rank}', style: const TextStyle(color: TVTheme.infoCyan, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (content.genres.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: content.genres.map<Widget>((genre) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: TVTheme.getGenreColor(genre).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: TVTheme.getGenreColor(genre).withValues(alpha: 0.3)),
                            ),
                            child: Text(genre, style: TextStyle(color: TVTheme.getGenreColor(genre), fontSize: 12)),
                          );
                        }).toList(),
                      ),
                    if (content.keywords.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(content.keywords.take(5).join(' - '), style: const TextStyle(color: TVTheme.textDisabled, fontSize: 11)),
                    ],
                    const SizedBox(height: 24),
                    if (languages.isNotEmpty) ...[
                      const Text('Langue :', style: TextStyle(color: TVTheme.textSecondary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: languages.map((lang) {
                          final isSelected = _selectedLanguage == lang;
                          return _TVFocusableChip(
                            label: WatchLinkUtils.labelForLanguage(lang),
                            isSelected: isSelected,
                            onTap: () => setState(() => _selectedLanguage = lang),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Row(
                      children: [
                        TVFocusableCard(
                          onTap: canPlay ? _playContent : () {},
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow, color: canPlay ? Colors.white : TVTheme.textDisabled, size: 28),
                              const SizedBox(width: 8),
                              Text(content.isSerie ? 'LANCER LA LECTURE' : 'REGARDER', style: TextStyle(color: canPlay ? Colors.white : TVTheme.textDisabled, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        TVFocusableCard(
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              if (content.inLibrary) {
                                await _api.removeFromLibrary(content.id);
                                messenger.showSnackBar(const SnackBar(content: Text('Retire de votre liste'), backgroundColor: TVTheme.textSecondary));
                              } else {
                                await _api.addToLibrary(content.id);
                                messenger.showSnackBar(const SnackBar(content: Text('Ajoute a votre liste'), backgroundColor: TVTheme.accentRed));
                              }
                              if (!mounted) return;
                              setState(() => content.inLibrary = !content.inLibrary);
                            } catch (_) {
                              messenger.showSnackBar(const SnackBar(content: Text('Erreur'), backgroundColor: TVTheme.errorRed));
                            }
                          },
                          padding: const EdgeInsets.all(12),
                          child: Icon(content.inLibrary ? Icons.check : Icons.add, color: content.inLibrary ? TVTheme.accentRed : TVTheme.textPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (content.description != null) ...[
            const Text('Synopsis', style: TextStyle(color: TVTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(content.description!, style: const TextStyle(color: TVTheme.textSecondary, fontSize: 15, height: 1.5)),
            const SizedBox(height: 32),
          ],
          if (content.isSerie && content.seasons.isNotEmpty) ...[
            const Text('Episodes', style: TextStyle(color: TVTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: seasonNumbers.map((season) {
                final isSelected = _selectedSeason == season;
                return _TVFocusableChip(
                  label: 'Saison $season',
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedSeason = season),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            ...selectedSeasonEpisodes.map((episode) {
              final preferredLinks = _rankLinks(episode.watchLinks);
              final isPlayable = preferredLinks.isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TVFocusableCard(
                  onTap: isPlayable
                      ? () {
                          _isNavigating = true;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen(
                                content: content,
                                videoSourceUrl: preferredLinks.first.url,
                                candidateServers: preferredLinks,
                                preferredLanguage: _selectedLanguage,
                                episodeId: 'S${episode.season}E${episode.episode}',
                              ),
                            ),
).then((_) {
                             if (mounted) {
                               _isNavigating = false;
                               _loadDetail();
                             }
                           });
                        }
                      : () {},
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(gradient: TVTheme.heroGradient, borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text('E${episode.episode}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(episode.title, style: const TextStyle(color: TVTheme.textPrimary, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(episode.label, style: const TextStyle(color: TVTheme.textSecondary, fontSize: 12)),
                            if (episode.availableLanguages.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                children: episode.availableLanguages.map((lang) =>
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (_selectedLanguage == lang ? TVTheme.accentRed : TVTheme.cardColor).withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(WatchLinkUtils.labelForLanguage(lang), style: TextStyle(color: _selectedLanguage == lang ? Colors.white : TVTheme.textSecondary, fontSize: 10)),
                                  ),
                                ).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(isPlayable ? Icons.play_circle : Icons.lock_outline, color: isPlayable ? TVTheme.accentRed : TVTheme.textDisabled),
                    ],
                  ),
                ),
              );
            }),
          ],
          if (content.similar.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Text('Contenus similaires', style: TextStyle(color: TVTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const TVScrollPhysics(),
                itemCount: content.similar.length,
                itemBuilder: (context, index) {
                  final item = content.similar[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: TVFocusableCard(
                      minWidth: 140,
                      maxWidth: 160,
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => TVDetailScreen(contentId: item.id)),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: TVTheme.cardColor),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (item.fullPosterUrl.isNotEmpty)
                                    Image.network(item.fullPosterUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                                  else
                                    _placeholder(),
                                  if (item.rating > 0)
                                    Positioned(
                                      top: 6, right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          const Icon(Icons.star, color: TVTheme.accentGold, size: 10),
                                          const SizedBox(width: 2),
                                          Text(item.rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 10)),
                                        ]),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(item.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TVTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                          Text(item.typeLabel, style: const TextStyle(color: TVTheme.textSecondary, fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (content.createdAt != null || content.updatedAt != null) ...[
            const SizedBox(height: 24),
            Text('Ajoute : ${content.createdAt?.split(' ').first ?? '-'} | Mis a jour : ${content.updatedAt?.split(' ').first ?? '-'}', style: const TextStyle(color: TVTheme.textDisabled, fontSize: 11)),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: TVTheme.cardColor,
      child: Center(child: Icon(Icons.movie_outlined, color: TVTheme.textDisabled, size: 40)),
    );
  }
}

class _TVFocusableChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TVFocusableChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TVFocusableChip> createState() => _TVFocusableChipState();
}

class _TVFocusableChipState extends State<_TVFocusableChip> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: TVConfig.focusAnimationDuration,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: widget.isSelected ? TVTheme.heroGradient : null,
            color: widget.isSelected ? null : (_isFocused ? TVTheme.surfaceColor : TVTheme.cardColor),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? TVTheme.accentRed
                  : (_isFocused ? TVTheme.accentRed : TVTheme.defaultBorderColor),
              width: _isFocused ? 2.5 : 1,
            ),
            boxShadow: _isFocused
                ? [BoxShadow(color: TVTheme.accentRed.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2)]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isSelected || _isFocused ? Colors.white : TVTheme.textSecondary,
              fontWeight: widget.isSelected || _isFocused ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}