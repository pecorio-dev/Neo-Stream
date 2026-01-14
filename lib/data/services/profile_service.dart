import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

/// Service pour gérer les profils utilisateur
class ProfileService {
  static const String _profilesKey = 'user_profiles';
  static const String _activeProfileKey = 'active_profile_id';
  static const int maxProfiles = 8; // Limite de profils

  /// Obtient tous les profils
  static Future<List<UserProfile>> getAllProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = prefs.getString(_profilesKey);
      
      if (profilesJson == null) return [];
      
      final List<dynamic> profilesList = json.decode(profilesJson);
      return profilesList
          .map((json) => UserProfile.fromJson(json as Map<String, dynamic>))
          .where((profile) => profile.isActive)
          .toList();
    } catch (e) {
      print('Erreur lors du chargement des profils: $e');
      return [];
    }
  }

  /// Crée un nouveau profil
  static Future<bool> createProfile(UserProfile profile) async {
    try {
      final profiles = await getAllProfiles();
      
      // Vérifier la limite de profils
      if (profiles.length >= maxProfiles) {
        throw Exception('Limite de $maxProfiles profils atteinte');
      }
      
      // Vérifier que le nom n'existe pas déjà
      if (profiles.any((p) => p.name.toLowerCase() == profile.name.toLowerCase())) {
        throw Exception('Un profil avec ce nom existe déjà');
      }
      
      // Ajouter le nouveau profil
      profiles.add(profile);
      
      // Sauvegarder
      await _saveProfiles(profiles);
      
      // Si c'est le premier profil, le définir comme actif
      if (profiles.length == 1) {
        await setActiveProfile(profile.id);
      }
      
      return true;
    } catch (e) {
      print('Erreur lors de la création du profil: $e');
      rethrow;
    }
  }

  /// Met à jour un profil existant
  static Future<bool> updateProfile(UserProfile profile) async {
    try {
      final profiles = await getAllProfiles();
      final index = profiles.indexWhere((p) => p.id == profile.id);
      
      if (index == -1) {
        throw Exception('Profil non trouvé');
      }
      
      profiles[index] = profile;
      await _saveProfiles(profiles);
      return true;
    } catch (e) {
      print('Erreur lors de la mise à jour du profil: $e');
      return false;
    }
  }

  /// Supprime un profil
  static Future<bool> deleteProfile(String profileId) async {
    try {
      final profiles = await getAllProfiles();
      final profileToDelete = profiles.firstWhere(
        (p) => p.id == profileId,
        orElse: () => throw Exception('Profil non trouvé'),
      );
      
      // Marquer comme inactif au lieu de supprimer
      final updatedProfile = profileToDelete.copyWith(isActive: false);
      await updateProfile(updatedProfile);
      
      // Si c'était le profil actif, choisir un autre
      final activeProfileId = await getActiveProfileId();
      if (activeProfileId == profileId) {
        final remainingProfiles = await getAllProfiles();
        if (remainingProfiles.isNotEmpty) {
          await setActiveProfile(remainingProfiles.first.id);
        } else {
          await clearActiveProfile();
        }
      }
      
      return true;
    } catch (e) {
      print('Erreur lors de la suppression du profil: $e');
      return false;
    }
  }

  /// Obtient un profil par ID
  static Future<UserProfile?> getProfile(String profileId) async {
    try {
      final profiles = await getAllProfiles();
      return profiles.firstWhere(
        (p) => p.id == profileId,
        orElse: () => throw Exception('Profil non trouvé'),
      );
    } catch (e) {
      print('Erreur lors de la récupération du profil: $e');
      return null;
    }
  }

  /// Définit le profil actif
  static Future<bool> setActiveProfile(String profileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeProfileKey, profileId);
      
      // Marquer le profil comme utilisé
      final profile = await getProfile(profileId);
      if (profile != null) {
        await updateProfile(profile.markAsUsed());
      }
      
      return true;
    } catch (e) {
      print('Erreur lors de la définition du profil actif: $e');
      return false;
    }
  }

  /// Obtient l'ID du profil actif
  static Future<String?> getActiveProfileId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_activeProfileKey);
    } catch (e) {
      print('Erreur lors de la récupération du profil actif: $e');
      return null;
    }
  }

  /// Obtient le profil actif
  static Future<UserProfile?> getActiveProfile() async {
    try {
      final activeId = await getActiveProfileId();
      if (activeId == null) return null;
      return await getProfile(activeId);
    } catch (e) {
      print('Erreur lors de la récupération du profil actif: $e');
      return null;
    }
  }

  /// Efface le profil actif
  static Future<void> clearActiveProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeProfileKey);
    } catch (e) {
      print('Erreur lors de l\'effacement du profil actif: $e');
    }
  }

  /// Obtient les profils récemment utilisés
  static Future<List<UserProfile>> getRecentProfiles({int limit = 4}) async {
    try {
      final profiles = await getAllProfiles();
      profiles.sort((a, b) {
        final aTime = a.lastUsed ?? a.createdAt;
        final bTime = b.lastUsed ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      return profiles.take(limit).toList();
    } catch (e) {
      print('Erreur lors de la récupération des profils récents: $e');
      return [];
    }
  }

  /// Vérifie si un nom de profil est disponible
  static Future<bool> isNameAvailable(String name, {String? excludeId}) async {
    try {
      final profiles = await getAllProfiles();
      return !profiles.any((p) => 
        p.name.toLowerCase() == name.toLowerCase() && 
        p.id != excludeId
      );
    } catch (e) {
      print('Erreur lors de la vérification du nom: $e');
      return false;
    }
  }

  /// Obtient les statistiques des profils
  static Future<Map<String, dynamic>> getProfileStats() async {
    try {
      final profiles = await getAllProfiles();
      final now = DateTime.now();
      
      int activeCount = 0;
      int recentCount = 0;
      DateTime? lastCreated;
      
      for (final profile in profiles) {
        if (profile.isActive) activeCount++;
        if (profile.isRecentlyUsed) recentCount++;
        
        if (lastCreated == null || profile.createdAt.isAfter(lastCreated)) {
          lastCreated = profile.createdAt;
        }
      }
      
      return {
        'total': profiles.length,
        'active': activeCount,
        'recent': recentCount,
        'maxAllowed': maxProfiles,
        'canCreateMore': profiles.length < maxProfiles,
        'lastCreated': lastCreated,
      };
    } catch (e) {
      print('Erreur lors de la récupération des statistiques: $e');
      return {
        'total': 0,
        'active': 0,
        'recent': 0,
        'maxAllowed': maxProfiles,
        'canCreateMore': true,
        'lastCreated': null,
      };
    }
  }

  /// Sauvegarde la liste des profils
  static Future<void> _saveProfiles(List<UserProfile> profiles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = json.encode(
        profiles.map((p) => p.toJson()).toList(),
      );
      await prefs.setString(_profilesKey, profilesJson);
    } catch (e) {
      print('Erreur lors de la sauvegarde des profils: $e');
      rethrow;
    }
  }

  /// Efface tous les profils (pour le debug/reset)
  static Future<void> clearAllProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profilesKey);
      await prefs.remove(_activeProfileKey);
    } catch (e) {
      print('Erreur lors de l\'effacement des profils: $e');
    }
  }

  /// Exporte les profils en JSON
  static Future<String?> exportProfiles() async {
    try {
      final profiles = await getAllProfiles();
      return json.encode({
        'profiles': profiles.map((p) => p.toJson()).toList(),
        'exportDate': DateTime.now().millisecondsSinceEpoch,
        'version': '1.0',
      });
    } catch (e) {
      print('Erreur lors de l\'export des profils: $e');
      return null;
    }
  }

  /// Importe les profils depuis JSON
  static Future<bool> importProfiles(String jsonData) async {
    try {
      final data = json.decode(jsonData) as Map<String, dynamic>;
      final profilesData = data['profiles'] as List<dynamic>;
      
      final importedProfiles = profilesData
          .map((json) => UserProfile.fromJson(json as Map<String, dynamic>))
          .toList();
      
      // Fusionner avec les profils existants
      final existingProfiles = await getAllProfiles();
      final allProfiles = <UserProfile>[];
      
      // Ajouter les profils existants
      allProfiles.addAll(existingProfiles);
      
      // Ajouter les profils importés (avec de nouveaux IDs si nécessaire)
      for (final imported in importedProfiles) {
        if (!allProfiles.any((p) => p.id == imported.id)) {
          allProfiles.add(imported);
        }
      }
      
      // Vérifier la limite
      if (allProfiles.length > maxProfiles) {
        throw Exception('L\'import dépasserait la limite de $maxProfiles profils');
      }
      
      await _saveProfiles(allProfiles);
      return true;
    } catch (e) {
      print('Erreur lors de l\'import des profils: $e');
      return false;
    }
  }
}