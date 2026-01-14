import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../constants/app_constants.dart';

/// Utilitaires globaux pour l'application NEO STREAM
class AppUtils {
  
  /// Formate une durée en format lisible (ex: "2h 30min")
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }
  
  /// Formate une durée depuis une chaîne (ex: "150" -> "2h 30min")
  static String formatDurationFromString(String durationStr) {
    final minutes = int.tryParse(durationStr) ?? 0;
    if (minutes <= 0) return 'Durée inconnue';
    
    final duration = Duration(minutes: minutes);
    return formatDuration(duration);
  }
  
  /// Formate une note (ex: 8.5 -> "8.5/10")
  static String formatRating(double rating) {
    if (rating <= 0) return 'Non noté';
    return '${rating.toStringAsFixed(1)}/10';
  }
  
  /// Obtient la couleur selon la note
  static Color getRatingColor(double rating) {
    if (rating >= AppConstants.ratingExcellent) {
      return AppColors.ratingExcellent;
    } else if (rating >= AppConstants.ratingGood) {
      return AppColors.ratingGood;
    } else if (rating >= AppConstants.ratingAverage) {
      return AppColors.ratingAverage;
    } else if (rating >= AppConstants.ratingPoor) {
      return AppColors.ratingPoor;
    } else {
      return AppColors.ratingBad;
    }
  }
  
  /// Formate une date depuis une chaîne ISO
  static String formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'Date inconnue';
    
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      // Si le parsing échoue, essayer d'extraire l'année
      final yearMatch = RegExp(r'\d{4}').firstMatch(dateStr);
      if (yearMatch != null) {
        return yearMatch.group(0)!;
      }
      return dateStr;
    }
  }
  
  /// Extrait l'année depuis une date
  static String extractYear(String dateStr) {
    if (dateStr.isEmpty) return '';
    
    try {
      final date = DateTime.parse(dateStr);
      return date.year.toString();
    } catch (e) {
      final yearMatch = RegExp(r'\d{4}').firstMatch(dateStr);
      return yearMatch?.group(0) ?? '';
    }
  }
  
  /// Formate une taille de fichier
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  /// Valide une URL
  static bool isValidUrl(String url) {
    if (url.isEmpty) return false;
    return RegExp(AppConstants.urlPattern).hasMatch(url);
  }
  
  /// Valide un email
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    return RegExp(AppConstants.emailPattern).hasMatch(email);
  }
  
  /// Nettoie une chaîne de caractères
  static String cleanString(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
  
  /// Tronque un texte avec des points de suspension
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
  
  /// Capitalise la première lettre
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
  
  /// Capitalise chaque mot
  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map(capitalize).join(' ');
  }
  
  /// Génère un ID unique simple
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
  
  /// Copie du texte dans le presse-papiers
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
  
  /// Affiche un SnackBar avec style NEO STREAM
  static void showSnackBar(
    BuildContext context, 
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: backgroundColor ?? AppColors.neonBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        duration: duration,
        action: action,
      ),
    );
  }
  
  /// Affiche un SnackBar de succès
  static void showSuccessSnackBar(BuildContext context, String message) {
    showSnackBar(
      context, 
      message, 
      backgroundColor: AppColors.success,
    );
  }
  
  /// Affiche un SnackBar d'erreur
  static void showErrorSnackBar(BuildContext context, String message) {
    showSnackBar(
      context, 
      message, 
      backgroundColor: AppColors.error,
      duration: const Duration(seconds: 5),
    );
  }
  
  /// Affiche un SnackBar d'avertissement
  static void showWarningSnackBar(BuildContext context, String message) {
    showSnackBar(
      context, 
      message, 
      backgroundColor: AppColors.warning,
    );
  }
  
  /// Affiche un dialogue de confirmation
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirmer',
    String cancelText = 'Annuler',
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cyberDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
          side: BorderSide(
            color: AppColors.neonBlue.withOpacity(0.5),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              cancelText,
              style: TextStyle(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              confirmText,
              style: TextStyle(
                color: confirmColor ?? AppColors.neonBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
  
  /// Affiche un dialogue d'information
  static Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cyberDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
          side: BorderSide(
            color: AppColors.neonBlue.withOpacity(0.5),
          ),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: AppColors.neonBlue,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              buttonText,
              style: TextStyle(
                color: AppColors.neonBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Calcule la taille responsive
  static double getResponsiveSize(BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < AppConstants.mobileBreakpoint) {
      return mobile;
    } else if (width < AppConstants.tabletBreakpoint) {
      return tablet;
    } else {
      return desktop;
    }
  }
  
  /// Obtient le nombre de colonnes pour la grille selon la taille d'écran
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final orientation = MediaQuery.of(context).orientation;
    
    if (width >= AppConstants.tabletBreakpoint) {
      return AppConstants.gridColumnsTablet;
    } else if (orientation == Orientation.landscape) {
      return AppConstants.gridColumnsLandscape;
    } else {
      return AppConstants.gridColumnsPortrait;
    }
  }
  
  /// Vérifie si l'appareil est en mode tablette
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= AppConstants.tabletBreakpoint;
  }
  
  /// Vérifie si l'appareil est en mode mobile
  static bool isMobile(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width < AppConstants.mobileBreakpoint;
  }
  
  /// Débounce pour les recherches
  static Timer? _debounceTimer;
  
  static void debounce(VoidCallback callback, {
    Duration delay = const Duration(milliseconds: 500),
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, callback);
  }
  
  /// Nettoie les ressources
  static void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}