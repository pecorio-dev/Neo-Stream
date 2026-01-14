import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/favorite_item.dart';
import '../../data/models/movie.dart';
import '../../data/models/series.dart';
import '../../data/repositories/favorites_repository.dart';

final favoritesProvider = ChangeNotifierProvider((ref) => FavoritesProvider());

enum FavoritesLoadingState {
  initial,
  loading,
  loaded,
  error,
}

enum FavoritesSortBy {
  dateAdded,
  title,
  rating,
  year,
  genre,
}

class FavoritesProvider extends ChangeNotifier {
  final FavoritesRepository _repository = FavoritesRepository();

  // État
  FavoritesLoadingState _loadingState = FavoritesLoadingState.initial;
  List<FavoriteItem> _favorites = [];
  List<FavoriteItem> _filteredFavorites = [];
  String _errorMessage = '';

  // Filtres et tri
  String _searchQuery = '';
  String _selectedGenre = '';
  String _selectedType = ''; // 'movie', 'series', ou ''
  FavoritesSortBy _sortBy = FavoritesSortBy.dateAdded;
  bool _sortAscending = false;

  // Statistiques
  Map<String, dynamic> _stats = {};

  // Getters
  FavoritesLoadingState get loadingState => _loadingState;
  List<FavoriteItem> get favorites => _filteredFavorites;
  List<FavoriteItem> get allFavorites => _favorites;
  String get errorMessage => _errorMessage;
  bool get isLoading => _loadingState == FavoritesLoadingState.loading;
  bool get hasError => _loadingState == FavoritesLoadingState.error;
  bool get hasFavorites => _filteredFavorites.isNotEmpty;
  bool get isEmpty => _filteredFavorites.isEmpty && _loadingState == FavoritesLoadingState.loaded;

  // Filtres getters
  String get searchQuery => _searchQuery;
  String get selectedGenre => _selectedGenre;
  String get selectedType => _selectedType;
  FavoritesSortBy get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;

  // Statistiques
  Map<String, dynamic> get stats => _stats;
  int get totalCount => _favorites.length;
  int get movieCount => _favorites.where((item) => item.type == 'movie').length;
  int get seriesCount => _favorites.where((item) => item.type == 'series').length;

  // Genres disponibles
  List<String> get availableGenres {
    final genres = <String>{};
    for (final item in _favorites) {
      genres.addAll(item.genres);
    }
    final sortedGenres = genres.toList()..sort();
    return ['Tous'] + sortedGenres;
  }

  /// Charge les favoris
  Future<void> loadFavorites() async {
    _loadingState = FavoritesLoadingState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      _favorites = await _repository.getFavorites();
      _stats = await _repository.getFavoritesStats();
      _applyFiltersAndSort();
      _loadingState = FavoritesLoadingState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _loadingState = FavoritesLoadingState.error;
    }

    notifyListeners();
  }

  /// Ajoute un film aux favoris
  Future<bool> addMovieToFavorites(Movie movie) async {
    try {
      final success = await _repository.addMovieToFavorites(movie);
      if (success) {
        await loadFavorites(); // Recharger pour mettre à jour l'affichage
      }
      return success;
    } catch (e) {
      print('Error adding movie to favorites: $e');
      return false;
    }
  }

  /// Ajoute une série aux favoris
  Future<bool> addSeriesToFavorites(Series series) async {
    try {
      final success = await _repository.addSeriesToFavorites(series);
      if (success) {
        await loadFavorites(); // Recharger pour mettre à jour l'affichage
      }
      return success;
    } catch (e) {
      print('Error adding series to favorites: $e');
      return false;
    }
  }

  /// Ajoute un film/série aux favoris (méthode générique pour compatibilité)
  Future<bool> addToFavorites(Movie movie) async {
    return await addMovieToFavorites(movie);
  }

  /// Retire un film/série des favoris
  Future<bool> removeFromFavorites(String itemId) async {
    try {
      final success = await _repository.removeFromFavorites(itemId);
      if (success) {
        await loadFavorites(); // Recharger pour mettre à jour l'affichage
      }
      return success;
    } catch (e) {
      print('Error removing from favorites: $e');
      return false;
    }
  }

  /// Bascule l'état favori d'un film
  Future<bool> toggleMovieFavorite(Movie movie) async {
    final itemId = movie.url.hashCode.toString();
    final isFav = await isFavorite(itemId);
    
    if (isFav) {
      return await removeFromFavorites(itemId);
    } else {
      return await addMovieToFavorites(movie);
    }
  }

  /// Bascule l'état favori d'une série
  Future<bool> toggleSeriesFavorite(Series series) async {
    final itemId = series.url.hashCode.toString();
    final isFav = await isFavorite(itemId);
    
    if (isFav) {
      return await removeFromFavorites(itemId);
    } else {
      return await addSeriesToFavorites(series);
    }
  }

  /// Bascule l'état favori d'un film/série (méthode générique pour compatibilité)
  Future<bool> toggleFavorite(Movie movie) async {
    return await toggleMovieFavorite(movie);
  }

  /// Vérifie si un film/série est en favoris
  Future<bool> isFavorite(String itemId) async {
    try {
      return await _repository.isFavorite(itemId);
    } catch (e) {
      print('Error checking favorite status: $e');
      return false;
    }
  }

  /// Vérifie si un film est en favoris (synchrone)
  bool isFavoriteSync(String itemId) {
    return _favorites.any((item) => item.id == itemId);
  }

  /// Met à jour la recherche
  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _applyFiltersAndSort();
      notifyListeners();
    }
  }

  /// Met à jour le filtre de genre
  void setGenreFilter(String genre) {
    if (_selectedGenre != genre) {
      _selectedGenre = genre;
      _applyFiltersAndSort();
      notifyListeners();
    }
  }

  /// Met à jour le filtre de type
  void setTypeFilter(String type) {
    if (_selectedType != type) {
      _selectedType = type;
      _applyFiltersAndSort();
      notifyListeners();
    }
  }

  /// Met à jour le tri
  void setSortBy(FavoritesSortBy sortBy, {bool? ascending}) {
    bool changed = false;
    
    if (_sortBy != sortBy) {
      _sortBy = sortBy;
      changed = true;
    }
    
    if (ascending != null && _sortAscending != ascending) {
      _sortAscending = ascending;
      changed = true;
    }
    
    if (changed) {
      _applyFiltersAndSort();
      notifyListeners();
    }
  }

  /// Inverse l'ordre de tri
  void toggleSortOrder() {
    _sortAscending = !_sortAscending;
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// Applique les filtres et le tri
  void _applyFiltersAndSort() {
    var filtered = List<FavoriteItem>.from(_favorites);

    // Filtre par recherche
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) =>
        item.title.toLowerCase().contains(query) ||
        item.originalTitle.toLowerCase().contains(query) ||
        item.genres.any((genre) => genre.toLowerCase().contains(query))
      ).toList();
    }

    // Filtre par genre
    if (_selectedGenre.isNotEmpty && _selectedGenre != 'Tous') {
      filtered = filtered.where((item) =>
        item.genres.any((genre) => 
          genre.toLowerCase().contains(_selectedGenre.toLowerCase())
        )
      ).toList();
    }

    // Filtre par type
    if (_selectedType.isNotEmpty) {
      filtered = filtered.where((item) => item.type == _selectedType).toList();
    }

    // Tri
    switch (_sortBy) {
      case FavoritesSortBy.dateAdded:
        filtered.sort((a, b) => _sortAscending 
          ? a.addedAt.compareTo(b.addedAt)
          : b.addedAt.compareTo(a.addedAt));
        break;
      case FavoritesSortBy.title:
        filtered.sort((a, b) => _sortAscending 
          ? a.title.compareTo(b.title)
          : b.title.compareTo(a.title));
        break;
      case FavoritesSortBy.rating:
        filtered.sort((a, b) => _sortAscending 
          ? a.numericRating.compareTo(b.numericRating)
          : b.numericRating.compareTo(a.numericRating));
        break;
      case FavoritesSortBy.year:
        filtered.sort((a, b) => _sortAscending 
          ? a.releaseYear.compareTo(b.releaseYear)
          : b.releaseYear.compareTo(a.releaseYear));
        break;
      case FavoritesSortBy.genre:
        filtered.sort((a, b) {
          final aGenre = a.genres.isNotEmpty ? a.genres.first : '';
          final bGenre = b.genres.isNotEmpty ? b.genres.first : '';
          return _sortAscending 
            ? aGenre.compareTo(bGenre)
            : bGenre.compareTo(aGenre);
        });
        break;
    }

    _filteredFavorites = filtered;
  }

  /// Réinitialise tous les filtres
  void clearFilters() {
    _searchQuery = '';
    _selectedGenre = '';
    _selectedType = '';
    _sortBy = FavoritesSortBy.dateAdded;
    _sortAscending = false;
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// Efface tous les favoris
  Future<bool> clearAllFavorites() async {
    try {
      final success = await _repository.clearAllFavorites();
      if (success) {
        await loadFavorites();
      }
      return success;
    } catch (e) {
      print('Error clearing all favorites: $e');
      return false;
    }
  }

  /// Exporte les favoris
  Future<String?> exportFavorites() async {
    try {
      return await _repository.exportFavorites();
    } catch (e) {
      print('Error exporting favorites: $e');
      return null;
    }
  }

  /// Importe les favoris
  Future<bool> importFavorites(String jsonData) async {
    try {
      final success = await _repository.importFavorites(jsonData);
      if (success) {
        await loadFavorites();
      }
      return success;
    } catch (e) {
      print('Error importing favorites: $e');
      return false;
    }
  }

  /// Obtient les favoris récents
  List<FavoriteItem> getRecentFavorites({int limit = 10}) {
    final recent = List<FavoriteItem>.from(_favorites);
    recent.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return recent.take(limit).toList();
  }

  /// Obtient les favoris les mieux notés
  List<FavoriteItem> getTopRatedFavorites({int limit = 10}) {
    final topRated = List<FavoriteItem>.from(_favorites);
    topRated.sort((a, b) => b.numericRating.compareTo(a.numericRating));
    return topRated.take(limit).toList();
  }

  /// Obtient les favoris par genre
  List<FavoriteItem> getFavoritesByGenre(String genre) {
    return _favorites.where((item) =>
      item.genres.any((g) => g.toLowerCase().contains(genre.toLowerCase()))
    ).toList();
  }

  /// Réessaie le chargement en cas d'erreur
  Future<void> retry() async {
    await loadFavorites();
  }

  @override
  void dispose() {
    super.dispose();
  }
}