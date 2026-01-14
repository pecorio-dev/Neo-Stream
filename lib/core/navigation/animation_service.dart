import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../../data/services/platform_service.dart';

/// Service pour les animations et transitions améliorées
class AnimationService {
  /// Durée standard pour les animations
  static const Duration standardDuration = Duration(milliseconds: 300);
  
  /// Durée longue pour les animations
  static const Duration longDuration = Duration(milliseconds: 500);
  
  /// Durée courte pour les animations
  static const Duration shortDuration = Duration(milliseconds: 150);

  /// Courbe d'animation standard
  static const Curve standardCurve = Curves.easeInOut;

  /// Courbe d'animation pour les entrées
  static const Curve enterCurve = Curves.easeOut;

  /// Courbe d'animation pour les sorties
  static const Curve exitCurve = Curves.easeIn;

  /// Créer une animation de fondu
  static Widget fadeAnimation({
    required Widget child,
    Duration duration = standardDuration,
    Curve curve = standardCurve,
    AnimationController? controller,
  }) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: curve),
          child: child,
        );
      },
      child: KeyedSubtree(key: ValueKey(child.hashCode), child: child),
    );
  }

  /// Créer une animation de glissement
  static Widget slideAnimation({
    required Widget child,
    Duration duration = standardDuration,
    Curve curve = standardCurve,
    Offset begin = const Offset(1, 0),
    Offset end = Offset.zero,
  }) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) {
        final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);
        return SlideTransition(
          position: Tween<Offset>(begin: begin, end: end).animate(curvedAnimation),
          child: child,
        );
      },
      child: KeyedSubtree(key: ValueKey(child.hashCode), child: child),
    );
  }

  /// Créer une animation d'échelle
  static Widget scaleAnimation({
    required Widget child,
    Duration duration = standardDuration,
    Curve curve = standardCurve,
    double begin = 0.8,
    double end = 1.0,
  }) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) {
        final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);
        return ScaleTransition(
          scale: Tween<double>(begin: begin, end: end).animate(curvedAnimation),
          child: child,
        );
      },
      child: KeyedSubtree(key: ValueKey(child.hashCode), child: child),
    );
  }

  /// Créer une animation combinée (glissement + fondu)
  static Widget combinedAnimation({
    required Widget child,
    Duration duration = standardDuration,
    Curve curve = standardCurve,
  }) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) {
        final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.1, 0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(child.hashCode), child: child),
    );
  }
}

/// Widget pour une page avec animation personnalisée
class AnimatedPageWrapper extends StatelessWidget {
  final Widget child;
  final bool isTVMode;
  final Duration duration;
  final Curve curve;

  const AnimatedPageWrapper({
    Key? key,
    required this.child,
    this.isTVMode = false,
    this.duration = AnimationService.standardDuration,
    this.curve = AnimationService.standardCurve,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Pour TV, on utilise une animation de fondu
    if (isTVMode || PlatformService.isTVMode) {
      return FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: AlwaysStoppedAnimation(1), curve: curve),
        ),
        child: child,
      );
    } else {
      // Pour mobile, on utilise une animation de glissement
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: AlwaysStoppedAnimation(1), curve: curve),
        ),
        child: child,
      );
    }
  }
}

/// Widget pour une liste animée
class AnimatedListWrapper extends StatelessWidget {
  final List<Widget> children;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;
  final bool isTVMode;
  final Duration itemAnimationDuration;
  final Curve itemAnimationCurve;

  const AnimatedListWrapper({
    Key? key,
    required this.children,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.isTVMode = false,
    this.itemAnimationDuration = AnimationService.shortDuration,
    this.itemAnimationCurve = AnimationService.standardCurve,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveTVMode = isTVMode || PlatformService.isTVMode;

    if (effectiveTVMode) {
      // Pour TV: on n'anime pas les éléments individuellement pour des raisons de performance
      return ListView(
        scrollDirection: scrollDirection,
        reverse: reverse,
        controller: controller,
        padding: padding,
        children: children,
      );
    } else {
      // Pour mobile: on anime chaque élément avec un délai progressif
      return ListView(
        scrollDirection: scrollDirection,
        reverse: reverse,
        controller: controller,
        padding: padding,
        children: children.asMap().entries.map((entry) {
          return AnimatedBuilder(
            animation: AlwaysStoppedAnimation(1),
            builder: (context, child) {
              final animation = Tween<double>(
                begin: 50.0,
                end: 0.0,
              ).animate(
                CurvedAnimation(
                  parent: AlwaysStoppedAnimation(1),
                  curve: Interval(
                    (entry.key * 0.1).clamp(0.0, 0.8),
                    1.0,
                    curve: itemAnimationCurve,
                  ),
                ),
              );

              return Transform.translate(
                offset: Offset(animation.value, 0),
                child: Opacity(
                  opacity: animation.status == AnimationStatus.forward ? 1.0 : 1.0,
                  child: entry.value,
                ),
              );
            },
          );
        }).toList(),
      );
    }
  }
}

/// Widget pour une grille animée
class AnimatedGridWrapper extends StatelessWidget {
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final List<Widget> children;
  final bool isTVMode;
  final Duration itemAnimationDuration;
  final Curve itemAnimationCurve;

  const AnimatedGridWrapper({
    Key? key,
    required this.crossAxisCount,
    this.childAspectRatio = 0.7,
    this.crossAxisSpacing = 8.0,
    this.mainAxisSpacing = 8.0,
    required this.children,
    this.isTVMode = false,
    this.itemAnimationDuration = AnimationService.shortDuration,
    this.itemAnimationCurve = AnimationService.standardCurve,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveTVMode = isTVMode || PlatformService.isTVMode;

    if (effectiveTVMode) {
      // Pour TV: grille standard sans animation pour la performance
      return GridView(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
        ),
        children: children,
      );
    } else {
      // Pour mobile: grille avec animation progressive
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
        ),
        itemCount: children.length,
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: AlwaysStoppedAnimation(1),
            builder: (context, child) {
              final animation = Tween<double>(
                begin: 50.0,
                end: 0.0,
              ).animate(
                CurvedAnimation(
                  parent: AlwaysStoppedAnimation(1),
                  curve: Interval(
                    (index * 0.05).clamp(0.0, 0.9),
                    1.0,
                    curve: itemAnimationCurve,
                  ),
                ),
              );

              return Transform.translate(
                offset: Offset(animation.value, 0),
                child: Opacity(
                  opacity: animation.status == AnimationStatus.forward ? 1.0 : 1.0,
                  child: children[index],
                ),
              );
            },
          );
        },
      );
    }
  }
}

/// Widget pour une transition personnalisée entre écrans avec effets néon
class CustomPageRoute<T> extends PageRoute<T> {
  final Widget child;
  final bool isTVMode;
  final Duration duration;
  final Curve curve;
  final Color? transitionColor;
  final bool enableGlowEffect;

  CustomPageRoute({
    required this.child,
    this.isTVMode = false,
    this.duration = AnimationService.standardDuration,
    this.curve = AnimationService.standardCurve,
    this.transitionColor,
    this.enableGlowEffect = true,
    RouteSettings? settings,
  }) : super(settings: settings, fullscreenDialog: false);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => duration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

    if (isTVMode) {
      // Pour TV: transition de fondu avec effet de zoom
      return _buildFadeScaleTransition(curvedAnimation);
    } else {
      // Pour mobile: transition sophistiquée avec effets néon
      return _buildNeonSlideTransition(curvedAnimation);
    }
  }

  Widget _buildFadeScaleTransition(Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 0.95,
          end: 1.0,
        ).animate(animation),
        child: child,
      ),
    );
  }

  Widget _buildNeonSlideTransition(Animation<double> animation) {
    final slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(animation);

    final scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(animation);

    final glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    ));

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final transitionChild = SlideTransition(
          position: slideAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: FadeTransition(
              opacity: animation,
              child: this.child,
            ),
          ),
        );

        if (!enableGlowEffect) return transitionChild;

        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: (transitionColor ?? const Color(0xFF00D4FF)).withOpacity(
                  0.3 * glowAnimation.value,
                ),
                blurRadius: 30 * glowAnimation.value,
                spreadRadius: 10 * glowAnimation.value,
              ),
            ],
          ),
          child: transitionChild,
        );
      },
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Utiliser la transition par défaut de Flutter pour les dialogues
    if (fullscreenDialog) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    }

    return child;
  }
}

/// Transition page avec effet de ripple néon
class NeonRipplePageTransition extends PageRouteBuilder {
  final Widget page;
  final Color rippleColor;
  final Duration duration;

  NeonRipplePageTransition({
    required this.page,
    this.rippleColor = const Color(0xFF00D4FF),
    this.duration = const Duration(milliseconds: 500),
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return _buildRippleTransition(
        animation,
        child,
        rippleColor,
        duration,
      );
    },
  );

  static Widget _buildRippleTransition(
    Animation<double> animation,
    Widget child,
    Color rippleColor,
    Duration duration,
  ) {
    final scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.elasticOut,
    ));

    final opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    ));

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                rippleColor.withOpacity(0.1 * opacityAnimation.value),
                Colors.transparent,
              ],
              radius: scaleAnimation.value * 2,
            ),
          ),
          child: ScaleTransition(
            scale: scaleAnimation,
            child: FadeTransition(
              opacity: opacityAnimation,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// Transition avec effet de particules néon
class NeonParticleTransition extends PageRouteBuilder {
  final Widget page;
  final Color particleColor;
  final int particleCount;

  NeonParticleTransition({
    required this.page,
    this.particleColor = const Color(0xFF00D4FF),
    this.particleCount = 20,
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return Stack(
        children: [
          // Fond avec particules
          _buildParticleBackground(animation, particleColor, particleCount),
          // Contenu principal
          FadeTransition(
            opacity: animation,
            child: child,
          ),
        ],
      );
    },
  );

  static Widget _buildParticleBackground(
    Animation<double> animation,
    Color color,
    int count,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlePainter(
            progress: animation.value,
            color: color,
            count: count,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;
  final int count;

  _ParticlePainter({
    required this.progress,
    required this.color,
    required this.count,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6 * progress)
      ..style = PaintingStyle.fill;

    final random = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < count; i++) {
      final x = (random + i * 97) % size.width.toInt();
      final y = (random + i * 43) % size.height.toInt();
      final radius = (random + i * 23) % 3 + 1.0;

      canvas.drawCircle(
        Offset(x.toDouble(), y.toDouble()),
        radius * progress,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}