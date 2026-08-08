import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Presets d'animations réutilisables applicables via `.staggeredFade()` etc.
extension SatisfyingAnimations on Widget {
  /// Fondu + léger glissement vertical, retardé par index (effet stagger).
  Widget staggeredFade({
    int index = 0,
    Duration baseDuration = const Duration(milliseconds: 350),
    Duration stepDelay = const Duration(milliseconds: 45),
  }) {
    return animate(delay: stepDelay * index).fadeIn(
      duration: baseDuration,
      curve: Curves.easeOutCubic,
    ).slideY(
      begin: 0.08,
      duration: baseDuration,
      curve: Curves.easeOutCubic,
    );
  }

  /// Fondu + scale doux (effet « pop »).
  Widget popIn({
    int index = 0,
    Duration duration = const Duration(milliseconds: 400),
    Duration delay = Duration.zero,
  }) {
    return animate(
      delay: delay + (const Duration(milliseconds: 45) * index),
    ).fadeIn(
      duration: duration,
      curve: Curves.easeOutCubic,
    ).scale(
      begin: const Offset(0.92, 0.92),
      duration: duration,
      curve: Curves.easeOutBack,
    );
  }

  /// Lueur rouge pulsante pour les éléments mis en avant.
  Widget redGlow({Duration duration = const Duration(milliseconds: 1600)}) {
    return animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
      duration: duration,
      color: const Color(0x33E50914),
    );
  }

  /// Entrée « ressort » : fondu + scale avec léger dépassement (easeOutBack),
  /// retardée par index — plus dynamique que [staggeredFade].
  Widget springPop({
    int index = 0,
    Duration baseDuration = const Duration(milliseconds: 420),
    Duration stepDelay = const Duration(milliseconds: 40),
  }) {
    return animate(delay: stepDelay * index)
        .fadeIn(duration: baseDuration * 0.7, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.88, 0.88),
          end: const Offset(1, 1),
          duration: baseDuration,
          curve: Curves.easeOutBack,
        );
  }

  /// Glissement vertical + fondu en boucle, pour attirer l'œil sur un
  /// rappel (ex : indicateur « faites défiler »).
  Widget floatHint({Duration duration = const Duration(milliseconds: 1800)}) {
    return animate(onPlay: (c) => c.repeat(reverse: true)).moveY(
      begin: -2,
      end: 2,
      duration: duration,
      curve: Curves.easeInOutSine,
    );
  }
}

/// Rend n'importe quel enfant « pressable » : il s'enfonce légèrement
/// (scale 0.96) au contact puis revient avec un effet ressort — micro-
/// interaction « satisfying » pour les boutons et cartes.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final HitTestBehavior behavior;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _pressed ? Curves.easeInCubic : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
