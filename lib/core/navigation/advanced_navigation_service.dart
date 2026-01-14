import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tv/tv_navigation_service.dart';

/// Service avancé de navigation avec gestion des routes et état
class AdvancedNavigationService {
  static final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  static final List<Route<dynamic>> _routeStack = [];
  
  static GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  /// Navigation vers un nouvel écran avec animation personnalisée
  static Future pushWithAnimation(
    BuildContext context,
    Widget screen, {
    bool isTVMode = false,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Navigator.of(context).push(_createPageRoute(screen, isTVMode, duration));
  }

  /// Navigation vers un nouvel écran avec remplacement et animation personnalisée
  static Future pushReplacementWithAnimation(
    BuildContext context,
    Widget screen, {
    bool isTVMode = false,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Navigator.of(context).pushReplacement(_createPageRoute(screen, isTVMode, duration));
  }

  /// Création d'une route personnalisée selon le mode (TV ou mobile)
  static Route _createPageRoute(
    Widget screen,
    bool isTVMode,
    Duration duration,
  ) {
    if (isTVMode) {
      // Pour le mode TV: animation de fondu
      return PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return FadeTransition(
            opacity: curvedAnimation,
            child: child,
          );
        },
        transitionDuration: duration,
      );
    } else {
      // Pour le mode mobile: animation de glissement
      return PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          );
        },
        transitionDuration: duration,
      );
    }
  }

  /// Navigation vers un écran avec gestion des erreurs
  static Future<void> navigateSafely<T extends Object?>(
    BuildContext context,
    Widget screen, {
    bool isTVMode = false,
    String? errorMessage,
    Duration duration = const Duration(milliseconds: 300),
  }) async {
    try {
      await pushWithAnimation(
        context,
        screen,
        isTVMode: isTVMode,
        duration: duration,
      );
    } catch (e) {
      debugPrint('Navigation error: $e');
      if (errorMessage != null && context.mounted) {
        _showErrorDialog(context, errorMessage);
      }
    }
  }

  /// Navigation vers un écran nommé avec gestion des erreurs
  static Future<void> navigateToNamedSafely<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
    String? errorMessage,
  }) async {
    try {
      Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
    } catch (e) {
      debugPrint('Navigation error: $e');
      if (errorMessage != null && context.mounted) {
        _showErrorDialog(context, errorMessage);
      }
    }
  }

  /// Afficher une boîte de dialogue d'erreur
  static Future<void> _showErrorDialog(BuildContext context, String message) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Erreur'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Naviguer vers le premier écran de l'application
  static void goToFirstScreen(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Naviguer vers le précédent écran ou quitter si c'est le dernier
  static void goBackOrExit(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // Ici on pourrait appeler SystemNavigator.pop() sur Android
      // ou une fonction de fermeture personnalisée
    }
  }

  /// Vérifier si l'utilisateur est sur l'écran d'accueil
  static bool isOnHomeScreen(BuildContext context) {
    return Navigator.of(context).canPop() == false;
  }
}

/// Widget pour la navigation avec raccourcis clavier
class KeyboardNavigationWrapper extends StatelessWidget {
  final Widget child;
  final Map<LogicalKeySet, Intent>? shortcuts;
  final Map<Type, Action<Intent>>? actions;

  const KeyboardNavigationWrapper({
    Key? key,
    required this.child,
    this.shortcuts,
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Utiliser les raccourcis par défaut si none sont fournis
    final effectiveShortcuts = shortcuts ?? _getDefaultShortcuts();
    final effectiveActions = actions ?? _getDefaultActions(context);

    return Shortcuts(
      shortcuts: effectiveShortcuts,
      child: Actions(
        actions: effectiveActions,
        child: child,
      ),
    );
  }

  Map<LogicalKeySet, Intent> _getDefaultShortcuts() {
    return {
      ...TVNavigationService.getTVShortcuts(),
      // Raccourcis supplémentaires pour les deux modes
      LogicalKeySet(LogicalKeyboardKey.tab): const DirectionalFocusIntent(TraversalDirection.down),
      LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.tab): const DirectionalFocusIntent(TraversalDirection.up),
    };
  }

  Map<Type, Action<Intent>> _getDefaultActions(BuildContext context) {
    return {
      ...TVNavigationService.getTVActions(context),
      // Actions supplémentaires
      DirectionalFocusIntent: DirectionalFocusAction(),
    };
  }
}

/// Action personnalisée pour la navigation directionnelle
class DirectionalFocusAction extends Action<DirectionalFocusIntent> {
  @override
  Object? invoke(DirectionalFocusIntent intent) {
    // Pour l'instant, on ne fait rien dans cette action pour éviter les erreurs
    // Elle peut être implémentée plus tard avec une logique appropriée
    return null;
  }
}

/// Intent pour la navigation directionnelle
class DirectionalFocusIntent extends Intent {
  final TraversalDirection direction;

  const DirectionalFocusIntent(this.direction);
}