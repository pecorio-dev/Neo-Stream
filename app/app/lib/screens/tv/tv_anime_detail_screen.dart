import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/tv_config.dart';
import '../../models/anime.dart';
import '../../services/api_service.dart';
import '../../widgets/tv_wrapper.dart';
import '../../widgets/tv_focusable_card.dart';
import '../../widgets/metadata_pill.dart';
import '../player_screen.dart';

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

  /// Nœud du bouton Regarder : cible initiale + fallback anti perte de focus.
  final FocusNode _watchFocusNode = FocusNode(debugLabel: 'watchButton');
  // A3 : nœuds dédiés à l'état erreur (Réessayer autofocus + Retour fallback).
  final FocusNode _retryFocusNode = FocusNode(debugLabel: 'retryButton');
  final FocusNode _errorBackFocusNode = FocusNode(debugLabel: 'errorBack');
  // Loading : bouton Retour focusé d'attente (jamais de D-pad mort).
  final FocusNode _loadingBackFocusNode = FocusNode(debugLabel: 'loadingBack');
  final ScrollController _scrollController = ScrollController();
  bool _didInitialAutofocus = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_handleFocusLoss);
    // Focus INITIAL garanti dès le mount, même pendant le loading.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      if (FocusManager.instance.primaryFocus == null) {
        _loadingBackFocusNode.requestFocus();
      }
    });
    _loadAnime();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusLoss);
    _watchFocusNode.dispose();
    _retryFocusNode.dispose();
    _errorBackFocusNode.dispose();
    _loadingBackFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Cible de fallback selon l'état courant.
  FocusNode _focusTargetForState() {
    if (_isLoading) return _loadingBackFocusNode;
    if (_errorMessage != null || _anime == null) return _retryFocusNode;
    return _watchFocusNode;
  }

  /// Force le focus sur [node] au prochain frame + rattrapage au frame
  /// suivant si le primaire est encore null (nœud pas encore attaché).
  void _forceFocus(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      if (node.canRequestFocus && !node.hasFocus) {
        node.requestFocus();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ModalRoute.of(context)?.isCurrent != true) return;
        if (FocusManager.instance.primaryFocus == null &&
            !node.hasFocus &&
            node.canRequestFocus) {
          node.requestFocus();
        }
      });
    });
  }

  /// Fallback : si le focus primaire devient null après une navigation
  /// D-pad (y compris pendant le loading), on le restaure au prochain
  /// frame selon l'état courant. Se re-déclenche à chaque perte.
  /// Pas de FocusScope interne (TVWrapper/TVRemoteNavigator gèrent la racine).
  void _handleFocusLoss() {
    if (!mounted) return;
    if (FocusManager.instance.primaryFocus != null) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final target = _focusTargetForState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (FocusManager.instance.primaryFocus == null &&
          ModalRoute.of(context)?.isCurrent == true) {
        if (target.canRequestFocus && !target.hasFocus) {
          target.requestFocus();
        }
      }
    });
  }

  /// Focus contenu forcé à chaque arrivée (premier chargement, retry,
  /// retour player). `_didInitialAutofocus` ne sert qu'au param `autoFocus`
  /// du widget — jamais de garde bloquant le restore.
  void _requestInitialFocus() {
    _didInitialAutofocus = true;
    _forceFocus(_watchFocusNode);
  }

  Future<void> _loadAnime() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    // Transition -> loading : refocus Retour d'attente (jamais de D-pad mort).
    _forceFocus(_loadingBackFocusNode);
    try {
      final data = await _api.getAnimeDetail(widget.animeId);
      if (!mounted) return;
      if (data['anime'] == null) throw Exception('Données anime non disponibles');
      final animeData = data['anime'];
      if (animeData is! Map<String, dynamic>) throw Exception('Format invalide');
      final anime = Anime.fromJson(animeData);

      bool inLibrary = false;
      try {
        inLibrary = await _api.checkAnimeInLibrary(anime.id);
      } catch (_) {}
      if (!mounted) return;

      final validKeys = anime.seasons.entries.where((e) => e.value.episodes.isNotEmpty).map((e) => e.key).toList()..sort();

      setState(() {
        _anime = anime;
        _inLibrary = inLibrary;
        _validSeasonKeys = validKeys;
        _selectedSeason = validKeys.isNotEmpty ? validKeys.first : 1;
        _isLoading = false;
      });
      _requestInitialFocus();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
      // A3 : focus mort en erreur -> Réessayer inconditionnel au prochain
      // frame (même si un focus résiduel/racine existe).
      _forceFocus(_retryFocusNode);
    }
  }

  void _playEpisode(int seasonNumber, AnimeEpisode episode, List<Map<String, String>> sources) {
    if (_anime == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
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
    // autofocusRoot: false — sinon TVRemoteNavigator vole le focus vers un
    // nœud racine invisible (primaryFocus != null) et ni Regarder ni
    // Réessayer ne reçoivent le focus (D-pad mort). Miroir tv_detail_screen.
    return TVWrapper(
      showBackButton: true,
      autofocusRoot: false,
      onBack: () => Navigator.pop(context),
      child: _isLoading
          ? _buildLoading()
          : _errorMessage != null
              ? _buildError()
              : _buildContent(),
    );
  }

  /// Loading : spinner display-only + bouton Retour focusable avec
  /// autofocus. Garantit une cible D-pad pendant le chargement (avant :
  /// aucun widget focusable -> D-pad mort sur tout le fetch réseau).
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: TVTheme.accentRed),
          const SizedBox(height: 24),
          TVFocusableCard(
            focusNode: _loadingBackFocusNode,
            autoFocus: true,
            onTap: () => Navigator.pop(context),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, color: TVTheme.textPrimary),
                SizedBox(width: 8),
                Text('Retour', style: TextStyle(color: TVTheme.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A3 : erreur focusable D-pad (Réessayer autofocus + Retour fallback header).
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 64, color: TVTheme.errorRed),
          const SizedBox(height: 16),
          Text(_errorMessage ?? 'Erreur', style: const TextStyle(color: TVTheme.textPrimary, fontSize: 18)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              TVFocusableCard(
                focusNode: _retryFocusNode,
                autoFocus: true,
                onTap: _loadAnime,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Réessayer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              TVFocusableCard(
                focusNode: _errorBackFocusNode,
                autoFocus: false,
                onTap: () => Navigator.pop(context),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, color: TVTheme.textPrimary),
                    SizedBox(width: 8),
                    Text('Retour', style: TextStyle(color: TVTheme.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final anime = _anime!;
    final season = anime.seasons[_selectedSeason];
    // A1/A2 : jouable seulement si au moins une saison valide non vide.
    // Grisé visuel comme VOD quand non jouable, MaListe reste atteignable.
    final canPlay = _validSeasonKeys.isNotEmpty;

    // Groupe de traversal ordonné haut->bas / gauche->droite pour un
    // ordre D-pad prévisible. Pas de FocusScope interne (racine déjà
    // gérée par TVWrapper/TVRemoteNavigator).
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: SingleChildScrollView(
        controller: _scrollController,
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
                  errorWidget: (_1, _2, _3) => Container(color: TVTheme.cardColor, child: const Icon(Icons.animation, color: TVTheme.textDisabled, size: 48)),
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
                    MetadataPillsRow(
                      pills: pillsFromAnime(anime, short: true),
                      maxPills: 4,
                      fontSize: 10,
                    ),
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      final stats = animeWatchStats(anime);
                      if (stats.total <= 0 || stats.watched <= 0) {
                        return const SizedBox.shrink();
                      }
                      final label = seriesProgressLabel(
                          stats.watched, stats.total, stats.percent);
                      return Semantics(
                        label: label,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: const TextStyle(
                                    color: TVTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value:
                                    (stats.percent / 100).clamp(0.0, 1.0),
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation(
                                    TVTheme.accentRed),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
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
                          // Seul autofocus de l'écran, consommé au premier
                          // chargement. Right -> Ma Liste (même Row,
                          // flèches en ignored dans TVFocusableCard).
                          focusNode: _watchFocusNode,
                          autoFocus: !_didInitialAutofocus,
                          onTap: canPlay
                              ? () {
                                  // A2 : joue la saison sélectionnée si
                                  // valide, sinon validKeys.first (jamais
                                  // keys.first brut qui peut être vide).
                                  final playKey =
                                      _validSeasonKeys.contains(_selectedSeason)
                                          ? _selectedSeason
                                          : _validSeasonKeys.first;
                                  final playSeason = anime.seasons[playKey];
                                  if (playSeason != null &&
                                      playSeason.episodes.isNotEmpty) {
                                    _playEpisode(
                                        playKey,
                                        playSeason.episodes[0],
                                        playSeason.episodes[0].players);
                                  }
                                }
                              : () {},
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow,
                                  color: canPlay
                                      ? Colors.white
                                      : TVTheme.textDisabled,
                                  size: 28),
                              const SizedBox(width: 8),
                              Text('LANCER LA LECTURE',
                                  style: TextStyle(
                                      color: canPlay
                                          ? Colors.white
                                          : TVTheme.textDisabled,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
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
                                if (!mounted) return;
                                messenger.showSnackBar(const SnackBar(content: Text('Retiré de votre liste'), backgroundColor: TVTheme.textSecondary));
                              } else {
                                await _api.addAnimeToLibrary(anime.id);
                                if (!mounted) return;
                                messenger.showSnackBar(const SnackBar(content: Text('Ajouté à votre liste'), backgroundColor: TVTheme.accentRed));
                              }
                              if (!mounted) return;
                              setState(() => _inLibrary = !_inLibrary);
                            } catch (_) {
                              if (!mounted) return;
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
            const Text('Épisodes', style: TextStyle(color: TVTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            FocusTraversalGroup(
              policy: WidgetOrderTraversalPolicy(),
              child: Wrap(
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
            ),
            const SizedBox(height: 16),
            if (season != null && season.episodes.isNotEmpty)
              ...season.episodes.map((episode) {
                final sources = episode.players;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TVFocusableCard(
                    // onTap toujours non-null : chaque épisode est
                    // focusable au D-pad.
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
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                        episode.title.isNotEmpty
                                            ? episode.title
                                            : 'Episode ${episode.episodeNumber}',
                                        style: const TextStyle(
                                            color: TVTheme.textPrimary,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: 8),
                                  EpisodeProgressPill(
                                    apiPercent: episode.progressPercent,
                                    localKey:
                                        localProgressKeyForAnimeEpisode(
                                            anime.id,
                                            _selectedSeason,
                                            episode.episodeNumber),
                                    fontSize: 9,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                  '${anime.seasons[_selectedSeason]?.name ?? 'Saison $_selectedSeason'} - ${sources.length} source${sources.length > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                      color: TVTheme.textSecondary,
                                      fontSize: 12)),
                              if ((episode.progressPercent ?? 0) > 0) ...[
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: (episode.progressPercent! / 100)
                                        .clamp(0.0, 1.0),
                                    backgroundColor: Colors.white12,
                                    valueColor:
                                        const AlwaysStoppedAnimation(
                                            TVTheme.accentRed),
                                    minHeight: 3,
                                  ),
                                ),
                              ],
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
                color: TVTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TVTheme.defaultBorderColor),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: TVTheme.textSecondary),
                  SizedBox(width: 12),
                  Expanded(child: Text('Les episodes de cet anime ne sont pas encore disponibles.', style: TextStyle(color: TVTheme.textSecondary))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
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
        // Flèches en ignored : traversal directionnel D-pad.
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
            // Visuel focus : bordure rouge épaisse + halo.
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