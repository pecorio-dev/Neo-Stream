import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class UserProfileService {
  static const String _profilesKey = 'user_profiles';
  static const String _currentProfileKey = 'current_profile_id';
  static const String _hasSeenProfileSetupKey = 'has_seen_profile_setup';

  /// Obtient tous les profils utilisateur
  static Future<List<UserProfile>> getAllProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = prefs.getStringList(_profilesKey) ?? [];
      
      final profiles = profilesJson
          .map((json) => UserProfile.fromJson(json))
          .toList();
      
      // S'assurer qu'il y a au moins un profil par défaut
      if (profiles.isEmpty) {
        final defaultProfile = UserProfile.defaultProfile();
        await _saveProfiles([defaultProfile]);
        await setCurrentProfile(defaultProfile.id);
        return [defaultProfile];
      }
      
      // Trier par dernière utilisation
      profiles.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
      
      print('👤 Profils chargés: ${profiles.length}');
      return profiles;
    } catch (e) {
      print('❌ Erreur lors du chargement des profils: $e');
      // En cas d'erreur, retourner un profil par défaut
      final defaultProfile = UserProfile.defaultProfile();
      return [defaultProfile];
    }
  }

  /// Obtient le profil actuel
  static Future<UserProfile> getCurrentProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentProfileId = prefs.getString(_currentProfileKey);
      
      final profiles = await getAllProfiles();
      
      if (currentProfileId != null) {
        final currentProfile = profiles.firstWhere(
          (profile) => profile.id == currentProfileId,
          orElse: () => profiles.first,
        );
        print('👤 Profil actuel: ${currentProfile.name}');
        return currentProfile;
      }
      
      // Si aucun profil actuel défini, prendre le premier
      final firstProfile = profiles.first;
      await setCurrentProfile(firstProfile.id);
      return firstProfile;
    } catch (e) {
      print('❌ Erreur lors du chargement du profil actuel: $e');
      return UserProfile.defaultProfile();
    }
  }

  /// Définit le profil actuel
  static Future<bool> setCurrentProfile(String profileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentProfileKey, profileId);
      
      // Mettre à jour la date de dernière utilisation
      final profiles = await getAllProfiles();
      final updatedProfiles = profiles.map((profile) {
        if (profile.id == profileId) {
          return profile.updateLastUsed();
        }
        return profile;
      }).toList();
      
      await _saveProfiles(updatedProfiles);
      
      print('👤 Profil actuel défini: $profileId');
      return true;
    } catch (e) {
      print('❌ Erreur lors de la définition du profil actuel: $e');
      return false;
    }
  }

  /// Sauvegarde un profil (alias pour createProfile)
  static Future<UserProfile?> saveProfile(UserProfile profile) async {
    try {
      final profiles = await getAllProfiles();
      
      // Vérifier que le nom n'existe pas déjà
      final nameExists = profiles.any((p) => 
        p.name.toLowerCase() == profile.name.toLowerCase() && p.id != profile.id
      );
      
      if (nameExists) {
        throw Exception('Un profil avec ce nom existe déjà');
      }

      // Limiter le nombre de profils
      if (profiles.length >= 10) {
        throw Exception('Nombre maximum de profils atteint (10)');
      }

      final updatedProfiles = [...profiles, profile];
      await _saveProfiles(updatedProfiles);
      
      print('👤 Profil sauvegardé: ${profile.name}');
      return profile;
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde du profil: $e');
      return null;
    }
  }

  /// Crée un nouveau profil
  static Future<UserProfile?> createProfile({
    required String name,
    String? avatarPath,
  }) async {
    try {
      if (name.trim().isEmpty) {
        throw Exception('Le nom du profil ne peut pas être vide');
      }

      final profiles = await getAllProfiles();
      
      // Vérifier que le nom n'existe pas déjà
      final nameExists = profiles.any((profile) => 
        profile.name.toLowerCase() == name.trim().toLowerCase()
      );
      
      if (nameExists) {
        throw Exception('Un profil avec ce nom existe déjà');
      }

      // Limiter le nombre de profils
      if (profiles.length >= 10) {
        throw Exception('Nombre maximum de profils atteint (10)');
      }

      final newProfile = UserProfile.create(
        name: name.trim(),
        avatarPath: avatarPath,
      );

      final updatedProfiles = [...profiles, newProfile];
      await _saveProfiles(updatedProfiles);
      
      print('👤 Nouveau profil créé: ${newProfile.name}');
      return newProfile;
    } catch (e) {
      print('❌ Erreur lors de la création du profil: $e');
      return null;
    }
  }

  /// Met à jour un profil existant
  static Future<bool> updateProfile(UserProfile updatedProfile) async {
    try {
      final profiles = await getAllProfiles();
      final profileIndex = profiles.indexWhere((p) => p.id == updatedProfile.id);
      
      if (profileIndex == -1) {
        throw Exception('Profil non trouvé');
      }

      // Vérifier que le nouveau nom n'existe pas déjà (sauf pour le profil actuel)
      final nameExists = profiles.any((profile) => 
        profile.id != updatedProfile.id &&
        profile.name.toLowerCase() == updatedProfile.name.toLowerCase()
      );
      
      if (nameExists) {
        throw Exception('Un profil avec ce nom existe déjà');
      }

      profiles[profileIndex] = updatedProfile;
      await _saveProfiles(profiles);
      
      print('👤 Profil mis à jour: ${updatedProfile.name}');
      return true;
    } catch (e) {
      print('❌ Erreur lors de la mise à jour du profil: $e');
      return false;
    }
  }

  /// Supprime un profil
  static Future<bool> deleteProfile(String profileId) async {
    try {
      final profiles = await getAllProfiles();
      
      // Ne pas supprimer s'il n'y a qu'un seul profil
      if (profiles.length <= 1) {
        throw Exception('Impossible de supprimer le dernier profil');
      }

      // Ne pas supprimer le profil par défaut
      final profileToDelete = profiles.firstWhere(
        (p) => p.id == profileId,
        orElse: () => throw Exception('Profil non trouvé'),
      );

      if (profileToDelete.isDefault) {
        throw Exception('Impossible de supprimer le profil par défaut');
      }

      final updatedProfiles = profiles.where((p) => p.id != profileId).toList();
      await _saveProfiles(updatedProfiles);

      // Si le profil supprimé était le profil actuel, changer pour le premier disponible
      final currentProfile = await getCurrentProfile();
      if (currentProfile.id == profileId) {
        await setCurrentProfile(updatedProfiles.first.id);
      }
      
      print('👤 Profil supprimé: ${profileToDelete.name}');
      return true;
    } catch (e) {
      print('❌ Erreur lors de la suppression du profil: $e');
      return false;
    }
  }

  /// Sauvegarde la liste des profils
  static Future<void> _saveProfiles(List<UserProfile> profiles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = profiles.map((profile) => profile.toJson()).toList();
      await prefs.setStringList(_profilesKey, profilesJson);
      print('👤 ${profiles.length} profils sauvegardés');
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde des profils: $e');
      throw e;
    }
  }

  /// Vérifie si l'utilisateur a déjà vu la configuration des profils
  static Future<bool> hasSeenProfileSetup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_hasSeenProfileSetupKey) ?? false;
    } catch (e) {
      print('❌ Erreur lors de la vérification du setup: $e');
      return false;
    }
  }

  /// Marque que l'utilisateur a vu la configuration des profils
  static Future<void> markProfileSetupAsSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasSeenProfileSetupKey, true);
      print('👤 Configuration des profils marquée comme vue');
    } catch (e) {
      print('❌ Erreur lors du marquage du setup: $e');
    }
  }

  /// Réinitialise tous les profils (pour le développement/debug)
  static Future<void> resetAllProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profilesKey);
      await prefs.remove(_currentProfileKey);
      await prefs.remove(_hasSeenProfileSetupKey);
      print('👤 Tous les profils ont été réinitialisés');
    } catch (e) {
      print('❌ Erreur lors de la réinitialisation: $e');
    }
  }

  /// Obtient les statistiques des profils
  static Future<Map<String, dynamic>> getProfileStats() async {
    try {
      final profiles = await getAllProfiles();
      final currentProfile = await getCurrentProfile();
      
      return {
        'totalProfiles': profiles.length,
        'currentProfileId': currentProfile.id,
        'currentProfileName': currentProfile.name,
        'recentlyUsedProfiles': profiles.where((p) => p.isRecentlyUsed).length,
        'oldestProfile': profiles.isNotEmpty 
            ? profiles.reduce((a, b) => a.createdAt.isBefore(b.createdAt) ? a : b).name
            : null,
        'newestProfile': profiles.isNotEmpty 
            ? profiles.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b).name
            : null,
      };
    } catch (e) {
      print('❌ Erreur lors du calcul des statistiques: $e');
      return {};
    }
  }

  /// Exporte tous les profils (pour sauvegarde)
  static Future<String> exportProfiles() async {
    try {
      final profiles = await getAllProfiles();
      final currentProfile = await getCurrentProfile();
      
      final exportData = {
        'profiles': profiles.map((p) => p.toMap()).toList(),
        'currentProfileId': currentProfile.id,
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0',
      };
      
      return json.encode(exportData);
    } catch (e) {
      print('❌ Erreur lors de l\'export: $e');
      throw e;
    }
  }

  /// Importe des profils depuis une sauvegarde
  static Future<bool> importProfiles(String exportData) async {
    try {
      final data = json.decode(exportData);
      
      if (data['version'] != '1.0') {
        throw Exception('Version de sauvegarde non supportée');
      }

      final profilesData = data['profiles'] as List;
      final profiles = profilesData.map((p) => UserProfile.fromMap(p)).toList();
      
      if (profiles.isEmpty) {
        throw Exception('Aucun profil trouvé dans la sauvegarde');
      }

      await _saveProfiles(profiles);
      
      final currentProfileId = data['currentProfileId'] as String?;
      if (currentProfileId != null && profiles.any((p) => p.id == currentProfileId)) {
        await setCurrentProfile(currentProfileId);
      } else {
        await setCurrentProfile(profiles.first.id);
      }
      
      print('👤 ${profiles.length} profils importés avec succès');
      return true;
    } catch (e) {
      print('❌ Erreur lors de l\'import: $e');
      return false;
    }
  }
}