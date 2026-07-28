import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../config/neo.dart';
import '../models/content.dart';
import '../services/api_service.dart';
import 'detail_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class FavoritesScreen extends StatefulWidget {
  FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final ApiService _api = ApiService();
  List<Content> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _api.libraryRevision.addListener(_load);
  }

  @override
  void dispose() {
    _api.libraryRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    if (_isLoading) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _api.getLibrary();
      if (!mounted) return;
      setState(() {
        _items = data.map(Content.fromJson).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = humanizeApiError(e); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTV = NeoTheme.isTV(context);
    final pad = NeoTheme.screenPadding(context);

    return Scaffold(
      backgroundColor: Neo.bgBase(context),
      appBar: AppBar(
        backgroundColor: Neo.bgBase(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: NeoTheme.heroGradient,
                borderRadius: BorderRadius.circular(NeoTheme.radiusSm),
              ),
              child: Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
            ),
            SizedBox(width: 10),
            Text('Mes Favoris', style: Neo.headlineMedium(context)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Historique',
            icon: Icon(Icons.history_rounded, color: Neo.textSecondary(context)),
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => HistoryScreen())),
          ),
          IconButton(
            tooltip: 'Profil',
            icon: Icon(Icons.person_rounded, color: Neo.textSecondary(context)),
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => ProfileScreen())),
          ),
          IconButton(
            tooltip: 'Paramètres',
            icon: Icon(Icons.settings_rounded, color: Neo.textSecondary(context)),
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => SettingsScreen())),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : _error != null
              ? _buildError()
              : _items.isEmpty
                  ? _buildEmpty(context)
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: Theme.of(context).colorScheme.primary,
                      child: FocusTraversalGroup(
                        policy: ReadingOrderTraversalPolicy(),
                        child: GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            pad.left, 12, pad.right,
                            32 + MediaQuery.of(context).padding.bottom,
                          ),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isTV ? 5 : (MediaQuery.of(context).size.width > 600 ? 4 : 3),
                            childAspectRatio: 2 / 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _items.length,
                          itemBuilder: (ctx, i) => _FavCard(
                            content: _items[i],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetailScreen(contentId: _items[i].id),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border_rounded, size: 64, color: Neo.textDisabled(context)),
          SizedBox(height: 16),
          Text('Aucun favori', style: Neo.titleMedium(context)),
          SizedBox(height: 8),
          Text(
            'Ajoutez des films et séries à vos favoris\npour les retrouver ici.',
            style: Neo.bodyMedium(context).copyWith(color: Neo.textSecondary(context)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: NeoTheme.errorRed),
          SizedBox(height: 12),
          Text('Erreur de chargement', style: Neo.titleMedium(context)),
          SizedBox(height: 8),
          TextButton.icon(
            onPressed: _load,
            icon: Icon(Icons.refresh_rounded),
            label: Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class _FavCard extends StatelessWidget {
  final Content content;
  final VoidCallback onTap;
  _FavCard({required this.content, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
               event.logicalKey == LogicalKeyboardKey.select)) {
            onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (ctx) {
            final focused = Focus.of(ctx).hasFocus;
            return AnimatedContainer(
              duration: Duration(milliseconds: 150),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                border: Border.all(
                  color: focused ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  width: 2,
                ),
                boxShadow: focused ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                    blurRadius: 10,
                  )
                ] : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: content.fullPosterUrl,
                      fit: BoxFit.cover,
                      placeholder: (_1, _2) => Container(color: Neo.bgSurface(context)),
                      errorWidget: (_1, _2, _3) => Container(
                        color: Neo.bgSurface(context),
                        child: Icon(Icons.movie_outlined, color: Neo.textDisabled(context)),
                      ),
                    ),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: Text(
                          content.displayTitle,
                          style: Neo.labelSmall(context).copyWith(color: Colors.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
