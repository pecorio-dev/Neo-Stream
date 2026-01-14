import '../constants/app_constants.dart';

/// Classe de validation pour les formulaires
class Validators {
  
  /// Valide un email
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'L\'email est requis';
    }
    
    if (!RegExp(AppConstants.emailPattern).hasMatch(value)) {
      return 'Format d\'email invalide';
    }
    
    return null;
  }
  
  /// Valide un mot de passe
  static String? password(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }
    
    if (value.length < minLength) {
      return 'Le mot de passe doit contenir au moins $minLength caractères';
    }
    
    return null;
  }
  
  /// Valide un mot de passe fort
  static String? strongPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }
    
    if (value.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères';
    }
    
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Le mot de passe doit contenir au moins une majuscule';
    }
    
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Le mot de passe doit contenir au moins une minuscule';
    }
    
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Le mot de passe doit contenir au moins un chiffre';
    }
    
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Le mot de passe doit contenir au moins un caractère spécial';
    }
    
    return null;
  }
  
  /// Valide la confirmation de mot de passe
  static String? confirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'La confirmation du mot de passe est requise';
    }
    
    if (value != password) {
      return 'Les mots de passe ne correspondent pas';
    }
    
    return null;
  }
  
  /// Valide un nom d'utilisateur
  static String? username(String? value, {int minLength = 3, int maxLength = 20}) {
    if (value == null || value.isEmpty) {
      return 'Le nom d\'utilisateur est requis';
    }
    
    if (value.length < minLength) {
      return 'Le nom d\'utilisateur doit contenir au moins $minLength caractères';
    }
    
    if (value.length > maxLength) {
      return 'Le nom d\'utilisateur ne peut pas dépasser $maxLength caractères';
    }
    
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Le nom d\'utilisateur ne peut contenir que des lettres, chiffres et underscores';
    }
    
    return null;
  }
  
  /// Valide un nom complet
  static String? fullName(String? value, {int minLength = 2}) {
    if (value == null || value.isEmpty) {
      return 'Le nom complet est requis';
    }
    
    if (value.trim().length < minLength) {
      return 'Le nom doit contenir au moins $minLength caractères';
    }
    
    if (!RegExp(r'^[a-zA-ZÀ-ÿ\s]+$').hasMatch(value)) {
      return 'Le nom ne peut contenir que des lettres et espaces';
    }
    
    return null;
  }
  
  /// Valide un numéro de téléphone
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le numéro de téléphone est requis';
    }
    
    // Supprimer les espaces et caractères spéciaux
    final cleanPhone = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    if (!RegExp(AppConstants.phonePattern).hasMatch(cleanPhone)) {
      return 'Format de numéro de téléphone invalide';
    }
    
    return null;
  }
  
  /// Valide une URL
  static String? url(String? value) {
    if (value == null || value.isEmpty) {
      return 'L\'URL est requise';
    }
    
    if (!RegExp(AppConstants.urlPattern).hasMatch(value)) {
      return 'Format d\'URL invalide';
    }
    
    return null;
  }
  
  /// Valide un champ requis
  static String? required(String? value, {String fieldName = 'Ce champ'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName est requis';
    }
    
    return null;
  }
  
  /// Valide la longueur minimale
  static String? minLength(String? value, int minLength, {String fieldName = 'Ce champ'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName est requis';
    }
    
    if (value.length < minLength) {
      return '$fieldName doit contenir au moins $minLength caractères';
    }
    
    return null;
  }
  
  /// Valide la longueur maximale
  static String? maxLength(String? value, int maxLength, {String fieldName = 'Ce champ'}) {
    if (value != null && value.length > maxLength) {
      return '$fieldName ne peut pas dépasser $maxLength caractères';
    }
    
    return null;
  }
  
  /// Valide une plage de longueur
  static String? lengthRange(String? value, int minLength, int maxLength, {String fieldName = 'Ce champ'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName est requis';
    }
    
    if (value.length < minLength || value.length > maxLength) {
      return '$fieldName doit contenir entre $minLength et $maxLength caractères';
    }
    
    return null;
  }
  
  /// Valide un nombre entier
  static String? integer(String? value, {String fieldName = 'Ce champ'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName est requis';
    }
    
    if (int.tryParse(value) == null) {
      return '$fieldName doit être un nombre entier';
    }
    
    return null;
  }
  
  /// Valide un nombre décimal
  static String? decimal(String? value, {String fieldName = 'Ce champ'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName est requis';
    }
    
    if (double.tryParse(value) == null) {
      return '$fieldName doit être un nombre';
    }
    
    return null;
  }
  
  /// Valide une plage de nombres
  static String? numberRange(String? value, double min, double max, {String fieldName = 'Ce champ'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName est requis';
    }
    
    final number = double.tryParse(value);
    if (number == null) {
      return '$fieldName doit être un nombre';
    }
    
    if (number < min || number > max) {
      return '$fieldName doit être entre $min et $max';
    }
    
    return null;
  }
  
  /// Valide une date
  static String? date(String? value, {String fieldName = 'La date'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName est requise';
    }
    
    try {
      DateTime.parse(value);
      return null;
    } catch (e) {
      return 'Format de date invalide';
    }
  }
  
  /// Valide une date dans le futur
  static String? futureDate(String? value, {String fieldName = 'La date'}) {
    final dateError = date(value, fieldName: fieldName);
    if (dateError != null) return dateError;
    
    final parsedDate = DateTime.parse(value!);
    if (parsedDate.isBefore(DateTime.now())) {
      return '$fieldName doit être dans le futur';
    }
    
    return null;
  }
  
  /// Valide une date dans le passé
  static String? pastDate(String? value, {String fieldName = 'La date'}) {
    final dateError = date(value, fieldName: fieldName);
    if (dateError != null) return dateError;
    
    final parsedDate = DateTime.parse(value!);
    if (parsedDate.isAfter(DateTime.now())) {
      return '$fieldName doit être dans le passé';
    }
    
    return null;
  }
  
  /// Valide l'âge minimum
  static String? minimumAge(String? value, int minAge, {String fieldName = 'La date de naissance'}) {
    final dateError = pastDate(value, fieldName: fieldName);
    if (dateError != null) return dateError;
    
    final birthDate = DateTime.parse(value!);
    final age = DateTime.now().difference(birthDate).inDays ~/ 365;
    
    if (age < minAge) {
      return 'Vous devez avoir au moins $minAge ans';
    }
    
    return null;
  }
  
  /// Valide une liste de valeurs autorisées
  static String? oneOf(String? value, List<String> allowedValues, {String fieldName = 'Ce champ'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName est requis';
    }
    
    if (!allowedValues.contains(value)) {
      return '$fieldName doit être l\'une des valeurs suivantes: ${allowedValues.join(', ')}';
    }
    
    return null;
  }
  
  /// Valide avec une expression régulière personnalisée
  static String? pattern(String? value, String pattern, String errorMessage) {
    if (value == null || value.isEmpty) {
      return 'Ce champ est requis';
    }
    
    if (!RegExp(pattern).hasMatch(value)) {
      return errorMessage;
    }
    
    return null;
  }
  
  /// Combine plusieurs validateurs
  static String? Function(String?) combine(List<String? Function(String?)> validators) {
    return (String? value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) return error;
      }
      return null;
    };
  }
  
  /// Valide seulement si la condition est vraie
  static String? Function(String?) conditional(
    bool condition,
    String? Function(String?) validator,
  ) {
    return (String? value) {
      if (condition) {
        return validator(value);
      }
      return null;
    };
  }
  
  /// Valide une recherche
  static String? search(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // La recherche peut être vide
    }
    
    if (value.trim().length < AppConstants.minSearchLength) {
      return 'La recherche doit contenir au moins ${AppConstants.minSearchLength} caractères';
    }
    
    if (value.length > AppConstants.maxSearchLength) {
      return 'La recherche ne peut pas dépasser ${AppConstants.maxSearchLength} caractères';
    }
    
    return null;
  }
  
  /// Valide un titre de contenu
  static String? contentTitle(String? value) {
    return combine([
      required,
      (value) => minLength(value, 1, fieldName: 'Le titre'),
      (value) => maxLength(value, 200, fieldName: 'Le titre'),
    ])(value);
  }
  
  /// Valide une description
  static String? description(String? value, {bool isRequired = false}) {
    if (!isRequired && (value == null || value.trim().isEmpty)) {
      return null;
    }
    
    return combine([
      if (isRequired) required,
      (value) => maxLength(value, 1000, fieldName: 'La description'),
    ])(value);
  }
  
  /// Valide une note (rating)
  static String? rating(String? value) {
    return combine([
      decimal,
      (value) => numberRange(value, 0.0, 10.0, fieldName: 'La note'),
    ])(value);
  }
}