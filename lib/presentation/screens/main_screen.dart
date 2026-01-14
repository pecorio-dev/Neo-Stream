import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/platform_service.dart';
import '../../main.dart';
import '../widgets/tv_mode_indicator.dart';
import '../widgets/sidebar_navigation.dart';
import '../screens/movies_screen.dart';
import '../screens/search_screen.dart';
import '../screens/series_screen.dart';
import '../screens/favorites/favorites_screen.dart';
import '../screens/settings/settings_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // TV Navigation
  bool _isOnNavigationBar = false;

  final List<Widget> _screens = [
    const MoviesScreen(),
    const SearchScreen(),
    const SeriesScreen(),
    const FavoritesScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (PlatformService.isTVMode) {
      child = Scaffold(
        body: Row(
          children: [
            SidebarNavigation(
              currentIndex: _currentIndex,
              onTabTapped: _onTabTapped,
            ),
            Expanded(
              child: Stack(
                children: [
                  FadeTransition(
                    opacity: _animation,
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() => _currentIndex = index);
                      },
                      children: _screens,
                    ),
                  ),
                  const TVModeIndicator(),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      child = Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.backgroundPrimary,
          elevation: 0,
          title: const Text(
            'Neo Stream',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [],
        ),
        body: Stack(
          children: [
            FadeTransition(
              opacity: _animation,
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                children: _screens,
              ),
            ),
            const TVModeIndicator(),
          ],
        ),
        bottomNavigationBar: _buildMobileBottomNavBar(),
      );
    }

    if (PlatformService.isTVMode) {
      child = Shortcuts(
        shortcuts: {
          ...PlatformService.getTVShortcuts(),
        },
        child: Actions(
          actions: {
            ...PlatformService.getTVActions(context),
          },
          child: child,
        ),
      );
    }

    return child;
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _handleBackNavigation() {
    if (!_isOnNavigationBar) {
      setState(() {
        _isOnNavigationBar = true;
      });
      HapticFeedback.selectionClick();
    } else {
      Navigator.pushNamed(context, '/profile-selection');
    }
  }

  Widget _buildMobileBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF00D4FF).withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00D4FF),
        unselectedItemColor: const Color(0xFF808080),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.movie), label: 'Films'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Recherche'),
          BottomNavigationBarItem(icon: Icon(Icons.tv), label: 'Séries'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favoris'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Paramètres'),
        ],
      ),
    );
  }
}
