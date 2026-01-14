import 'dart:convert';
import 'security_question.dart';

class UserProfile {
  final String id;
  final String name;
  final String avatarPath;
  final DateTime createdAt;
  final DateTime lastUsed;
  final bool isDefault;
  final bool hasPassword;
  final String? passwordHash;
  final int? securityQuestionId;
  final String? securityAnswerHash;
  final bool isLocked;
  final bool isActive;
  final int color; // Couleur du profil (0xAARRGGBB)
  final bool isMain; // Si c'est le profil principal
  final String? googleAccountEmail; // Email Google lié (optionnel)

  const UserProfile({
    required this.id,
    required this.name,
    required this.avatarPath,
    required this.createdAt,
    required this.lastUsed,
    this.isDefault = false,
    this.hasPassword = false,
    this.passwordHash,
    this.securityQuestionId,
    this.securityAnswerHash,
    this.isLocked = false,
    this.isActive = true, // Default to true for existing profiles
    this.color = 0xFF00D9FF, // Couleur par défaut (neon blue)
    this.isMain = false,
    this.googleAccountEmail,
  });

  /// Crée un profil par défaut
  factory UserProfile.defaultProfile() {
    final now = DateTime.now();
    return UserProfile(
      id: 'default',
      name: 'Profil principal',
      avatarPath: 'avatar_1.png',
      createdAt: now,
      lastUsed: now,
      isDefault: true,
    );
  }

  /// Crée un nouveau profil avec un nom donné
  factory UserProfile.create({
    required String name,
    String? avatarPath,
  }) {
    final now = DateTime.now();
    final avatarIndex = (DateTime.now().millisecondsSinceEpoch % 12) + 1;
    return UserProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      avatarPath: avatarPath ?? 'avatar_$avatarIndex.png',
      createdAt: now,
      lastUsed: now,
    );
  }

  /// Copie le profil avec des modifications
  UserProfile copyWith({
    String? id,
    String? name,
    String? avatarPath,
    DateTime? createdAt,
    DateTime? lastUsed,
    bool? isDefault,
    bool? hasPassword,
    String? passwordHash,
    int? securityQuestionId,
    String? securityAnswerHash,
    bool? isLocked,
    bool? isActive,
    int? color,
    bool? isMain,
    String? googleAccountEmail,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarPath: avatarPath ?? this.avatarPath,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      isDefault: isDefault ?? this.isDefault,
      hasPassword: hasPassword ?? this.hasPassword,
      passwordHash: passwordHash ?? this.passwordHash,
      securityQuestionId: securityQuestionId ?? this.securityQuestionId,
      securityAnswerHash: securityAnswerHash ?? this.securityAnswerHash,
      isLocked: isLocked ?? this.isLocked,
      isActive: isActive ?? this.isActive,
      color: color ?? this.color,
      isMain: isMain ?? this.isMain,
      googleAccountEmail: googleAccountEmail ?? this.googleAccountEmail,
    );
  }

  /// Met à jour la date de dernière utilisation
  UserProfile updateLastUsed() {
    return copyWith(lastUsed: DateTime.now());
  }

  /// Marque le profil comme utilisé maintenant
  UserProfile markAsUsed() {
    return copyWith(lastUsed: DateTime.now());
  }

  /// Convertit en Map pour la sérialisation
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatarPath': avatarPath,
      'createdAt': createdAt.toIso8601String(),
      'lastUsed': lastUsed.toIso8601String(),
      'isDefault': isDefault,
      'hasPassword': hasPassword,
      'passwordHash': passwordHash,
      'securityQuestionId': securityQuestionId,
      'securityAnswerHash': securityAnswerHash,
      'isLocked': isLocked,
      'isActive': isActive,
      'color': color,
      'isMain': isMain,
      'googleAccountEmail': googleAccountEmail,
    };
  }

  /// Crée depuis une Map
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      avatarPath: map['avatarPath'] ?? 'avatar_1.png',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      lastUsed: DateTime.parse(map['lastUsed'] ?? DateTime.now().toIso8601String()),
      isDefault: map['isDefault'] ?? false,
      hasPassword: map['hasPassword'] ?? false,
      passwordHash: map['passwordHash'],
      securityQuestionId: map['securityQuestionId'],
      securityAnswerHash: map['securityAnswerHash'],
      isLocked: map['isLocked'] ?? false,
      isActive: map['isActive'] ?? true,
      color: map['color'] ?? 0xFF00D9FF,
      isMain: map['isMain'] ?? false,
      googleAccountEmail: map['googleAccountEmail'],
    );
  }

  /// Convertit en JSON
  String toJson() => json.encode(toMap());

  /// Crée depuis JSON (peut être une String ou un Map - utilisé par différents services)
  factory UserProfile.fromJson(dynamic source) {
    if (source is String) {
      return UserProfile.fromMap(json.decode(source) as Map<String, dynamic>);
    } else if (source is Map<String, dynamic>) {
      return UserProfile.fromMap(source);
    } else {
      throw ArgumentError('Invalid source type: ${source.runtimeType}');
    }
  }

  /// Obtient l'initiale du nom pour l'avatar
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : 'U';

  /// Obtient les initiales du nom (2 caractères max)
  String get initials {
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return initial;
  }

  /// Vérifie si le profil a été utilisé récemment (moins de 7 jours)
  bool get isRecentlyUsed {
    final now = DateTime.now();
    final difference = now.difference(lastUsed);
    return difference.inDays < 7;
  }

  /// Obtient une couleur basée sur l'ID du profil
  int get colorSeed => id.hashCode;
  
  /// Obtient la question de sécurité
  SecurityQuestion? get securityQuestion {
    if (securityQuestionId == null) return null;
    try {
      return SecurityQuestion.predefinedQuestions
          .firstWhere((q) => q.id == securityQuestionId);
    } catch (e) {
      return null;
    }
  }
  
  /// Vérifie si le profil nécessite une authentification
  bool get requiresAuth => hasPassword && !isLocked;
  
  /// Obtient la liste des avatars disponibles
  static List<String> get availableAvatars {
    return List.generate(12, (index) => 'avatar_${index + 1}.png');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.id == id;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        avatarPath.hashCode ^
        createdAt.hashCode ^
        lastUsed.hashCode ^
        isDefault.hashCode ^
        hasPassword.hashCode ^
        passwordHash.hashCode ^
        securityQuestionId.hashCode ^
        securityAnswerHash.hashCode ^
        isLocked.hashCode ^
        isActive.hashCode ^
        color.hashCode ^
        isMain.hashCode ^
        googleAccountEmail.hashCode;
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, name: $name, avatarPath: $avatarPath, createdAt: $createdAt, lastUsed: $lastUsed, isDefault: $isDefault, hasPassword: $hasPassword, isLocked: $isLocked, isActive: $isActive)';
  }
}