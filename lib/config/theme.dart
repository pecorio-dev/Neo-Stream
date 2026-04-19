import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class NeoTheme {
  NeoTheme._();

  // ─── Backgrounds ──────────────────────────────────────────────
  static const Color bgBase = Color(0xFF06060C);
  static const Color bgSurface = Color(0xFF0C0C16);
  static const Color bgElevated = Color(0xFF12121F);
  static const Color bgOverlay = Color(0xFF18182A);
  static const Color bgGlass = Color(0xBB0E0E1C);
  static const Color bgActive = Color(0xFF1E1E34);
  static const Color bgHover = Color(0xFF262642);
  static const Color bgBorder = Color(0xFF2A2A4A);

  // ─── Brand ────────────────────────────────────────────────────
  static const Color primaryRed = Color(0xFFE50914);
  static const Color primaryRedHover = Color(0xFFFF1C28);
  static const Color primaryRedDark = Color(0xFF9C0610);
  static const Color primaryRedGlow = Color(0x44E50914);
  static const Color prestigeGold = Color(0xFFE8B84A);
  static const Color goldDark = Color(0xFFC49320);
  static const Color goldGlow = Color(0x33E8B84A);

  // ─── Semantic ─────────────────────────────────────────────────
  static const Color successGreen = Color(0xFF0AD48B);
  static const Color infoCyan = Color(0xFF38BDF8);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color purpleAccent = Color(0xFFA78BFA);
  static const Color indigoAccent = Color(0xFF818CF8);

  // ─── Text ─────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F5FA);
  static const Color textSecondary = Color(0xFFBEC4D8);
  static const Color textTertiary = Color(0xFF8A90AB);
  static const Color textDisabled = Color(0xFF5C6180);

  // ─── Genre Colors ─────────────────────────────────────────────
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

  static Color getGenreColor(String genre) {
    return genreColors[genre] ?? purpleAccent;
  }

  // ─── Gradients ────────────────────────────────────────────────
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE50914), Color(0xFFFF4D35)],
  );

  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8B84A), Color(0xFFD4922A)],
  );

  static const LinearGradient auroraGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF12122A), Color(0xFF0A0A18), Color(0xFF06060C)],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF141428), Color(0xFF0C0C18)],
  );

  static const LinearGradient posterFadeGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xFF06060C)],
    stops: [0.38, 1],
  );

  static const LinearGradient cardOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0x8006060C), Color(0xF206060C)],
    stops: [0, 0.52, 1],
  );

  static const LinearGradient topPanelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xDD16163A), Color(0xDD0A0A18)],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xCC1A1A38), Color(0x990E0E20)],
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    begin: Alignment(-1.5, -0.3),
    end: Alignment(1.5, 0.3),
    colors: [Color(0xFF12121F), Color(0xFF1E1E34), Color(0xFF12121F)],
  );

  // ─── Radii ────────────────────────────────────────────────────
  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 22;
  static const double radius2xl = 28;

  // ─── Spacing ──────────────────────────────────────────────────
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double space2xl = 32;
  static const double space3xl = 48;
  static const double space4xl = 64;

  // ─── Animation Curves ─────────────────────────────────────────
  static const Curve smoothOut = Curves.easeOutCubic;
  static const Curve smoothIn = Curves.easeInCubic;
  static const Curve bounceOut = Curves.elasticOut;
  static const Curve premium = Cubic(0.16, 1, 0.3, 1);
  static const Curve cinematic = Cubic(0.4, 0, 0, 1);

  // ─── Durations ────────────────────────────────────────────────
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 280);
  static const Duration durationSlow = Duration(milliseconds: 420);
  static const Duration durationHero = Duration(milliseconds: 650);
  static const Duration durationSplash = Duration(milliseconds: 900);
  static const Duration staggerDelay = Duration(milliseconds: 60);

  // ─── Shadows ──────────────────────────────────────────────────
  static List<BoxShadow> shadowLevel1 = const [
    BoxShadow(color: Color(0x50000000), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x18000020), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static List<BoxShadow> shadowLevel2 = const [
    BoxShadow(color: Color(0x60000000), blurRadius: 24, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x20000020), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static List<BoxShadow> shadowLevel3 = const [
    BoxShadow(color: Color(0x78000000), blurRadius: 40, offset: Offset(0, 16)),
    BoxShadow(color: Color(0x28000020), blurRadius: 10, offset: Offset(0, 4)),
  ];

  static List<BoxShadow> shadowGlow = [
    BoxShadow(
      color: primaryRed.withValues(alpha: 0.2),
      blurRadius: 48,
      offset: const Offset(0, 20),
    ),
    BoxShadow(
      color: primaryRed.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> shadowGoldGlow = [
    BoxShadow(
      color: prestigeGold.withValues(alpha: 0.18),
      blurRadius: 36,
      offset: const Offset(0, 14),
    ),
  ];

  // ─── Decorations ──────────────────────────────────────────────
  static BoxDecoration cardDecoration = BoxDecoration(
    gradient: surfaceGradient,
    borderRadius: BorderRadius.circular(radiusLg),
    border: Border.all(color: bgBorder.withValues(alpha: 0.22), width: 0.5),
    boxShadow: shadowLevel1,
  );

  static BoxDecoration cardFocusedDecoration = BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1C1C3A), Color(0xFF0E0E1E)],
    ),
    borderRadius: BorderRadius.circular(radiusLg),
    border: Border.all(color: primaryRed, width: 2.5),
    boxShadow: [
      BoxShadow(
        color: primaryRed.withValues(alpha: 0.4),
        blurRadius: 24,
        spreadRadius: 2,
      ),
      BoxShadow(
        color: primaryRed.withValues(alpha: 0.15),
        blurRadius: 48,
        spreadRadius: 8,
      ),
    ],
  );

  static BoxDecoration glassDecoration = BoxDecoration(
    gradient: glassGradient,
    borderRadius: BorderRadius.circular(radiusXl),
    border: Border.all(color: bgBorder.withValues(alpha: 0.25), width: 0.5),
    boxShadow: shadowLevel2,
  );

  static BoxDecoration panelDecoration({Color? accent, bool elevated = false}) {
    final edge = accent ?? bgBorder;
    return BoxDecoration(
      gradient: elevated ? topPanelGradient : surfaceGradient,
      borderRadius: BorderRadius.circular(radiusLg),
      border: Border.all(
        color: edge.withValues(alpha: accent != null ? 0.35 : 0.2),
        width: 0.5,
      ),
      boxShadow: elevated ? shadowLevel2 : shadowLevel1,
    );
  }

  static BoxDecoration pillDecoration({Color? color, bool selected = false}) {
    final base = color ?? bgElevated;
    return BoxDecoration(
      color: selected ? base : base.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: selected
            ? (color ?? primaryRed).withValues(alpha: 0.8)
            : bgBorder.withValues(alpha: 0.2),
        width: 0.5,
      ),
    );
  }

  // ─── Responsive Helpers ───────────────────────────────────────
  /// TV detection: width >= 1200px (excludes large tablets)
  /// 4K TVs (3840px) are also detected as TV
  static bool isTV(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 1200;
  }
  
  /// 4K display detection for ultra-high resolution
  static bool is4K(BuildContext context) =>
      MediaQuery.of(context).size.width >= 3840;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 700 && width < 1200;
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 700;

  /// True on Windows, macOS, or Linux (non-web).
  static bool get isDesktopPlatform {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// True when the UI should use focus-based navigation (TV or desktop).
  static bool needsFocusNavigation(BuildContext context) =>
      isTV(context) || isDesktopPlatform;

  static double scaleFactor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1400) return 1.3;
    if (width >= 1100) return 1.18;
    if (width >= 900) return 1.08;
    return 1;
  }

  // ─── TV & Desktop Optimized Dimensions ────────────────────

  /// Navigation rail width for TV (sidebar)
  static double tvRailWidth(BuildContext context) => isTV(context) ? 220 : 0;

  /// Navigation rail width when expanded (search mode)
  static double tvRailWidthExpanded = 420;

  /// Hero banner heights - optimized for TV viewing
  static double heroHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1920) return 480; // 4K displays
    if (width >= 1600) return 420; // Large displays
    if (width >= 1280) return 380; // Standard HD
    if (width >= 1024) return 340; // Tablets landscape
    return 300; // Mobile
  }

  /// Card dimensions - precise for grid layouts
  static double cardWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1920) return 240; // 4K: 7 cards per row
    if (width >= 1600) return 220; // Large: 6 cards
    if (width >= 1280) return 200; // HD: 5 cards
    if (width >= 1024) return 180; // Tablet: 4 cards
    if (width >= 768) return 160; // Small tablet: 3 cards
    return 150; // Mobile: 2 cards
  }

  static double cardHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1920) return 380; // 4K
    if (width >= 1600) return 350; // Large
    if (width >= 1280) return 320; // HD
    if (width >= 1024) return 290; // Tablet
    if (width >= 768) return 260; // Small tablet
    return 240; // Mobile
  }

  /// Horizontal card height for carousels
  static double horizontalCardHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1920) return 200; // 4K
    if (width >= 1600) return 180; // Large
    if (width >= 1280) return 160; // HD
    return 140; // Default
  }

  /// Search card height for list view
  static double searchCardHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1280) return 140;
    if (width >= 1024) return 120;
    return 100;
  }

  /// Section gaps - consistent spacing
  static double sectionGap(BuildContext context) {
    if (isTV(context)) return 48;
    if (isTablet(context)) return 36;
    return 28;
  }

  /// Screen padding - responsive horizontal margins
  static EdgeInsets screenPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1920) return const EdgeInsets.symmetric(horizontal: 48);
    if (width >= 1600) return const EdgeInsets.symmetric(horizontal: 40);
    if (width >= 1280) return const EdgeInsets.symmetric(horizontal: 32);
    if (width >= 1024) return const EdgeInsets.symmetric(horizontal: 24);
    return const EdgeInsets.symmetric(horizontal: 16);
  }

  /// Grid spacing between cards
  static double gridSpacing(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1920) return 24;
    if (width >= 1600) return 20;
    if (width >= 1280) return 16;
    if (width >= 1024) return 14;
    return 12;
  }

  /// Content padding inside cards and panels
  static EdgeInsets contentPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1920) return const EdgeInsets.all(24);
    if (width >= 1600) return const EdgeInsets.all(20);
    if (width >= 1280) return const EdgeInsets.all(16);
    if (width >= 1024) return const EdgeInsets.all(14);
    return const EdgeInsets.all(12);
  }

  /// Icon sizes
  static double iconSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1920) return 28;
    if (width >= 1280) return 24;
    if (width >= 1024) return 22;
    return 20;
  }

  /// Chip/pill height
  static double chipHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1280) return 48;
    if (width >= 768) return 44;
    return 38;
  }

  /// Avatar size for profiles
  static double avatarSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1920) return 120;
    if (width >= 1280) return 96;
    if (width >= 768) return 80;
    return 72;
  }

  /// Poster dimensions for search/continue cards
  static Size posterSize(BuildContext context, {bool tall = false}) {
    final width = MediaQuery.of(context).size.width;
    if (tall) {
      if (width >= 1920) return const Size(160, 260);
      if (width >= 1280) return const Size(140, 230);
      if (width >= 768) return const Size(128, 208);
      return const Size(118, 192);
    }
    if (width >= 1920) return const Size(160, 230);
    if (width >= 1280) return const Size(140, 200);
    if (width >= 768) return const Size(128, 186);
    return const Size(118, 172);
  }

  /// Grid columns - precise for each breakpoint
  static int gridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1920) return 7; // 4K
    if (width >= 1600) return 6; // Large
    if (width >= 1280) return 5; // HD
    if (width >= 1024) return 4; // Tablet landscape
    if (width >= 768) return 3; // Tablet portrait
    return 2; // Mobile
  }

  /// Focus border width for TV navigation
  static double focusBorderWidth(BuildContext context) {
    return isTV(context) ? 3.0 : 2.0;
  }

  /// Focus border radius - cohérence avec le reste
  static double focusBorderRadius(BuildContext context) {
    return isTV(context) ? radiusLg : radiusMd;
  }

  /// Default focused card scale for TV
  static double focusedCardScale(BuildContext context) {
    return isTV(context) ? 1.06 : 1.04;
  }
  
  /// Minimum touch target size for TV (48dp recommended)
  static double minTouchTarget(BuildContext context) {
    return isTV(context) ? 48.0 : 44.0;
  }
  
  /// Badge height for TV accessibility
  static double badgeHeight(BuildContext context) {
    return isTV(context) ? 48.0 : 32.0;
  }

  // ─── Typography ───────────────────────────────────────────────
  static TextStyle _text(
    BuildContext context, {
    required double size,
    required FontWeight weight,
    required Color color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontSize: size * scaleFactor(context),
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle displayLarge(BuildContext context) => _text(
    context,
    size: 36,
    weight: FontWeight.w900,
    color: textPrimary,
    letterSpacing: -1.2,
    height: 1.05,
  );

  static TextStyle displayMedium(BuildContext context) => _text(
    context,
    size: 28,
    weight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.6,
    height: 1.08,
  );

  static TextStyle headlineLarge(BuildContext context) => _text(
    context,
    size: 24,
    weight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.4,
    height: 1.12,
  );

  static TextStyle headlineMedium(BuildContext context) => _text(
    context,
    size: 20,
    weight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.2,
    height: 1.14,
  );

  static TextStyle titleLarge(BuildContext context) => _text(
    context,
    size: 18,
    weight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.1,
    height: 1.2,
  );

  static TextStyle titleMedium(BuildContext context) => _text(
    context,
    size: 16,
    weight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0,
    height: 1.22,
  );

  static TextStyle bodyLarge(BuildContext context) => _text(
    context,
    size: 16,
    weight: FontWeight.w400,
    color: textSecondary,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static TextStyle bodyMedium(BuildContext context) => _text(
    context,
    size: 14,
    weight: FontWeight.w400,
    color: textSecondary,
    letterSpacing: 0.1,
    height: 1.45,
  );

  static TextStyle bodySmall(BuildContext context) => _text(
    context,
    size: isTV(context) ? 14 : 12,
    weight: FontWeight.w400,
    color: textTertiary,
    letterSpacing: 0.15,
    height: 1.4,
  );

  static TextStyle labelLarge(BuildContext context) => _text(
    context,
    size: 14,
    weight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.2,
    height: 1.2,
  );

  static TextStyle labelMedium(BuildContext context) => _text(
    context,
    size: 12,
    weight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.3,
    height: 1.18,
  );

  static TextStyle labelSmall(BuildContext context) => _text(
    context,
    size: 10,
    weight: FontWeight.w600,
    color: textTertiary,
    letterSpacing: 0.5,
    height: 1.12,
  );

  static ThemeData get themeData => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgBase,
    primaryColor: primaryRed,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme.dark(
      primary: primaryRed,
      secondary: prestigeGold,
      surface: bgSurface,
      error: errorRed,
      onPrimary: textPrimary,
      onSecondary: Color(0xFF000000),
      onSurface: textPrimary,
      onError: textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: textPrimary, size: 22),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedItemColor: primaryRed,
      unselectedItemColor: textDisabled,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      selectedIconTheme: const IconThemeData(color: primaryRed, size: 24),
      unselectedIconTheme: const IconThemeData(color: textDisabled, size: 22),
      selectedLabelTextStyle: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: textDisabled,
        fontWeight: FontWeight.w500,
        fontSize: 10,
      ),
      indicatorColor: primaryRed.withValues(alpha: 0.15),
      groupAlignment: -0.7,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: bgElevated,
      disabledColor: bgSurface,
      selectedColor: primaryRed,
      secondarySelectedColor: primaryRed,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: 0.2,
      ),
      secondaryLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      side: BorderSide(color: bgBorder.withValues(alpha: 0.25)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    cardTheme: CardThemeData(
      color: bgSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bgElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: bgBorder.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: bgBorder.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: primaryRed, width: 1.5),
      ),
      hintStyle: const TextStyle(color: textDisabled, fontSize: 14),
      labelStyle: const TextStyle(color: textTertiary, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryRed,
        foregroundColor: textPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textSecondary,
        side: BorderSide(color: bgBorder.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: infoCyan,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryRed,
      linearTrackColor: bgElevated,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: bgOverlay,
      contentTextStyle: const TextStyle(color: textPrimary, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: bgOverlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusXl),
      ),
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(
      color: bgBorder.withValues(alpha: 0.2),
      thickness: 0.5,
      space: 1,
    ),
  );
}
