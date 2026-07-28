import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../config/theme.dart';
import '../config/neo.dart';
import '../models/anime.dart';
import '../models/content.dart';
import '../services/api_service.dart';
import '../widgets/content_card.dart';
import 'anime_detail_screen.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  List<Content> _results = [];
  List<Anime> _animeResults = [];
  bool _loading = false;
  String _query = '';
  String? _error;
  int _searchId = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocus);
    // Ne pas ouvrir automatiquement le dialogue - l'utilisateur doit cliquer explicitement
  }

  void _onFocus() { if (mounted) setState(() {}); }

  Future<void> _openSearchDialog() async {
    final controller = TextEditingController(text: _controller.text);
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _SearchDialog(controller: controller),
    );
    if (!mounted) return;
    if (result != null && result.trim().length >= 2) {
      _controller.text = result;
      _search(result.trim());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.removeListener(_onFocus);
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(Duration(milliseconds: 400), () {
      final q = v.trim();
      if (q.length >= 2 && q != _query) _search(q);
      if (q.isEmpty) setState(() { _results = []; _animeResults = []; _query = ''; _error = null; });
    });
  }

  Future<void> _search(String q) async {
    final currentId = ++_searchId;
    setState(() { _loading = true; _query = q; _error = null; });
    try {
      final raw = await _api.searchContent(q);
      if (!mounted) return;
      final films = raw.where((c) => c.contentType != 'anime').toList();
      final animeAsContent = raw.where((c) => c.contentType == 'anime').toList();
      // Lancer aussi la recherche anime en parallèle
      List<Anime> animes = [];
      try {
        final animeData = await _api.searchAnime(q);
        animes = animeData.map((e) => Anime.fromJson(e)).toList();
      } catch (_) {}
      if (currentId != _searchId) return; // stale request
      // Fusionner : si un anime est dans les deux listes, garder fromJson
      final animeIds = {for (final a in animes) a.id};
      final extraAnimes = animeAsContent
          .where((c) => !animeIds.contains(c.id))
          .map((c) => Anime.fromJson({
                'id': c.id, 'anime_id': c.id.toString(), 'url': c.id.toString(),
                'title': c.title, 'genres': c.genres,
                'poster_url': c.poster, 'seasons': {}, 'total_seasons': 0,
                'total_episodes': 0,
              }))
          .toList();
      setState(() {
        _results = films;
        _animeResults = [...animes, ...extraAnimes];
        _loading = false;
      });
    } catch (e) {
      if (currentId != _searchId) return; // stale request
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _openDetail(Content c) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => DetailScreen(contentId: c.id)));

  void _openAnime(Anime a) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => AnimeDetailScreen(animeId: a.id)));

  @override
  Widget build(BuildContext context) {
    final isTV = NeoTheme.isTV(context);
    final pad = NeoTheme.screenPadding(context);
    final total = _results.length + _animeResults.length;

    return Scaffold(
      backgroundColor: Neo.bgBase(context),
      body: SafeArea(
        top: !isTV,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          child: Column(
          children: [
            // ── Barre de recherche ───────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(pad.left, 12, pad.right, 8),
              child: isTV
                  ? _buildTVSearchButton(context)
                  : Container(
                      decoration: BoxDecoration(
                        color: Neo.bgOverlay(context),
                        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                        border: Border.all(
                          color: _focusNode.hasFocus
                              ? Theme.of(context).colorScheme.primary
                              : Neo.bgBorder(context).withValues(alpha: 0.3),
                          width: _focusNode.hasFocus ? 2 : 0.5,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: false,
                        textInputAction: TextInputAction.search,
                        onChanged: _onChanged,
                        style: Neo.bodyLarge(context).copyWith(color: Neo.textPrimary(context)),
                        decoration: InputDecoration(
                          hintText: 'Titre, genre, acteur...',
                          hintStyle: Neo.bodyMedium(context).copyWith(color: Neo.textDisabled(context)),
                          prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.primary),
                          suffixIcon: _controller.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded, color: Neo.textTertiary(context)),
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() { _results = []; _animeResults = []; _query = ''; _error = null; });
                                    _focusNode.requestFocus();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 16),
                          isDense: true,
                        ),
                      ),
                    ),
            ),

            // ── Header résultats ─────────────────────────────────────
            if (_query.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 8),
                child: Row(
                  children: [
                    Text(
                      _loading ? 'Recherche...' : '$total résultat${total > 1 ? "s" : ""} pour "$_query"',
                      style: Neo.bodySmall(context).copyWith(color: Neo.textSecondary(context)),
                    ),
                    if (_loading) ...[
                      SizedBox(width: 8),
                      SizedBox(width: 12, height: 12,
                          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary, strokeWidth: 2)),
                    ],
                  ],
                ),
              ),

            // ── Contenu ──────────────────────────────────────────────
            Expanded(child: _buildContent(context, pad, isTV)),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, EdgeInsets pad, bool isTV) {
    if (_query.isEmpty) return _buildEmpty(context, false);
    if (_loading && _results.isEmpty) return _buildShimmer(context, isTV, pad);
    if (_error != null) return _buildEmpty(context, true);
    if (_results.isEmpty && _animeResults.isEmpty) return _buildEmpty(context, false);

    final all = <dynamic>[..._results, ..._animeResults];
    final cols = isTV ? 5 : (MediaQuery.of(context).size.width >= 900 ? 4 : 2);
    final useGrid = isTV || MediaQuery.of(context).size.width >= 600;

    if (useGrid) {
      return FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: GridView.builder(
          padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 32),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: 2 / 3,
            crossAxisSpacing: NeoTheme.gridSpacing(context),
            mainAxisSpacing: NeoTheme.gridSpacing(context),
          ),
          itemCount: all.length,
          itemBuilder: (ctx, i) => _buildCard(ctx, all[i], i),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 32),
      itemCount: all.length,
      itemBuilder: (ctx, i) => Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: _buildCard(ctx, all[i], i),
      ),
    );
  }

  Widget _buildCard(BuildContext context, dynamic item, int index) {
    Content content;
    VoidCallback onTap;

    if (item is Anime) {
      content = Content(
        id: item.id, title: item.title, description: item.synopsis,
        contentType: 'anime', genres: item.genres, rating: 0,
        poster: item.posterUrl, keywords: [], watchLinks: [],
        releaseDate: null, createdAt: null,
      );
      onTap = () => _openAnime(item);
    } else {
      content = item as Content;
      onTap = () => _openDetail(content);
    }

    return ContentCard(
      content: content,
      variant: NeoTheme.isTV(context) ? CardVariant.standard : CardVariant.search,
      index: index,
      onTap: onTap,
    );
  }

  Widget _buildEmpty(BuildContext context, bool isError) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.wifi_off_rounded
                  : _query.isEmpty ? Icons.search_rounded
                  : Icons.search_off_rounded,
              size: 56, color: Neo.textDisabled(context),
            ),
            SizedBox(height: 16),
            Text(
              isError ? 'Erreur de recherche'
                  : _query.isEmpty ? 'Recherchez un film, série ou anime'
                  : 'Aucun résultat pour "$_query"',
              style: Neo.titleMedium(context),
              textAlign: TextAlign.center,
            ),
            if (_query.isEmpty) ...[
              SizedBox(height: 8),
              Text('Tapez au moins 2 caractères',
                  style: Neo.bodyMedium(context).copyWith(color: Neo.textSecondary(context)),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTVSearchButton(BuildContext context) {
    final hasQuery = _query.isNotEmpty;
    return ElevatedButton.icon(
      autofocus: true,
      onPressed: _openSearchDialog,
      icon: Icon(Icons.search_rounded, size: 22),
      label: Text(
        hasQuery ? 'Modifier : "$_query"' : 'Appuyer OK pour rechercher',
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: hasQuery ? Theme.of(context).colorScheme.primary : Neo.bgOverlay(context),
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, 52),
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NeoTheme.radiusLg)),
        side: BorderSide(
          color: hasQuery ? Theme.of(context).colorScheme.primary : Neo.bgBorder(context).withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildShimmer(BuildContext context, bool isTV, EdgeInsets pad) {
    final cols = isTV ? 5 : 2;
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 32),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: NeoTheme.gridSpacing(context),
        mainAxisSpacing: NeoTheme.gridSpacing(context),
      ),
      itemCount: cols * 3,
      itemBuilder: (_1, _2) => Shimmer.fromColors(
        baseColor: Neo.bgElevated(context),
        highlightColor: Neo.bgBorder(context).withValues(alpha: 0.3),
        child: Container(
          decoration: BoxDecoration(
            color: Neo.bgElevated(context),
            borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
          ),
        ),
      ),
    );
  }
}

// ── Dialogue de recherche TV ─────────────────────────────────────────────────

class _SearchDialog extends StatefulWidget {
  final TextEditingController controller;
  _SearchDialog({required this.controller});

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.controller.text);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_ctrl.text);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Color(0xFF0D1827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rechercher', style: Neo.titleMedium(context)),
            SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              style: Neo.bodyLarge(context).copyWith(color: Neo.textPrimary(context)),
              decoration: InputDecoration(
                hintText: 'Titre, genre, acteur...',
                hintStyle: Neo.bodyMedium(context).copyWith(color: Neo.textDisabled(context)),
                prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.primary),
                filled: true,
                fillColor: Neo.bgOverlay(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Annuler'),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  autofocus: false,
                  onPressed: _submit,
                  icon: Icon(Icons.search_rounded),
                  label: Text('Rechercher'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
