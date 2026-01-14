import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_system/color_system.dart';

class AppTheme {
  // Compatibilité avec l'ancien système tout en utilisant ColorSystem

  // NeoStream Color Palette - pour compatibilité
  static const Color backgroundPrimary = Color(0xFF0A0A0F);
  static const Color backgroundSecondary = Color(0xFF1A1A24);
  static const Color surface = Color(0xFF2A2A3A);

  // Accent Colors - pour compatibilité
  static const Color accentNeon = Color(0xFF00D4FF);
  static const Color accentSecondary = Color(0xFF8B5CF6);
  static const Color focusColor = Color(0xFF00F5FF);

  // Status Colors - pour compatibilité
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);

  // Rating Color - pour compatibilité
  static const Color ratingColor = Color(0xFFFFD700);

  // Text Colors - pour compatibilité
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF666666);

  // Box Shadows - pour compatibilité
  static List<BoxShadow> get neonShadow => [
    BoxShadow(
      color: accentNeon.withOpacity(0.15),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: ColorSystem.neonCyan,
      scaffoldBackgroundColor: ColorSystem.backgroundPrimary,
      colorScheme: ColorScheme.dark(
        primary: ColorSystem.neonCyan,
        secondary: ColorSystem.neonPurple,
        surface: ColorSystem.backgroundTertiary,
        error: ColorSystem.errorColor,
        onPrimary: ColorSystem.textPrimary,
        onSecondary: ColorSystem.textPrimary,
        onSurface: ColorSystem.textPrimary,
        onError: ColorSystem.textPrimary,
      ),
      
      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.orbitron(
          color: ColorSystem.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(
          color: ColorSystem.neonCyan,
          size: 24,
        ),
      ),
      
      // Text Theme
      textTheme: TextTheme(
        displayLarge: GoogleFonts.orbitron(
          color: ColorSystem.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.orbitron(
          color: ColorSystem.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: GoogleFonts.orbitron(
          color: ColorSystem.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: GoogleFonts.rajdhani(
          color: ColorSystem.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.rajdhani(
          color: ColorSystem.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: GoogleFonts.rajdhani(
          color: ColorSystem.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: GoogleFonts.rajdhani(
          color: ColorSystem.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.rajdhani(
          color: ColorSystem.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: GoogleFonts.rajdhani(
          color: ColorSystem.textTertiary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.rajdhani(
          color: ColorSystem.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: GoogleFonts.rajdhani(
          color: ColorSystem.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        bodySmall: GoogleFonts.rajdhani(
          color: ColorSystem.textTertiary,
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
        labelLarge: GoogleFonts.rajdhani(
          color: ColorSystem.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: GoogleFonts.rajdhani(
          color: ColorSystem.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: GoogleFonts.rajdhani(
          color: ColorSystem.textTertiary,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: ColorSystem.backgroundTertiary,
        elevation: 8,
        shadowColor: ColorSystem.neonCyan.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ColorSystem.backgroundSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: ColorSystem.neonCyan.withOpacity(0.3),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(
            color: ColorSystem.neonCyan,
            width: 2,
          ),
        ),
        hintStyle: GoogleFonts.rajdhani(
          color: ColorSystem.textTertiary,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.rajdhani(
          color: ColorSystem.textSecondary,
          fontSize: 14,
        ),
        prefixIconColor: ColorSystem.neonCyan,
        suffixIconColor: ColorSystem.neonCyan,
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorSystem.neonCyan,
          foregroundColor: ColorSystem.backgroundPrimary,
          elevation: 8,
          shadowColor: ColorSystem.neonCyan.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.rajdhani(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(
        color: ColorSystem.neonCyan,
        size: 24,
      ),
      
      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: ColorSystem.backgroundTertiary,
        selectedItemColor: ColorSystem.neonCyan,
        unselectedItemColor: ColorSystem.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 16,
        selectedLabelStyle: GoogleFonts.rajdhani(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: GoogleFonts.rajdhani(
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
      ),
      
      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: ColorSystem.neonCyan,
        inactiveTrackColor: ColorSystem.backgroundSecondary,
        thumbColor: ColorSystem.neonCyan,
        overlayColor: ColorSystem.neonCyan.withOpacity(0.2),
        valueIndicatorColor: ColorSystem.neonCyan,
        valueIndicatorTextStyle: GoogleFonts.rajdhani(
          color: ColorSystem.backgroundPrimary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      
      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ColorSystem.neonCyan,
        linearTrackColor: ColorSystem.backgroundSecondary,
        circularTrackColor: ColorSystem.backgroundSecondary,
      ),
      
      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: ColorSystem.backgroundSecondary,
        thickness: 1,
        space: 1,
      ),
    );
  }
  
  // Custom Gradients
  static const LinearGradient neonGradient = LinearGradient(
    colors: [accentNeon, accentSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    colors: [surface, backgroundSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Box Shadows (compatibilité - déjà définis plus haut)
  
  // Custom Box Decorations
  static BoxDecoration get neonGlowDecoration => BoxDecoration(
    color: ColorSystem.backgroundPrimary.withOpacity(0.3),
    borderRadius: BorderRadius.circular(28),
    boxShadow: [
      BoxShadow(
        color: ColorSystem.neonCyan.withOpacity(0.4),
        blurRadius: 20,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: ColorSystem.neonPurple.withOpacity(0.3),
        blurRadius: 40,
        spreadRadius: 0,
      ),
    ],
  );
  
  static BoxDecoration get cardGlowDecoration => BoxDecoration(
    gradient: cardGradient,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: ColorSystem.neonCyan.withOpacity(0.2),
        blurRadius: 16,
        spreadRadius: 0,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration get backgroundGradientDecoration => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [backgroundPrimary, backgroundSecondary],
    ),
  );
}