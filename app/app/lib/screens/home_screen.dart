import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../config/neo.dart';
import '../models/content.dart';
import '../providers/providers.dart';
import '../widgets/content_card.dart';
import '../widgets/hero_banner.dart';
import '../widgets/satisfying_animations.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_loading.dart';
import 'anime_detail_screen.dart';
import 'anime_screen.dart';
import 'browse_screen.dart';
import 'detail_screen.dart';
import 'favorites_screen.dart';
import 'iptv_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final ScrollController _scrollController;
  late final AnimationController _fadeController;
  double _appBarOpacity = 0;
  
  final List<FocusNode> _navFocusNodes = List.generate(6, (_) => FocusNode());
  final FocusNode _settingsFocusNode = FocusNode();
  final List<FocusScopeNode> _tabFocusScopeNodes = List.generate(
    6,
    (i) => FocusScopeNode(debugLabel: 'Tab_$i'),
  );
  final FocusScopeNode _contentFocusScopeNode =
      FocusScopeNode(debugLabel: 'ContentArea');

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

      if (NeoTheme.isTV(context)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && NeoTheme.isTV(context)) {
            _contentFocusScopeNode.requestFocus();
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
    _settingsFocusNode.dispose();
    for (final node in _tabFocusScopeNodes) {
      node.dispose();
    }
    _contentFocusScopeNode.dispose();
    super.dispose();
  }

  void _switchToTab(int index, {bool moveToContent = false}) {
    setState(() => _currentIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Pour l'onglet Recherche (index 4), ne pas donner le focus au contenu automatiquement
      if (moveToContent && index != 4) {
        _contentFocusScopeNode.requestFocus();
      } else {
        _navFocusNodes[index].requestFocus();
      }
    });
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
    final Widget destination = content.contentType == 'anime'
        ? AnimeDetailScreen(animeId: content.id)
        : DetailScreen(contentId: content.id);
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_1, animation, _2) => destination,
        transitionDuration: Duration(milliseconds: 250),
        reverseTransitionDuration: Duration(milliseconds: 200),
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
                begin: Offset(0.05, 0),
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
        return BrowseScreen();
      case 2:
        return AnimeScreen();
      case 3:
        return IptvScreen();
      case 4:
        return SearchScreen();
      case 5:
        return FavoritesScreen();
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
      duration: Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0.03, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_currentIndex),
        child: FocusScope(
          node: _contentFocusScopeNode,
          onKeyEvent: (node, event) {
            if (!NeoTheme.isTV(context)) return KeyEventResult.ignored;
            if (event is! KeyDownEvent) return KeyEventResult.ignored;

            // Escape/Back : retour vers navbar
            if (event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.goBack ||
                event.logicalKey == LogicalKeyboardKey.browserBack) {
              _navFocusNodes[_currentIndex].requestFocus();
              return KeyEventResult.handled;
            }

            return KeyEventResult.ignored;
          },
          child: _buildScreenForIndex(_currentIndex),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Neo.bgBase(context),
      extendBodyBehindAppBar: !isTV,
      body: isTV
          ? Row(
              children: [
                _buildTVNavigationRail(context),
                Expanded(
                  child: ClipRect(child: shellContent),
                ),
              ],
            )
          : Stack(
              children: [
                shellContent,
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 12,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SettingsScreen()),
                      ),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Neo.bgSurface(context).withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Neo.bgBorder(context).withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.settings_rounded,
                          size: 18,
                          color: Neo.textSecondary(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: isTV
          ? null
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: Theme.of(context).brightness == Brightness.light
                      ? [Neo.bgBase(context).withValues(alpha: 0.92), Neo.bgBase(context)]
                      : [Color(0xE00C0C1C), Color(0xF506060C)],
                ),
                border: Border(
                  top: BorderSide(
                    color: Neo.bgBorder(context).withValues(alpha: 0.12),
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
                  selectedItemColor: Theme.of(context).colorScheme.primary,
                  unselectedItemColor: Neo.textDisabled(context),
                  selectedFontSize: 11,
                  unselectedFontSize: 11,
                  selectedLabelStyle: TextStyle(
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
                      Icons.live_tv_outlined,
                      Icons.live_tv,
                      'Direct',
                      3,
                    ),
                    _buildNavItem(
                      Icons.search_rounded,
                      Icons.manage_search_rounded,
                      'Recherche',
                      4,
                    ),
                    _buildNavItem(
                      Icons.favorite_border_rounded,
                      Icons.favorite_rounded,
                      'Favoris',
                      5,
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
            margin: EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(1),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
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
    final isPremium =
        context.select<ContentProvider, bool>((c) => c.isPremium);

    return FocusScope(
      debugLabel: 'NavigationRail',
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Neo.bgSurface(context), Neo.bgBase(context)],
          ),
          border: Border(
            right: BorderSide(
              color: Neo.bgBorder(context).withValues(alpha: 0.12),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 32),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: Neo.heroGradient(context),
                borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Neo.onHeroGradient(context),
                size: 28,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'NEO',
              style: Neo.labelLarge(context).copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildTVNavItem(context, 0, Icons.home_outlined, Icons.home_rounded, 'Accueil'),
                    SizedBox(height: 8),
                    _buildTVNavItem(context, 1, Icons.grid_view_rounded, Icons.grid_view, 'Catalogue'),
                    SizedBox(height: 8),
                    _buildTVNavItem(context, 2, Icons.animation, Icons.animation_outlined, 'Anime'),
                    SizedBox(height: 8),
                    _buildTVNavItem(context, 3, Icons.live_tv_outlined, Icons.live_tv, 'TV Direct'),
                    SizedBox(height: 8),
                    _buildTVNavItem(context, 4, Icons.search_rounded, Icons.manage_search_rounded, 'Recherche'),
                    SizedBox(height: 8),
                    _buildTVNavItem(context, 5, Icons.favorite_border_rounded, Icons.favorite_rounded, 'Favoris'),
                    SizedBox(height: 16),
                    Divider(
                      color: Neo.bgBorder(context).withValues(alpha: 0.1),
                      indent: 20, endIndent: 20,
                    ),
                    SizedBox(height: 8),
                    _buildTVSettingsItem(context, isPremium),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTVNavItem(BuildContext context, int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;

    return Focus(
      focusNode: _navFocusNodes[index],
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          if (index > 0) {
            _navFocusNodes[index - 1].requestFocus();
          } else {
            _settingsFocusNode.requestFocus();
          }
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          if (index < 5) {
            _navFocusNodes[index + 1].requestFocus();
          } else {
            _settingsFocusNode.requestFocus();
          }
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.select) {
          if (_currentIndex != index) {
            _switchToTab(index, moveToContent: true);
          } else {
            _contentFocusScopeNode.requestFocus();
          }
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          if (_currentIndex != index) {
            _switchToTab(index, moveToContent: true);
          } else {
            _contentFocusScopeNode.requestFocus();
          }
          return KeyEventResult.handled;
        }

        // Bloquer flèche gauche uniquement si on est déjà dans la navbar
        // (empêche de sortir de la navbar vers la gauche)
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;

          void handleTap() {
            _switchToTab(index, moveToContent: false);
          }

          return GestureDetector(
            onTap: handleTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedScale(
              scale: isFocused ? 1.02 : 1.0,
              duration: Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                margin: EdgeInsets.symmetric(horizontal: 12),
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: isFocused
                      ? LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                  border: Border.all(
                    color: isFocused
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
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
                          ? Neo.textPrimary(context)
                          : (isSelected ? Theme.of(context).colorScheme.primary : Neo.textDisabled(context)),
                      size: 26,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: Neo.labelLarge(context).copyWith(
                          color: isFocused
                              ? Neo.textPrimary(context)
                              : (isSelected ? Neo.textPrimary(context) : Neo.textDisabled(context)),
                          fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTVSettingsItem(BuildContext context, bool isPremium) {
    return Focus(
      focusNode: _settingsFocusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.select) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()));
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _navFocusNodes[5].requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _navFocusNodes[0].requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _contentFocusScopeNode.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen())),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              margin: EdgeInsets.symmetric(horizontal: 12),
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                gradient: isFocused
                    ? LinearGradient(
                        colors: [
                          Neo.textTertiary(context).withValues(alpha: 0.2),
                          Neo.textTertiary(context).withValues(alpha: 0.1),
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                border: Border.all(
                  color: isFocused ? Neo.textSecondary(context) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.settings_rounded,
                    color: isFocused ? Neo.textPrimary(context) : Neo.textDisabled(context),
                    size: 26,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Parametres',
                      style: Neo.labelLarge(context).copyWith(
                        color: isFocused ? Neo.textPrimary(context) : Neo.textDisabled(context),
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
    final popularAnime = content.popularAnime.take(12).toList();
    final recentAnime = content.recentAnime.take(12).toList();

    if (content.isLoadingHome) {
      return ShimmerHomeLoading();
    }

    if (content.homeError != null) {
      return Center(
        child: Padding(
          padding: NeoTheme.screenPadding(context),
          child: Container(
            padding: EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: Neo.surfaceGradient(context),
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
                SizedBox(height: 18),
                Text(
                  'Erreur de chargement',
                  style: Neo.titleLarge(context),
                ),
                SizedBox(height: 8),
                Text(
                  content.homeError!,
                  style: Neo.bodyMedium(context),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => content.loadHome(),
                  icon: Icon(Icons.refresh_rounded),
                  label: Text('Réessayer'),
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
        top: !NeoTheme.isTV(context),
        child: RefreshIndicator(
          onRefresh: () => content.loadHome(),
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: Neo.bgElevated(context),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              if (!NeoTheme.isTV(context))
                SliverAppBar(
                  floating: true,
                  snap: true,
                elevation: 0,
                backgroundColor: Neo.bgBase(context).withValues(
                  alpha: _appBarOpacity,
                ),
                title: AnimatedOpacity(
                  opacity: _appBarOpacity,
                  duration: NeoTheme.durationFast,
                  child: Row(
                    children: [
                      Text(
                        'NEO',
                        style: Neo.titleLarge(context).copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'STREAM',
                        style: Neo.titleLarge(context).copyWith(
                          color: Neo.textPrimary(context),
                          fontWeight: FontWeight.w300,
                          letterSpacing: 2.8,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: (content.isPremium
                                ? NeoTheme.prestigeGold
                                : Neo.bgBorder(context))
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: (content.isPremium
                                  ? NeoTheme.prestigeGold
                                  : Neo.bgBorder(context))
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
                                : Neo.textSecondary(context),
                          ),
                          SizedBox(width: 6),
                          Text(
                            content.isPremium ? 'Premium' : 'Standard',
                            style: Neo.labelMedium(context).copyWith(
                              color: content.isPremium
                                  ? NeoTheme.prestigeGold
                                  : Neo.textSecondary(context),
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
                  height: 196,
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
              if (popularAnime.isNotEmpty)
                _buildHorizontalSection(
                  'Anime populaires',
                  'Les séries animées les plus complètes sur Neo-Stream.',
                  popularAnime,
                  icon: Icons.animation,
                ),
              if (recentAnime.isNotEmpty)
                _buildHorizontalSection(
                  'Anime récents',
                  'Les derniers anime ajoutés ou mis à jour.',
                  recentAnime,
                  icon: Icons.fiber_new_outlined,
                ),
              SliverToBoxAdapter(child: SizedBox(height: 40)),
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
        'color': Theme.of(context).colorScheme.primary,
      },
      {
        'label': 'Films et series',
        'value': totalFilms > 0 || totalSeries > 0
            ? '$totalFilms films / $totalSeries series'
            : 'Catalogue complet',
        'icon': Icons.movie_filter_outlined,
        'color': Neo.textPrimary(context),
      },
      {
        'label': isPremium ? 'Premium' : 'En ce moment',
        'value': averageRating > 0
            ? 'Note ${averageRating.toStringAsFixed(1)}'
            : '$continueCount en cours',
        'icon': isPremium
            ? Icons.workspace_premium_rounded
            : Icons.local_fire_department_outlined,
        'color': isPremium ? NeoTheme.prestigeGold : Theme.of(context).colorScheme.primary,
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
          separatorBuilder: (_1, _2) => SizedBox(width: 12),
          itemBuilder: (context, index) {
            final card = cards[index];
            return Container(
              width: NeoTheme.isTV(context) ? 238 : 208,
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: Neo.topPanelGradient(context),
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
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          card['label'] as String,
                          style: Neo.labelSmall(context),
                        ),
                        SizedBox(height: 4),
                        Text(
                          card['value'] as String,
                          style: Neo.titleMedium(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).staggeredFade(index: index);
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
          SizedBox(height: 14),
          SizedBox(
            height: (height ?? NeoTheme.cardHeight(context)) + 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: EdgeInsets.fromLTRB(
                NeoTheme.screenPadding(context).left,
                20,
                NeoTheme.screenPadding(context).right + 40,
                20,
              ),
              itemCount: visibleItems.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: ContentCard(
                    content: visibleItems[index],
                    variant: cardVariant,
                    index: index,
                    onTap: () => _navigateToDetail(visibleItems[index]),
                  ),
                ).staggeredFade(index: index);
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
      SliverToBoxAdapter(child: SizedBox(height: 14)),
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
