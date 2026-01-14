import 'package:flutter/material.dart';
import '../utils/app_utils.dart';

/// Extensions pour String
extension StringExtensions on String {
  /// Capitalise la première lettre
  String get capitalize => AppUtils.capitalize(this);
  
  /// Capitalise chaque mot
  String get capitalizeWords => AppUtils.capitalizeWords(this);
  
  /// Nettoie la chaîne
  String get clean => AppUtils.cleanString(this);
  
  /// Tronque le texte
  String truncate(int maxLength) => AppUtils.truncateText(this, maxLength);
  
  /// Vérifie si c'est une URL valide
  bool get isValidUrl => AppUtils.isValidUrl(this);
  
  /// Vérifie si c'est un email valide
  bool get isValidEmail => AppUtils.isValidEmail(this);
  
  /// Vérifie si la chaîne est vide ou null
  bool get isNullOrEmpty => isEmpty;
  
  /// Vérifie si la chaîne n'est pas vide
  bool get isNotNullOrEmpty => isNotEmpty;
  
  /// Extrait l'année depuis une date
  String get extractYear => AppUtils.extractYear(this);
  
  /// Formate comme une date
  String get formatDate => AppUtils.formatDate(this);
  
  /// Convertit en couleur (hex)
  Color? get toColor {
    try {
      String hex = replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return null;
    }
  }
}

/// Extensions pour double
extension DoubleExtensions on double {
  /// Formate comme une note
  String get formatRating => AppUtils.formatRating(this);
  
  /// Obtient la couleur selon la note
  Color get ratingColor => AppUtils.getRatingColor(this);
  
  /// Arrondit à n décimales
  double roundTo(int decimals) {
    final factor = 1.0 * (10 * decimals);
    return (this * factor).round() / factor;
  }
  
  /// Convertit en pourcentage
  String get toPercentage => '${(this * 100).toStringAsFixed(1)}%';
  
  /// Vérifie si c'est un nombre valide
  bool get isValid => !isNaN && isFinite;
}

/// Extensions pour int
extension IntExtensions on int {
  /// Formate comme une taille de fichier
  String get formatFileSize => AppUtils.formatFileSize(this);
  
  /// Convertit en Duration (minutes)
  Duration get minutes => Duration(minutes: this);
  
  /// Convertit en Duration (secondes)
  Duration get seconds => Duration(seconds: this);
  
  /// Convertit en Duration (heures)
  Duration get hours => Duration(hours: this);
  
  /// Formate avec des séparateurs de milliers
  String get withThousandsSeparator {
    return toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }
}

/// Extensions pour Duration
extension DurationExtensions on Duration {
  /// Formate en format lisible
  String get format => AppUtils.formatDuration(this);
  
  /// Obtient les heures
  int get hoursOnly => inHours;
  
  /// Obtient les minutes restantes
  int get minutesOnly => inMinutes.remainder(60);
  
  /// Obtient les secondes restantes
  int get secondsOnly => inSeconds.remainder(60);
  
  /// Formate en HH:MM:SS
  String get toHHMMSS {
    final hours = hoursOnly.toString().padLeft(2, '0');
    final minutes = minutesOnly.toString().padLeft(2, '0');
    final seconds = secondsOnly.toString().padLeft(2, '0');
    
    if (hoursOnly > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }
  
  /// Formate en MM:SS
  String get toMMSS {
    final minutes = inMinutes.toString().padLeft(2, '0');
    final seconds = secondsOnly.toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// Extensions pour DateTime
extension DateTimeExtensions on DateTime {
  /// Formate en date courte
  String get formatShort => AppUtils.formatDate(toIso8601String());
  
  /// Obtient l'année
  String get yearString => year.toString();
  
  /// Vérifie si c'est aujourd'hui
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
  
  /// Vérifie si c'est hier
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }
  
  /// Obtient le temps relatif (ex: "il y a 2 heures")
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(this);
    
    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return 'il y a $years an${years > 1 ? 's' : ''}';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return 'il y a $months mois';
    } else if (difference.inDays > 0) {
      return 'il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'à l\'instant';
    }
  }
}

/// Extensions pour List
extension ListExtensions<T> on List<T> {
  /// Vérifie si la liste n'est pas vide
  bool get isNotNullOrEmpty => isNotEmpty;
  
  /// Obtient un élément de manière sécurisée
  T? safeGet(int index) {
    if (index >= 0 && index < length) {
      return this[index];
    }
    return null;
  }
  
  /// Divise la liste en chunks
  List<List<T>> chunk(int size) {
    final chunks = <List<T>>[];
    for (int i = 0; i < length; i += size) {
      chunks.add(sublist(i, (i + size > length) ? length : i + size));
    }
    return chunks;
  }
  
  /// Supprime les doublons
  List<T> get unique => toSet().toList();
  
  /// Mélange la liste
  List<T> get shuffled {
    final list = List<T>.from(this);
    list.shuffle();
    return list;
  }
}

/// Extensions pour Color
extension ColorExtensions on Color {
  /// Obtient la couleur avec opacité
  Color withOpacityValue(double opacity) => withOpacity(opacity.clamp(0.0, 1.0));
  
  /// Convertit en hex
  String get toHex {
    return '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
  
  /// Obtient une version plus claire
  Color get lighter {
    return Color.lerp(this, Colors.white, 0.2) ?? this;
  }
  
  /// Obtient une version plus sombre
  Color get darker {
    return Color.lerp(this, Colors.black, 0.2) ?? this;
  }
  
  /// Vérifie si la couleur est claire
  bool get isLight {
    return computeLuminance() > 0.5;
  }
  
  /// Vérifie si la couleur est sombre
  bool get isDark => !isLight;
  
  /// Obtient la couleur de contraste
  Color get contrastColor => isLight ? Colors.black : Colors.white;
}

/// Extensions pour BuildContext
extension BuildContextExtensions on BuildContext {
  /// Obtient le thème
  ThemeData get theme => Theme.of(this);
  
  /// Obtient les couleurs du thème
  ColorScheme get colors => theme.colorScheme;
  
  /// Obtient le style de texte
  TextTheme get textTheme => theme.textTheme;
  
  /// Obtient la taille de l'écran
  Size get screenSize => MediaQuery.of(this).size;
  
  /// Obtient la largeur de l'écran
  double get screenWidth => screenSize.width;
  
  /// Obtient la hauteur de l'écran
  double get screenHeight => screenSize.height;
  
  /// Vérifie si c'est un mobile
  bool get isMobile => AppUtils.isMobile(this);
  
  /// Vérifie si c'est une tablette
  bool get isTablet => AppUtils.isTablet(this);
  
  /// Obtient le nombre de colonnes pour la grille
  int get gridColumns => AppUtils.getGridColumns(this);
  
  /// Affiche un SnackBar
  void showSnackBar(String message, {Color? backgroundColor}) {
    AppUtils.showSnackBar(this, message, backgroundColor: backgroundColor);
  }
  
  /// Affiche un SnackBar de succès
  void showSuccessSnackBar(String message) {
    AppUtils.showSuccessSnackBar(this, message);
  }
  
  /// Affiche un SnackBar d'erreur
  void showErrorSnackBar(String message) {
    AppUtils.showErrorSnackBar(this, message);
  }
  
  /// Affiche un SnackBar d'avertissement
  void showWarningSnackBar(String message) {
    AppUtils.showWarningSnackBar(this, message);
  }
  
  /// Affiche un dialogue de confirmation
  Future<bool> showConfirmDialog({
    required String title,
    required String message,
    String confirmText = 'Confirmer',
    String cancelText = 'Annuler',
    Color? confirmColor,
  }) {
    return AppUtils.showConfirmDialog(
      this,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      confirmColor: confirmColor,
    );
  }
  
  /// Affiche un dialogue d'information
  Future<void> showInfoDialog({
    required String title,
    required String message,
    String buttonText = 'OK',
  }) {
    return AppUtils.showInfoDialog(
      this,
      title: title,
      message: message,
      buttonText: buttonText,
    );
  }
}

/// Extensions pour Widget
extension WidgetExtensions on Widget {
  /// Ajoute un padding
  Widget paddingAll(double value) => Padding(
    padding: EdgeInsets.all(value),
    child: this,
  );
  
  /// Ajoute un padding symétrique
  Widget paddingSymmetric({double horizontal = 0, double vertical = 0}) => Padding(
    padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
    child: this,
  );
  
  /// Ajoute un padding seulement
  Widget paddingOnly({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) => Padding(
    padding: EdgeInsets.only(left: left, top: top, right: right, bottom: bottom),
    child: this,
  );
  
  /// Centre le widget
  Widget get center => Center(child: this);
  
  /// Étend le widget
  Widget get expanded => Expanded(child: this);
  
  /// Rend le widget flexible
  Widget flexible({int flex = 1}) => Flexible(flex: flex, child: this);
  
  /// Ajoute une zone cliquable
  Widget onTap(VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: this,
  );
  
  /// Rend le widget visible/invisible
  Widget visible(bool visible) => Visibility(
    visible: visible,
    child: this,
  );
  
  /// Ajoute une animation de fondu
  Widget fadeIn({Duration duration = const Duration(milliseconds: 300)}) => AnimatedOpacity(
    opacity: 1.0,
    duration: duration,
    child: this,
  );
}