import 'package:dio/dio.dart';
import '../models/movie.dart';
import '../models/series.dart';
import '../models/api_responses.dart';
import '../../core/constants/app_constants.dart';
import 'dio_client.dart';

class MoviesApiService {
  static const String _tag = 'MoviesApiService';

  static Dio get _dio => DioClient.instance;

  // Cache simple
  static ApiResponse<Movie>? _cachedMovies;
  static DateTime? _lastFetchTime;

  /// Récupère les films avec pagination
  static Future<ApiResponse<Movie>> getMovies({
    bool forceRefresh = false,
    int? limit,
    int offset = 0,
    String? year,
    String? sort, // 'title', 'year', 'watch_links'
  }) async {
    // Vérifier le cache
    if (!forceRefresh && _cachedMovies != null && _lastFetchTime != null) {
      final timeDiff = DateTime.now().difference(_lastFetchTime!);
      if (timeDiff < AppConstants.cacheExpiration) {
        print('$_tag: Returning cached movies');
        return _cachedMovies!;
      }
    }

    try {
      print(
          '$_tag: Fetching movies from API with limit=$limit, offset=$offset...');

      final queryParams = <String, dynamic>{
        if (limit != null) 'limit': limit,
        if (offset > 0) 'offset': offset,
        if (year != null) 'year': year,
        if (sort != null) 'sort': sort,
      };

      final response = await _dio.get(
        '/films',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      // La réponse de l'API a une structure différente
      final responseData = response.data;
      final apiResponse = ApiResponse<Movie>(
        total: responseData['total'] ?? 0,
        offset: responseData['offset'] ?? 0,
        limit: responseData['limit'],
        count: responseData['count'] ?? 0,
        data: (responseData['data'] as List<dynamic>? ?? [])
            .map((json) => Movie.fromJson(json as Map<String, dynamic>))
            .toList(),
      );

      // Mettre en cache
      _cachedMovies = apiResponse;
      _lastFetchTime = DateTime.now();

      print('$_tag: Successfully fetched ${apiResponse.count} movies');
      return apiResponse;
    } catch (e) {
      print('$_tag: Error fetching movies: $e');

      // Retourner le cache si disponible en cas d'erreur
      if (_cachedMovies != null) {
        print('$_tag: Returning cached movies due to error');
        return _cachedMovies!;
      }

      rethrow;
    }
  }

  /// Récupère les détails d'un film spécifique
  static Future<Movie> getMovieDetails(String movieId) async {
    try {
      print('$_tag: Fetching movie details for ID: $movieId');

      final response = await _dio.get('/item/$movieId');
      final movie = Movie.fromJson(response.data);

      print('$_tag: Successfully fetched movie details: ${movie.title}');
      return movie;
    } catch (e) {
      print('$_tag: Error fetching movie details: $e');
      rethrow;
    }
  }

  /// Recherche de films et séries
  static Future<List<Movie>> searchMovies({required String query}) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      print('$_tag: Searching content with query: $query');

      final response = await _dio.get(
        '/search',
        queryParameters: {'q': query.trim()},
      );

      final responseData = response.data;
      final results = (responseData['data'] as List<dynamic>? ?? [])
          .map((item) => Movie.fromJson(item as Map<String, dynamic>))
          .toList();

      print('$_tag: Found ${results.length} items for query: $query');
      return results;
    } catch (e) {
      print('$_tag: Error searching content: $e');
      rethrow;
    }
  }

  /// Récupère les films par genre
  static Future<List<Movie>> getMoviesByGenre(String genre) async {
    try {
      final allMovies = await getMovies();
      return allMovies.data
          .where((movie) => movie.genres
              .any((g) => g.toLowerCase().contains(genre.toLowerCase())))
          .toList();
    } catch (e) {
      print('$_tag: Error filtering movies by genre: $e');
      rethrow;
    }
  }

  /// Récupère les films populaires (basé sur la note)
  static Future<List<Movie>> getPopularMovies({int limit = 20}) async {
    try {
      final allMovies = await getMovies();
      final sortedMovies = List<Movie>.from(allMovies.data);

      // Trier par note décroissante
      sortedMovies.sort((a, b) => b.numericRating.compareTo(a.numericRating));

      return sortedMovies.take(limit).toList();
    } catch (e) {
      print('$_tag: Error getting popular movies: $e');
      rethrow;
    }
  }

  /// Récupère les films récents (basé sur l'année de sortie)
  static Future<List<Movie>> getRecentMovies({int limit = 20}) async {
    try {
      final allMovies = await getMovies();
      final sortedMovies = List<Movie>.from(allMovies.data);

      // Trier par année décroissante
      sortedMovies.sort((a, b) => b.releaseYear.compareTo(a.releaseYear));

      return sortedMovies.take(limit).toList();
    } catch (e) {
      print('$_tag: Error getting recent movies: $e');
      rethrow;
    }
  }

  /// Vide le cache
  static void clearCache() {
    _cachedMovies = null;
    _lastFetchTime = null;
    print('$_tag: Cache cleared');
  }

  /// Vérifie si le cache est valide
  static bool get isCacheValid {
    if (_cachedMovies == null || _lastFetchTime == null) return false;
    final timeDiff = DateTime.now().difference(_lastFetchTime!);
    return timeDiff < AppConstants.cacheExpiration;
  }

  /// Obtient les statistiques du cache
  static Map<String, dynamic> getCacheStats() {
    return {
      'has_cache': _cachedMovies != null,
      'cache_time': _lastFetchTime?.toIso8601String(),
      'cache_valid': isCacheValid,
      'movies_count': _cachedMovies?.count ?? 0,
    };
  }

  // ==================== SÉRIES ====================

  static ApiResponse<Series>? _cachedSeries;
  static DateTime? _lastSeriesFetchTime;

  /// Récupère les séries avec pagination
  static Future<ApiResponse<Series>> getSeries({
    bool forceRefresh = false,
    int? limit,
    int offset = 0,
    String? year,
    String? sort,
  }) async {
    // Vérifier le cache
    if (!forceRefresh &&
        _cachedSeries != null &&
        _lastSeriesFetchTime != null) {
      final timeDiff = DateTime.now().difference(_lastSeriesFetchTime!);
      if (timeDiff < AppConstants.cacheExpiration) {
        print('$_tag: Returning cached series');
        return _cachedSeries!;
      }
    }

    try {
      print(
          '$_tag: Fetching series from API with limit=$limit, offset=$offset...');

      final queryParams = <String, dynamic>{
        if (limit != null) 'limit': limit,
        if (offset > 0) 'offset': offset,
        if (year != null) 'year': year,
        if (sort != null) 'sort': sort,
      };

      final response = await _dio.get(
        '/series',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final responseData = response.data;
      final apiResponse = ApiResponse<Series>(
        total: responseData['total'] ?? 0,
        offset: responseData['offset'] ?? 0,
        limit: responseData['limit'],
        count: responseData['count'] ?? 0,
        data: (responseData['data'] as List<dynamic>? ?? [])
            .map((json) => Series.fromJson(json as Map<String, dynamic>))
            .toList(),
      );

      // Mettre en cache
      _cachedSeries = apiResponse;
      _lastSeriesFetchTime = DateTime.now();

      print('$_tag: Successfully fetched ${apiResponse.count} series');
      return apiResponse;
    } catch (e) {
      print('$_tag: Error fetching series: $e');

      // Retourner le cache si disponible en cas d'erreur
      if (_cachedSeries != null) {
        print('$_tag: Returning cached series due to error');
        return _cachedSeries!;
      }

      rethrow;
    }
  }

  /// Extrait un ID propre depuis une URL ou retourne l'ID si déjà propre
  static String _extractCleanId(String idOrUrl) {
    if (idOrUrl.startsWith('http')) {
      final uri = Uri.parse(idOrUrl);
      String cleanId = uri.pathSegments.last;
      if (cleanId.contains('-')) {
        cleanId = cleanId.split('-').first;
      }
      if (cleanId.endsWith('.html')) {
        cleanId = cleanId.replaceAll('.html', '');
      }
      print('$_tag: Extracted clean ID: $cleanId from URL: $idOrUrl');
      return cleanId;
    }
    return idOrUrl;
  }

  /// Récupère les détails d'une série spécifique
  static Future<Series> getSeriesDetails(String seriesId) async {
    try {
      print('$_tag: Fetching series details for ID: $seriesId');

      final cleanId = _extractCleanId(seriesId);
      final response = await _dio.get('/item/$cleanId');
      final series = Series.fromJson(response.data);

      print('$_tag: Successfully fetched series details: ${series.title}');
      return series;
    } catch (e) {
      print('$_tag: Error fetching series details: $e');
      rethrow;
    }
  }

  /// Recherche de séries
  static Future<List<Series>> searchSeries({required String query}) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      print('$_tag: Searching series with query: $query');

      final response = await _dio.get(
        '/search',
        queryParameters: {'q': query.trim()},
      );

      final responseData = response.data;
      final results = (responseData['data'] as List<dynamic>? ?? [])
          .where((item) => (item as Map<String, dynamic>)['type'] == 'serie')
          .map((item) => Series.fromJson(item as Map<String, dynamic>))
          .toList();

      print('$_tag: Found ${results.length} series for query: $query');
      return results;
    } catch (e) {
      print('$_tag: Error searching series: $e');
      rethrow;
    }
  }

  /// Récupère les séries par genre
  static Future<List<Series>> getSeriesByGenre(String genre) async {
    try {
      final allSeries = await getSeries();
      return allSeries.data
          .where((series) => series.genres
              .any((g) => g.toLowerCase().contains(genre.toLowerCase())))
          .toList();
    } catch (e) {
      print('$_tag: Error filtering series by genre: $e');
      rethrow;
    }
  }

  /// Récupère les séries populaires
  static Future<List<Series>> getPopularSeries({int limit = 20}) async {
    try {
      final allSeries = await getSeries();
      final sortedSeries = List<Series>.from(allSeries.data);

      // Trier par note décroissante
      sortedSeries.sort((a, b) => b.numericRating.compareTo(a.numericRating));

      return sortedSeries.take(limit).toList();
    } catch (e) {
      print('$_tag: Error getting popular series: $e');
      rethrow;
    }
  }

  /// Récupère les séries récentes
  static Future<List<Series>> getRecentSeries({int limit = 20}) async {
    try {
      final allSeries = await getSeries();
      final sortedSeries = List<Series>.from(allSeries.data);

      // Trier par année décroissante
      sortedSeries.sort((a, b) => b.releaseYear.compareTo(a.releaseYear));

      return sortedSeries.take(limit).toList();
    } catch (e) {
      print('$_tag: Error getting recent series: $e');
      rethrow;
    }
  }

  /// Vide le cache des séries
  static void clearSeriesCache() {
    _cachedSeries = null;
    _lastSeriesFetchTime = null;
    print('$_tag: Series cache cleared');
  }

  /// Vérifie si le cache des séries est valide
  static bool get isSeriesCacheValid {
    if (_cachedSeries == null || _lastSeriesFetchTime == null) return false;
    final timeDiff = DateTime.now().difference(_lastSeriesFetchTime!);
    return timeDiff < AppConstants.cacheExpiration;
  }

  /// Obtient les statistiques du cache des séries
  static Map<String, dynamic> getSeriesCacheStats() {
    return {
      'has_cache': _cachedSeries != null,
      'cache_time': _lastSeriesFetchTime?.toIso8601String(),
      'cache_valid': isSeriesCacheValid,
      'series_count': _cachedSeries?.count ?? 0,
    };
  }
}
