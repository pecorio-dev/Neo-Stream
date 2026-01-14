import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tv/tv_navigation_service.dart';

/// Service centralisé pour la navigation entre écrans
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  /// Navigateur actuel
  static NavigatorState? get navigator => navigatorKey.currentState;

  /// Navigation vers un nouvel écran
  static Future<T?> push<T extends Object?>(
    BuildContext context,
    Widget screen, {
    bool maintainState = true,
    bool fullscreenDialog = false,
    bool allowReturn = true,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<T>(
        builder: (context) => screen,
        maintainState: maintainState,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  /// Navigation vers un nouvel écran avec remplacement
  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    BuildContext context,
    Widget screen, {
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) {
    return Navigator.of(context).pushReplacement(
      MaterialPageRoute<T>(
        builder: (context) => screen,
        maintainState: maintainState,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  /// Navigation vers un nouvel écran nommé
  static Future<T?> pushNamed<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
  }

  /// Navigation vers un écran nommé avec remplacement
  static Future pushReplacementNamed(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushReplacementNamed(
      routeName,
      arguments: arguments,
    );
  }

  /// Fermer l'écran actuel
  static bool pop<T extends Object?>(
    BuildContext context, [
    T? result,
  ]) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
      return true;
    }
    return false;
  }

  /// Vérifie si l'écran peut être fermé
  static bool canPop(BuildContext context) {
    return Navigator.of(context).canPop();
  }
}

/// Extension pour une utilisation plus fluide
extension NavigationExtension on BuildContext {
  /// Naviguer vers un nouvel écran
  Future<T?> navigateTo<T extends Object?>(
    Widget screen, {
    bool maintainState = true,
    bool fullscreenDialog = false,
    bool allowReturn = true,
  }) {
    return NavigationService.push<T>(
      this,
      screen,
      maintainState: maintainState,
      fullscreenDialog: fullscreenDialog,
      allowReturn: allowReturn,
    );
  }

  /// Naviguer vers un nouvel écran avec remplacement
  Future<T?> replaceWith<T extends Object?, TO extends Object?>(
    Widget screen, {
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) {
    return NavigationService.pushReplacement<T, TO>(
      this,
      screen,
      maintainState: maintainState,
      fullscreenDialog: fullscreenDialog,
    );
  }

  /// Naviguer vers un écran nommé
  Future<T?> navigateToNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    return NavigationService.pushNamed<T>(this, routeName, arguments: arguments);
  }

  /// Naviguer vers un écran nommé avec remplacement
  Future replaceWithNamed(
    String routeName, {
    Object? arguments,
  }) {
    return NavigationService.pushReplacementNamed(
      this,
      routeName,
      arguments: arguments,
    );
  }

  /// Fermer l'écran actuel
  bool goBack<T extends Object?>([T? result]) {
    return NavigationService.pop<T>(this, result);
  }

  /// Vérifier si l'écran peut être fermé
  bool canGoBack() {
    return NavigationService.canPop(this);
  }
}

/// Widget pour encapsuler la navigation avec prise en charge TV
class TVSafeNavigator extends StatefulWidget {
  final Widget child;
  final bool enableTVNavigation;
  final List<String> tvInstructions;

  const TVSafeNavigator({
    Key? key,
    required this.child,
    this.enableTVNavigation = true,
    this.tvInstructions = const [],
  }) : super(key: key);

  @override
  State<TVSafeNavigator> createState() => _TVSafeNavigatorState();
}

class _TVSafeNavigatorState extends State<TVSafeNavigator> {
  @override
  Widget build(BuildContext context) {
    Widget navigator = widget.child;

    // Ajouter les raccourcis TV si activés
    if (widget.enableTVNavigation) {
      navigator = Shortcuts(
        shortcuts: TVNavigationService.getTVShortcuts(),
        child: Actions(
          actions: TVNavigationService.getTVActions(context),
          child: navigator,
        ),
      );
    }

    // Ajouter les instructions TV si fournies
    if (widget.tvInstructions.isNotEmpty) {
      navigator = Stack(
        children: [
          navigator,
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                ),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: widget.tvInstructions.map((instruction) {
                  final parts = instruction.split(':');
                  if (parts.length == 2) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            parts[0].trim(),
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          parts[1].trim(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    );
                  }
                  return Text(
                    instruction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      );
    }

    return navigator;
  }
}

/// Wrapper pour la navigation avec des transitions animées
class AnimatedNavigationWrapper extends StatelessWidget {
  final Widget child;
  final bool isTVMode;
  final Duration duration;

  const AnimatedNavigationWrapper({
    Key? key,
    required this.child,
    this.isTVMode = false,
    this.duration = const Duration(milliseconds: 300),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) {
        if (isTVMode) {
          // Pour TV: transition simple
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        } else {
          // Pour mobile: transition slide
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        }
      },
      child: KeyedSubtree(
        key: ValueKey(child.hashCode),
        child: child,
      ),
    );
  }
}