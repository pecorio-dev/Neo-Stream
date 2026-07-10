import 'package:flutter/material.dart';

import '../config/light_theme.dart';
import '../config/theme.dart';
import '../config/neo.dart';

/// Barre de recherche contextuelle qui s'adapte selon l'écran actif
///
/// - Sur l'écran Anime → recherche parmi les anime
/// - Sur l'écran Films/Séries → recherche parmi le contenu VOD
/// - Sur l'écran IPTV → recherche parmi les chaînes TV
/// - Autres écrans → recherche globale
class ContextualSearchBar extends StatefulWidget {
  /// Type de contexte de recherche
  final SearchContext context;

  /// Callback appelé lors de la soumission de la recherche
  final Function(String query)? onSearch;

  /// Placeholder personnalisé (optionnel)
  final String? placeholder;

  /// Afficher l'icône de filtre
  final bool showFilterButton;

  /// Callback pour le bouton filtre
  final VoidCallback? onFilterTap;

  /// Activer l'effet glass (mode clair uniquement)
  final bool useGlass;

  ContextualSearchBar({
    super.key,
    required this.context,
    this.onSearch,
    this.placeholder,
    this.showFilterButton = false,
    this.onFilterTap,
    this.useGlass = true,
  });

  @override
  State<ContextualSearchBar> createState() => _ContextualSearchBarState();
}

class _ContextualSearchBarState extends State<ContextualSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode()
      ..addListener(() {
        if (mounted) {
          setState(() => _hasFocus = _focusNode.hasFocus);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _defaultPlaceholder {
    switch (widget.context) {
      case SearchContext.anime:
        return 'Rechercher un anime...';
      case SearchContext.movies:
        return 'Rechercher un film...';
      case SearchContext.series:
        return 'Rechercher une série...';
      case SearchContext.iptv:
        return 'Rechercher une chaîne...';
      case SearchContext.favorites:
        return 'Rechercher dans mes favoris...';
      case SearchContext.history:
        return 'Rechercher dans mon historique...';
      case SearchContext.global:
        return 'Rechercher...';
    }
  }

  IconData get _contextIcon {
    switch (widget.context) {
      case SearchContext.anime:
        return Icons.animation_rounded;
      case SearchContext.movies:
        return Icons.movie_rounded;
      case SearchContext.series:
        return Icons.tv_rounded;
      case SearchContext.iptv:
        return Icons.live_tv_rounded;
      case SearchContext.favorites:
        return Icons.favorite_rounded;
      case SearchContext.history:
        return Icons.history_rounded;
      case SearchContext.global:
        return Icons.search_rounded;
    }
  }

  void _onSubmit() {
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      widget.onSearch?.call(query);
      _focusNode.unfocus();
    }
  }

  void _clear() {
    _controller.clear();
    widget.onSearch?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLightMode = theme.brightness == Brightness.light;
    final isDark = !isLightMode;

    Widget searchBar = AnimatedContainer(
      duration: Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _hasFocus
            ? (isDark
                ? Neo.bgSurface(context).withValues(alpha: 0.9)
                : NeoLightTheme.bgSurface)
            : (isDark
                ? Neo.bgBorder(context).withValues(alpha: 0.1)
                : NeoLightTheme.bgElevated.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(
          isLightMode ? NeoLightTheme.radiusMd : NeoTheme.radiusMd,
        ),
        border: Border.all(
          color: _hasFocus
              ? (isDark ? NeoTheme.primaryRed : NeoLightTheme.primaryRed)
              : (isDark
                  ? Neo.bgBorder(context).withValues(alpha: 0.2)
                  : NeoLightTheme.border),
          width: _hasFocus ? 2 : 1,
        ),
        boxShadow: _hasFocus
            ? [
                BoxShadow(
                  color: (isDark ? NeoTheme.primaryRed : NeoLightTheme.primaryRed)
                      .withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: Offset(0, 2),
                ),
              ]
            : (isLightMode
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null),
      ),
      child: Row(
        children: [
          // Icône de contexte
          Padding(
            padding: EdgeInsets.only(left: 16, right: 8),
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 200),
              child: Icon(
                _contextIcon,
                key: ValueKey(widget.context),
                size: 20,
                color: _hasFocus
                    ? (isDark ? NeoTheme.primaryRed : NeoLightTheme.primaryRed)
                    : (isDark
                        ? Neo.textDisabled(context)
                        : NeoLightTheme.textSecondary),
              ),
            ),
          ),
          // TextField
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: TextStyle(
                color: isDark ? Neo.textPrimary(context) : NeoLightTheme.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: widget.placeholder ?? _defaultPlaceholder,
                hintStyle: TextStyle(
                  color: isDark
                      ? Neo.textDisabled(context)
                      : NeoLightTheme.textTertiary,
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: (_) => _onSubmit(),
              onChanged: (value) {
                // Recherche en temps réel si activée
                if (widget.onSearch != null && value.trim().isNotEmpty) {
                  widget.onSearch!(value.trim());
                } else if (value.trim().isEmpty) {
                  widget.onSearch?.call('');
                }
              },
            ),
          ),
          // Bouton clear
          if (_controller.text.isNotEmpty)
            IconButton(
              onPressed: _clear,
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: isDark
                    ? Neo.textSecondary(context)
                    : NeoLightTheme.textSecondary,
              ),
              tooltip: 'Effacer',
            ),
          // Bouton filtre
          if (widget.showFilterButton && widget.onFilterTap != null)
            IconButton(
              onPressed: widget.onFilterTap,
              icon: Icon(
                Icons.tune_rounded,
                size: 20,
                color: isDark
                    ? Neo.textSecondary(context)
                    : NeoLightTheme.textSecondary,
              ),
              tooltip: 'Filtres',
            ),
        ],
      ),
    );

    // Ajouter l'effet glass en mode clair si activé
    if (widget.useGlass && isLightMode && !_hasFocus) {
      return NeoLightTheme.glassContainer(
        blur: 15,
        opacity: 0.90,
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(NeoLightTheme.radiusMd),
        child: searchBar,
      );
    }

    return searchBar;
  }
}

/// Contextes de recherche disponibles
enum SearchContext {
  global,
  anime,
  movies,
  series,
  iptv,
  favorites,
  history,
}

/// Widget de barre de recherche fixe en haut de l'écran
class StickySearchBar extends StatelessWidget {
  final SearchContext context;
  final Function(String)? onSearch;
  final String? placeholder;
  final bool showFilterButton;
  final VoidCallback? onFilterTap;

  StickySearchBar({
    super.key,
    required this.context,
    this.onSearch,
    this.placeholder,
    this.showFilterButton = false,
    this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLightMode = theme.brightness == Brightness.light;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 8,
        16,
        12,
      ),
      decoration: BoxDecoration(
        gradient: isLightMode
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  NeoLightTheme.bgBase,
                  NeoLightTheme.bgBase.withValues(alpha: 0.95),
                  NeoLightTheme.bgBase.withValues(alpha: 0.0),
                ],
              )
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Neo.bgBase(context),
                  Neo.bgBase(context).withValues(alpha: 0.95),
                  Neo.bgBase(context).withValues(alpha: 0.0),
                ],
              ),
      ),
      child: SafeArea(
        bottom: false,
        child: ContextualSearchBar(
          context: this.context,
          onSearch: onSearch,
          placeholder: placeholder,
          showFilterButton: showFilterButton,
          onFilterTap: onFilterTap,
        ),
      ),
    );
  }
}
