import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/series_compact.dart';
import '../../data/services/series_compact_service.dart';
import '../../data/services/dio_client.dart';

// Import pour SeriesLoadingProgress
import '../../data/services/series_compact_service.dart' show SeriesLoadingProgress;

final seriesCompactProvider = ChangeNotifierProvider((ref) => SeriesCompactProvider());

enum SeriesLoadingState {
  initial,
  loading,
  loaded,
  error,
  loadingMore,
}

class SeriesCompactProvider extends ChangeNotifier {
  
  // État
  SeriesLoadingState _loadingState = SeriesLoadingState.initial;
  List<SeriesCompact> _series = [];
  List<SeriesCompact> _filteredSeries = [];
  String _errorMessage = '';
  
  // Service
  late final SeriesCompactService _service;
  
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
  int _totalItems = 0;

  // Préchargement en arrière-plan
  bool _backgroundPreloadingEnabled = true;
  int _preloadThreshold = 10; // Nombre d'éléments restants avant de déclencher le préchargement
  bool _isPreloading = false;
  
  SeriesCompactProvider() {
    _service = SeriesCompactService(DioClient.instance);
  }
  
  // Getters
  SeriesLoadingState get loadingState => _loadingState;
  List<SeriesCompact> get series => _filteredSeries;
  List<SeriesCompact> get allSeries => _series;
  String? get error => _loadingState == SeriesLoadingState.error ? _errorMessage : null;
  bool get isLoading => _loadingState == SeriesLoadingState.loading;
  bool get isLoadingMore => _loadingState == SeriesLoadingState.loadingMore || _isLoadingMore;
  bool get hasError => _loadingState == SeriesLoadingState.error;
  bool get isPreloading => _isPreloading;
  bool get hasMoreItems => _hasMoreItems;
  int get totalItems => _totalItems;
  bool get hasSeries => _filteredSeries.isNotEmpty;
  
  // Filtres getters
  String get selectedGenre => _selectedGenre;
  String get selectedQuality => _selectedQuality;
  String get selectedLanguage => _selectedLanguage;
  int get selectedYear => _selectedYear;
  double get minRating => _minRating;
  String get sortBy => _sortBy;
  
  // Statistiques
  int get totalSeries => _series.length;
  int get filteredSeriesCount => _filteredSeries.length;
  
  List<String> get availableGenres {
    if (_series.isEmpty) return [];
    final genres = <String>{};
    for (final series in _series) {
      genres.addAll(series.genres);
    }
    final sortedGenres = genres.toList()..sort();
    return sortedGenres;
  }
  
  List<String> get availableQualities {
    if (_series.isEmpty) return [];
    // SeriesCompact doesn't have quality property, return empty list for now
    return [];
  }
  
  List<String> get availableLanguages {
    // SeriesCompact doesn't have language property, return empty list for now
    return [];
  }
  
  List<int> get availableYears {
    if (_series.isEmpty) return [];
    // Extract years from releaseDate string
    final years = <int>{};
    for (final series in _series) {
      if (series.releaseDate.isNotEmpty) {
        final year = int.tryParse(series.releaseDate.substring(0, 4));
        if (year != null && year > 0) {
          years.add(year);
        }
      }
    }
    final sortedYears = years.toList();
    sortedYears.sort((a, b) => b.compareTo(a)); // Plus récent en premier
    return sortedYears;
  }

  /// Charge les séries depuis l'API
  Future<void> loadSeries({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 0;
      _hasMoreItems = true;
      _series.clear();
      _filteredSeries.clear();
    }
    
    if (_loadingState == SeriesLoadingState.loading || 
        _loadingState == SeriesLoadingState.loadingMore ||
        _isLoadingMore) {
      return;
    }
    
    _loadingState = _currentPage == 0 
        ? SeriesLoadingState.loading 
        : SeriesLoadingState.loadingMore;
    _errorMessage = '';
    notifyListeners();
    
    try {
      final offset = _currentPage * _itemsPerPage;
      final response = await _service.getSeriesCompact(
        limit: _itemsPerPage,
        offset: offset,
      );
      
      if (refresh || _currentPage == 0) {
        _series = response.series;
      } else {
        _series.addAll(response.series);
      }
      
      // Vérifier s'il y a plus d'éléments
      _hasMoreItems = response.series.length == _itemsPerPage;
      
      _applyFilters();
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
    if (!_hasMoreItems || _isLoadingMore || _loadingState == SeriesLoadingState.loading) {
      return;
    }
    
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      final offset = _currentPage * _itemsPerPage;
      final response = await _service.getSeriesCompact(
        limit: _itemsPerPage,
        offset: offset,
      );
      
      _series.addAll(response.series);
      
      // Vérifier s'il y a plus d'éléments
      _hasMoreItems = response.series.length == _itemsPerPage;
      
      _applyFilters();
      _currentPage++;
      
    } catch (e) {
      _errorMessage = e.toString();
    }
    
    _isLoadingMore = false;
    notifyListeners();
  }

  /// Recherche des séries
  Future<void> searchSeries(String query) async {
    if (query.trim().isEmpty) {
      await loadSeries(refresh: true);
      return;
    }
    
    _loadingState = SeriesLoadingState.loading;
    _errorMessage = '';
    notifyListeners();
    
    try {
      final response = await _service.searchSeriesCompact(query: query);
      _series = response.series;
      _applyFilters();
      _loadingState = SeriesLoadingState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _loadingState = SeriesLoadingState.error;
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
    var filtered = List<SeriesCompact>.from(_series);
    
    // Filtrer les séries de démonstration
    filtered = filtered.where((series) => !_isDemoSeries(series)).toList();
    
    // Filtre par genre
    if (_selectedGenre.isNotEmpty) {
      filtered = filtered.where((series) =>
        series.genres.any((genre) => 
          genre.toLowerCase().contains(_selectedGenre.toLowerCase())
        )
      ).toList();
    }
    
    // Filtre par qualité (not available for SeriesCompact)
    // Skip quality filter as SeriesCompact doesn't have quality property
    
    // Filtre par langue (not available for SeriesCompact)
    // Skip language filter as SeriesCompact doesn't have language property
    
    // Filtre par année
    if (_selectedYear > 0) {
      filtered = filtered.where((series) {
        if (series.releaseDate.isNotEmpty) {
          final year = int.tryParse(series.releaseDate.substring(0, 4));
          return year == _selectedYear;
        }
        return false;
      }).toList();
    }
    
    // Filtre par note minimum
    if (_minRating > 0) {
      filtered = filtered.where((series) => series.numericRating >= _minRating).toList();
    }
    
    // Tri
    switch (_sortBy) {
      case 'rating':
        filtered.sort((a, b) => b.numericRating.compareTo(a.numericRating));
        break;
      case 'year':
        filtered.sort((a, b) {
          final yearA = int.tryParse(a.releaseDate.isNotEmpty ? a.releaseDate.substring(0, 4) : '0') ?? 0;
          final yearB = int.tryParse(b.releaseDate.isNotEmpty ? b.releaseDate.substring(0, 4) : '0') ?? 0;
          return yearB.compareTo(yearA);
        });
        break;
      case 'title':
        filtered.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'relevance':
      default:
        // Garder l'ordre original
        break;
    }
    
    _filteredSeries = filtered;
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

  /// Recherche dans les séries chargées
  List<SeriesCompact> searchInSeries(String query) {
    if (query.trim().isEmpty) return _filteredSeries;
    
    final searchQuery = query.toLowerCase();
    return _filteredSeries.where((series) =>
      series.title.toLowerCase().contains(searchQuery) ||
      series.originalTitle.toLowerCase().contains(searchQuery) ||
      series.director.toLowerCase().contains(searchQuery) ||
      series.actors.any((actor) => actor.toLowerCase().contains(searchQuery)) ||
      series.genres.any((genre) => genre.toLowerCase().contains(searchQuery))
    ).toList();
  }

  /// Obtient les séries par genre
  List<SeriesCompact> getSeriesByGenre(String genre) {
    return _series.where((series) =>
      series.genres.any((g) => g.toLowerCase().contains(genre.toLowerCase()))
    ).toList();
  }

  /// Obtient les séries les mieux notées
  List<SeriesCompact> getTopRatedSeries({int limit = 10}) {
    final sorted = List<SeriesCompact>.from(_series);
    sorted.sort((a, b) => b.numericRating.compareTo(a.numericRating));
    return sorted.take(limit).toList();
  }

  /// Obtient les séries récentes
  List<SeriesCompact> getRecentSeries({int limit = 10}) {
    final sorted = List<SeriesCompact>.from(_series);
    sorted.sort((a, b) {
      final yearA = int.tryParse(a.releaseDate.isNotEmpty ? a.releaseDate.substring(0, 4) : '0') ?? 0;
      final yearB = int.tryParse(b.releaseDate.isNotEmpty ? b.releaseDate.substring(0, 4) : '0') ?? 0;
      return yearB.compareTo(yearA);
    });
    return sorted.take(limit).toList();
  }

  /// Charge les séries de manière progressive avec mises à jour en temps réel
  Stream<SeriesLoadingProgress> loadSeriesProgressive({
    bool refresh = false,
    String? genre,
    String? quality,
    String? language,
    int? year,
    double? minRating,
    String? sortBy,
  }) async* {
    try {
      if (refresh) {
        _loadingState = SeriesLoadingState.loading;
        _series.clear();
        _filteredSeries.clear();
        _currentPage = 0;
        _hasMoreItems = true;
        notifyListeners();
      }

      final effectiveGenre = genre ?? _selectedGenre;
      final effectiveSortBy = sortBy ?? _sortBy;

final stream = _service.getSeriesCompactProgressive(
        limit: _itemsPerPage,
        offset: _currentPage * _itemsPerPage,
        genre: effectiveGenre.isNotEmpty ? effectiveGenre : null,
        sortBy: effectiveSortBy,
        enrichData: false, // Désactivé pour optimiser le chargement
      );

      await for (final progress in stream) {
        if (progress.hasError) {
          _loadingState = SeriesLoadingState.error;
          _errorMessage = progress.errorMessage ?? 'Erreur inconnue';
          notifyListeners();
          return;
        }

        // Mettre à jour les données avec la progression
        _series = progress.series;
        _applyFilters();
        _loadingState = progress.isCompleted ? SeriesLoadingState.loaded : SeriesLoadingState.loading;

        // Calculer le nombre total d'éléments
        _totalItems = progress.total;

        notifyListeners();

        // Si c'est terminé, mettre à jour la pagination
        if (progress.isCompleted) {
          _currentPage++;
          _hasMoreItems = _series.length < progress.total;
        }

        yield progress;
      }

    } catch (e) {
      _loadingState = SeriesLoadingState.error;
      _errorMessage = 'Erreur lors du chargement progressif: $e';
      notifyListeners();
    }
  }

  /// Réessaie le chargement en cas d'erreur
  Future<void> retry() async {
    await loadSeries(refresh: true);
  }
  
  /// Vérifie si le préchargement doit être déclenché
  void checkAndTriggerPreloading() {
    if (!_backgroundPreloadingEnabled || _isPreloading || !_hasMoreItems) return;

    final remainingItems = _series.length - (_currentPage * _itemsPerPage);
    if (remainingItems <= _preloadThreshold) {
      _preloadNextPage();
    }
  }

  /// Précharge la page suivante en arrière-plan
  Future<void> _preloadNextPage() async {
    if (_isPreloading || !_hasMoreItems) return;

    _isPreloading = true;

    try {
      final nextPage = _currentPage;
final stream = _service.getSeriesCompactProgressive(
        limit: _itemsPerPage,
        offset: nextPage * _itemsPerPage,
        genre: _selectedGenre.isNotEmpty ? _selectedGenre : null,
        sortBy: _sortBy,
        enrichData: false, // Désactivé pour optimiser le chargement
      );

      await for (final progress in stream) {
        if (progress.isCompleted && progress.series.isNotEmpty) {
          // Ajouter les nouvelles séries à la liste sans notifier immédiatement
          // pour éviter de perturber l'UI pendant le scroll
          _series.addAll(progress.series.where((newSeries) =>
            !_series.any((existing) => existing.id == newSeries.id)
          ));

          _totalItems = progress.total;
          _hasMoreItems = _series.length < progress.total;
          break; // On arrête après la première completion
        }
      }
    } catch (e) {
      print('Erreur lors du préchargement: $e');
    } finally {
      _isPreloading = false;
    }
  }


  /// Vérifie si une série est une série de démonstration
  bool _isDemoSeries(SeriesCompact series) {
    final titleLower = series.title.toLowerCase();
    final posterLower = series.poster.toLowerCase();

    return titleLower.contains('demo-series-') ||
           posterLower.contains('demo-series-');
  }

  @override
  void dispose() {
    super.dispose();
  }
}