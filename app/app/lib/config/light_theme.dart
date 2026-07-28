import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Thème clair avec effet glassmorphism pour Neo-Stream
class NeoLightTheme {
  NeoLightTheme._();

  // COULEURS DE BASE

  // Couleurs primaires
  static const Color primaryRed = Color(0xFFE50914);
  static const Color primaryRedDark = Color(0xFFB20710);
  static const Color primaryRedLight = Color(0xFFFF1F29);

  // Backgrounds clairs (gris foncé — reposant pour les yeux)
  static const Color bgBase = Color(0xFFD1D5DB); // Gris neutre
  static const Color bgSurface = Color(0xFFDDE1E8); // Surface gris clair
  static const Color bgElevated = Color(0xFFC6CBD3); // Légèrement élevé
  static const Color bgGlass = Color(0xF0DDE1E8); // Fond glass

  // Bordures et séparateurs (gris moyen)
  static const Color border = Color(0xFFA8AEB8);
  static const Color borderLight = Color(0xFFBCC2CC);
  static const Color borderDark = Color(0xFF9098A4);

  // Texte (assombris pour meilleur contraste sur fonds réduits)
  static const Color textPrimary = Color(0xFF171C28);
  static const Color textSecondary = Color(0xFF555E6E);
  static const Color textTertiary = Color(0xFF7E8796);
  static const Color textDisabled = Color(0xFFB0B7C3);

  // Accent colors
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentGold = Color(0xFFFBBF24);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentPurple = Color(0xFF8B5CF6);

  // États
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color infoBlue = Color(0xFF3B82F6);

  // ACCENT GOLD / PRESTIGE

  static const Color prestigeGold = Color(0xFFE8B84A);
  static const Color goldDark = Color(0xFFC49320);
  static final Color goldGlow = prestigeGold.withValues(alpha: 0.20);

  // EFFET GLASSMORPHISM

  /// Crée un effet glassmorphism avec blur backdrop
  static BoxDecoration glassDecoration({
    Color? color,
    double blur = 10.0,
    double opacity = 0.94,
    BorderRadius? borderRadius,
    Border? border,
  }) {
    return BoxDecoration(
      color: (color ?? bgGlass).withValues(alpha: opacity),
      borderRadius: borderRadius ?? BorderRadius.circular(radiusMd),
      border: border ??
          Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Widget glass container avec backdrop filter
  static Widget glassContainer({
    required Widget child,
    Color? color,
    double blur = 10.0,
    double opacity = 0.94,
    BorderRadius? borderRadius,
    Border? border,
    EdgeInsets? padding,
    EdgeInsets? margin,
  }) {
    return Container(
      margin: margin,
      decoration: glassDecoration(
        color: color,
        blur: blur,
        opacity: opacity,
        borderRadius: borderRadius,
        border: border,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(radiusMd),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.2),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Glass card avec effet de profondeur
  static Widget glassCard({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double blur = 10.0,
  }) {
    final card = glassContainer(
      color: bgGlass,
      blur: blur,
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin,
      borderRadius: BorderRadius.circular(radiusLg),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radiusLg),
        child: card,
      );
    }

    return card;
  }

  // RADIUS

  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radius2xl = 24.0;
  static const double radiusFull = 999.0;
  static const double radiusXs = 4.0;

  // SHADOWS

  static final List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static final List<BoxShadow> shadowXl = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];

  static final List<BoxShadow> shadowGlow = [
    BoxShadow(
      color: primaryRed.withValues(alpha: 0.3),
      blurRadius: 20,
      offset: const Offset(0, 0),
    ),
  ];

  // GRADIENTS

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryRed, primaryRedDark],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgSurface, bgElevated],
  );

  /// Dégradé « hero » rouge cinématique (cohérent avec le thème sombre).
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryRed, primaryRedDark],
  );

  /// Dégradé prestige (or) pour les badges premium.
  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [prestigeGold, goldDark],
  );

  static final LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      bgSurface.withValues(alpha: 0.95),
      bgSurface.withValues(alpha: 0.85),
    ],
  );

  static final LinearGradient shimmerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      bgElevated,
      bgSurface.withValues(alpha: 0.3),
      bgElevated,
    ],
  );

  // DECORATIONS (cohérentes avec NeoTheme sombre)

  /// Décoration de panneau (carte surface claire).
  static BoxDecoration panelDecoration({Color? accent}) => BoxDecoration(
        gradient: surfaceGradient,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(
          color: (accent ?? border).withValues(alpha: accent != null ? 0.35 : 1),
          width: 0.5,
        ),
        boxShadow: shadowMd,
      );

  /// Décoration de carte standard.
  static BoxDecoration cardDecoration({Color? accent}) => BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(
          color: (accent ?? border).withValues(alpha: accent != null ? 0.3 : 1),
          width: 0.5,
        ),
        boxShadow: shadowSm,
      );

  /// Décoration pill (chips, badges, boutons ronds).
  static BoxDecoration pillDecoration({Color? color, bool selected = false}) =>
      BoxDecoration(
        color: selected
            ? (color ?? primaryRed).withValues(alpha: 0.12)
            : bgElevated,
        borderRadius: BorderRadius.circular(radiusFull),
        border: Border.all(
          color: selected
              ? (color ?? primaryRed).withValues(alpha: 0.5)
              : borderLight,
          width: 1,
        ),
      );

  // THEME DATA

  static ThemeData get themeData => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: primaryRed,
        scaffoldBackgroundColor: bgBase,
        colorScheme: const ColorScheme.light(
          primary: primaryRed,
          secondary: accentBlue,
          surface: bgSurface,
          error: errorRed,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: textPrimary,
          onError: Colors.white,
        ),
        textTheme: const TextTheme(
          // Display
          displayLarge: TextStyle(
            fontSize: 57,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.5,
          ),
          displayMedium: TextStyle(
            fontSize: 45,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.25,
          ),
          displaySmall: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          // Headline
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          headlineSmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          // Title
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textPrimary,
            letterSpacing: 0.15,
          ),
          titleSmall: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textPrimary,
            letterSpacing: 0.1,
          ),
          // Body
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: textPrimary,
            letterSpacing: 0.5,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textSecondary,
            letterSpacing: 0.25,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: textTertiary,
            letterSpacing: 0.4,
          ),
          // Label
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textPrimary,
            letterSpacing: 0.1,
          ),
          labelMedium: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textSecondary,
            letterSpacing: 0.5,
          ),
          labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: textTertiary,
            letterSpacing: 0.5,
          ),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: bgBase,
          foregroundColor: textPrimary,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: bgSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
            side: const BorderSide(color: border, width: 1),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryRed,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryRed,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bgSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: primaryRed, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: errorRed),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: bgElevated,
          selectedColor: primaryRed,
          disabledColor: bgElevated,
          labelStyle: const TextStyle(color: textPrimary),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusFull),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: border,
          thickness: 1,
          space: 1,
        ),
      );

  // DURATIONS & CURVES

  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 350);

  static const Curve smoothOut = Curves.easeOutCubic;

  // RESPONSIVE HELPERS (miroir de NeoTheme pour cohérence d'API)

  /// Seuil de détection TV.
  static const double tvBreakpoint = 960;

  static bool isTV(BuildContext context) {
    if (isDesktopPlatform) return false;
    return MediaQuery.sizeOf(context).width >= tvBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 600 && w < tvBreakpoint;
  }

  // ── Alias API (compatibilité avec NeoTheme sombre) ───────────────────
  // Nécessaires pour que le pont Neo dispatch clair/sombre sans toucher
  // aux 29 écrans qui appellent ces membres.

  // Backgrounds (mirroir des noms NeoTheme) — bgGlass déjà défini plus haut
  static const Color bgBorder = border;
  static const Color bgActive = Color(0xFFBCC2CC);
  static const Color bgHover = Color(0xFFB0B6C0);
  static const Color bgOverlay = Color(0xFFDDE1E8);

  // Brand accents manquants (primaryRedDark/bgGlass déjà définis plus haut)
  static const Color primaryRedHover = Color(0xFFFF1C28);
  static const Color purpleAccent = accentPurple;
  static const Color infoCyan = Color(0xFF0EA5E9);

  // Genre colors (identiques au thème sombre pour cohérence visuelle)
  static const Map<String, Color> genreColors = {
    'Action': Color(0xFFFF2D55),
    'Drame': Color(0xFF7C6AFF),
    'Comedie': Color(0xFFFFCC00),
    'Horreur': Color(0xFF6E5CE6),
    'Romance': Color(0xFFFF4D6A),
    'Sci-Fi': Color(0xFF64D2FF),
    'Science-Fiction': Color(0xFF64D2FF),
    'Thriller': Color(0xFFF97316),
    'Animation': Color(0xFF22D3EE),
    'Documentaire': Color(0xFFC084FC),
    'Fantastique': Color(0xFF3B82F6),
    'Aventure': Color(0xFFFF3B30),
    'Crime': Color(0xFF94A3B8),
    'Guerre': Color(0xFF78716C),
    'Musique': Color(0xFFF472B6),
    'Western': Color(0xFFA16207),
    'Telefilm': Color(0xFF0EA5E9),
    'Famille': Color(0xFF34D399),
    'Histoire': Color(0xFFD4A574),
    'Mystere': Color(0xFF7C6AFF),
  };

  static Color getGenreColor(String genre) =>
      genreColors[genre] ?? purpleAccent;

  // ── Décorations (version claire) ─────────────────────────────────────

  static BoxDecoration get cardFocusedDecoration => BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: primaryRed, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: primaryRed.withValues(alpha: 0.35),
            blurRadius: 22,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: primaryRed.withValues(alpha: 0.12),
            blurRadius: 44,
            spreadRadius: 6,
          ),
        ],
      );

  static LinearGradient get topPanelGradient => surfaceGradient;

  static LinearGradient get cardOverlayGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Color(0x66FFFFFF), Color(0xE6FFFFFF)],
        stops: [0, 0.52, 1],
      );

  // Shadows level (compatibilité API NeoTheme)
  static List<BoxShadow> get shadowLevel1 => shadowSm;
  static List<BoxShadow> get shadowLevel2 => shadowMd;
  static List<BoxShadow> get shadowLevel3 => shadowLg;

  static List<BoxShadow> shadowGoldGlow = [
    BoxShadow(
      color: prestigeGold.withValues(alpha: 0.22),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];

  // ── Curves & Durations manquantes ────────────────────────────────────
  static const Curve premium = Cubic(0.16, 1, 0.3, 1);
  static const Curve cinematic = Cubic(0.4, 0, 0, 1);
  static const Curve bounceOut = Curves.elasticOut;
  static const Curve smoothIn = Curves.easeInCubic;
  static const Curve smoothInOut = Curves.easeInOutCubic;
  static const Duration durationNormal = Duration(milliseconds: 280);
  static const Duration durationHero = Duration(milliseconds: 650);
  static const Duration durationSplash = Duration(milliseconds: 900);

  // ── Spacing tokens ───────────────────────────────────────────────────
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double space2xl = 32;
  static const double space3xl = 48;
  static const double space4xl = 64;
  static const Duration staggerDelay = Duration(milliseconds: 60);

  // ── Responsive helpers (compatibilité NeoTheme) ──────────────────────

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static double scaleFactor(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1400) return 1.3;
    if (width >= 1100) return 1.18;
    if (width >= 900) return 1.08;
    return 1;
  }

  static bool get isDesktopPlatform {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Focus navigation universelle (D-pad / remote TV).
  static bool needsFocusNavigation(BuildContext context) => true;

  static EdgeInsets screenPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1920) return const EdgeInsets.symmetric(horizontal: 48);
    if (width >= 1280) return const EdgeInsets.symmetric(horizontal: 32);
    if (width >= 1024) return const EdgeInsets.symmetric(horizontal: 24);
    return const EdgeInsets.symmetric(horizontal: 16);
  }

  static double sectionGap(BuildContext context) {
    if (isTV(context)) return 40;
    if (isTablet(context)) return 32;
    return 24;
  }

  static double tvRailWidth(BuildContext context) => isTV(context) ? 220 : 0;
  static double get tvRailWidthExpanded => 420;

  static double heroHeight(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1920) return 440;
    if (width >= 1600) return 400;
    if (width >= 1280) return 360;
    if (width >= 1024) return 320;
    return 300;
  }

  static double cardWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1920) return 220;
    if (width >= 1600) return 200;
    if (width >= 1280) return 180;
    if (width >= 1024) return 168;
    if (width >= 768) return 152;
    return 140;
  }

  static double cardHeight(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1920) return 340;
    if (width >= 1600) return 320;
    if (width >= 1280) return 296;
    if (width >= 1024) return 270;
    if (width >= 768) return 248;
    return 232;
  }

  static double horizontalCardHeight(BuildContext context) =>
      cardHeight(context) + 28;

  static double searchCardHeight(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1280) return 132;
    if (width >= 1024) return 116;
    return 100;
  }

  static double gridSpacing(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1920) return 22;
    if (width >= 1600) return 20;
    if (width >= 1280) return 16;
    if (width >= 1024) return 14;
    return 12;
  }

  static EdgeInsets contentPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1920) return const EdgeInsets.all(24);
    if (width >= 1600) return const EdgeInsets.all(20);
    if (width >= 1280) return const EdgeInsets.all(16);
    if (width >= 1024) return const EdgeInsets.all(14);
    return const EdgeInsets.all(12);
  }

  static double iconSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1920) return 28;
    if (width >= 1280) return 24;
    if (width >= 1024) return 22;
    return 20;
  }

  static double chipHeight(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1280) return 46;
    if (width >= 768) return 42;
    return 38;
  }

  static double avatarSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1920) return 116;
    if (width >= 1280) return 92;
    if (width >= 768) return 78;
    return 70;
  }

  static Size posterSize(BuildContext context, {bool tall = false}) {
    final width = MediaQuery.sizeOf(context).width;
    if (tall) {
      if (width >= 1920) return const Size(160, 252);
      if (width >= 1280) return const Size(140, 224);
      if (width >= 768) return const Size(128, 202);
      return const Size(118, 188);
    }
    if (width >= 1920) return const Size(160, 224);
    if (width >= 1280) return const Size(140, 196);
    if (width >= 768) return const Size(128, 182);
    return const Size(118, 168);
  }

  static double focusBorderWidth(BuildContext context) =>
      isTV(context) ? 3.0 : 2.0;

  static double focusBorderRadius(BuildContext context) =>
      isTV(context) ? radiusLg : radiusMd;

  static double focusedCardScale(BuildContext context) =>
      isTV(context) ? 1.06 : 1.04;

  static double minTouchTarget(BuildContext context) =>
      isTV(context) ? 48.0 : 44.0;

  static double badgeHeight(BuildContext context) =>
      isTV(context) ? 44.0 : 32.0;

  // ── Typographie responsive (compatibilité NeoTheme) ──────────────────
  static TextStyle _scaled(
    BuildContext context, {
    required double size,
    required FontWeight weight,
    required Color color,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontSize: size * scaleFactor(context),
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle displayLarge(BuildContext context) => _scaled(
        context,
        size: 36,
        weight: FontWeight.w900,
        color: textPrimary,
        letterSpacing: -1.2,
        height: 1.05,
      );

  static TextStyle displayMedium(BuildContext context) => _scaled(
        context,
        size: 28,
        weight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: -0.6,
        height: 1.08,
      );

  static TextStyle headlineLarge(BuildContext context) => _scaled(
        context,
        size: 24,
        weight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.4,
        height: 1.12,
      );

  static TextStyle headlineMedium(BuildContext context) => _scaled(
        context,
        size: 20,
        weight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.2,
        height: 1.14,
      );

  static TextStyle titleLarge(BuildContext context) => _scaled(
        context,
        size: 18,
        weight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.1,
        height: 1.2,
      );

  static TextStyle titleMedium(BuildContext context) => _scaled(
        context,
        size: 16,
        weight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: 0,
        height: 1.22,
      );

  static TextStyle bodyLarge(BuildContext context) => _scaled(
        context,
        size: 16,
        weight: FontWeight.w400,
        color: textSecondary,
        letterSpacing: 0.1,
        height: 1.5,
      );

  static TextStyle bodyMedium(BuildContext context) => _scaled(
        context,
        size: 14,
        weight: FontWeight.w400,
        color: textSecondary,
        letterSpacing: 0.1,
        height: 1.45,
      );

  static TextStyle bodySmall(BuildContext context) => _scaled(
        context,
        size: isTV(context) ? 14 : 12,
        weight: FontWeight.w400,
        color: textTertiary,
        letterSpacing: 0.15,
        height: 1.4,
      );

  static TextStyle labelLarge(BuildContext context) => _scaled(
        context,
        size: 14,
        weight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: 0.2,
        height: 1.2,
      );

  static TextStyle labelMedium(BuildContext context) => _scaled(
        context,
        size: 12,
        weight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: 0.3,
        height: 1.18,
      );

  static TextStyle labelSmall(BuildContext context) => _scaled(
        context,
        size: 10,
        weight: FontWeight.w600,
        color: textTertiary,
        letterSpacing: 0.5,
        height: 1.12,
      );
}
