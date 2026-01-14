import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class Helpers {
  // Formatage des notes
  static String formatRating(double rating) {
    if (rating <= 0) return 'N/A';
    return rating.toStringAsFixed(1);
  }

  // Formatage des durées
  static String formatDuration(int minutes) {
    if (minutes <= 0) return '';
    
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${remainingMinutes}min';
    } else {
      return '${minutes}min';
    }
  }

  // Formatage des années
  static String formatYear(int year) {
    if (year <= 0) return 'Année inconnue';
    return year.toString();
  }

  // Formatage des genres
  static String formatGenres(List<String> genres, {int maxGenres = 3}) {
    if (genres.isEmpty) return '';
    
    final cleanGenres = genres.where((g) => g.isNotEmpty).toList();
    if (cleanGenres.isEmpty) return '';
    
    final displayGenres = cleanGenres.take(maxGenres).toList();
    return displayGenres.join(', ');
  }

  // Couleur basée sur la note
  static Color getRatingColor(double rating) {
    if (rating >= 8.0) return Colors.green;
    if (rating >= 6.0) return Colors.orange;
    if (rating >= 4.0) return Colors.red;
    return AppTheme.textSecondary;
  }

  // Icône basée sur la qualité
  static IconData getQualityIcon(String quality) {
    switch (quality.toUpperCase()) {
      case 'HD':
      case 'FULL HD':
        return Icons.hd;
      case '4K':
      case 'UHD':
        return Icons.four_k;
      case 'SD':
        return Icons.sd;
      default:
        return Icons.video_library;
    }
  }

  // Couleur basée sur la qualité
  static Color getQualityColor(String quality) {
    switch (quality.toUpperCase()) {
      case 'HD':
      case 'FULL HD':
        return Colors.blue;
      case '4K':
      case 'UHD':
        return Colors.purple;
      case 'SD':
        return Colors.orange;
      default:
        return AppTheme.textSecondary;
    }
  }

  // Validation d'URL d'image
  static bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && 
             (uri.scheme == 'http' || uri.scheme == 'https') &&
             (url.toLowerCase().endsWith('.jpg') ||
              url.toLowerCase().endsWith('.jpeg') ||
              url.toLowerCase().endsWith('.png') ||
              url.toLowerCase().endsWith('.webp') ||
              url.toLowerCase().contains('poster') ||
              url.toLowerCase().contains('image'));
    } catch (e) {
      return false;
    }
  }

  // Formatage du synopsis
  static String formatSynopsis(String synopsis, {int maxLength = 150}) {
    if (synopsis.isEmpty) return 'Aucun synopsis disponible.';
    
    if (synopsis.length <= maxLength) return synopsis;
    
    // Trouver le dernier espace avant la limite
    int cutIndex = maxLength;
    while (cutIndex > 0 && synopsis[cutIndex] != ' ') {
      cutIndex--;
    }
    
    if (cutIndex == 0) cutIndex = maxLength;
    
    return '${synopsis.substring(0, cutIndex)}...';
  }

  // Détection du type de contenu
  static bool isMovie(String type) {
    return type.toLowerCase() == 'movie';
  }

  static bool isSeries(String type) {
    return type.toLowerCase() == 'series';
  }

  // Formatage des acteurs
  static String formatActors(List<String> actors, {int maxActors = 3}) {
    if (actors.isEmpty) return '';
    
    final displayActors = actors.take(maxActors).toList();
    return displayActors.join(', ');
  }

  // Génération d'un ID unique pour les films
  static String generateMovieId(String url) {
    // Extraire l'ID depuis l'URL CpasMieux
    final regex = RegExp(r'/(\d+)-');
    final match = regex.firstMatch(url);
    
    if (match != null) {
      return match.group(1) ?? url.hashCode.toString();
    }
    
    return url.hashCode.toString();
  }

  // Validation de la version linguistique
  static List<String> parseLanguageVersion(String version) {
    final languages = <String>[];
    
    if (version.contains('VF')) languages.add('VF');
    if (version.contains('VOSTFR')) languages.add('VOSTFR');
    if (version.contains('VO')) languages.add('VO');
    if (version.contains('French')) languages.add('Français');
    if (version.contains('TrueFrench')) languages.add('TrueFrench');
    
    return languages;
  }

  // Formatage de la taille de fichier
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Calcul de la couleur dominante d'une image (placeholder)
  static Color getDominantColor(String imageUrl) {
    // Pour l'instant, retourner une couleur basée sur le hash de l'URL
    final hash = imageUrl.hashCode;
    final colors = [
      AppTheme.accentNeon,
      AppTheme.accentSecondary,
      Colors.purple,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
    ];
    
    return colors[hash.abs() % colors.length];
  }

  // Debounce pour les recherches
  static void debounce(
    Duration duration,
    VoidCallback callback,
    Timer? timer,
  ) {
    timer?.cancel();
    timer = Timer(duration, callback);
  }

  // Formatage des dates relatives
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return 'Il y a $years an${years > 1 ? 's' : ''}';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return 'Il y a $months mois';
    } else if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }

  // Validation des données de film
  static bool isValidMovie(Map<String, dynamic> movieData) {
    return movieData.containsKey('title') &&
           movieData.containsKey('url') &&
           movieData['title'] != null &&
           movieData['title'].toString().isNotEmpty;
  }

  // Nettoyage des chaînes de caractères
  static String cleanString(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  // Extraction du nom de serveur depuis une URL
  static String extractServerName(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceAll('www.', '');
    } catch (e) {
      return 'Serveur inconnu';
    }
  }

  // Génération d'une couleur aléatoire pour les placeholders
  static Color generatePlaceholderColor(String seed) {
    final hash = seed.hashCode;
    final hue = (hash % 360).toDouble();
    return HSVColor.fromAHSV(1.0, hue, 0.3, 0.8).toColor();
  }
}

// Extension pour les chaînes de caractères
extension StringExtensions on String {
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }

  String get capitalizeWords {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  bool get isValidUrl {
    try {
      final uri = Uri.parse(this);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}

// Extension pour les listes
extension ListExtensions<T> on List<T> {
  List<T> get unique {
    return toSet().toList();
  }

  T? get firstOrNull {
    return isEmpty ? null : first;
  }

  T? get lastOrNull {
    return isEmpty ? null : last;
  }
}

