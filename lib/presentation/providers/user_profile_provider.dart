import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_profile.dart';
import '../../data/services/user_profile_service.dart';

final userProfileProvider = ChangeNotifierProvider((ref) => UserProfileProvider());

class UserProfileProvider extends ChangeNotifier {
  List<UserProfile> _profiles = [];
  UserProfile? _currentProfile;
  bool _isLoading = false;
  String _errorMessage = '';

  // Getters
  List<UserProfile> get profiles => _profiles;
  UserProfile? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get hasProfiles => _profiles.isNotEmpty;
  bool get hasMultipleProfiles => _profiles.length > 1;

  /// Initialise le provider en chargeant les profils
  Future<void> initialize() async {
    await loadProfiles();
    await loadCurrentProfile();
  }

  /// Charge tous les profils
  Future<void> loadProfiles() async {
    try {
      _setLoading(true);
      _profiles = await UserProfileService.getAllProfiles();
      _clearError();
      print('👤 Provider: ${_profiles.length} profils chargés');
    } catch (e) {
      _setError('Erreur lors du chargement des profils: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Charge le profil actuel
  Future<void> loadCurrentProfile() async {
    try {
      _currentProfile = await UserProfileService.getCurrentProfile();
      print('👤 Provider: Profil actuel chargé: ${_currentProfile?.name}');
      notifyListeners();
    } catch (e) {
      _setError('Erreur lors du chargement du profil actuel: $e');
    }
  }

  /// Change le profil actuel
  Future<bool> switchProfile(String profileId) async {
    try {
      _setLoading(true);
      
      final success = await UserProfileService.setCurrentProfile(profileId);
      if (success) {
        await loadCurrentProfile();
        await loadProfiles(); // Recharger pour mettre à jour les dates
        print('👤 Provider: Profil changé vers: $profileId');
        return true;
      }
      return false;
    } catch (e) {
      _setError('Erreur lors du changement de profil: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Crée un nouveau profil
  Future<UserProfile?> createProfile({
    required String name,
    String? avatarPath,
  }) async {
    try {
      _setLoading(true);
      
      // Créer le profil avec l'avatar spécifié ou un avatar aléatoire
      final profile = UserProfile.create(
        name: name,
        avatarPath: avatarPath,
      );
      
      final newProfile = await UserProfileService.saveProfile(profile);
      
      if (newProfile != null) {
        await loadProfiles();
        print('👤 Provider: Nouveau profil créé: ${newProfile.name}');
        return newProfile;
      }
      return null;
    } catch (e) {
      _setError('Erreur lors de la création du profil: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Met à jour un profil
  Future<bool> updateProfile(UserProfile updatedProfile) async {
    try {
      _setLoading(true);
      
      final success = await UserProfileService.updateProfile(updatedProfile);
      if (success) {
        await loadProfiles();
        
        // Si c'est le profil actuel, le recharger
        if (_currentProfile?.id == updatedProfile.id) {
          await loadCurrentProfile();
        }
        
        print('👤 Provider: Profil mis à jour: ${updatedProfile.name}');
        return true;
      }
      return false;
    } catch (e) {
      _setError('Erreur lors de la mise à jour du profil: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Supprime un profil
  Future<bool> deleteProfile(String profileId) async {
    try {
      _setLoading(true);
      
      final success = await UserProfileService.deleteProfile(profileId);
      if (success) {
        await loadProfiles();
        await loadCurrentProfile(); // Recharger au cas où le profil actuel a changé
        print('👤 Provider: Profil supprimé: $profileId');
        return true;
      }
      return false;
    } catch (e) {
      _setError('Erreur lors de la suppression du profil: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Obtient un profil par son ID
  UserProfile? getProfileById(String profileId) {
    try {
      return _profiles.firstWhere((profile) => profile.id == profileId);
    } catch (e) {
      return null;
    }
  }

  /// Vérifie si un nom de profil existe déjà
  bool isNameTaken(String name, {String? excludeProfileId}) {
    return _profiles.any((profile) => 
      profile.name.toLowerCase() == name.toLowerCase() &&
      profile.id != excludeProfileId
    );
  }

  /// Obtient les profils récemment utilisés
  List<UserProfile> get recentProfiles {
    return _profiles.where((profile) => profile.isRecentlyUsed).toList();
  }

  /// Obtient les statistiques des profils
  Future<Map<String, dynamic>> getStats() async {
    try {
      return await UserProfileService.getProfileStats();
    } catch (e) {
      _setError('Erreur lors du calcul des statistiques: $e');
      return {};
    }
  }

  /// Exporte tous les profils
  Future<String?> exportProfiles() async {
    try {
      _setLoading(true);
      final exportData = await UserProfileService.exportProfiles();
      print('👤 Provider: Profils exportés');
      return exportData;
    } catch (e) {
      _setError('Erreur lors de l\'export: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Importe des profils
  Future<bool> importProfiles(String exportData) async {
    try {
      _setLoading(true);
      
      final success = await UserProfileService.importProfiles(exportData);
      if (success) {
        await loadProfiles();
        await loadCurrentProfile();
        print('👤 Provider: Profils importés avec succès');
        return true;
      }
      return false;
    } catch (e) {
      _setError('Erreur lors de l\'import: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Réinitialise tous les profils (debug)
  Future<void> resetAllProfiles() async {
    try {
      _setLoading(true);
      await UserProfileService.resetAllProfiles();
      await loadProfiles();
      await loadCurrentProfile();
      print('👤 Provider: Tous les profils réinitialisés');
    } catch (e) {
      _setError('Erreur lors de la réinitialisation: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Vérifie si l'utilisateur a vu la configuration des profils
  Future<bool> hasSeenProfileSetup() async {
    try {
      return await UserProfileService.hasSeenProfileSetup();
    } catch (e) {
      return false;
    }
  }

  /// Marque la configuration des profils comme vue
  Future<void> markProfileSetupAsSeen() async {
    try {
      await UserProfileService.markProfileSetupAsSeen();
    } catch (e) {
      print('❌ Erreur lors du marquage du setup: $e');
    }
  }

  // Méthodes privées pour la gestion d'état
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    print('❌ UserProfileProvider Error: $error');
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  /// Nettoie les ressources
  @override
  void dispose() {
    super.dispose();
  }
}