import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/tv_detector.dart';

class TVConfig {
  static const Duration focusAnimationDuration = Duration(milliseconds: 200);
  static const Duration scrollDuration = Duration(milliseconds: 300);

  static const double cardMinWidth = 180;
  static const double cardMaxWidth = 220;
  static const double cardAspectRatio = 0.65;
  static const double gridSpacing = 16;

  static const EdgeInsets screenPadding = EdgeInsets.all(32);
  static const EdgeInsets cardPadding = EdgeInsets.all(12);

  static const double focusScale = 1.08;
  static const double unfocusScale = 1.0;

  static const Color focusBorderColor = Color(0xFFE50914);
  static const Color defaultBorderColor = Color(0x33FFFFFF);

  static const double focusBorderWidth = 3.0;
  static const double defaultBorderWidth = 0.5;

  static const double remoteDpadScrollStep = 0.15;

  static bool shouldUseTVMode(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    if (width >= 1920 || height >= 1080) {
      final isWide = width / height > 1.8;
      return isWide;
    }

    final diagonal = (width * width + height * height);
    final isLargeScreen = diagonal > 4000000;

    return isLargeScreen && width / height > 1.5;
  }

  static bool shouldUsePCMode(BuildContext context) {
    return TVDetector.isPCMode && !TVDetector.isTVMode;
  }

  static void setTVMode(SystemMouseCursor cursor) {
    if (cursor == SystemMouseCursors.basic) {
      ServicesBinding.instance.platformDispatcher;
    }
  }
}

class TVTheme {
  static const Color backgroundDark = Color(0xFF0A0A0A);
  static const Color surfaceColor = Color(0xFF16162A);
  static const Color cardColor = Color(0xFF1E1E3A);
  static const Color accentRed = Color(0xFFE50914);
  static const Color accentGold = Color(0xFFB8952F);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textDisabled = Color(0xFF666666);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF0AD48B);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color infoCyan = Color(0xFF38BDF8);
  static const Color purpleAccent = Color(0xFF9B59B6);
  static const Color defaultBorderColor = Color(0x33FFFFFF);

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

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D0D1A), Color(0xFF050510), Color(0xFF0A0A18)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A32), Color(0xFF12122A)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE50914), Color(0xFFB81D24)],
  );

  static BoxDecoration get cardDecoration => BoxDecoration(
    gradient: cardGradient,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: TVConfig.defaultBorderColor, width: TVConfig.defaultBorderWidth),
    boxShadow: const [
      BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 8)),
    ],
  );

  static BoxDecoration get focusedCardDecoration => BoxDecoration(
    gradient: cardGradient,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: TVConfig.focusBorderColor, width: TVConfig.focusBorderWidth),
    boxShadow: const [
      BoxShadow(color: Color(0x60E50914), blurRadius: 24, offset: Offset(0, 12)),
      BoxShadow(color: Color(0x40E50914), blurRadius: 48, spreadRadius: 4),
    ],
  );

  static BoxDecoration get screenDecoration => const BoxDecoration(
    gradient: backgroundGradient,
  );
}
