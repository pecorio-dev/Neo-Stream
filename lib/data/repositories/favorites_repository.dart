import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/favorite_item.dart';
import '../models/movie.dart';
import '../models/series.dart';
// import favorites_storage_service removed

class FavoritesRepository {
  static const String _favoritesKey = 'favorites';
  static const String _favoriteMoviesKey = 'favorite_movies';
  static const String _favoriteSeriesKey = 'favorite_series';
  
  // Cache en mémoire des favoris
  static List<FavoriteItem>? _cachedFavorites;
  
  /// Initialise le service de stockage
  static Future<void> init() async {
    // FavoritesStorageService init skipped - media_kit only
  }
  
  /// Invalide le cache
  static void _invalidateCache() {
    _cachedFavorites = null;
  }

  /// Ajoute un film aux favoris avec fallback
  Future<bool> addMovieToFavorites(Movie movie) async {
    try {
      final favorites = await getFavorites();
      
      final favoriteItem = FavoriteItem.fromMovie(movie);
      
      // Vérifier si déjà en favoris
      if (favorites.any((item) => item.id == favoriteItem.id)) {
        return false; // Déjà en favoris
      }
      
      favorites.add(favoriteItem);
      _cachedFavorites = favorites;
      
      // Essayer de sauvegarder
      try {
        final prefs = await SharedPreferences.getInstance();
        final favoritesJson = favorites.map((item) => item.toJson()).toList();
        await prefs.setString(_favoritesKey, json.encode(favoritesJson));
      } catch (e) {
        print('⚠️ Could not save to SharedPreferences: $e (kept in memory)');
      }
      
      return true;
    } catch (e) {
      print('Error adding movie to favorites: $e');
      return false;
    }
  }

  /// Ajoute une série aux favoris avec fallback
  Future<bool> addSeriesToFavorites(Series series) async {
    try {
      final favorites = await getFavorites();
      
      final favoriteItem = FavoriteItem.fromSeries(series);
      
      // Vérifier si déjà en favoris
      if (favorites.any((item) => item.id == favoriteItem.id)) {
        return false; // Déjà en favoris
      }
      
      favorites.add(favoriteItem);
      _cachedFavorites = favorites;
      
      // Essayer de sauvegarder
      try {
        final prefs = await SharedPreferences.getInstance();
        final favoritesJson = favorites.map((item) => item.toJson()).toList();
        await prefs.setString(_favoritesKey, json.encode(favoritesJson));
      } catch (e) {
        print('⚠️ Could not save to SharedPreferences: $e (kept in memory)');
      }
      
      return true;
    } catch (e) {
      print('Error adding series to favorites: $e');
      return false;
    }
  }

  /// Ajoute un film/série aux favoris (méthode générique pour compatibilité)
  Future<bool> addToFavorites(Movie movie) async {
    return await addMovieToFavorites(movie);
  }

  /// Retire un film/série des favoris avec fallback
  Future<bool> removeFromFavorites(String itemId) async {
    try {
      final favorites = await getFavorites();
      
      final initialLength = favorites.length;
      favorites.removeWhere((item) => item.id == itemId);
      
      if (favorites.length == initialLength) {
        return false; // Pas trouvé
      }
      
      _cachedFavorites = favorites;
      
      // Essayer de sauvegarder
      try {
        final prefs = await SharedPreferences.getInstance();
        final favoritesJson = favorites.map((item) => item.toJson()).toList();
        await prefs.setString(_favoritesKey, json.encode(favoritesJson));
      } catch (e) {
        print('⚠️ Could not save to SharedPreferences: $e (kept in memory)');
      }
      
      return true;
    } catch (e) {
      print('Error removing from favorites: $e');
      return false;
    }
  }

  /// Vérifie si un film/série est en favoris
  Future<bool> isFavorite(String itemId) async {
    try {
      final favorites = await getFavorites();
      return favorites.any((item) => item.id == itemId);
    } catch (e) {
      print('Error checking favorite status: $e');
      return false;
    }
  }

  /// Récupère tous les favoris avec fallback en mémoire
  Future<List<FavoriteItem>> getFavorites() async {
    // Retourner depuis le cache si disponible
    if (_cachedFavorites != null) {
      return _cachedFavorites!;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesString = prefs.getString(_favoritesKey);
      
      if (favoritesString == null || favoritesString.isEmpty) {
        _cachedFavorites = [];
        return [];
      }
      
      final favoritesJson = json.decode(favoritesString) as List;
      final favorites = favoritesJson
          .map((item) => FavoriteItem.fromJson(item))
          .toList();
      
      _cachedFavorites = favorites;
      return favorites;
    } catch (e) {
      print('⚠️ Error getting favorites (using empty list): $e');
      // Si SharedPreferences échoue, initialiser le service de stockage
      // FavoritesStorageService init skipped - media_kit only
      _cachedFavorites = [];
      return [];
    }
  }

  /// Récupère les films favoris uniquement
  Future<List<FavoriteItem>> getFavoriteMovies() async {
    final favorites = await getFavorites();
    return favorites.where((item) => item.type == 'movie').toList();
  }

  /// Récupère les séries favorites uniquement
  Future<List<FavoriteItem>> getFavoriteSeries() async {
    final favorites = await getFavorites();
    return favorites.where((item) => item.type == 'series').toList();
  }

  /// Récupère les favoris triés par date d'ajout (plus récents en premier)
  Future<List<FavoriteItem>> getFavoritesByDate() async {
    final favorites = await getFavorites();
    favorites.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return favorites;
  }

  /// Récupère les favoris triés par note
  Future<List<FavoriteItem>> getFavoritesByRating() async {
    final favorites = await getFavorites();
    favorites.sort((a, b) => b.numericRating.compareTo(a.numericRating));
    return favorites;
  }

  /// Récupère les favoris triés par titre
  Future<List<FavoriteItem>> getFavoritesByTitle() async {
    final favorites = await getFavorites();
    favorites.sort((a, b) => a.title.compareTo(b.title));
    return favorites;
  }

  /// Récupère les favoris par genre
  Future<List<FavoriteItem>> getFavoritesByGenre(String genre) async {
    final favorites = await getFavorites();
    return favorites.where((item) => 
      item.genres.any((g) => g.toLowerCase().contains(genre.toLowerCase()))
    ).toList();
  }

  /// Recherche dans les favoris
  Future<List<FavoriteItem>> searchFavorites(String query) async {
    if (query.trim().isEmpty) return getFavorites();
    
    final favorites = await getFavorites();
    final searchQuery = query.toLowerCase();
    
    return favorites.where((item) =>
      item.title.toLowerCase().contains(searchQuery) ||
      item.originalTitle.toLowerCase().contains(searchQuery) ||
      item.genres.any((genre) => genre.toLowerCase().contains(searchQuery))
    ).toList();
  }

  /// Efface tous les favoris
  Future<bool> clearAllFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_favoritesKey);
      return true;
    } catch (e) {
      print('Error clearing favorites: $e');
      return false;
    }
  }

  /// Exporte les favoris en JSON
  Future<String?> exportFavorites() async {
    try {
      final favorites = await getFavorites();
      final exportData = {
        'version': '1.0',
        'exported_at': DateTime.now().toIso8601String(),
        'count': favorites.length,
        'favorites': favorites.map((item) => item.toJson()).toList(),
      };
      return json.encode(exportData);
    } catch (e) {
      print('Error exporting favorites: $e');
      return null;
    }
  }

  /// Importe les favoris depuis JSON
  Future<bool> importFavorites(String jsonData) async {
    try {
      final importData = json.decode(jsonData);
      final favoritesList = importData['favorites'] as List;
      
      final favorites = favoritesList
          .map((item) => FavoriteItem.fromJson(item))
          .toList();
      
      // Sauvegarder les favoris importés
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = favorites.map((item) => item.toJson()).toList();
      await prefs.setString(_favoritesKey, json.encode(favoritesJson));
      
      return true;
    } catch (e) {
      print('Error importing favorites: $e');
      return false;
    }
  }

  /// Obtient les statistiques des favoris
  Future<Map<String, dynamic>> getFavoritesStats() async {
    final favorites = await getFavorites();
    
    final movieCount = favorites.where((item) => item.type == 'movie').length;
    final seriesCount = favorites.where((item) => item.type == 'series').length;
    
    // Genres les plus populaires
    final genreCount = <String, int>{};
    for (final item in favorites) {
      for (final genre in item.genres) {
        genreCount[genre] = (genreCount[genre] ?? 0) + 1;
      }
    }
    
    final topGenres = genreCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Note moyenne
    final totalRating = favorites.fold<double>(
      0.0, 
      (sum, item) => sum + item.numericRating
    );
    final averageRating = favorites.isNotEmpty ? totalRating / favorites.length : 0.0;
    
    return {
      'total_count': favorites.length,
      'movie_count': movieCount,
      'series_count': seriesCount,
      'average_rating': averageRating,
      'top_genres': topGenres.take(5).map((e) => {
        'genre': e.key,
        'count': e.value,
      }).toList(),
      'oldest_favorite': favorites.isNotEmpty 
          ? favorites.reduce((a, b) => a.addedAt.isBefore(b.addedAt) ? a : b).addedAt
          : null,
      'newest_favorite': favorites.isNotEmpty 
          ? favorites.reduce((a, b) => a.addedAt.isAfter(b.addedAt) ? a : b).addedAt
          : null,
    };
  }
}


