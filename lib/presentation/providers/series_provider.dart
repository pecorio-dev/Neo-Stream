import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/series.dart';
import '../../data/services/series_api_service.dart';

final seriesProvider = ChangeNotifierProvider((ref) => SeriesProvider());

enum SeriesLoadingState {
  initial,
  loading,
  loaded,
  error,
}

enum SeriesSortBy {
  rating,
  year,
  title,
  relevance,
  episodes,
  seasons,
}

enum SeriesFilterType {
  all,
  ongoing,
  completed,
}

class SeriesProvider extends ChangeNotifier {
  // État
  SeriesLoadingState _loadingState = SeriesLoadingState.initial;
  List<Series> _allSeries = [];
  List<Series> _filteredSeries = [];
  String _errorMessage = '';

  // Filtres et tri
  String _searchQuery = '';
  String _selectedGenre = '';
  String _selectedQuality = '';
  SeriesFilterType _filterType = SeriesFilterType.all;
  double _minRating = 0.0;
  SeriesSortBy _sortBy = SeriesSortBy.relevance;
  bool _sortAscending = false;

  // Pagination
  int _currentPage = 0;
  final int _itemsPerPage = 50;
  bool _hasMoreItems = true;
  bool _isLoadingMore = false;

  // Cache des genres et qualités
  List<String> _availableGenres = ['Tous'];
  List<String> _availableQualities = ['Toutes'];

  // Getters
  SeriesLoadingState get loadingState => _loadingState;
  List<Series> get series => _filteredSeries;
  List<Series> get allSeries => _allSeries;
  String get errorMessage => _errorMessage;
  bool get isLoading => _loadingState == SeriesLoadingState.loading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasError => _loadingState == SeriesLoadingState.error;
  bool get hasSeries => _filteredSeries.isNotEmpty;
  bool get isEmpty =>
      _filteredSeries.isEmpty && _loadingState == SeriesLoadingState.loaded;
  bool get hasMoreItems => _hasMoreItems;

  // Filtres getters
  String get searchQuery => _searchQuery;
  String get selectedGenre => _selectedGenre;
  String get selectedQuality => _selectedQuality;
  SeriesFilterType get filterType => _filterType;
  double get minRating => _minRating;
  SeriesSortBy get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;

  // Statistiques
  int get totalSeriesCount => _allSeries.length;
  int get filteredSeriesCount => _filteredSeries.length;
  int get ongoingSeriesCount => _allSeries.where((s) => s.isOngoing).length;
  int get completedSeriesCount => _allSeries.where((s) => s.isCompleted).length;

  // Genres et qualités disponibles
  List<String> get availableGenres => _availableGenres;
  List<String> get availableQualities => _availableQualities;

  /// Charge les séries avec pagination
  Future<void> loadSeries({bool refresh = false}) async {
    if (_loadingState == SeriesLoadingState.loading || _isLoadingMore) return;

    if (refresh) {
      _currentPage = 0;
      _hasMoreItems = true;
      _allSeries.clear();
      _filteredSeries.clear();
    }

    _loadingState = SeriesLoadingState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final offset = _currentPage * _itemsPerPage;
      final response = await SeriesApiService.getSeries(
        limit: _itemsPerPage,
        offset: offset,
        forceRefresh: refresh,
      );

      if (refresh || _currentPage == 0) {
        _allSeries = response.data;
      } else {
        _allSeries.addAll(response.data);
      }

      // Vérifier s'il y a plus d'éléments
      _hasMoreItems = response.data.length == _itemsPerPage;

      _updateAvailableFilters();
      _applyFiltersAndSort();

      _loadingState = SeriesLoadingState.loaded;
      _currentPage++;
    } catch (e) {
      _errorMessage = e.toString();
      _loadingState = SeriesLoadingState.error;
    }

    notifyListeners();
  }

  /// Charge plus de séries (pagination)
  Future<void> loadMoreSeries() async {
    if (!_hasMoreItems ||
        _isLoadingMore ||
        _loadingState == SeriesLoadingState.loading) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      final offset = _currentPage * _itemsPerPage;
      final response = await SeriesApiService.getSeries(
        limit: _itemsPerPage,
        offset: offset,
        forceRefresh: true,
      );

      _allSeries.addAll(response.data);

      // Vérifier s'il y a plus d'éléments
      _hasMoreItems = response.data.length == _itemsPerPage;

      _updateAvailableFilters();
      _applyFiltersAndSort();
      _currentPage++;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  /// Recherche dans les séries locales
  List<Series> searchInSeries(String query) {
    if (query.trim().isEmpty) return _allSeries;

    final searchQuery = query.toLowerCase();
    return _allSeries
        .where((series) =>
            series.title.toLowerCase().contains(searchQuery) ||
            (series.originalTitle?.toLowerCase().contains(searchQuery) ??
                false) ||
            series.genres
                .any((genre) => genre.toLowerCase().contains(searchQuery)) ||
            series.director.toLowerCase().contains(searchQuery) ||
            series.actors
                .any((actor) => actor.toLowerCase().contains(searchQuery)))
        .toList();
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

  /// Met à jour le filtre de qualité
  void setQualityFilter(String quality) {
    if (_selectedQuality != quality) {
      _selectedQuality = quality;
      _applyFiltersAndSort();
      notifyListeners();
    }
  }

  /// Met à jour le filtre de type
  void setFilterType(SeriesFilterType type) {
    if (_filterType != type) {
      _filterType = type;
      _applyFiltersAndSort();
      notifyListeners();
    }
  }

  /// Met à jour le filtre de note
  void setRatingFilter(double rating) {
    if (_minRating != rating) {
      _minRating = rating;
      _applyFiltersAndSort();
      notifyListeners();
    }
  }

  /// Met à jour le tri
  void setSortBy(String sortBy) {
    SeriesSortBy newSortBy;
    switch (sortBy) {
      case 'rating':
        newSortBy = SeriesSortBy.rating;
        break;
      case 'year':
        newSortBy = SeriesSortBy.year;
        break;
      case 'title':
        newSortBy = SeriesSortBy.title;
        break;
      case 'episodes':
        newSortBy = SeriesSortBy.episodes;
        break;
      case 'seasons':
        newSortBy = SeriesSortBy.seasons;
        break;
      default:
        newSortBy = SeriesSortBy.relevance;
    }

    if (_sortBy != newSortBy) {
      _sortBy = newSortBy;
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
    var filtered = List<Series>.from(_allSeries);

    // Filtrer les séries de démonstration
    filtered = filtered.where((series) => !_isDemoSeries(series)).toList();

    // Filtre par recherche
    if (_searchQuery.isNotEmpty) {
      filtered = searchInSeries(_searchQuery);
    }

    // Filtre par genre
    if (_selectedGenre.isNotEmpty && _selectedGenre != 'Tous') {
      filtered = filtered
          .where((series) => series.genres.any((genre) =>
              genre.toLowerCase().contains(_selectedGenre.toLowerCase())))
          .toList();
    }

    // Filtre par qualité
    if (_selectedQuality.isNotEmpty && _selectedQuality != 'Toutes') {
      filtered = filtered
          .where((series) => (series.quality?.toLowerCase() ?? '')
              .contains(_selectedQuality.toLowerCase()))
          .toList();
    }

    // Filtre par type
    switch (_filterType) {
      case SeriesFilterType.ongoing:
        filtered = filtered.where((series) => series.isOngoing).toList();
        break;
      case SeriesFilterType.completed:
        filtered = filtered.where((series) => series.isCompleted).toList();
        break;
      case SeriesFilterType.all:
        // Pas de filtre
        break;
    }

    // Filtre par note
    if (_minRating > 0) {
      filtered = filtered
          .where((series) => series.numericRating >= _minRating)
          .toList();
    }

    // Tri
    switch (_sortBy) {
      case SeriesSortBy.rating:
        filtered.sort((a, b) => _sortAscending
            ? a.numericRating.compareTo(b.numericRating)
            : b.numericRating.compareTo(a.numericRating));
        break;
      case SeriesSortBy.year:
        filtered.sort((a, b) => _sortAscending
            ? a.releaseYear.compareTo(b.releaseYear)
            : b.releaseYear.compareTo(a.releaseYear));
        break;
      case SeriesSortBy.title:
        filtered.sort((a, b) => _sortAscending
            ? a.title.compareTo(b.title)
            : b.title.compareTo(a.title));
        break;
      case SeriesSortBy.episodes:
        filtered.sort((a, b) => _sortAscending
            ? a.actualTotalEpisodes.compareTo(b.actualTotalEpisodes)
            : b.actualTotalEpisodes.compareTo(a.actualTotalEpisodes));
        break;
      case SeriesSortBy.seasons:
        filtered.sort((a, b) => _sortAscending
            ? a.actualTotalSeasons.compareTo(b.actualTotalSeasons)
            : b.actualTotalSeasons.compareTo(a.actualTotalSeasons));
        break;
      case SeriesSortBy.relevance:
        // Tri par pertinence (note + année)
        filtered.sort((a, b) {
          final scoreA = a.numericRating + (a.releaseYear / 10000);
          final scoreB = b.numericRating + (b.releaseYear / 10000);
          return _sortAscending
              ? scoreA.compareTo(scoreB)
              : scoreB.compareTo(scoreA);
        });
        break;
    }

    _filteredSeries = filtered;
  }

  /// Met à jour les filtres disponibles
  void _updateAvailableFilters() {
    // Genres
    final genres = <String>{'Tous'};
    for (final series in _allSeries) {
      genres.addAll(series.cleanGenres);
    }
    _availableGenres = genres.toList()..sort();

    // Qualités
    final qualities = <String>{'Toutes'};
    for (final series in _allSeries) {
      if ((series.quality?.isNotEmpty ?? false)) {
        qualities.add(series.quality!);
      }
    }
    _availableQualities = qualities.toList()..sort();
  }

  /// Efface tous les filtres
  void clearFilters() {
    _searchQuery = '';
    _selectedGenre = '';
    _selectedQuality = '';
    _filterType = SeriesFilterType.all;
    _minRating = 0.0;
    _sortBy = SeriesSortBy.relevance;
    _sortAscending = false;
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// Obtient les séries populaires
  Future<List<Series>> getPopularSeries({int limit = 10}) async {
    try {
      return await SeriesApiService.getPopularSeries(limit: limit);
    } catch (e) {
      print('Error getting popular series: $e');
      return [];
    }
  }

  /// Obtient les séries récentes
  Future<List<Series>> getRecentSeries({int limit = 10}) async {
    try {
      return await SeriesApiService.getRecentSeries(limit: limit);
    } catch (e) {
      print('Error getting recent series: $e');
      return [];
    }
  }

  /// Obtient les séries par genre
  Future<List<Series>> getSeriesByGenre(String genre) async {
    try {
      return await SeriesApiService.getSeriesByGenre(genre);
    } catch (e) {
      print('Error getting series by genre: $e');
      return [];
    }
  }

  /// Recherche de séries via l'API
  Future<List<Series>> searchSeries(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      return await SeriesApiService.searchSeries(query: query);
    } catch (e) {
      print('Error searching series: $e');
      return [];
    }
  }

  /// Obtient les détails d'une série
  Future<Series?> getSeriesDetails(String seriesId) async {
    try {
      return await SeriesApiService.getSeriesDetails(seriesId);
    } catch (e) {
      print('Error getting series details: $e');
      return null;
    }
  }

  /// Réessaie le chargement en cas d'erreur
  Future<void> retry() async {
    await loadSeries(refresh: true);
  }

  /// Vide le cache
  void clearCache() {
    SeriesApiService.clearCache();
  }

  /// Vérifie si une série est une série de démonstration
  bool _isDemoSeries(Series series) {
    final titleLower = series.title.toLowerCase();
    final posterLower = series.poster?.toLowerCase() ?? '';

    return titleLower.contains('demo-series-') ||
        posterLower.contains('demo-series-');
  }

  @override
  void dispose() {
    super.dispose();
  }
}
