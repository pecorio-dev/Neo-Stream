import 'package:flutter/material.dart';

/// Palette de couleurs cyberpunk pour NEO STREAM
class AppColors {
  // Couleurs principales
  static const Color cyberBlack = Color(0xFF0A0A0F);
  static const Color cyberDark = Color(0xFF1A1A24);
  static const Color cyberGray = Color(0xFF2A2A3A);
  
  // Couleurs néon
  static const Color neonBlue = Color(0xFF00D4FF);
  static const Color neonPurple = Color(0xFF8B5CF6);
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color neonPink = Color(0xFFFF0080);
  static const Color neonYellow = Color(0xFFFFD700);
  
  // Couleurs laser
  static const Color laserRed = Color(0xFFFF0040);
  static const Color laserOrange = Color(0xFFFF8000);
  static const Color neonOrange = Color(0xFFFF8000);
  
  // Couleurs de texte
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF666666);
  static const Color textDisabled = Color(0xFF404040);
  
  // Couleurs de statut
  static const Color success = Color(0xFF00FF88);
  static const Color warning = Color(0xFFFFD700);
  static const Color error = Color(0xFFFF0040);
  static const Color info = Color(0xFF00D4FF);
  
  // Couleurs de rating
  static const Color ratingGold = Color(0xFFFFD700);
  static const Color ratingGreen = Color(0xFF00FF88);
  static const Color ratingOrange = Color(0xFFFF8000);
  static const Color ratingRed = Color(0xFFFF0040);
  
  // Couleurs de rating par niveau
  static const Color ratingExcellent = Color(0xFF00FF88);
  static const Color ratingGood = Color(0xFF00D4FF);
  static const Color ratingAverage = Color(0xFFFFD700);
  static const Color ratingPoor = Color(0xFFFF8000);
  static const Color ratingBad = Color(0xFFFF0040);
  
  // Gradients prédéfinis
  static const List<Color> backgroundGradient = [
    cyberBlack,
    cyberDark,
  ];
  
  static const List<Color> cardGradient = [
    cyberDark,
    cyberGray,
  ];
  
  static const List<Color> neonGradient = [
    neonBlue,
    neonPurple,
  ];
  
  static const List<Color> laserGradient = [
    laserRed,
    laserOrange,
  ];
  
  static const List<Color> successGradient = [
    neonGreen,
    Color(0xFF00CC70),
  ];
  
  // Méthodes utilitaires
  static LinearGradient createGradient(
    List<Color> colors, {
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      colors: colors,
      begin: begin,
      end: end,
    );
  }
  
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
  
  static Color darken(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
  
  static Color lighten(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }
  
  // Couleurs spécifiques aux composants
  static const Color shimmerBase = Color(0xFF2A2A3A);
  static const Color shimmerHighlight = Color(0xFF3A3A4A);
  
  static const Color divider = Color(0xFF404040);
  static const Color border = Color(0xFF505050);
  
  static const Color overlay = Color(0x80000000);
  static const Color modalBarrier = Color(0x80000000);
  
  // Couleurs pour les différents types de contenu
  static const Color movieAccent = neonBlue;
  static const Color seriesAccent = neonPurple;
  static const Color animeAccent = neonPink;
  static const Color documentaryAccent = neonGreen;
  
  // Couleurs pour les genres
  static const Map<String, Color> genreColors = {
    'Action': laserRed,
    'Adventure': neonGreen,
    'Animation': neonPink,
    'Comedy': neonYellow,
    'Crime': Color(0xFF8B0000),
    'Documentary': neonGreen,
    'Drama': neonPurple,
    'Family': Color(0xFFFFB6C1),
    'Fantasy': Color(0xFF9370DB),
    'History': Color(0xFFCD853F),
    'Horror': Color(0xFF8B0000),
    'Music': neonYellow,
    'Mystery': Color(0xFF4B0082),
    'Romance': neonPink,
    'Science Fiction': neonBlue,
    'TV Movie': Color(0xFF20B2AA),
    'Thriller': laserRed,
    'War': Color(0xFF696969),
    'Western': Color(0xFFD2691E),
  };
  
  static Color getGenreColor(String genre) {
    return genreColors[genre] ?? neonBlue;
  }
}