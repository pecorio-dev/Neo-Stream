import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/movie.dart';
import '../../data/models/series.dart';
import '../../data/services/movies_api_service.dart';
import '../../data/services/series_api_service.dart';
import '../../core/constants/app_constants.dart';

final searchProvider = ChangeNotifierProvider((ref) => SearchProvider());

// Classe pour unifier les résultats de recherche
class SearchResult {
  final String id;
  final String title;
  final String? originalTitle;
  final String? poster;
  final double rating;
  final int year;
  final List<String> genres;
  final String type; // 'movie' ou 'series'
  final Movie? movie;
  final Series? series;

  SearchResult({
    required this.id,
    required this.title,
    this.originalTitle,
    this.poster,
    required this.rating,
    required this.year,
    required this.genres,
    required this.type,
    this.movie,
    this.series,
  });

  factory SearchResult.fromMovie(Movie movie) {
    return SearchResult(
      id: movie.id,
      title: movie.title,
      originalTitle: movie.originalTitle,
      poster: movie.poster,
      rating: movie.numericRating,
      year: movie.releaseYear,
      genres: movie.cleanGenres,
      type: 'movie',
      movie: movie,
    );
  }

  factory SearchResult.fromSeries(Series series) {
    return SearchResult(
      id: series.id,
      title: series.title,
      originalTitle: series.originalTitle,
      poster: series.poster,
      rating: series.numericRating,
      year: series.releaseYear,
      genres: series.cleanGenres,
      type: 'series',
      series: series,
    );
  }
}

enum SearchLoadingState {
  initial,
  loading,
  loaded,
  error,
}

enum SearchType {
  all,
  movies,
  series,
}

class SearchProvider extends ChangeNotifier {
  // État
  SearchLoadingState _loadingState = SearchLoadingState.initial;
  List<SearchResult> _searchResults = [];
  String _errorMessage = '';
  String _currentQuery = '';
  SearchType _searchType = SearchType.all;

  // Historique de recherche
  List<String> _searchHistory = [];

  // Filtres
  String _selectedGenre = '';
  double _minRating = 0.0;
  int _minYear = 0;
  int _maxYear = DateTime.now().year;

  // Suggestions
  List<String> _suggestions = [];

  // Debounce
  Timer? _debounceTimer;

  // Getters
  SearchLoadingState get loadingState => _loadingState;
  List<SearchResult> get searchResults => _searchResults;
  String get errorMessage => _errorMessage;
  String get currentQuery => _currentQuery;
  SearchType get searchType => _searchType;
  List<String> get searchHistory => _searchHistory;
  String get selectedGenre => _selectedGenre;
  double get minRating => _minRating;
  int get minYear => _minYear;
  int get maxYear => _maxYear;
  List<String> get suggestions => _suggestions;

  bool get isLoading => _loadingState == SearchLoadingState.loading;
  bool get hasError => _loadingState == SearchLoadingState.error;
  bool get hasResults => _searchResults.isNotEmpty;
  bool get isEmpty =>
      _searchResults.isEmpty && _loadingState == SearchLoadingState.loaded;

  /// Effectue une recherche
  Future<void> search(String query, {SearchType? type}) async {
    if (query.trim().isEmpty) {
      _clearResults();
      return;
    }

    // Annuler la recherche précédente
    _debounceTimer?.cancel();

    // Debounce pour éviter trop de requêtes
    _debounceTimer = Timer(AppConstants.searchDebounce, () {
      _performSearch(query, type ?? _searchType);
    });
  }

  /// Effectue la recherche réelle (TOUJOURS via l'API, jamais en cache local)
  Future<void> _performSearch(String query, SearchType type) async {
    _loadingState = SearchLoadingState.loading;
    _currentQuery = query;
    _searchType = type;
    _errorMessage = '';
    notifyListeners();

    try {
      // Ajouter à l'historique
      _addToHistory(query);

      // IMPORTANT: Toujours effectuer la recherche via l'API distante
      // Ne jamais utiliser de cache local pour garantir des résultats à jour
      List<SearchResult> results = [];

      switch (type) {
        case SearchType.movies:
          // Recherche de films via l'API uniquement
          final movieResults =
              await MoviesApiService.searchMovies(query: query);
          results = movieResults
              .map((movie) => SearchResult.fromMovie(movie))
              .toList();
          break;
        case SearchType.series:
          // Recherche de séries via l'API uniquement
          final seriesResults =
              await SeriesApiService.searchSeries(query: query);
          results = seriesResults
              .map((series) => SearchResult.fromSeries(series))
              .toList();
          break;
        case SearchType.all:
        default:
          // Recherche combinée films + séries via l'API
          final movieResults =
              await MoviesApiService.searchMovies(query: query);
          final seriesResults =
              await SeriesApiService.searchSeries(query: query);
          final movieSearchResults = movieResults
              .map((movie) => SearchResult.fromMovie(movie))
              .toList();
          final seriesSearchResults = seriesResults
              .map((series) => SearchResult.fromSeries(series))
              .toList();
          results = [...movieSearchResults, ...seriesSearchResults];
          break;
      }

      // Stocker les résultats bruts avant filtrage
      _searchResults = results;

      // Appliquer les filtres côté client
      _applyFilters();

      _loadingState = SearchLoadingState.loaded;
    } catch (e) {
      _errorMessage = 'Erreur de recherche: ${e.toString()}';
      _loadingState = SearchLoadingState.error;
      _searchResults = [];
    }

    notifyListeners();
  }

  /// Applique les filtres aux résultats
  void _applyFilters() {
    var filtered = List<SearchResult>.from(_searchResults);

    // Filtre par genre
    if (_selectedGenre.isNotEmpty) {
      filtered = filtered
          .where((result) => result.genres.any((genre) =>
              genre.toLowerCase().contains(_selectedGenre.toLowerCase())))
          .toList();
    }

    // Filtre par note
    if (_minRating > 0) {
      filtered =
          filtered.where((result) => result.rating >= _minRating).toList();
    }

    // Filtre par année
    if (_minYear > 0) {
      filtered = filtered.where((result) => result.year >= _minYear).toList();
    }

    if (_maxYear < DateTime.now().year) {
      filtered = filtered.where((result) => result.year <= _maxYear).toList();
    }

    _searchResults = filtered;
  }

  /// Change le type de recherche
  void setSearchType(SearchType type) {
    if (_searchType != type) {
      _searchType = type;
      if (_currentQuery.isNotEmpty) {
        _performSearch(_currentQuery, type);
      }
    }
  }

  /// Met à jour le filtre de genre
  void setGenreFilter(String genre) {
    _selectedGenre = genre;
    _applyFilters();
    notifyListeners();
  }

  /// Met à jour le filtre de note
  void setRatingFilter(double rating) {
    _minRating = rating;
    _applyFilters();
    notifyListeners();
  }

  /// Met à jour le filtre d'année
  void setYearFilter(int minYear, int maxYear) {
    _minYear = minYear;
    _maxYear = maxYear;
    _applyFilters();
    notifyListeners();
  }

  /// Efface tous les filtres
  void clearFilters() {
    _selectedGenre = '';
    _minRating = 0.0;
    _minYear = 0;
    _maxYear = DateTime.now().year;
    _applyFilters();
    notifyListeners();
  }

  /// Ajoute une requête à l'historique
  void _addToHistory(String query) {
    if (query.trim().isEmpty) return;

    // Supprimer si déjà présent
    _searchHistory.remove(query);

    // Ajouter au début
    _searchHistory.insert(0, query);

    // Limiter à 20 éléments
    if (_searchHistory.length > 20) {
      _searchHistory = _searchHistory.take(20).toList();
    }
  }

  /// Supprime un élément de l'historique
  void removeFromHistory(String query) {
    _searchHistory.remove(query);
    notifyListeners();
  }

  /// Efface tout l'historique
  void clearHistory() {
    _searchHistory.clear();
    notifyListeners();
  }

  /// Génère des suggestions basées sur la requête
  void generateSuggestions(String query) {
    if (query.trim().isEmpty) {
      _suggestions = [];
      notifyListeners();
      return;
    }

    // Suggestions basées sur l'historique
    final historySuggestions = _searchHistory
        .where((item) => item.toLowerCase().contains(query.toLowerCase()))
        .take(5)
        .toList();

    // Suggestions prédéfinies
    final predefinedSuggestions = [
      'Action',
      'Comédie',
      'Drame',
      'Thriller',
      'Science-Fiction',
      'Romance',
      'Horreur',
      'Animation',
      'Documentaire',
      'Guerre',
    ]
        .where((item) => item.toLowerCase().contains(query.toLowerCase()))
        .take(3)
        .toList();

    _suggestions = [...historySuggestions, ...predefinedSuggestions];
    notifyListeners();
  }

  /// Efface les résultats
  void _clearResults() {
    _searchResults = [];
    _currentQuery = '';
    _loadingState = SearchLoadingState.initial;
    _errorMessage = '';
    notifyListeners();
  }

  /// Réessaie la dernière recherche
  Future<void> retry() async {
    if (_currentQuery.isNotEmpty) {
      await _performSearch(_currentQuery, _searchType);
    }
  }

  /// Recherche instantanée (sans debounce)
  Future<void> instantSearch(String query, {SearchType? type}) async {
    _debounceTimer?.cancel();
    await _performSearch(query, type ?? _searchType);
  }

  /// Obtient les résultats populaires
  Future<void> loadPopularResults() async {
    _loadingState = SearchLoadingState.loading;
    _currentQuery = 'Populaires';
    _errorMessage = '';
    notifyListeners();

    try {
      final movieResults = await MoviesApiService.getPopularMovies();
      _searchResults =
          movieResults.map((movie) => SearchResult.fromMovie(movie)).toList();
      _loadingState = SearchLoadingState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _loadingState = SearchLoadingState.error;
      _searchResults = [];
    }

    notifyListeners();
  }

  /// Obtient les résultats récents
  Future<void> loadRecentResults() async {
    _loadingState = SearchLoadingState.loading;
    _currentQuery = 'Récents';
    _errorMessage = '';
    notifyListeners();

    try {
      final movieResults = await MoviesApiService.getRecentMovies();
      _searchResults =
          movieResults.map((movie) => SearchResult.fromMovie(movie)).toList();
      _loadingState = SearchLoadingState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _loadingState = SearchLoadingState.error;
      _searchResults = [];
    }

    notifyListeners();
  }

  /// Obtient les genres disponibles
  List<String> getAvailableGenres() {
    final genres = <String>{};
    for (final result in _searchResults) {
      genres.addAll(result.genres);
    }
    return genres.toList()..sort();
  }

  /// Obtient les années disponibles
  List<int> getAvailableYears() {
    final years = <int>{};
    for (final result in _searchResults) {
      if (result.year > 0) {
        years.add(result.year);
      }
    }
    final sortedYears = years.toList()..sort();
    return sortedYears.reversed.toList();
  }

  /// Obtient les films depuis les résultats
  List<Movie> getMoviesFromResults() {
    return _searchResults
        .where((result) => result.type == 'movie' && result.movie != null)
        .map((result) => result.movie!)
        .toList();
  }

  /// Obtient les séries depuis les résultats
  List<Series> getSeriesFromResults() {
    return _searchResults
        .where((result) => result.type == 'series' && result.series != null)
        .map((result) => result.series!)
        .toList();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
