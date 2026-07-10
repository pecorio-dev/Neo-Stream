import 'dart:ui';

import 'package:flutter/material.dart';

import '../config/neo.dart';

/// Carte « glassmorphism » réutilisable.
///
/// - En **thème clair** : vrai effet verre dépoli (BackdropFilter + dégradé
///   blanc translucide + bordure lumineuse), rendu « satisfying ».
/// - En **thème sombre** : repli sur une surface sombre classique (le blur sur
///   fond noir est peu visible et coûteux) afin de rester lisible.
///
/// Utilisée pour les cartes de chaînes, panneaux d'overview, barres de recherche…
class NeoGlassCard extends StatefulWidget {
  NeoGlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.radius,
    this.blur,
    this.accent,
    this.elevation = 0,
    this.animateHover = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? radius;
  final double? blur;
  final Color? accent;
  final double elevation;
  final bool animateHover;

  @override
  State<NeoGlassCard> createState() => _NeoGlassCardState();
}

class _NeoGlassCardState extends State<NeoGlassCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final radius = widget.radius ?? Neo.radiusLg;

    Widget content = Padding(
      padding: widget.padding ?? EdgeInsets.all(16),
      child: widget.child,
    );

    if (isLight) {
      // ── Vrai glassmorphism (thème clair) ──────────────────────────────
      final blur = widget.blur ?? 16.0;
      content = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Neo.bgSurface(context).withValues(alpha: 0.82),
                  Neo.bgSurface(context).withValues(alpha: 0.62),
                ],
              ),
              border: Border.all(
                color: (widget.accent ?? Neo.bgSurface(context))
                    .withValues(alpha: widget.accent != null ? 0.4 : 0.55),
                width: 1.2,
              ),
            ),
            child: content,
          ),
        ),
      );
    } else {
      // ── Surface sombre (thème sombre) ─────────────────────────────────
      content = Container(
        decoration: BoxDecoration(
          gradient: Neo.surfaceGradient,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: Neo.bgBorder(context).withValues(alpha: 0.6),
            width: 0.5,
          ),
        ),
        child: content,
      );
    }

    // Ombre / élévation.
    content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isLight ? 0.08 + widget.elevation * 0.02 : 0.18,
            ),
            blurRadius: 18 + widget.elevation * 4,
            offset: Offset(0, 4 + widget.elevation),
          ),
          if (widget.accent != null)
            BoxShadow(
              color: widget.accent!.withValues(alpha: isLight ? 0.15 : 0.25),
              blurRadius: 22,
              offset: Offset(0, 0),
            ),
        ],
      ),
      child: content,
    );

    if (widget.margin != null) {
      content = Padding(padding: widget.margin!, child: content);
    }

    // Hover scale optionnel (effet satisfying au survol tactile/desktop).
    if (widget.animateHover && widget.onTap != null) {
      content = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: _hovered ? 1.03 : 1.0,
          duration: Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: content,
        ),
      );
    }

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
    return content;
  }
}
