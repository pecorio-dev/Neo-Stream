import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Générateur de logo NeoStream avec effets LED/néon
class LogoGenerator {
  /// Crée le widget logo NeoStream avec effets néon
  static Widget createNeoStreamLogo({
    double size = 120,
    bool showDecorations = true,
    double glowIntensity = 1.0,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: [
            AppTheme.accentNeon.withOpacity(0.9 * glowIntensity),
            AppTheme.accentSecondary.withOpacity(0.7 * glowIntensity),
            AppTheme.backgroundPrimary,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        border: Border.all(
          color: AppTheme.accentNeon.withOpacity(0.8 * glowIntensity),
          width: size * 0.016, // Proportionnel à la taille
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cercle intérieur avec effet néon
          Container(
            width: size * 0.67, // 80/120 = 0.67
            height: size * 0.67,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.backgroundPrimary,
              border: Border.all(
                color: AppTheme.accentNeon,
                width: size * 0.0125, // 1.5/120 = 0.0125
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentNeon.withOpacity(0.6 * glowIntensity),
                  blurRadius: size * 0.125, // 15/120 = 0.125
                  spreadRadius: size * 0.016, // 2/120 = 0.016
                ),
              ],
            ),
          ),
          // Logo "N" stylisé avec effet LED
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                AppTheme.accentNeon,
                AppTheme.accentSecondary,
                AppTheme.accentNeon,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds),
            child: Text(
              'N',
              style: TextStyle(
                fontSize: size * 0.4, // 48/120 = 0.4
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: size * 0.016, // 2/120 = 0.016
                shadows: [
                  Shadow(
                    color: AppTheme.accentNeon.withOpacity(glowIntensity),
                    blurRadius: size * 0.083, // 10/120 = 0.083
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
            ),
          ),
          // Points LED décoratifs (seulement si demandé)
          if (showDecorations) ..._buildDecorations(size, glowIntensity),
        ],
      ),
    );
  }

  /// Crée les points LED décoratifs
  static List<Widget> _buildDecorations(double size, double glowIntensity) {
    return [
      // Point LED principal (haut-droite)
      Positioned(
        top: size * 0.125, // 15/120 = 0.125
        right: size * 0.208, // 25/120 = 0.208
        child: Container(
          width: size * 0.05, // 6/120 = 0.05
          height: size * 0.05,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.accentNeon,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentNeon.withOpacity(glowIntensity),
                blurRadius: size * 0.067, // 8/120 = 0.067
                spreadRadius: size * 0.008, // 1/120 = 0.008
              ),
            ],
          ),
        ),
      ),
      // Point LED secondaire (bas-gauche)
      Positioned(
        bottom: size * 0.167, // 20/120 = 0.167
        left: size * 0.167, // 20/120 = 0.167
        child: Container(
          width: size * 0.033, // 4/120 = 0.033
          height: size * 0.033,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.accentSecondary,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentSecondary.withOpacity(glowIntensity),
                blurRadius: size * 0.05, // 6/120 = 0.05
                spreadRadius: size * 0.008, // 1/120 = 0.008
              ),
            ],
          ),
        ),
      ),
      // Point LED tertiaire (haut-gauche)
      Positioned(
        top: size * 0.208, // 25/120 = 0.208
        left: size * 0.125, // 15/120 = 0.125
        child: Container(
          width: size * 0.025, // 3/120 = 0.025
          height: size * 0.025,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.focusColor,
            boxShadow: [
              BoxShadow(
                color: AppTheme.focusColor.withOpacity(glowIntensity),
                blurRadius: size * 0.033, // 4/120 = 0.033
                spreadRadius: size * 0.008, // 1/120 = 0.008
              ),
            ],
          ),
        ),
      ),
    ];
  }

  /// Crée une version simplifiée du logo pour les petites tailles (icônes)
  static Widget createSimplifiedLogo({
    double size = 48,
    double glowIntensity = 0.8,
  }) {
    return createNeoStreamLogo(
      size: size,
      showDecorations: false, // Pas de décorations pour les petites tailles
      glowIntensity: glowIntensity,
    );
  }

  /// Crée le logo avec animation de glow
  static Widget createAnimatedLogo({
    required Animation<double> glowAnimation,
    double size = 120,
    bool showDecorations = true,
  }) {
    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, child) {
        return createNeoStreamLogo(
          size: size,
          showDecorations: showDecorations,
          glowIntensity: glowAnimation.value,
        );
      },
    );
  }
}