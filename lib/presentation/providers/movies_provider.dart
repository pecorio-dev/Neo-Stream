import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/movie.dart';
import '../../data/services/movies_api_service.dart';

final moviesProvider = ChangeNotifierProvider((ref) => MoviesProvider());

enum MoviesLoadingState {
  initial,
  loading,
  loaded,
  error,
  loadingMore,
}

class MoviesProvider extends ChangeNotifier {
  // État
  MoviesLoadingState _loadingState = MoviesLoadingState.initial;
  List<Movie> _movies = [];
  List<Movie> _filteredMovies = [];
  String _errorMessage = '';

  // Filtres
  String _selectedGenre = '';
  String _selectedQuality = '';
  String _selectedLanguage = '';
  int _selectedYear = 0;
  double _minRating = 0.0;
  String _sortBy = 'rating'; // rating, year, title, relevance

  // Pagination
  int _currentPage = 0;
  final int _itemsPerPage = 50;
  bool _hasMoreItems = true;
  bool _isLoadingMore = false;

  // Getters
  MoviesLoadingState get loadingState => _loadingState;
  List<Movie> get movies => _filteredMovies;
  List<Movie> get allMovies => _movies;
  String get errorMessage => _errorMessage;
  bool get isLoading => _loadingState == MoviesLoadingState.loading;
  bool get isLoadingMore =>
      _loadingState == MoviesLoadingState.loadingMore || _isLoadingMore;
  bool get hasError => _loadingState == MoviesLoadingState.error;
  bool get hasMovies => _filteredMovies.isNotEmpty;
  bool get hasMoreItems => _hasMoreItems;
  bool get hasMore => _hasMoreItems;
  String? get error => hasError ? _errorMessage : null;

  // Filtres getters
  String get selectedGenre => _selectedGenre;
  String get selectedQuality => _selectedQuality;
  String get selectedLanguage => _selectedLanguage;
  int get selectedYear => _selectedYear;
  double get minRating => _minRating;
  String get sortBy => _sortBy;

  // Statistiques
  int get totalMovies => _movies.length;
  int get filteredMoviesCount => _filteredMovies.length;

  List<String> get availableGenres {
    if (_movies.isEmpty) return ['Tous'];
    final genres = <String>{};
    for (final movie in _movies) {
      if (movie.genres != null) {
        genres.addAll(movie.genres!);
      }
    }
    final sortedGenres = genres.toList()..sort();
    return ['Tous'] + sortedGenres;
  }

  List<String> get availableQualities {
    if (_movies.isEmpty) return ['Toutes'];
    final qualities = _movies
        .map((m) => m.quality ?? '')
        .where((q) => q.isNotEmpty)
        .toSet()
        .toList();
    qualities.sort();
    return ['Toutes'] + qualities;
  }

  List<String> get availableLanguages {
    final languages = _movies
        .map((m) => m.language ?? '')
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList();
    languages.sort();
    return ['Toutes'] + languages;
  }

  List<int> get availableYears {
    final years = _movies
        .map((m) => m.releaseYear ?? 0)
        .where((y) => y > 0)
        .toSet()
        .toList();
    years.sort((a, b) => b.compareTo(a)); // Plus récent en premier
    return [0] + years; // 0 = Toutes les années
  }

  /// Charge les films depuis l'API
  Future<void> loadMovies({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 0;
      _hasMoreItems = true;
      _movies.clear();
      _filteredMovies.clear();
    }

    if (_loadingState == MoviesLoadingState.loading ||
        _loadingState == MoviesLoadingState.loadingMore ||
        _isLoadingMore) {
      return;
    }

    _loadingState = _currentPage == 0
        ? MoviesLoadingState.loading
        : MoviesLoadingState.loadingMore;
    _errorMessage = '';
    notifyListeners();

    try {
      final offset = _currentPage * _itemsPerPage;
      final response = await MoviesApiService.getMovies(
        limit: _itemsPerPage,
        offset: offset,
        forceRefresh: refresh,
      );

      if (refresh || _currentPage == 0) {
        _movies = response.data;
      } else {
        _movies.addAll(response.data);
      }

      // Vérifier s'il y a plus d'éléments
      _hasMoreItems = response.data.length == _itemsPerPage;

      _applyFilters();
      _loadingState = MoviesLoadingState.loaded;
      _currentPage++;
    } catch (e) {
      _errorMessage = e.toString();
      _loadingState = MoviesLoadingState.error;
    }

    notifyListeners();
  }

  /// Charge plus de films (pagination)
  Future<void> loadMoreMovies() async {
    if (!_hasMoreItems ||
        _isLoadingMore ||
        _loadingState == MoviesLoadingState.loading) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      final offset = _currentPage * _itemsPerPage;
      final response = await MoviesApiService.getMovies(
        limit: _itemsPerPage,
        offset: offset,
        forceRefresh: true,
      );

      _movies.addAll(response.data);

      // Vérifier s'il y a plus d'éléments
      _hasMoreItems = response.data.length == _itemsPerPage;

      _applyFilters();
      _currentPage++;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  /// Recherche des films
  Future<void> searchMovies(String query) async {
    if (query.trim().isEmpty) {
      await loadMovies(refresh: true);
      return;
    }

    _loadingState = MoviesLoadingState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await MoviesApiService.searchMovies(query: query);
      if (response is List<Movie>) {
        _movies = response;
      } else {
        // Assume response has a movies property or is a MoviesResponse
        try {
          _movies = (response as dynamic).movies ?? [];
        } catch (e) {
          _movies = [];
        }
      }
      _applyFilters();
      _loadingState = MoviesLoadingState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _loadingState = MoviesLoadingState.error;
    }

    notifyListeners();
  }

  /// Filtre par genre
  Future<void> filterByGenre(String genre) async {
    _selectedGenre = genre;
    _applyFilters();
    notifyListeners();
  }

  /// Applique les filtres et le tri
  void _applyFilters() {
    var filtered = List<Movie>.from(_movies);

    // Filtre par genre
    if (_selectedGenre.isNotEmpty && _selectedGenre != 'Tous') {
      filtered = filtered
          .where((movie) =>
              movie.genres?.any((genre) =>
                  genre.toLowerCase().contains(_selectedGenre.toLowerCase())) ??
              false)
          .toList();
    }

    // Filtre par qualité
    if (_selectedQuality.isNotEmpty && _selectedQuality != 'Toutes') {
      filtered = filtered
          .where((movie) =>
              (movie.quality ?? '').toLowerCase() ==
              _selectedQuality.toLowerCase())
          .toList();
    }

    // Filtre par langue
    if (_selectedLanguage.isNotEmpty && _selectedLanguage != 'Toutes') {
      filtered = filtered
          .where((movie) => (movie.language ?? '')
              .toLowerCase()
              .contains(_selectedLanguage.toLowerCase()))
          .toList();
    }

    // Filtre par année
    if (_selectedYear > 0) {
      filtered = filtered
          .where((movie) => (movie.releaseYear ?? 0) == _selectedYear)
          .toList();
    }

    // Filtre par note minimum
    if (_minRating > 0) {
      filtered = filtered
          .where((movie) => (movie.numericRating ?? 0) >= _minRating)
          .toList();
    }

    // Tri
    switch (_sortBy) {
      case 'rating':
        filtered.sort(
            (a, b) => (b.numericRating ?? 0).compareTo(a.numericRating ?? 0));
        break;
      case 'year':
        filtered
            .sort((a, b) => (b.releaseYear ?? 0).compareTo(a.releaseYear ?? 0));
        break;
      case 'title':
        filtered.sort((a, b) => (a.title ?? '').compareTo(b.title ?? ''));
        break;
      case 'relevance':
      default:
        // Garder l'ordre original
        break;
    }

    _filteredMovies = filtered;
  }

  /// Met à jour le filtre de genre
  void setGenreFilter(String genre) {
    if (_selectedGenre != genre) {
      _selectedGenre = genre;
      _applyFilters();
      notifyListeners();
    }
  }

  /// Met à jour le filtre de qualité
  void setQualityFilter(String quality) {
    if (_selectedQuality != quality) {
      _selectedQuality = quality;
      _applyFilters();
      notifyListeners();
    }
  }

  /// Met à jour le filtre de langue
  void setLanguageFilter(String language) {
    if (_selectedLanguage != language) {
      _selectedLanguage = language;
      _applyFilters();
      notifyListeners();
    }
  }

  /// Met à jour le filtre d'année
  void setYearFilter(int year) {
    if (_selectedYear != year) {
      _selectedYear = year;
      _applyFilters();
      notifyListeners();
    }
  }

  /// Met à jour le filtre de note minimum
  void setRatingFilter(double rating) {
    if (_minRating != rating) {
      _minRating = rating;
      _applyFilters();
      notifyListeners();
    }
  }

  /// Met à jour le tri
  void setSortBy(String sortBy) {
    if (_sortBy != sortBy) {
      _sortBy = sortBy;
      _applyFilters();
      notifyListeners();
    }
  }

  /// Réinitialise tous les filtres
  void clearFilters() {
    _selectedGenre = '';
    _selectedQuality = '';
    _selectedLanguage = '';
    _selectedYear = 0;
    _minRating = 0.0;
    _sortBy = 'rating';
    _applyFilters();
    notifyListeners();
  }

  /// Recherche dans les films chargés
  List<Movie> searchInMovies(String query) {
    if (query.trim().isEmpty) return _filteredMovies;

    final searchQuery = query.toLowerCase();
    return _filteredMovies
        .where((movie) =>
            (movie.title ?? '').toLowerCase().contains(searchQuery) ||
            (movie.originalTitle ?? '').toLowerCase().contains(searchQuery) ||
            (movie.director ?? '').toLowerCase().contains(searchQuery) ||
            (movie.actors?.any(
                    (actor) => actor.toLowerCase().contains(searchQuery)) ??
                false) ||
            (movie.genres?.any(
                    (genre) => genre.toLowerCase().contains(searchQuery)) ??
                false))
        .toList();
  }

  /// Obtient les films par genre
  List<Movie> getMoviesByGenre(String genre) {
    return _movies
        .where((movie) =>
            movie.genres
                ?.any((g) => g.toLowerCase().contains(genre.toLowerCase())) ??
            false)
        .toList();
  }

  /// Obtient les films les mieux notés
  List<Movie> getTopRatedMovies({int limit = 10}) {
    final sorted = List<Movie>.from(_movies);
    sorted
        .sort((a, b) => (b.numericRating ?? 0).compareTo(a.numericRating ?? 0));
    return sorted.take(limit).toList();
  }

  /// Obtient les films récents
  List<Movie> getRecentMovies({int limit = 10}) {
    final sorted = List<Movie>.from(_movies);
    sorted.sort((a, b) => (b.releaseYear ?? 0).compareTo(a.releaseYear ?? 0));
    return sorted.take(limit).toList();
  }

  /// Réessaie le chargement en cas d'erreur
  Future<void> retry() async {
    await loadMovies(refresh: true);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
