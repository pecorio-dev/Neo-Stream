import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Système d'animation avancé pour NEO-Stream
/// Fournit des animations cohérentes et spectaculaires pour toute l'application
class AnimationSystem {
  // ============================================================================
  // DURATIONS - Durées d'animation
  // ============================================================================

  static const Duration ultraShort = Duration(milliseconds: 150);
  static const Duration short = Duration(milliseconds: 300);
  static const Duration medium = Duration(milliseconds: 500);
  static const Duration long = Duration(milliseconds: 800);
  static const Duration veryLong = Duration(milliseconds: 1200);

  // ============================================================================
  // CURVES - Courbes d'animation
  // ============================================================================

  static const Curve easeInOutCubic = Cubic(0.645, 0.045, 0.355, 1.0);
  static const Curve easeOutQuint = Cubic(0.23, 1.0, 0.32, 1.0);
  static const Curve easeInQuart = Cubic(0.895, 0.03, 0.685, 0.22);
  static const Curve elasticOut = Cubic(0.68, -0.55, 0.265, 1.55);
  static const Curve bounceOut = Cubic(0.34, 1.56, 0.64, 1.0);

  // Cyber/Neon aesthetic curves
  static const Curve neonPulse = Cubic(0.43, 0.13, 0.23, 0.96);
  static const Curve cyberSlide = Cubic(0.25, 0.46, 0.45, 0.94);
  static const Curve laserFlash = Cubic(0.77, 0, 0.175, 1);

  // ============================================================================
  // ANIMATION BUILDERS
  // ============================================================================

  /// Animation de fade-in simple
  static Animation<double> fadeIn(AnimationController controller) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );
  }

  /// Animation de scale avec rebond
  static Animation<double> scaleWithBounce(AnimationController controller) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: bounceOut),
    );
  }

  /// Animation de slide depuis la gauche
  static Animation<Offset> slideFromLeft(AnimationController controller) {
    return Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: cyberSlide));
  }

  /// Animation de slide depuis la droite
  static Animation<Offset> slideFromRight(AnimationController controller) {
    return Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: cyberSlide));
  }

  /// Animation de slide depuis le haut
  static Animation<Offset> slideFromTop(AnimationController controller) {
    return Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: cyberSlide));
  }

  /// Animation de slide depuis le bas
  static Animation<Offset> slideFromBottom(AnimationController controller) {
    return Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: cyberSlide));
  }

  /// Animation de rotation 360°
  static Animation<double> rotate360(AnimationController controller) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.linear),
    );
  }

  /// Animation de pulsion (scale breathing)
  static Animation<double> pulse(AnimationController controller) {
    return Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: controller, curve: neonPulse),
    );
  }

  /// Animation de shake (tremblement)
  static Animation<double> shake(AnimationController controller) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );
  }

  /// Animation de glow (fluorescence)
  static Animation<double> glow(AnimationController controller) {
    return Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: neonPulse),
    );
  }

  /// Animation combinée: fade + scale
  static Animation<double> fadeAndScale(AnimationController controller) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: easeOutQuint),
    );
  }

  /// Animation staggered pour listes
  static Animation<double> staggeredAnimation(
    AnimationController controller,
    int index,
    int totalItems,
  ) {
    final start = (index / totalItems) * 0.5;
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(start, start + 0.5, curve: easeOutQuint),
      ),
    );
  }
}

/// Classe pour gérer les transitions de page
class PageTransitions {
  /// Transition avec effet de fondu (fade)
  static PageRoute<T> fadeTransition<T>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: duration,
    );
  }

  /// Transition avec slide depuis la droite
  static PageRoute<T> slideRightTransition<T>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 500),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end);
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AnimationSystem.cyberSlide,
        );
        return SlideTransition(
          position: tween.animate(curvedAnimation),
          child: child,
        );
      },
      transitionDuration: duration,
    );
  }

  /// Transition avec scale et fade combinés
  static PageRoute<T> scaleTransition<T>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 500),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;
        final tween = Tween(begin: begin, end: end);
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AnimationSystem.easeOutQuint,
        );

        return ScaleTransition(
          scale: tween.animate(curvedAnimation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      transitionDuration: duration,
    );
  }

  /// Transition avec rotation
  static PageRoute<T> rotateTransition<T>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 600),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;
        final tween = Tween(begin: begin, end: end);
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AnimationSystem.easeInOutCubic,
        );

        return ScaleTransition(
          scale: tween.animate(curvedAnimation),
          child: RotationTransition(
            turns: tween.animate(curvedAnimation),
            child: child,
          ),
        );
      },
      transitionDuration: duration,
    );
  }

  /// Transition spectaculaire: slide + scale + fade
  static PageRoute<T> spectacularTransition<T>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 700),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideTween = Tween<Offset>(
          begin: const Offset(1.0, 0.3),
          end: Offset.zero,
        );
        final scaleTween = Tween<double>(begin: 0.8, end: 1.0);
        final fadeTween = Tween<double>(begin: 0.0, end: 1.0);

        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AnimationSystem.easeOutQuint,
        );

        return SlideTransition(
          position: slideTween.animate(curvedAnimation),
          child: ScaleTransition(
            scale: scaleTween.animate(curvedAnimation),
            child: FadeTransition(
              opacity: fadeTween.animate(curvedAnimation),
              child: child,
            ),
          ),
        );
      },
      transitionDuration: duration,
    );
  }
}

/// Classe pour les effets d'interaction
class InteractionEffects {
  /// Effet de tap avec feedback haptique
  static Future<void> tapEffect(BuildContext context) async {
    HapticFeedback.lightImpact();
  }

  /// Effet de double tap
  static Future<void> doubleTapEffect(BuildContext context) async {
    HapticFeedback.mediumImpact();
  }

  /// Effet de long press
  static Future<void> longPressEffect(BuildContext context) async {
    HapticFeedback.heavyImpact();
  }

  /// Effet de succès
  static Future<void> successEffect(BuildContext context) async {
    HapticFeedback.heavyImpact();
  }

  /// Effet d'erreur
  static Future<void> errorEffect(BuildContext context) async {
    HapticFeedback.vibrate();
  }
}

/// Configuration des animations pour différents types de contenu
class ContentAnimationConfig {
  /// Configuration pour les cartes (movies, series)
  static const cardAnimationDuration = AnimationSystem.medium;
  static const cardAnimationCurve = AnimationSystem.easeOutQuint;

  /// Configuration pour les listes
  static const listItemDuration = AnimationSystem.short;
  static const listItemCurve = AnimationSystem.cyberSlide;

  /// Configuration pour les modales
  static const modalDuration = AnimationSystem.long;
  static const modalCurve = AnimationSystem.bounceOut;

  /// Configuration pour les transitions
  static const transitionDuration = AnimationSystem.medium;
  static const transitionCurve = AnimationSystem.easeInOutCubic;

  /// Configuration pour les micro-interactions
  static const microDuration = AnimationSystem.ultraShort;
  static const microCurve = Curves.easeInOut;

  /// Configuration pour les chargements
  static const loadingDuration = AnimationSystem.veryLong;
  static const loadingCurve = Curves.linear;
}
