import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../config/tv_config.dart';
import '../../providers/providers.dart';
import '../../providers/theme_provider.dart';
import '../iptv_screen.dart';
import 'tv_anime_screen.dart';
import 'tv_history_screen.dart';
import 'tv_home_screen.dart';
import 'tv_search_screen.dart';
import 'tv_settings_screen.dart';

/// Coquille TV unifiée : sidebar de navigation persistante à gauche +
/// zone de contenu qui change selon l'onglet sélectionné (style Android TV).
///
/// Les écrans de détail / lecteur continuent d'être poussés en plein écran
/// par-dessus la coquille via Navigator.push.
class TVShell extends StatefulWidget {
  const TVShell({super.key});

  @override
  State<TVShell> createState() => _TVShellState();
}

class _TVNavItemData {
  final IconData icon;
  final String label;
  const _TVNavItemData(this.icon, this.label);
}

class _TVShellState extends State<TVShell> {
  int _index = 0;

  // Liste des onglets sans la "Recherche" qui est intégrée directement sous forme de champ de saisie
  static const List<_TVNavItemData> _items = [
    _TVNavItemData(Icons.home_rounded, 'Accueil'),
    _TVNavItemData(Icons.animation_rounded, 'Anime'),
    _TVNavItemData(Icons.live_tv_rounded, 'Direct'),
    _TVNavItemData(Icons.history_rounded, 'Historique'),
    _TVNavItemData(Icons.settings_rounded, 'Paramètres'),
  ];

  late final List<FocusNode> _navNodes =
      List.generate(_items.length, (_) => FocusNode());

  late final FocusScopeNode _sidebarFocusScopeNode = FocusScopeNode();
  late final FocusScopeNode _contentFocusScopeNode = FocusScopeNode();

  // Contrôleurs de focus pour la recherche
  late final FocusNode _searchFocusNode = FocusNode();
  late final FocusNode _searchTextFieldNode = FocusNode();
  late final FocusNode _themeToggleFocusNode = FocusNode();

  // Contrôleur de recherche
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Suivi du focus sur la barre latérale
  bool _isSidebarFocused = false;

  @override
  void initState() {
    super.initState();
    _sidebarFocusScopeNode.addListener(_onSidebarFocusChanged);

    if (mounted) {
      context.read<ContentProvider>().loadHome();
      if (_navNodes.isNotEmpty) _navNodes[0].requestFocus();
    }
  }

  void _onSidebarFocusChanged() {
    final hasFocus = _sidebarFocusScopeNode.hasFocus;
    if (_isSidebarFocused != hasFocus && mounted) {
      setState(() {
        _isSidebarFocused = hasFocus;
      });
    }
  }

  /// Indice de contenu « virtuel » pour la recherche (pas d'onglet sidebar).
  static const int _searchContentIndex = -1;

  int get _activeContentIndex =>
      _searchQuery.isNotEmpty ? _searchContentIndex : _index;

  Widget _buildContent(int contentIndex) {
    switch (contentIndex) {
      case 0:
        return const TVHomeScreen(embedded: true);
      case 1:
        return const TVAnimeScreen(embedded: true);
      case 2:
        return const IptvScreen();
      case 3:
        return const TVHistoryScreen(embedded: true);
      case 4:
        return const TVSettingsScreen(embedded: true);
      case _searchContentIndex:
        return TVSearchScreen(query: _searchQuery);
      default:
        return const TVHomeScreen(embedded: true);
    }
  }

  void _select(int contentIndex) {
    if (contentIndex == _searchContentIndex) {
      // Basculer vers la recherche : on garde l'index sidebar courant mais
      // on active le mode recherche via _searchQuery non vide.
      return;
    }
    if (contentIndex != _index) {
      setState(() {
        _index = contentIndex;
        _searchQuery = '';
        _searchController.clear();
      });
    }
  }

  @override
  void dispose() {
    _sidebarFocusScopeNode.removeListener(_onSidebarFocusChanged);
    for (final n in _navNodes) {
      n.dispose();
    }
    _searchFocusNode.dispose();
    _searchTextFieldNode.dispose();
    _themeToggleFocusNode.dispose();
    _searchController.dispose();
    _sidebarFocusScopeNode.dispose();
    _contentFocusScopeNode.dispose();
    super.dispose();
  }

  void _focusActiveNavItem() {
    final targetIndex = _index.clamp(0, _items.length - 1);
    _navNodes[targetIndex].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!_isSidebarFocused && mounted) {
          _focusActiveNavItem();
        } else if (mounted) {
          SystemNavigator.pop();
        }
      },
        child: FocusTraversalGroup(
          child: Scaffold(
          backgroundColor: TVTheme.backgroundDark,
          body: Row(
            children: [
              _buildSidebar(),
              Expanded(
                  child: FocusScope(
                  node: _contentFocusScopeNode,
                  onKeyEvent: (node, event) {
                    if (event is! KeyDownEvent) return KeyEventResult.ignored;
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      final primary = FocusManager.instance.primaryFocus;
                      if (primary != null && primary.enclosingScope == node) {
                        _focusActiveNavItem();
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.02, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(_activeContentIndex),
                      child: _buildContent(_activeContentIndex),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return FocusScope(
      node: _sidebarFocusScopeNode,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: _isSidebarFocused ? 240 : 72,
        decoration: const BoxDecoration(
          color: Color(0xFF111014),
          border: Border(
            right: BorderSide(color: Color(0x22FFFFFF), width: 1),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              _buildLogo(_isSidebarFocused),
              const SizedBox(height: 24),
              _buildSearchField(_isSidebarFocused),
              const SizedBox(height: 16),
              for (var i = 0; i < _items.length; i++)
                _buildNavItem(i, _isSidebarFocused),
              const Spacer(),
              _buildThemeToggle(_isSidebarFocused),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Bouton bascule Clair/Sombre en bas du sidebar TV.
  Widget _buildThemeToggle(bool expanded) {
    final themeProvider = context.watch<ThemeProvider>();
    final isLight = themeProvider.isLight;
    return Focus(
      focusNode: _themeToggleFocusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowUp) {
          _navNodes[_items.length - 1].requestFocus();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          _searchFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          _contentFocusScopeNode.requestFocus();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.space) {
          themeProvider.toggleTheme();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => themeProvider.toggleTheme(),
        behavior: HitTestBehavior.opaque,
        child: Builder(
          builder: (ctx) {
            final focused = Focus.of(ctx).hasFocus;
            return AnimatedContainer(
              duration: TVConfig.focusAnimationDuration,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? 16 : 0,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: focused ? const Color(0x33E50914) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: focused ? TVTheme.accentRed : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: focused
                    ? [
                        BoxShadow(
                          color: TVTheme.accentRed.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment:
                    expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  Icon(
                    isLight ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    size: 20,
                    color: focused
                        ? Colors.white
                        : (isLight ? TVTheme.accentGold : TVTheme.textSecondary),
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 14),
                    Text(
                      isLight ? 'Thème sombre' : 'Thème clair',
                      style: TextStyle(
                        color: focused ? Colors.white : TVTheme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogo(bool expanded) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 250),
      firstCurve: Curves.easeInOut,
      secondCurve: Curves.easeInOut,
      crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Image.asset(
          'assets/logo.png',
          height: 50,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
      secondChild: Padding(
        padding: const EdgeInsets.all(6),
        child: Image.asset(
          'assets/logo.png',
          height: 36,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildSearchField(bool expanded) {
    return Focus(
      focusNode: _searchFocusNode,
      canRequestFocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowDown) {
          _navNodes[0].requestFocus();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp) {
          _themeToggleFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        // Enter/OK : activer le TextField pour taper
        if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) {
          _searchTextFieldNode.requestFocus();
          return KeyEventResult.handled;
        }
        // Flèche droite : aller dans les résultats (si recherche en cours)
        if (key == LogicalKeyboardKey.arrowRight) {
          if (mounted) _contentFocusScopeNode.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (ctx) {
          final isFocused = Focus.of(ctx).hasFocus;
          return AnimatedContainer(
            duration: TVConfig.focusAnimationDuration,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 12 : 0,
              vertical: expanded ? 4 : 8,
            ),
            decoration: BoxDecoration(
              color: isFocused
                  ? const Color(0xFF1E1C22)
                  : (expanded ? const Color(0xFF151419) : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFocused ? TVTheme.accentRed : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: TVTheme.accentRed.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: isFocused ? Colors.white : TVTheme.textSecondary,
                ),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is! KeyDownEvent) return KeyEventResult.ignored;
                        final key = event.logicalKey;
                        if (key == LogicalKeyboardKey.escape) {
                          _searchTextFieldNode.unfocus();
                          _searchFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                        if (key == LogicalKeyboardKey.arrowDown) {
                          _searchTextFieldNode.unfocus();
                          _navNodes[0].requestFocus();
                          return KeyEventResult.handled;
                        }
                        if (key == LogicalKeyboardKey.arrowUp) {
                          _searchTextFieldNode.unfocus();
                          _themeToggleFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                        if (key == LogicalKeyboardKey.arrowRight) {
                          _searchTextFieldNode.unfocus();
                          if (mounted) _contentFocusScopeNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchTextFieldNode,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Rechercher...',
                          hintStyle: TextStyle(color: TVTheme.textDisabled, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        onSubmitted: (_) {
                          if (_searchQuery.isNotEmpty && mounted) {
                            _searchTextFieldNode.unfocus();
                            _contentFocusScopeNode.requestFocus();
                          }
                        },
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    Focus(
                      child: Builder(
                        builder: (ctx) {
                          final focused = Focus.of(ctx).hasFocus;
                          return InkWell(
                            onTap: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.close_rounded,
                                color: focused ? TVTheme.accentRed : TVTheme.textSecondary,
                                size: 18,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildNavItem(int index, bool expanded) {
    final item = _items[index];
    final selected = index == _index && _searchQuery.isEmpty;
    return Focus(
      focusNode: _navNodes[index],
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowUp) {
          if (index > 0) {
            _navNodes[index - 1].requestFocus();
          } else {
            _searchFocusNode.requestFocus();
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          if (index < _items.length - 1) {
            _navNodes[index + 1].requestFocus();
          } else {
            _themeToggleFocusNode.requestFocus();
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.space) {
          _select(index);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          _select(index);
          if (mounted) _contentFocusScopeNode.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          final highlight = focused || selected;
          return GestureDetector(
            onTap: () => _select(index),
            behavior: HitTestBehavior.opaque,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: TVConfig.focusAnimationDuration,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                padding: EdgeInsets.symmetric(
                  horizontal: expanded ? 16 : 0,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: focused
                      ? const LinearGradient(
                          colors: [TVTheme.accentRed, Color(0xFF7A0A12)],
                        )
                      : null,
                  color: !focused && selected ? const Color(0x22E50914) : null,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected && !focused
                        ? TVTheme.accentRed
                        : (focused ? TVTheme.accentRed : Colors.transparent),
                    width: 1.5,
                  ),
                  boxShadow: focused
                      ? [
                          BoxShadow(
                            color: TVTheme.accentRed.withValues(alpha: 0.4),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.icon,
                      size: 22,
                      color: highlight ? Colors.white : TVTheme.textSecondary,
                    ),
                    if (expanded) ...[
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: highlight ? Colors.white : TVTheme.textSecondary,
                            fontSize: 15,
                            fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
