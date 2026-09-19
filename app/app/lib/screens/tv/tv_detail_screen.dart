import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/tv_config.dart';
import '../../models/content.dart';
import '../../services/api_service.dart';
import '../../widgets/tv_wrapper.dart';
import '../../widgets/tv_focusable_card.dart';
import '../../widgets/metadata_pill.dart';
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

  /// Nœud du bouton Regarder : cible initiale + fallback anti perte de focus.
  final FocusNode _watchFocusNode = FocusNode(debugLabel: 'watchButton');
  // B1/B2 : nœuds dédiés aux états erreur/loading pour garantir un focus
  // D-pad (Réessayer en autofocus, Retour header en fallback).
  final FocusNode _retryFocusNode = FocusNode(debugLabel: 'retryButton');
  final FocusNode _errorBackFocusNode = FocusNode(debugLabel: 'errorBack');
  final FocusNode _loadingBackFocusNode = FocusNode(debugLabel: 'loadingBack');
  final ScrollController _scrollController = ScrollController();
  bool _didInitialAutofocus = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_handleFocusLoss);
    _loadDetail();
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

  /// Fallback : si le focus primaire devient null après une navigation
  /// D-pad (cas SingleChildScrollView / nœud racine TVWrapper), on le
  /// restaure au prochain frame. Cible selon l'état : loading -> Retour
  /// header (B2), erreur -> Réessayer (B1), contenu -> Regarder.
  /// Pas de FocusScope second : TVWrapper/TVRemoteNavigator gèrent la racine.
  void _handleFocusLoss() {
    if (!mounted || _isNavigating) return;
    if (FocusManager.instance.primaryFocus != null) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isNavigating) return;
      if (FocusManager.instance.primaryFocus == null &&
          ModalRoute.of(context)?.isCurrent == true) {
        if (_isLoading) {
          _loadingBackFocusNode.requestFocus();
        } else if (_error != null || _content == null) {
          _retryFocusNode.requestFocus();
        } else {
          _watchFocusNode.requestFocus();
        }
      }
    });
  }

  void _requestInitialFocus() {
    if (_didInitialAutofocus) return;
    _didInitialAutofocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isNavigating) return;
      if (FocusManager.instance.primaryFocus == null) {
        _watchFocusNode.requestFocus();
      }
    });
  }

  Future<void> _loadDetail() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final content = await _api.getContentDetail(widget.contentId);
      if (!mounted) return;
      final seasons = content.seasons.keys.toList()..sort();
      setState(() {
        _content = content;
        _isLoading = false;
        if (seasons.isNotEmpty) _selectedSeason = seasons.first;
        _selectedLanguage = WatchLinkUtils.defaultLanguage(content.availableLanguages);
      });
      _requestInitialFocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger le contenu';
        _isLoading = false;
      });
      // B1 : focus mort en erreur -> autofocus Réessayer au prochain frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (FocusManager.instance.primaryFocus == null) {
          _retryFocusNode.requestFocus();
        }
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
          ? _buildLoading()
          : _error != null || _content == null
              ? _buildError()
              : _buildContent(),
    );
  }

  /// B2 loading : spinner display-only + bouton Retour focusable avec
  /// autofocus (miroir du header Retour, non adressable depuis le child).
  /// Garantit une cible D-pad pendant le chargement.
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

  /// B1 : erreur focusable D-pad (Réessayer autofocus + Retour fallback
  /// header). MaListe reste atteignable via l'écran contenu après retry.
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 64, color: TVTheme.errorRed),
          const SizedBox(height: 16),
          Text(_error ?? 'Contenu introuvable', style: const TextStyle(color: TVTheme.textPrimary, fontSize: 18)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              TVFocusableCard(
                focusNode: _retryFocusNode,
                autoFocus: true,
                onTap: _loadDetail,
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
    final content = _content!;
    final seasonNumbers = content.seasons.keys.toList()..sort();
    final selectedSeasonEpisodes = content.seasons[_selectedSeason] ?? const <Episode>[];
    final canPlay = _rankLinks(content.watchLinks).isNotEmpty;
    final languages = WatchLinkUtils.sortLanguages(content.availableLanguages.where((l) => l != 'unknown').toList());

    // Groupe de traversal ordonné haut->bas / gauche->droite pour un
    // ordre D-pad prévisible. Un seul groupe racine : pas de FocusScope
    // interne (TVWrapper/TVRemoteNavigator gèrent déjà la racine).
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
                  imageUrl: content.fullPosterUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_1, _2, _3) => Container(color: TVTheme.cardColor, child: const Icon(Icons.movie, color: TVTheme.textDisabled, size: 48)),
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
                              Text(content.rating.toStringAsFixed(1), style: const TextStyle(color: TVTheme.accentGold, fontWeight: FontWeight.bold)),
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
                            decoration: BoxDecoration(color: TVTheme.accentGold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.emoji_events, color: TVTheme.accentGold, size: 14),
                              const SizedBox(width: 4),
                              Text('#${content.rank}', style: const TextStyle(color: TVTheme.accentGold, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Header progression : séries X/Y (Z%), films Vu à X%
                    if (content.isSerie)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _SeriesProgressHeader(content: content),
                      )
                    else if ((content.progressPercent ?? 0) > 0 ||
                        (content.userProgress?['progress_percent'] is num))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _FilmProgressHeader(content: content),
                      ),
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
                      FocusTraversalGroup(
                        policy: WidgetOrderTraversalPolicy(),
                        child: Wrap(
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
                      ),
                      const SizedBox(height: 24),
                    ],
                    Row(
                      children: [
                        TVFocusableCard(
                          // Seul autofocus de l'écran, consommé au premier
                          // chargement. Right depuis Regarder -> Ma Liste
                          // (même Row, flèches en ignored dans TVFocusableCard).
                          focusNode: _watchFocusNode,
                          autoFocus: !_didInitialAutofocus,
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
                                messenger.showSnackBar(const SnackBar(content: Text('Retiré de votre liste'), backgroundColor: TVTheme.textSecondary));
                              } else {
                                await _api.addToLibrary(content.id);
                                messenger.showSnackBar(const SnackBar(content: Text('Ajouté à votre liste'), backgroundColor: TVTheme.accentRed));
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
            const Text('Épisodes', style: TextStyle(color: TVTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            FocusTraversalGroup(
              policy: WidgetOrderTraversalPolicy(),
              child: Wrap(
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
            ),
            const SizedBox(height: 16),
            ...selectedSeasonEpisodes.map((episode) {
              final preferredLinks = _rankLinks(episode.watchLinks);
              final isPlayable = preferredLinks.isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TVFocusableCard(
                  // onTap toujours non-null : même non playable la carte
                  // reste focusable au D-pad (affiche le cadenas).
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text(episode.title, style: const TextStyle(color: TVTheme.textPrimary, fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 8),
                                EpisodeProgressPill(
                                  apiPercent: episode.progressPercent,
                                  localKey: localProgressKeyForContentEpisode(
                                      content.id, episode.season, episode.episode),
                                  fontSize: 9,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(episode.label, style: const TextStyle(color: TVTheme.textSecondary, fontSize: 12)),
                            if ((episode.progressPercent ?? 0) > 0) ...[
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: (episode.progressPercent! / 100).clamp(0.0, 1.0),
                                  backgroundColor: Colors.white12,
                                  valueColor: const AlwaysStoppedAnimation(TVTheme.accentRed),
                                  minHeight: 3,
                                ),
                              ),
                            ],
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
          // B5 : série sans saisons -> bandeau explicite display-only
          // (ExcludeFocus : pas de cible D-pad morte, simple information).
          if (content.isSerie && content.seasons.isEmpty)
            const ExcludeFocus(
              child: _NoSeasonBanner(),
            ),
          if (content.similar.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Text('Contenus similaires', style: TextStyle(color: TVTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              // Groupe ordonné : gauche/droite naviguent entre cartes,
              // bas remonte au groupe parent au lieu de perdre le focus.
              child: FocusTraversalGroup(
                policy: WidgetOrderTraversalPolicy(),
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
                        // B4 : push simple (pas de replacement) pour que BACK
                        // revienne à la fiche précédente. MaListe reste
                        // atteignable via chaque fiche (bouton + header).
                        Navigator.push(
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
                                    Image.network(item.fullPosterUrl, fit: BoxFit.cover, errorBuilder: (_1, _2, _3) => _placeholder())
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
            ),
          ],
          if (content.createdAt != null || content.updatedAt != null) ...[
            const SizedBox(height: 24),
            Text('Ajouté : ${content.createdAt?.split(' ').first ?? '-'} | Mis à jour : ${content.updatedAt?.split(' ').first ?? '-'}', style: const TextStyle(color: TVTheme.textDisabled, fontSize: 11)),
          ],
          const SizedBox(height: 40),
        ],
      ),
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
        // Flèches en ignored : traversal directionnel D-pad vers
        // les chips voisins / rangées voisines.
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

/// Header progression série TV : "Progression : X/Y épisodes (Z%)" + barre.
class _NoSeasonBanner extends StatelessWidget {
  const _NoSeasonBanner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Aucune saison disponible pour cette série',
      child: Container(
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
            Expanded(
              child: Text(
                'Aucune saison disponible pour cette série pour le moment.',
                style: TextStyle(color: TVTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header progression série TV : "Progression : X/Y épisodes (Z%)" + barre.
class _SeriesProgressHeader extends StatelessWidget {
  final Content content;
  const _SeriesProgressHeader({required this.content});

  @override
  Widget build(BuildContext context) {
    final stats = seriesWatchStats(content);
    final label = seriesProgressLabel(stats.watched, stats.total, stats.percent);
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TVTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TVTheme.defaultBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.play_circle_outline_rounded,
                    size: 14, color: TVTheme.accentRed),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          color: TVTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (stats.percent / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.white12,
                valueColor:
                    const AlwaysStoppedAnimation(TVTheme.accentRed),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header progression film TV : "Vu à X%" + barre.
class _FilmProgressHeader extends StatelessWidget {
  final Content content;
  const _FilmProgressHeader({required this.content});

  @override
  Widget build(BuildContext context) {
    final raw = content.progressPercent ??
        (content.userProgress?['progress_percent'] is num
            ? (content.userProgress!['progress_percent'] as num).toDouble()
            : 0.0);
    final label = filmProgressLabel(raw.clamp(0.0, 100.0));
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TVTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TVTheme.defaultBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Continuer la lecture',
                    style: TextStyle(
                        color: TVTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                Text(label,
                    style: const TextStyle(
                        color: TVTheme.accentRed,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (raw / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.white12,
                valueColor:
                    const AlwaysStoppedAnimation(TVTheme.accentRed),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}