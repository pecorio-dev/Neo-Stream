import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Système de couleurs avancé pour NEO-Stream
/// Fournit des palettes cohérentes et des dégradés spectaculaires
class ColorSystem {
  // ============================================================================
  // COULEURS PRIMAIRES - Palette Cyberpunk/Neon
  // ============================================================================

  // Neon Cyan (Primaire)
  static const Color neonCyan = Color(0xFF00D4FF);
  static const Color neonCyanDark = Color(0xFF00A8CC);
  static const Color neonCyanLight = Color(0xFF4DEFF7);

  // Neon Purple (Secondaire)
  static const Color neonPurple = Color(0xFF8B5CF6);
  static const Color neonPurpleDark = Color(0xFF6D28D9);
  static const Color neonPurpleLight = Color(0xFFA78BFA);

  // Neon Pink (Accent)
  static const Color neonPink = Color(0xFFFF006E);
  static const Color neonPinkDark = Color(0xFFC2185B);
  static const Color neonPinkLight = Color(0xFFFF4D94);

  // Neon Green (Success)
  static const Color neonGreen = Color(0xFF00FF41);
  static const Color neonGreenDark = Color(0xFF00D648);
  static const Color neonGreenLight = Color(0xFF4DFF73);

  // ============================================================================
  // COULEURS DE FOND - Dark Theme
  // ============================================================================

  static const Color backgroundPrimary = Color(0xFF0A0A0F);
  static const Color backgroundSecondary = Color(0xFF1A1A24);
  static const Color backgroundTertiary = Color(0xFF2A2A3A);
  static const Color surfaceDark = Color(0xFF151520);
  static const Color surfaceLight = Color(0xFF3A3A4A);
  static const Color surface = Color(0xFF1A1A24);

  // ============================================================================
  // COULEURS DE TEXTE
  // ============================================================================

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF808080);
  static const Color textDisabled = Color(0xFF4D4D4D);

  // ============================================================================
  // COULEURS DE STATUT
  // ============================================================================

  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF3B82F6);

  // ============================================================================
  // DÉGRADÉS - Gradients Spectaculaires
  // ============================================================================

  /// Dégradé Cyan -> Purple
  static const LinearGradient cyanPurpleGradient = LinearGradient(
    colors: [neonCyan, neonPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dégradé Purple -> Pink
  static const LinearGradient purplePinkGradient = LinearGradient(
    colors: [neonPurple, neonPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dégradé Cyan -> Pink
  static const LinearGradient cyanPinkGradient = LinearGradient(
    colors: [neonCyan, neonPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dégradé Cyan -> Green
  static const LinearGradient cyanGreenGradient = LinearGradient(
    colors: [neonCyan, neonGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dégradé Fond Vertical
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [backgroundPrimary, backgroundSecondary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Dégradé Radial (Spotlight)
  static RadialGradient getRadialGradient({
    required Color centerColor,
    required Color edgeColor,
    double radius = 0.5,
  }) {
    return RadialGradient(
      radius: radius,
      colors: [centerColor, edgeColor],
    );
  }

  /// Dégradé Diagonal Principal
  static const LinearGradient primaryDiagonalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [neonCyan, neonPurple, neonPink],
  );

  /// Dégradé Diagonal Secondaire
  static const LinearGradient secondaryDiagonalGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [neonPurple, neonPink, neonCyan],
  );

  // ============================================================================
  // PALETTES - Ensembles cohérents de couleurs
  // ============================================================================

  /// Palette Cyberpunk
  static const List<Color> cyberpunkPalette = [
    neonCyan,
    neonPurple,
    neonPink,
    neonGreen,
  ];

  /// Palette Monochrome Cyan
  static const List<Color> cyanMonochrome = [
    neonCyan,
    neonCyanDark,
    neonCyanLight,
  ];

  /// Palette Monochrome Purple
  static const List<Color> purpleMonochrome = [
    neonPurple,
    neonPurpleDark,
    neonPurpleLight,
  ];

  /// Palette Monochrome Pink
  static const List<Color> pinkMonochrome = [
    neonPink,
    neonPinkDark,
    neonPinkLight,
  ];

  // ============================================================================
  // UTILITAIRES DE COULEUR
  // ============================================================================

  /// Obtenir une couleur avec opacité personnalisée
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }

  /// Obtenir une couleur plus claire
  static Color lighten(Color color, [double amount = 0.1]) {
    final hsl = HSLColor.fromColor(color);
    final lightened = hsl.withLightness(
      (hsl.lightness + amount).clamp(0.0, 1.0),
    );
    return lightened.toColor();
  }

  /// Obtenir une couleur plus foncée
  static Color darken(Color color, [double amount = 0.1]) {
    final hsl = HSLColor.fromColor(color);
    final darkened = hsl.withLightness(
      (hsl.lightness - amount).clamp(0.0, 1.0),
    );
    return darkened.toColor();
  }

  /// Interpoler entre deux couleurs
  static Color lerp(Color color1, Color color2, double t) {
    return Color.lerp(color1, color2, t) ?? color1;
  }

  /// Obtenir le dégradé linéaire entre deux couleurs
  static LinearGradient createGradient(
    Color startColor,
    Color endColor, {
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [startColor, endColor],
    );
  }

  /// Obtenir un dégradé multi-couleurs
  static LinearGradient createMultiGradient(
    List<Color> colors, {
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: colors,
    );
  }

  // ============================================================================
  // SCHÉMAS DE COULEURS PAR CONTEXTE
  // ============================================================================

  /// Schéma pour les cartes (movies, series)
  static const CardColorScheme cardColorScheme = CardColorScheme(
    background: backgroundTertiary,
    border: neonCyan,
    accent: neonPurple,
  );

  /// Schéma pour les boutons
  static const ButtonColorScheme buttonColorScheme = ButtonColorScheme(
    primary: neonCyan,
    primaryDark: neonCyanDark,
    secondary: neonPurple,
    disabled: textTertiary,
  );

  /// Schéma pour les icônes
  static const IconColorScheme iconColorScheme = IconColorScheme(
    primary: neonCyan,
    secondary: neonPurple,
    accent: neonPink,
    disabled: textTertiary,
  );

  /// Schéma pour le statut
  static const StatusColorScheme statusColorScheme = StatusColorScheme(
    success: neonGreen,
    warning: warningColor,
    error: errorColor,
    info: infoColor,
  );
}

/// Schéma de couleurs pour les cartes
class CardColorScheme {
  final Color background;
  final Color border;
  final Color accent;

  const CardColorScheme({
    required this.background,
    required this.border,
    required this.accent,
  });
}

/// Schéma de couleurs pour les boutons
class ButtonColorScheme {
  final Color primary;
  final Color primaryDark;
  final Color secondary;
  final Color disabled;

  const ButtonColorScheme({
    required this.primary,
    required this.primaryDark,
    required this.secondary,
    required this.disabled,
  });
}

/// Schéma de couleurs pour les icônes
class IconColorScheme {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color disabled;

  const IconColorScheme({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.disabled,
  });
}

/// Schéma de couleurs pour le statut
class StatusColorScheme {
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  const StatusColorScheme({
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
  });
}
