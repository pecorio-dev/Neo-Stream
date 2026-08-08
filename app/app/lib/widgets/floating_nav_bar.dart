import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../config/neo.dart';

/// Modèle d'un onglet de la [FloatingNavBar].
class FloatingNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const FloatingNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Barre de navigation flottante, façon « glassmorphism ».
///
/// Affichée uniquement sur mobile / desktop (le mode TV garde son rail
/// latéral). Caractéristiques :
///
/// - Capsule de verre dépoli ([BackdropFilter]) avec bordure lumineuse et
///   ombre douce, suspendue au-dessus du contenu qui défile en dessous.
/// - Pilule de sélection qui **glisse** entre les onglets avec une courbe
///   élastique et un dégradé dans la couleur d'accent.
/// - Icônes qui « poppent » à la sélection, libellé qui se déplie sous
///   l'icône active avec un effet de levée.
/// - Retour haptique à chaque changement d'onglet.
class FloatingNavBar extends StatelessWidget {
  FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  /// Index de l'onglet actif.
  final int currentIndex;

  /// Onglets affichés (de gauche à droite).
  final List<FloatingNavItem> items;

  /// Appelé lorsqu'un onglet est pressé.
  final ValueChanged<int> onTap;

  static const double _barHeight = 68;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // Nombre d'intervalles entre onglets (base du calcul de l'alignement).
    final segments = items.length > 1 ? items.length - 1 : 1;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        (bottomInset > 0 ? bottomInset : 12) + 6,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: _barHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isLight
                    ? [
                        Colors.white.withValues(alpha: 0.82),
                        Colors.white.withValues(alpha: 0.66),
                      ]
                    : [
                        Neo.bgSurface(context).withValues(alpha: 0.80),
                        Neo.bgBase(context).withValues(alpha: 0.88),
                      ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isLight
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.10 : 0.45),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: primary.withValues(alpha: isLight ? 0.10 : 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── Pilule de sélection coulissante ────────────────────
                AnimatedAlign(
                  alignment: Alignment(
                    -1 + 2 * currentIndex / segments,
                    0,
                  ),
                  duration: const Duration(milliseconds: 430),
                  curve: const Cubic(0.34, 1.4, 0.36, 1), // ressort doux
                  child: FractionallySizedBox(
                    widthFactor: 1 / items.length,
                    heightFactor: 0.94,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primary.withValues(alpha: isLight ? 0.16 : 0.22),
                            primary.withValues(alpha: isLight ? 0.08 : 0.10),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.35),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.20),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // ── Onglets ────────────────────────────────────────────
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(child: _buildItem(context, i, primary)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 420.ms, delay: 180.ms, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.55,
          end: 0,
          duration: 560.ms,
          delay: 150.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildItem(BuildContext context, int index, Color primary) {
    final selected = index == currentIndex;
    final item = items[index];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!selected) {
          HapticFeedback.selectionClick();
          onTap(index);
        }
      },
      child: SizedBox(
        height: _barHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.14 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(
                  begin: selected ? Neo.textDisabled(context) : primary,
                  end: selected ? primary : Neo.textDisabled(context),
                ),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                builder: (context, color, _) => Icon(
                  selected ? item.activeIcon : item.icon,
                  size: 23,
                  color: color,
                  shadows: selected
                      ? [
                          Shadow(
                            color: primary.withValues(alpha: 0.45),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
            // Libellé qui se déplie sous l'icône active (effet de levée).
            ClipRect(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                height: selected ? 15 : 0,
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
