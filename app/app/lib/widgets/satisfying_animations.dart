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
}
