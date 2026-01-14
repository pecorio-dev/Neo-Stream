import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/security_question.dart';

class ProfileSecurityService {
  /// Génère un hash sécurisé pour un mot de passe
  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Génère un salt aléatoire
  static String generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64.encode(saltBytes);
  }

  /// Vérifie un mot de passe
  static bool verifyPassword(String password, String hash, String salt) {
    final computedHash = hashPassword(password, salt);
    return computedHash == hash;
  }

  /// Hash une réponse de sécurité
  static String hashSecurityAnswer(String answer) {
    final normalizedAnswer = SecurityQuestion.normalizeAnswer(answer);
    final bytes = utf8.encode(normalizedAnswer);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Vérifie une réponse de sécurité
  static bool verifySecurityAnswer(String answer, String hash) {
    final computedHash = hashSecurityAnswer(answer);
    return computedHash == hash;
  }

  /// Configure la sécurité d'un profil
  static UserProfile setProfileSecurity({
    required UserProfile profile,
    required String password,
    required int securityQuestionId,
    required String securityAnswer,
  }) {
    final salt = generateSalt();
    final passwordHash = '$salt:${hashPassword(password, salt)}';
    final answerHash = hashSecurityAnswer(securityAnswer);

    return profile.copyWith(
      hasPassword: true,
      passwordHash: passwordHash,
      securityQuestionId: securityQuestionId,
      securityAnswerHash: answerHash,
      isLocked: false,
    );
  }

  /// Supprime la sécurité d'un profil
  static UserProfile removeProfileSecurity(UserProfile profile) {
    return profile.copyWith(
      hasPassword: false,
      passwordHash: null,
      securityQuestionId: null,
      securityAnswerHash: null,
      isLocked: false,
    );
  }

  /// Authentifie un profil avec un mot de passe
  static bool authenticateProfile(UserProfile profile, String password) {
    if (!profile.hasPassword || profile.passwordHash == null) {
      return true; // Pas de mot de passe défini
    }

    try {
      final parts = profile.passwordHash!.split(':');
      if (parts.length != 2) return false;

      final salt = parts[0];
      final hash = parts[1];

      return verifyPassword(password, hash, salt);
    } catch (e) {
      return false;
    }
  }

  /// Récupère l'accès via la question de sécurité
  static bool recoverProfileAccess(UserProfile profile, String securityAnswer) {
    if (profile.securityAnswerHash == null) {
      return false;
    }

    return verifySecurityAnswer(securityAnswer, profile.securityAnswerHash!);
  }

  /// Verrouille un profil après plusieurs tentatives échouées
  static UserProfile lockProfile(UserProfile profile) {
    return profile.copyWith(isLocked: true);
  }

  /// Déverrouille un profil
  static UserProfile unlockProfile(UserProfile profile) {
    return profile.copyWith(isLocked: false);
  }

  /// Change le mot de passe d'un profil
  static UserProfile changePassword({
    required UserProfile profile,
    required String newPassword,
  }) {
    if (!profile.hasPassword) {
      throw Exception('Le profil n\'a pas de mot de passe défini');
    }

    final salt = generateSalt();
    final passwordHash = '$salt:${hashPassword(newPassword, salt)}';

    return profile.copyWith(
      passwordHash: passwordHash,
      isLocked: false,
    );
  }

  /// Change la question de sécurité d'un profil
  static UserProfile changeSecurityQuestion({
    required UserProfile profile,
    required int securityQuestionId,
    required String securityAnswer,
  }) {
    final answerHash = hashSecurityAnswer(securityAnswer);

    return profile.copyWith(
      securityQuestionId: securityQuestionId,
      securityAnswerHash: answerHash,
    );
  }

  /// Valide la force d'un mot de passe
  static PasswordStrength validatePasswordStrength(String password) {
    if (password.length < 4) {
      return PasswordStrength.tooShort;
    }
    if (password.length < 6) {
      return PasswordStrength.weak;
    }
    if (password.length < 8) {
      return PasswordStrength.medium;
    }
    
    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    int criteria = 0;
    if (hasUpper) criteria++;
    if (hasLower) criteria++;
    if (hasDigit) criteria++;
    if (hasSpecial) criteria++;

    if (criteria >= 3 && password.length >= 8) {
      return PasswordStrength.strong;
    } else if (criteria >= 2) {
      return PasswordStrength.medium;
    } else {
      return PasswordStrength.weak;
    }
  }

  /// Génère un mot de passe aléatoire
  static String generateRandomPassword({int length = 8}) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }
}

enum PasswordStrength {
  tooShort,
  weak,
  medium,
  strong,
}

extension PasswordStrengthExtension on PasswordStrength {
  String get label {
    switch (this) {
      case PasswordStrength.tooShort:
        return 'Trop court';
      case PasswordStrength.weak:
        return 'Faible';
      case PasswordStrength.medium:
        return 'Moyen';
      case PasswordStrength.strong:
        return 'Fort';
    }
  }

  Color get color {
    switch (this) {
      case PasswordStrength.tooShort:
        return const Color(0xFFFF5252);
      case PasswordStrength.weak:
        return const Color(0xFFFF9800);
      case PasswordStrength.medium:
        return const Color(0xFFFFC107);
      case PasswordStrength.strong:
        return const Color(0xFF4CAF50);
    }
  }
}

