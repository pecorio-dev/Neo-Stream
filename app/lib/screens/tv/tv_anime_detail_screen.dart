import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/tv_config.dart';
import '../../models/anime.dart';
import '../../services/api_service.dart';
import '../../widgets/tv_wrapper.dart';
import '../../widgets/tv_focusable_card.dart';
import '../anime_player_screen.dart';

class TVAnimeDetailScreen extends StatefulWidget {
  final int animeId;

  const TVAnimeDetailScreen({super.key, required this.animeId});

  @override
  State<TVAnimeDetailScreen> createState() => _TVAnimeDetailScreenState();
}

class _TVAnimeDetailScreenState extends State<TVAnimeDetailScreen> {
  final ApiService _api = ApiService();
  Anime? _anime;
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedSeason = 1;
  bool _inLibrary = false;
  List<int> _validSeasonKeys = [];

  @override
  void initState() {
    super.initState();
    _loadAnime();
  }

  Future<void> _loadAnime() async {
    try {
      final data = await _api.getAnimeDetail(widget.animeId);
      if (data == null || data['anime'] == null) throw Exception('Donnees anime non disponibles');
      final animeData = data['anime'];
      if (animeData is! Map<String, dynamic>) throw Exception('Format invalide');
      final anime = Anime.fromJson(animeData);

      bool inLibrary = false;
      try {
        inLibrary = await _api.checkAnimeInLibrary(anime.id);
      } catch (_) {}

      final validKeys = anime.seasons.entries.where((e) => e.value.episodes.isNotEmpty).map((e) => e.key).toList()..sort();

      setState(() {
        _anime = anime;
        _inLibrary = inLibrary;
        _validSeasonKeys = validKeys;
        _selectedSeason = validKeys.isNotEmpty ? validKeys.first : 1;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  void _playEpisode(int seasonNumber, AnimeEpisode episode, List<Map<String, String>> sources) {
    if (_anime == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimePlayerScreen(
          anime: _anime!,
          seasonNumber: seasonNumber,
          episode: episode,
          sources: sources,
        ),
      ),
    ).then((_) {
      if (mounted) _loadAnime();
    });
  }

  @override
  Widget build(BuildContext context) {
    return TVWrapper(
      showBackButton: true,
      onBack: () => Navigator.pop(context),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: TVTheme.accentRed))
          : _errorMessage != null
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
          Text(_errorMessage ?? 'Erreur', style: const TextStyle(color: TVTheme.textPrimary, fontSize: 18)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadAnime,
            style: FilledButton.styleFrom(backgroundColor: TVTheme.accentRed),
            icon: const Icon(Icons.refresh),
            label: const Text('Reessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final anime = _anime!;
    final season = anime.seasons[_selectedSeason];

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
                  imageUrl: anime.posterUrl ?? '',
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: TVTheme.cardColor, child: const Icon(Icons.animation, color: TVTheme.textDisabled, size: 48)),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(anime.title, style: const TextStyle(color: TVTheme.textPrimary, fontSize: 32, fontWeight: FontWeight.bold)),
                    if (anime.titleAlt != null) ...[
                      const SizedBox(height: 8),
                      Text(anime.titleAlt!, style: const TextStyle(color: TVTheme.textSecondary, fontSize: 16)),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: TVTheme.accentRed.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.play_circle, color: TVTheme.accentRed, size: 14),
                            const SizedBox(width: 4),
                            Text('${anime.totalEpisodes} episodes', style: const TextStyle(color: TVTheme.accentRed, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: TVTheme.cardColor, borderRadius: BorderRadius.circular(20)),
                          child: Text('${anime.totalSeasons} saison${anime.totalSeasons > 1 ? 's' : ''}', style: const TextStyle(color: TVTheme.textSecondary)),
                        ),
                      ],
                    ),
                    if (anime.genres.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: anime.genres.map((genre) {
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
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        TVFocusableCard(
                          onTap: () {
                            if (anime.seasons.isNotEmpty) {
                              final firstSeason = anime.seasons[1];
                              if (firstSeason != null && firstSeason.episodes.isNotEmpty) {
                                _playEpisode(1, firstSeason.episodes[0], firstSeason.episodes[0].players);
                              }
                            }
                          },
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.play_arrow, color: Colors.white, size: 28),
                              SizedBox(width: 8),
                              Text('LANCER LA LECTURE', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        TVFocusableCard(
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              if (_inLibrary) {
                                await _api.removeAnimeFromLibrary(anime.id);
                                messenger.showSnackBar(const SnackBar(content: Text('Retire de votre liste'), backgroundColor: TVTheme.textSecondary));
                              } else {
                                await _api.addAnimeToLibrary(anime.id);
                                messenger.showSnackBar(const SnackBar(content: Text('Ajoute a votre liste'), backgroundColor: TVTheme.accentRed));
                              }
                              if (!mounted) return;
                              setState(() => _inLibrary = !_inLibrary);
                            } catch (_) {
                              messenger.showSnackBar(const SnackBar(content: Text('Erreur'), backgroundColor: TVTheme.errorRed));
                            }
                          },
                          padding: const EdgeInsets.all(12),
                          child: Icon(_inLibrary ? Icons.check : Icons.add, color: _inLibrary ? TVTheme.accentRed : TVTheme.textPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (anime.synopsis != null) ...[
            const SizedBox(height: 32),
            const Text('Synopsis', style: TextStyle(color: TVTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(anime.synopsis!, style: const TextStyle(color: TVTheme.textSecondary, fontSize: 15, height: 1.5)),
          ],
          const SizedBox(height: 32),
          if (_validSeasonKeys.isNotEmpty) ...[
            const Text('Episodes', style: TextStyle(color: TVTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: _validSeasonKeys.map((seasonNum) {
                final isSelected = _selectedSeason == seasonNum;
                final seasonName = anime.seasons[seasonNum]?.name ?? 'Saison $seasonNum';
                final episodeCount = anime.seasons[seasonNum]?.episodes.length ?? 0;
                return _TVFocusableChip(
                  label: episodeCount > 0 ? '$seasonName ($episodeCount)' : seasonName,
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedSeason = seasonNum),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (season != null && season.episodes.isNotEmpty)
              ...season.episodes.map((episode) {
                final sources = episode.players;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TVFocusableCard(
                    onTap: () => _playEpisode(_selectedSeason, episode, sources),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(gradient: TVTheme.heroGradient, borderRadius: BorderRadius.circular(8)),
                          child: Center(child: Text('${episode.episodeNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(episode.title.isNotEmpty ? episode.title : 'Episode ${episode.episodeNumber}', style: const TextStyle(color: TVTheme.textPrimary, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('${anime.seasons[_selectedSeason]?.name ?? 'Saison $_selectedSeason'} - ${sources.length} source${sources.length > 1 ? 's' : ''}', style: const TextStyle(color: TVTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.play_circle_filled, color: TVTheme.accentRed, size: 32),
                      ],
                    ),
                  ),
                );
              }),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TVTheme.warningOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TVTheme.warningOrange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: TVTheme.warningOrange),
                  SizedBox(width: 12),
                  Expanded(child: Text('Les episodes de cet anime ne sont pas encore disponibles.', style: TextStyle(color: TVTheme.textSecondary))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
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