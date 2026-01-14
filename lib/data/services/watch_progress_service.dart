import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/watch_progress.dart';

class WatchProgressService {
  static const String _progressKey = 'watch_progress';
  static const String _recentProgressKey = 'recent_progress';
  static const int _maxRecentItems = 20;
  static const int _maxDaysToKeep = 30;
  
  // Clé pour le profil actuel
  static String? _currentProfileId;
  
  /// Définit le profil actuel pour isoler les données
  static void setCurrentProfile(String profileId) {
    _currentProfileId = profileId;
    print('📺 WatchProgressService: Profil défini: $profileId');
  }
  
  /// Obtient la clé avec le profil actuel
  static String _getProfileKey(String baseKey) {
    if (_currentProfileId == null) {
      return baseKey; // Compatibilité avec l'ancien système
    }
    return '${baseKey}_profile_$_currentProfileId';
  }

  /// Sauvegarde la progression de lecture
  static Future<bool> saveProgress(WatchProgress progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Charger les progressions existantes pour le profil actuel
      final progressMap = await _loadAllProgress();
      
      // Ajouter/mettre à jour la progression
      progressMap[progress.id] = progress;
      
      // Sauvegarder avec la clé du profil
      final progressList = progressMap.values.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_getProfileKey(_progressKey), progressList);
      
      // Ajouter aux progressions récentes
      await _addToRecentProgress(progress);
      
      print('📺 Progression sauvegardée: ${progress.id} (Profil: $_currentProfileId)');
      print('📺 Position: ${progress.formattedPosition}/${progress.formattedDuration}');
      
      return true;
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde: $e');
      return false;
    }
  }

  /// Obtient la progression pour un contenu spécifique
  static Future<WatchProgress?> getProgress(
    String contentId, {
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    try {
      final progressMap = await _loadAllProgress();
      final progressId = WatchProgress.generateId(
        contentId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
      
      final progress = progressMap[progressId];
      if (progress != null) {
        print('📺 Progression trouvée: ${progress.formattedPosition}/${progress.formattedDuration}');
      }
      
      return progress;
    } catch (e) {
      print('❌ Erreur lors du chargement de la progression: $e');
      return null;
    }
  }

  /// Obtient la progression la plus récente pour une série
  static Future<WatchProgress?> getSeriesProgress(String seriesId) async {
    try {
      final progressMap = await _loadAllProgress();
      
      // Filtrer les progressions de cette série
      final seriesProgressions = progressMap.values
          .where((p) => p.contentId == seriesId && p.isEpisode)
          .toList();
      
      if (seriesProgressions.isEmpty) {
        print('📺 Aucune progression trouvée pour la série: $seriesId');
        return null;
      }
      
      // Trier par date de dernière mise à jour
      seriesProgressions.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
      
      final latestProgress = seriesProgressions.first;
      print('📺 Dernière progression de série: S${latestProgress.seasonNumber}E${latestProgress.episodeNumber}');
      
      return latestProgress;
    } catch (e) {
      print('❌ Erreur lors du chargement de la progression de série: $e');
      return null;
    }
  }

  /// Obtient toutes les progressions pour une série
  static Future<List<WatchProgress>> getAllSeriesProgress(String seriesId) async {
    try {
      final progressMap = await _loadAllProgress();
      
      // Filtrer les progressions de cette série
      final seriesProgressions = progressMap.values
          .where((p) => p.contentId == seriesId && p.isEpisode)
          .toList();
      
      // Trier par date
      seriesProgressions.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
      
      return seriesProgressions;
    } catch (e) {
      print('❌ Erreur lors du chargement de la progression de série: $e');
      return [];
    }
  }

  /// Charge toutes les progressions pour le profil actuel
  static Future<Map<String, WatchProgress>> _loadAllProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getProfileKey(_progressKey);
      
      // Essayer d'abord comme StringList
      List<String>? progressList;
      try {
        progressList = prefs.getStringList(key);
      } catch (e) {
        // Si ça échoue, essayer comme String (ancien format)
        final oldData = prefs.getString(key);
        if (oldData != null) {
          try {
            final decoded = jsonDecode(oldData);
            if (decoded is List) {
              progressList = decoded.cast<String>();
            }
          } catch (e2) {
            print('❌ Impossible de convertir les anciennes données: $e2');
          }
        }
      }
      
      progressList ??= [];
      
      final progressMap = <String, WatchProgress>{};
      
      for (final progressJson in progressList) {
        try {
          final progressData = jsonDecode(progressJson);
          final progress = WatchProgress.fromJson(progressData);
          progressMap[progress.id] = progress;
        } catch (e) {
          print('❌ Erreur lors du parsing d\'une progression: $e');
        }
      }
      
      print('📺 ${progressMap.length} progressions chargées (Profil: $_currentProfileId)');
      return progressMap;
    } catch (e) {
      print('❌ Erreur lors du chargement des progressions: $e');
      return {};
    }
  }

  /// Obtient toutes les progressions
  static Future<List<WatchProgress>> getAllProgress() async {
    try {
      final progressMap = await _loadAllProgress();
      final progressList = progressMap.values.toList();
      
      // Trier par date de dernière mise à jour
      progressList.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
      
      return progressList;
    } catch (e) {
      print('❌ Erreur lors du chargement de toutes les progressions: $e');
      return [];
    }
  }

  /// Obtient les progressions récentes pour le profil actuel
  static Future<List<WatchProgress>> getRecentProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentList = prefs.getStringList(_getProfileKey(_recentProgressKey)) ?? [];
      
      final recentProgress = <WatchProgress>[];
      
      for (final progressJson in recentList) {
        try {
          final progressData = jsonDecode(progressJson);
          final progress = WatchProgress.fromJson(progressData);
          recentProgress.add(progress);
        } catch (e) {
          print('❌ Erreur lors du parsing d\'une progression récente: $e');
        }
      }
      
      // Filtrer les progressions trop anciennes
      final cutoffDate = DateTime.now().subtract(const Duration(days: _maxDaysToKeep));
      final validProgress = recentProgress
          .where((p) => p.lastWatched.isAfter(cutoffDate))
          .toList();
      
      // Trier par date de dernière mise à jour
      validProgress.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
      
      print('📺 ${validProgress.length} progressions récentes (Profil: $_currentProfileId)');
      return validProgress.take(_maxRecentItems).toList();
    } catch (e) {
      print('❌ Erreur lors du chargement des progressions récentes: $e');
      return [];
    }
  }

  /// Ajoute à la liste des progressions récentes pour le profil actuel
  static Future<void> _addToRecentProgress(WatchProgress progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentList = prefs.getStringList(_getProfileKey(_recentProgressKey)) ?? [];
      
      // Convertir en objets WatchProgress
      final recentProgress = <WatchProgress>[];
      for (final progressJson in recentList) {
        try {
          final progressData = jsonDecode(progressJson);
          final existingProgress = WatchProgress.fromJson(progressData);
          recentProgress.add(existingProgress);
        } catch (e) {
          // Ignorer les progressions corrompues
        }
      }
      
      // Supprimer l'ancienne entrée si elle existe
      recentProgress.removeWhere((p) => p.id == progress.id);
      
      // Ajouter la nouvelle progression au début
      recentProgress.insert(0, progress);
      
      // Limiter le nombre d'éléments
      final limitedProgress = recentProgress.take(_maxRecentItems).toList();
      
      // Sauvegarder la liste mise à jour avec la clé du profil
      final updatedList = limitedProgress.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_getProfileKey(_recentProgressKey), updatedList);
      
      print('📺 Progression ajoutée aux récentes (${limitedProgress.length} total)');
    } catch (e) {
      print('❌ Erreur lors de l\'ajout aux progressions récentes: $e');
    }
  }

  /// Supprime une progression
  static Future<bool> removeProgress(String contentId, {
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressMap = await _loadAllProgress();
      
      final progressId = WatchProgress.generateId(
        contentId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
      
      if (progressMap.remove(progressId) != null) {
        // Sauvegarder la liste mise à jour
        final progressList = progressMap.values.map((p) => jsonEncode(p.toJson())).toList();
        await prefs.setStringList(_getProfileKey(_progressKey), progressList);
        
        print('📺 Progression supprimée: $progressId');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Erreur lors de la suppression: $e');
      return false;
    }
  }

  /// Nettoie les anciennes progressions pour le profil actuel
  static Future<void> cleanupOldProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressList = prefs.getStringList(_getProfileKey(_progressKey)) ?? [];
      
      final cutoffDate = DateTime.now().subtract(const Duration(days: _maxDaysToKeep));
      final validProgress = <WatchProgress>[];
      
      for (final progressJson in progressList) {
        try {
          final progressData = jsonDecode(progressJson);
          final progress = WatchProgress.fromJson(progressData);
          if (progress.lastWatched.isAfter(cutoffDate)) {
            validProgress.add(progress);
          }
        } catch (e) {
          // Ignorer les progressions corrompues
        }
      }
      
      // Sauvegarder la liste nettoyée avec la clé du profil
      final cleanedList = validProgress.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_getProfileKey(_progressKey), cleanedList);
      
      // Nettoyer aussi les progressions récentes pour le profil actuel
      final recentList = prefs.getStringList(_getProfileKey(_recentProgressKey)) ?? [];
      final validRecentProgress = <WatchProgress>[];
      
      for (final progressJson in recentList) {
        try {
          final progressData = jsonDecode(progressJson);
          final progress = WatchProgress.fromJson(progressData);
          if (progress.lastWatched.isAfter(cutoffDate)) {
            validRecentProgress.add(progress);
          }
        } catch (e) {
          // Ignorer les progressions corrompues
        }
      }
      
      final cleanedRecentList = validRecentProgress.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_getProfileKey(_recentProgressKey), cleanedRecentList);
      
      print('📺 Nettoyage terminé: ${validProgress.length} progressions conservées');
    } catch (e) {
      print('❌ Erreur lors du nettoyage: $e');
    }
  }

  /// Obtient les statistiques de progression pour le profil actuel
  static Future<Map<String, dynamic>> getProgressStats() async {
    try {
      final allProgress = await getAllProgress();
      final recentProgress = await getRecentProgress();
      
      final movieProgress = allProgress.where((p) => !p.isEpisode).length;
      final episodeProgress = allProgress.where((p) => p.isEpisode).length;
      final completedContent = allProgress.where((p) => p.isCompleted).length;
      
      return {
        'totalProgress': allProgress.length,
        'recentProgress': recentProgress.length,
        'movieProgress': movieProgress,
        'episodeProgress': episodeProgress,
        'completedContent': completedContent,
        'profileId': _currentProfileId,
      };
    } catch (e) {
      print('❌ Erreur lors du calcul des statistiques: $e');
      return {};
    }
  }

  /// Exporte toutes les progressions du profil actuel
  static Future<String> exportProgress() async {
    try {
      final allProgress = await getAllProgress();
      final recentProgress = await getRecentProgress();
      
      final exportData = {
        'profileId': _currentProfileId,
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0',
        'allProgress': allProgress.map((p) => p.toMap()).toList(),
        'recentProgress': recentProgress.map((p) => p.toMap()).toList(),
      };
      
      return json.encode(exportData);
    } catch (e) {
      print('❌ Erreur lors de l\'export: $e');
      throw e;
    }
  }

  /// Importe des progressions pour le profil actuel
  static Future<bool> importProgress(String exportData) async {
    try {
      final data = json.decode(exportData);
      
      if (data['version'] != '1.0') {
        throw Exception('Version de sauvegarde non supportée');
      }

      final prefs = await SharedPreferences.getInstance();
      
      // Importer les progressions principales
      final allProgressData = data['allProgress'] as List;
      final allProgress = allProgressData.map((p) => WatchProgress.fromMap(p)).toList();
      
      if (allProgress.isNotEmpty) {
        final progressList = allProgress.map((p) => jsonEncode(p.toJson())).toList();
        await prefs.setStringList(_getProfileKey(_progressKey), progressList);
      }
      
      // Importer les progressions récentes
      final recentProgressData = data['recentProgress'] as List;
      final recentProgress = recentProgressData.map((p) => WatchProgress.fromMap(p)).toList();
      
      if (recentProgress.isNotEmpty) {
        final recentList = recentProgress.map((p) => jsonEncode(p.toJson())).toList();
        await prefs.setStringList(_getProfileKey(_recentProgressKey), recentList);
      }
      
      print('📺 Import réussi: ${allProgress.length} progressions importées');
      return true;
    } catch (e) {
      print('❌ Erreur lors de l\'import: $e');
      return false;
    }
  }

  /// Réinitialise toutes les progressions du profil actuel
  static Future<void> resetProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getProfileKey(_progressKey));
      await prefs.remove(_getProfileKey(_recentProgressKey));
      
      print('📺 Progressions réinitialisées pour le profil: $_currentProfileId');
    } catch (e) {
      print('❌ Erreur lors de la réinitialisation: $e');
    }
  }
  
  /// Alias pour cleanupOldProgress pour compatibilité
  static Future<void> cleanOldProgress() async {
    await cleanupOldProgress();
  }
  
  /// Marque un contenu comme terminé
  static Future<bool> markAsCompleted(
    String contentId, {
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    try {
      final progressMap = await _loadAllProgress();
      final progressId = WatchProgress.generateId(
        contentId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
      
      final existingProgress = progressMap[progressId];
      if (existingProgress != null) {
        final completedProgress = existingProgress.copyWith(
          position: (existingProgress.duration * 0.95).round(),
          lastWatched: DateTime.now(),
        );
        return await saveProgress(completedProgress);
      }
      
      return false;
    } catch (e) {
      print('❌ Erreur lors du marquage comme terminé: $e');
      return false;
    }
  }
  
  /// Vérifie si un contenu a une progression récente
  static Future<bool> hasRecentProgress(
    String contentId, {
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    try {
      final progress = await getProgress(
        contentId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
      
      if (progress == null) return false;
      
      // Considérer comme récent si regardé dans les 7 derniers jours
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
      return progress.lastWatched.isAfter(cutoffDate);
    } catch (e) {
      print('❌ Erreur lors de la vérification de progression récente: $e');
      return false;
    }
  }
}