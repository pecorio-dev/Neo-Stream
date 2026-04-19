import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/content.dart';
import '../providers/providers.dart';
import '../widgets/content_card.dart';
import '../widgets/hero_banner.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_loading.dart';
import 'anime_screen.dart';
import 'browse_screen.dart';
import 'detail_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final ScrollController _scrollController;
  late final AnimationController _fadeController;
  double _appBarOpacity = 0;
  
  // Focus nodes pour la navigation TV
  final List<FocusNode> _navFocusNodes = List.generate(5, (_) => FocusNode());
  
  // Problem #27: FocusScopeNode par onglet pour navigation précise
  final List<FocusScopeNode> _tabFocusScopeNodes = List.generate(
    5,
    (i) => FocusScopeNode(debugLabel: 'Tab_$i'),
  );
  
  // FocusScopeNode pour la zone de contenu (navigation TV)
  final FocusScopeNode _contentFocusScopeNode = FocusScopeNode(debugLabel: 'ContentArea');

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _fadeController = AnimationController(
      vsync: this,
      duration: NeoTheme.durationSlow,
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContentProvider>().loadHome();
      
      // Problem #1: Home Focus au démarrage - focus auto sur le rail
      if (NeoTheme.isTV(context)) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _navFocusNodes[_currentIndex].requestFocus();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    for (final node in _navFocusNodes) {
      node.dispose();
    }
    // Problem #27 cleanup: dispose tab scope nodes
    for (final node in _tabFocusScopeNodes) {
      node.dispose();
    }
    _contentFocusScopeNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final nextOpacity = (offset / 220).clamp(0.0, 1.0);
    if ((nextOpacity - _appBarOpacity).abs() < 0.03) {
      return;
    }
    setState(() {
      _appBarOpacity = nextOpacity;
    });
  }

  void _navigateToDetail(Content content) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, _) => DetailScreen(contentId: content.id),
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );
  }

  int _gridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 6;
    if (width >= 900) return 5;
    if (width >= 600) return 4;
    return 2;
  }

  double _gridChildAspect(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 0.64;
    if (width >= 900) return 0.62;
    if (width >= 600) return 0.6;
    return 0.62;
  }

  Widget _buildScreenForIndex(int index) {
    switch (index) {
      case 1:
        return const BrowseScreen();
      case 2:
        return const AnimeScreen();
      case 3:
        return const SearchScreen();
      case 4:
        return const ProfileScreen();
      case 0:
      default:
        return _buildHomeContent();
    }
  }

  List<Content> _showcaseItems(ContentProvider content) {
    final items = <Content>[
      ...content.hero,
      ...content.dailyTop,
      ...content.recommended,
      ...content.popularFilms,
      ...content.popularSeries,
      ...content.recentFilms,
      ...content.recentSeries,
    ];

    final seen = <int>{};
    return items.where((item) => seen.add(item.id)).toList();
  }

  double _averageRating(List<Content> items) {
    final rated = items.where((item) => item.rating > 0).toList();
    if (rated.isEmpty) {
      return 0;
    }
    final total = rated.fold<double>(0, (sum, item) => sum + item.rating);
    return total / rated.length;
  }

  @override
  Widget build(BuildContext context) {
    final isTV = NeoTheme.isTV(context);
    final shellContent = AnimatedSwitcher(
      duration: NeoTheme.durationNormal,
      switchInCurve: NeoTheme.smoothOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey<int>(_currentIndex),
        child: _buildScreenForIndex(_currentIndex),
      ),
    );

    return Scaffold(
      backgroundColor: NeoTheme.bgBase,
      extendBodyBehindAppBar: !isTV,
      body: isTV
          ? Row(
              children: [
                _buildTVNavigationRail(context),
                Expanded(
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      
                      // Flèche gauche: retourner au rail sur l'onglet actuel
                      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                        // Donner le focus à l'item actuel du rail
                        _navFocusNodes[_currentIndex].requestFocus();
                        return KeyEventResult.handled;
                      }
                      
                      // Tab: navigation circulaire
                      if (event.logicalKey == LogicalKeyboardKey.tab) {
                        // Si Shift+Tab, aller au rail, sinon rester dans le contenu
                        final isShift = HardwareKeyboard.instance.isShiftPressed;
                        if (isShift) {
                          _navFocusNodes[_currentIndex].requestFocus();
                          return KeyEventResult.handled;
                        }
                      }
                      
                      // Touches numériques 1-5: changer d'onglet et garder focus dans sidebar
                      if (event.logicalKey == LogicalKeyboardKey.digit1 ||
                          event.logicalKey == LogicalKeyboardKey.numpad1) {
                        if (_currentIndex != 0) {
                          setState(() => _currentIndex = 0);
                        }
                        _navFocusNodes[0].requestFocus();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.digit2 ||
                          event.logicalKey == LogicalKeyboardKey.numpad2) {
                        if (_currentIndex != 1) {
                          setState(() => _currentIndex = 1);
                        }
                        _navFocusNodes[1].requestFocus();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.digit3 ||
                          event.logicalKey == LogicalKeyboardKey.numpad3) {
                        if (_currentIndex != 2) {
                          setState(() => _currentIndex = 2);
                        }
                        _navFocusNodes[2].requestFocus();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.digit4 ||
                          event.logicalKey == LogicalKeyboardKey.numpad4) {
                        if (_currentIndex != 3) {
                          setState(() => _currentIndex = 3);
                        }
                        _navFocusNodes[3].requestFocus();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.digit5 ||
                          event.logicalKey == LogicalKeyboardKey.numpad5) {
                        if (_currentIndex != 4) {
                          setState(() => _currentIndex = 4);
                        }
                        _navFocusNodes[4].requestFocus();
                        return KeyEventResult.handled;
                      }
                      
                      return KeyEventResult.ignored;
                    },
                    child: FocusScope(
                      node: _contentFocusScopeNode,
                      canRequestFocus: true,
                      child: ClipRect(
                        child: shellContent,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : shellContent,
      bottomNavigationBar: isTV
          ? null
          : Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xE00C0C1C), Color(0xF506060C)],
                ),
                border: Border(
                  top: BorderSide(
                    color: NeoTheme.bgBorder.withValues(alpha: 0.12),
                    width: 0.5,
                  ),
                ),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    if (index != _currentIndex) {
                      setState(() => _currentIndex = index);
                    }
                  },
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedItemColor: NeoTheme.primaryRed,
                  unselectedItemColor: NeoTheme.textDisabled,
                  selectedFontSize: 11,
                  unselectedFontSize: 11,
                  selectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                  items: [
                    _buildNavItem(
                      Icons.home_outlined,
                      Icons.home_rounded,
                      'Accueil',
                      0,
                    ),
                    _buildNavItem(
                      Icons.grid_view_rounded,
                      Icons.grid_view,
                      'Catalogue',
                      1,
                    ),
                    _buildNavItem(
                      Icons.animation,
                      Icons.animation_outlined,
                      'Anime',
                      2,
                    ),
                    _buildNavItem(
                      Icons.search_rounded,
                      Icons.manage_search_rounded,
                      'Recherche',
                      3,
                    ),
                    _buildNavItem(
                      Icons.person_outline_rounded,
                      Icons.person_rounded,
                      'Profil',
                      4,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
    IconData icon,
    IconData activeIcon,
    String label,
    int index,
  ) {
    final isSelected = _currentIndex == index;
    return BottomNavigationBarItem(
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: NeoTheme.durationFast,
            curve: NeoTheme.smoothOut,
            width: isSelected ? 24 : 0,
            height: 2,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: NeoTheme.primaryRed,
              borderRadius: BorderRadius.circular(1),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: NeoTheme.primaryRed.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
          Icon(isSelected ? activeIcon : icon, size: isSelected ? 24 : 22),
        ],
      ),
      label: label,
    );
  }

  Widget _buildTVNavigationRail(BuildContext context) {
    final content = context.watch<ContentProvider>();

    // Problem #26: Rail dalam FocusScope dengan autofocus pada indeks 0
    return FocusScope(
      autofocus: true,
      debugLabel: 'NavigationRail',
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E0E20), Color(0xFF08081A)],
          ),
          border: Border(
            right: BorderSide(
              color: NeoTheme.bgBorder.withValues(alpha: 0.12),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          const SizedBox(height: 32),
          // Logo
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: NeoTheme.heroGradient,
              borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: NeoTheme.primaryRed.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'NEO',
            style: NeoTheme.labelLarge(context).copyWith(
              color: NeoTheme.primaryRed,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          Text(
            'STREAM',
            style: NeoTheme.labelSmall(context).copyWith(
              color: NeoTheme.textPrimary.withValues(alpha: 0.7),
              letterSpacing: 2,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 48),
          // Nav Items
          _buildTVNavItem(context, 0, Icons.home_outlined, Icons.home_rounded, 'Accueil'),
          const SizedBox(height: 12),
          _buildTVNavItem(context, 1, Icons.grid_view_rounded, Icons.grid_view, 'Catalogue'),
          const SizedBox(height: 12),
          _buildTVNavItem(context, 2, Icons.animation, Icons.animation_outlined, 'Anime'),
          const SizedBox(height: 12),
          _buildTVNavItem(context, 3, Icons.search_rounded, Icons.manage_search_rounded, 'Recherche'),
          const SizedBox(height: 12),
          _buildTVNavItem(context, 4, Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
          const Spacer(),
          // Premium Badge
          Container(
            width: 180,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            margin: const EdgeInsets.only(bottom: 32),
            decoration: BoxDecoration(
              color: (content.isPremium ? NeoTheme.prestigeGold : NeoTheme.infoCyan)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
              border: Border.all(
                color: (content.isPremium ? NeoTheme.prestigeGold : NeoTheme.infoCyan)
                    .withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  content.isPremium
                      ? Icons.workspace_premium_rounded
                      : Icons.verified_user_outlined,
                  size: 18,
                  color: content.isPremium
                      ? NeoTheme.prestigeGold
                      : NeoTheme.infoCyan,
                ),
                const SizedBox(width: 8),
                Text(
                  content.isPremium ? 'Premium' : 'Standard',
                  textAlign: TextAlign.center,
                  style: NeoTheme.labelSmall(context).copyWith(
                    color: content.isPremium
                        ? NeoTheme.prestigeGold
                        : NeoTheme.infoCyan,
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

  Widget _buildTVNavItem(BuildContext context, int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    
    return Focus(
      focusNode: _navFocusNodes[index],
      autofocus: index == 0 && NeoTheme.needsFocusNavigation(context),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        
        // Haut/Bas: Navigation circulaire entre items
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          if (index > 0) {
            _navFocusNodes[index - 1].requestFocus();
          } else {
            // Navigation circulaire: premier -> dernier
            _navFocusNodes[4].requestFocus();
          }
          return KeyEventResult.handled;
        }
        
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          if (index < 4) {
            _navFocusNodes[index + 1].requestFocus();
          } else {
            // Navigation circulaire: dernier -> premier
            _navFocusNodes[0].requestFocus();
          }
          return KeyEventResult.handled;
        }
        
        // Touches numériques 1-5 pour accès direct
        if (event.logicalKey == LogicalKeyboardKey.digit1 ||
            event.logicalKey == LogicalKeyboardKey.numpad1) {
          if (_currentIndex != 0) {
            setState(() => _currentIndex = 0);
          }
          _navFocusNodes[0].requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.digit2 ||
            event.logicalKey == LogicalKeyboardKey.numpad2) {
          if (_currentIndex != 1) {
            setState(() => _currentIndex = 1);
          }
          _navFocusNodes[1].requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.digit3 ||
            event.logicalKey == LogicalKeyboardKey.numpad3) {
          if (_currentIndex != 2) {
            setState(() => _currentIndex = 2);
          }
          _navFocusNodes[2].requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.digit4 ||
            event.logicalKey == LogicalKeyboardKey.numpad4) {
          if (_currentIndex != 3) {
            setState(() => _currentIndex = 3);
          }
          _navFocusNodes[3].requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.digit5 ||
            event.logicalKey == LogicalKeyboardKey.numpad5) {
          if (_currentIndex != 4) {
            setState(() => _currentIndex = 4);
          }
          _navFocusNodes[4].requestFocus();
          return KeyEventResult.handled;
        }
        
        // Enter/OK: Changer d'onglet et RESTER dans la sidebar
        if (event.logicalKey == LogicalKeyboardKey.enter || 
            event.logicalKey == LogicalKeyboardKey.select) {
          if (_currentIndex != index) {
            setState(() => _currentIndex = index);
          }
          // Toujours garder le focus sur l'item actuel
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _navFocusNodes[index].requestFocus();
            }
          });
          return KeyEventResult.handled;
        }
        
        // Droite: Changer d'onglet ET aller au contenu
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          if (_currentIndex != index) {
            setState(() => _currentIndex = index);
          }
          // Aller au contenu
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _contentFocusScopeNode.requestFocus();
          });
          return KeyEventResult.handled;
        }
        
        // Gauche: Rester dans la sidebar
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          return KeyEventResult.handled;
        }
        
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          
          // Fonction pour gérer le clic/tap
          void handleTap() {
            // Donner le focus à cet item
            _navFocusNodes[index].requestFocus();
            // Changer d'onglet si nécessaire
            if (_currentIndex != index) {
              setState(() => _currentIndex = index);
            }
          }
          
          return GestureDetector(
            onTap: handleTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: NeoTheme.durationFast,
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                gradient: isFocused
                    ? LinearGradient(
                        colors: [
                          NeoTheme.primaryRed.withValues(alpha: 0.25),
                          NeoTheme.primaryRed.withValues(alpha: 0.15),
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                border: Border.all(
                  color: isFocused
                      ? NeoTheme.primaryRed
                      : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: NeoTheme.primaryRed.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: isFocused 
                        ? Colors.white 
                        : (isSelected ? NeoTheme.primaryRed : NeoTheme.textDisabled),
                    size: 26,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: NeoTheme.labelLarge(context).copyWith(
                        color: isFocused 
                            ? Colors.white 
                            : (isSelected ? NeoTheme.textPrimary : NeoTheme.textDisabled),
                        fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeContent() {
    final content = context.watch<ContentProvider>();
    final showcaseItems = _showcaseItems(content);
    final averageRating = _averageRating(showcaseItems);
    final spotlightAdditions = content.addedToday.take(6).toList();
    final recommendedItems = content.recommended.take(10).toList();
    final popularFilms = content.popularFilms.take(12).toList();
    final popularSeries = content.popularSeries.take(12).toList();

    if (content.isLoadingHome) {
      return const ShimmerHomeLoading();
    }

    if (content.homeError != null) {
      return Center(
        child: Padding(
          padding: NeoTheme.screenPadding(context),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: NeoTheme.surfaceGradient,
              borderRadius: BorderRadius.circular(NeoTheme.radiusXl),
              border: Border.all(
                color: NeoTheme.errorRed.withValues(alpha: 0.15),
                width: 0.5,
              ),
              boxShadow: NeoTheme.shadowLevel2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 64,
                  color: NeoTheme.errorRed.withValues(alpha: 0.78),
                ),
                const SizedBox(height: 18),
                Text(
                  'Erreur de chargement',
                  style: NeoTheme.titleLarge(context),
                ),
                const SizedBox(height: 8),
                Text(
                  content.homeError!,
                  style: NeoTheme.bodyMedium(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => content.loadHome(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeController,
      child: SafeArea(
        top: !NeoTheme.isTV(
          context,
        ), // Let TV go full screen behind the transparent app bar
        child: RefreshIndicator(
          onRefresh: () => content.loadHome(),
          color: NeoTheme.primaryRed,
          backgroundColor: NeoTheme.bgElevated,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              if (!NeoTheme.isTV(context))
                SliverAppBar(
                  floating: true,
                  snap: true,
                elevation: 0,
                backgroundColor: NeoTheme.bgBase.withValues(
                  alpha: _appBarOpacity,
                ),
                title: AnimatedOpacity(
                  opacity: _appBarOpacity,
                  duration: NeoTheme.durationFast,
                  child: Row(
                    children: [
                      Text(
                        'NEO',
                        style: NeoTheme.titleLarge(context).copyWith(
                          color: NeoTheme.primaryRed,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'STREAM',
                        style: NeoTheme.titleLarge(context).copyWith(
                          color: NeoTheme.textPrimary,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 2.8,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: (content.isPremium
                                ? NeoTheme.prestigeGold
                                : NeoTheme.bgBorder)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: (content.isPremium
                                  ? NeoTheme.prestigeGold
                                  : NeoTheme.bgBorder)
                              .withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            content.isPremium
                                ? Icons.workspace_premium_rounded
                                : Icons.lock_open_rounded,
                            size: 16,
                            color: content.isPremium
                                ? NeoTheme.prestigeGold
                                : NeoTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            content.isPremium ? 'Premium' : 'Standard',
                            style: NeoTheme.labelMedium(context).copyWith(
                              color: content.isPremium
                                  ? NeoTheme.prestigeGold
                                  : NeoTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (content.hero.isNotEmpty)
                SliverToBoxAdapter(
                  child: Focus(
                    autofocus: false,
                    child: HeroBanner(
                      items: content.hero,
                      onTap: _navigateToDetail,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: _buildOverviewRail(
                  totalAvailable: content.totalAvailable,
                  isPremium: content.isPremium,
                  continueCount: content.continueWatching.length,
                  totalFilms: content.totalFilms,
                  totalSeries: content.totalSeries,
                  averageRating: averageRating,
                ),
              ),
              if (content.continueWatching.isNotEmpty)
                _buildHorizontalSection(
                  'Continuer à regarder',
                  'Reprenez exactement où vous vous êtes arrêté.',
                  content.continueWatching,
                  cardVariant: CardVariant.continueWatching,
                  height: 150,
                  icon: Icons.play_circle_outline_rounded,
                ),
              if (content.dailyTop.isNotEmpty)
                _buildHorizontalSection(
                  'Top 10 du jour',
                  'Les contenus qui font le plus parler aujourd\'hui.',
                  content.dailyTop,
                  cardVariant: CardVariant.dailyTop,
                  height: NeoTheme.cardHeight(context) + 28,
                  icon: Icons.local_fire_department_outlined,
                ),
              if (recommendedItems.isNotEmpty)
                _buildHorizontalSection(
                  'Notre selection',
                  'Des choix simples et pertinents pour lancer vite.',
                  recommendedItems,
                  cardVariant: CardVariant.recommendation,
                  icon: Icons.auto_awesome_outlined,
                ),
              if (spotlightAdditions.isNotEmpty)
                ..._buildGridSlivers(
                  'Nouveautés',
                  'Les derniers ajouts mis en avant sur Neo-Stream.',
                  spotlightAdditions,
                  icon: Icons.fiber_new_outlined,
                ),
              if (popularFilms.isNotEmpty)
                _buildHorizontalSection(
                  'Films populaires',
                  'Une sélection cinéma claire et immédiate.',
                  popularFilms,
                  icon: Icons.movie_filter_outlined,
                ),
              if (popularSeries.isNotEmpty)
                _buildHorizontalSection(
                  'Séries tendance',
                  'Les séries qui méritent un vrai coup d\'œil.',
                  popularSeries,
                  icon: Icons.tv_outlined,
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ), // Reduced from 110 for TV
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewRail({
    required int totalAvailable,
    required bool isPremium,
    required int continueCount,
    required int totalFilms,
    required int totalSeries,
    required double averageRating,
  }) {
    final cards = [
      {
        'label': 'Catalogue',
        'value': totalAvailable > 0
            ? '$totalAvailable titres'
            : 'Toujours a jour',
        'icon': Icons.grid_view_rounded,
        'color': NeoTheme.primaryRed,
      },
      {
        'label': 'Films et series',
        'value': totalFilms > 0 || totalSeries > 0
            ? '$totalFilms films / $totalSeries series'
            : 'Catalogue complet',
        'icon': Icons.movie_filter_outlined,
        'color': NeoTheme.textPrimary, // Changed to white for 2-color scheme
      },
      {
        'label': isPremium ? 'Premium' : 'En ce moment',
        'value': averageRating > 0
            ? 'Note ${averageRating.toStringAsFixed(1)}'
            : '$continueCount en cours',
        'icon': isPremium
            ? Icons.workspace_premium_rounded
            : Icons.local_fire_department_outlined,
        'color': isPremium
            ? NeoTheme.prestigeGold
            : NeoTheme
                  .primaryRed, // Changed to red for 2-color scheme (except premium gold)
      },
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        NeoTheme.screenPadding(context).left,
        16,
        NeoTheme.screenPadding(context).right,
        0,
      ),
      child: SizedBox(
        height: 88,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final card = cards[index];
            return Container(
              width: NeoTheme.isTV(context) ? 238 : 208,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: NeoTheme.surfaceGradient,
                borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                border: Border.all(
                  color: (card['color'] as Color).withValues(alpha: 0.12),
                  width: 0.5,
                ),
                boxShadow: NeoTheme.shadowLevel1,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (card['color'] as Color).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                    ),
                    child: Icon(
                      card['icon'] as IconData,
                      color: card['color'] as Color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          card['label'] as String,
                          style: NeoTheme.labelSmall(context),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          card['value'] as String,
                          style: NeoTheme.titleMedium(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildHorizontalSection(
    String title,
    String subtitle,
    List<Content> items, {
    required IconData icon,
    CardVariant cardVariant = CardVariant.standard,
    double? height,
  }) {
    final visibleItems = items.take(12).toList();

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: NeoTheme.sectionGap(context)),
          SectionHeader(title: title, subtitle: subtitle, icon: icon),
          const SizedBox(height: 14),
          SizedBox(
            height: (height ?? NeoTheme.cardHeight(context)) + 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: EdgeInsets.fromLTRB(
                NeoTheme.screenPadding(context).left,
                20,
                NeoTheme.screenPadding(context).right + 40, // Problem #68: Ajouter padding à droite
                20,
              ),
              itemCount: visibleItems.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: ContentCard(
                    content: visibleItems[index],
                    variant: cardVariant,
                    index: index,
                    onTap: () => _navigateToDetail(visibleItems[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGridSlivers(
    String title,
    String subtitle,
    List<Content> items, {
    required IconData icon,
  }) {
    final visibleItems = items.take(6).toList();

    return [
      SliverToBoxAdapter(child: SizedBox(height: NeoTheme.sectionGap(context))),
      SliverToBoxAdapter(
        child: SectionHeader(title: title, subtitle: subtitle, icon: icon),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 14)),
      SliverPadding(
        padding: NeoTheme.screenPadding(context),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _gridColumns(context),
            childAspectRatio: _gridChildAspect(context),
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => ContentCard(
              content: visibleItems[index],
              variant: CardVariant.standard,
              index: index,
              onTap: () => _navigateToDetail(visibleItems[index]),
            ),
            childCount: visibleItems.length,
          ),
        ),
      ),
    ];
  }
}
