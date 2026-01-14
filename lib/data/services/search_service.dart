import 'package:dio/dio.dart';
import '../models/movie.dart';
import '../models/series_compact.dart';
import '../models/series.dart';

/// Service de recherche unifié pour l'API Zenix.sg
class SearchService {
  static const String baseUrl = 'http://node.zenix.sg:25825';

  final Dio _dio;

  SearchService(this._dio);

  /// Recherche unifiée films + séries (endpoint /search)
  Future<UnifiedSearchResponse> search({
    required String query,
    String type = 'all', // all, film, serie
    String fields = 'title,original_title,synopsis,genres,actors,director',
    bool consolidated = true,
    int limit = 50,
    int offset = 0,
    double? minRating,
  }) async {
    try {
      // Si type = 'all', faire deux requêtes séparées et combiner les résultats
      if (type == 'all') {
        final filmResponse = await _searchByType(query, 'film', fields, consolidated, limit ~/ 2, offset, minRating);
        final serieResponse = await _searchByType(query, 'serie', fields, consolidated, limit ~/ 2, offset, minRating);

        return UnifiedSearchResponse(
          movies: filmResponse.movies,
          series: serieResponse.series,
          count: filmResponse.count + serieResponse.count,
          total: filmResponse.total + serieResponse.total,
          limit: limit,
          offset: offset,
        );
      } else {
        return await _searchByType(query, type, fields, consolidated, limit, offset, minRating);
      }
    } catch (e) {
      print('Erreur search: $e');
      rethrow;
    }
  }

  /// Recherche par type spécifique
  Future<UnifiedSearchResponse> _searchByType(
    String query,
    String type,
    String fields,
    bool consolidated,
    int limit,
    int offset,
    double? minRating,
  ) async {
    final queryParams = {
      'q': query,
      'type': type,
      'fields': fields,
      'consolidated': consolidated.toString(),
      'limit': limit,
      'offset': offset,
    };

    if (minRating != null) {
      queryParams['minrating'] = minRating.toString();
    }

    print('🔍 SearchService._searchByType - type: $type, query: $query');
    final response = await _dio.get(
      '/search',
      queryParameters: queryParams,
    );

    print('🔍 SearchService response status: ${response.statusCode}');
    print('🔍 SearchService raw response type: ${response.data.runtimeType}');
    if (response.data is Map) {
      print('🔍 SearchService response keys: ${(response.data as Map).keys.toList()}');
    }

    return UnifiedSearchResponse.fromJson(response.data);
  }

  /// Recherche avancée avec filtres (endpoint /searchadvanced)
  Future<UnifiedSearchResponse> searchAdvanced({
    String type = 'all',
    String? query,
    String fields = 'title,overview',
    double? minRating,
    bool consolidated = true,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'type': type,
        'fields': fields,
        'consolidated': consolidated.toString(),
        'limit': limit,
        'offset': offset,
      };

      if (query != null && query.isNotEmpty) {
        queryParams['q'] = query;
      }

      if (minRating != null) {
        queryParams['minrating'] = minRating.toString();
      }

      final response = await _dio.get(
        '/searchadvanced',
        queryParameters: queryParams,
      );

      return UnifiedSearchResponse.fromJson(response.data);
    } catch (e) {
      print('Erreur searchAdvanced: $e');
      rethrow;
    }
  }

  /// Recherche spécifique aux films
  Future<List<Movie>> searchMovies({
    required String query,
    int limit = 50,
    int offset = 0,
    double? minRating,
  }) async {
    final response = await search(
      query: query,
      type: 'movies',
      limit: limit,
      offset: offset,
      minRating: minRating,
    );
    return response.movies;
  }

  /// Recherche spécifique aux séries
  Future<List<Series>> searchSeries({
    required String query,
    int limit = 50,
    int offset = 0,
    double? minRating,
  }) async {
    final response = await search(
      query: query,
      type: 'series',
      consolidated: true,
      limit: limit,
      offset: offset,
      minRating: minRating,
    );
    return response.series;
  }

  /// Recherche par genre
  Future<UnifiedSearchResponse> searchByGenre({
    required String genre,
    String type = 'all',
    int limit = 50,
    int offset = 0,
  }) async {
    return await searchAdvanced(
      query: genre,
      type: type,
      fields: 'genres',
      limit: limit,
      offset: offset,
    );
  }

  /// Recherche par note minimale
  Future<UnifiedSearchResponse> searchByRating({
    required double minRating,
    String type = 'all',
    int limit = 50,
    int offset = 0,
  }) async {
    return await searchAdvanced(
      type: type,
      minRating: minRating,
      limit: limit,
      offset: offset,
    );
  }
}

/// Réponse de recherche unifiée
class UnifiedSearchResponse {
  final List<Movie> movies;
  final List<Series> series;
  final int count;
  final int total;
  final int limit;
  final int offset;

  UnifiedSearchResponse({
    this.movies = const [],
    this.series = const [],
    this.count = 0,
    this.total = 0,
    this.limit = 50,
    this.offset = 0,
  });

  bool get hasMore => offset + count < total;
  int get nextOffset => offset + limit;
  int get currentPage => (offset / limit).floor() + 1;
  int get totalPages => (total / limit).ceil();

  bool get hasMovies => movies.isNotEmpty;
  bool get hasSeries => series.isNotEmpty;
  bool get hasResults => hasMovies || hasSeries;

  factory UnifiedSearchResponse.fromJson(Map<String, dynamic> json) {
    print('🔍 UnifiedSearchResponse.fromJson - Raw JSON keys: ${json.keys.toList()}');
    
    // Essayer différentes structures de réponse possibles
    var data = json['data'] as List<dynamic>? ?? 
               json['results'] as List<dynamic>? ?? 
               [];
    
    print('🔍 Data structure: ${data.isNotEmpty ? data.first.runtimeType : 'empty'}, count: ${data.length}');
    
    final movies = <Movie>[];
    final series = <Series>[];

    // Séparer les films et séries du tableau data
    for (final item in data) {
      try {
        final itemMap = item as Map<String, dynamic>;
        final type = itemMap['type'] as String?;

        print('🔍 Processing item - type: $type, keys: ${itemMap.keys.toList()}');

        if (type == 'film') {
          movies.add(Movie.fromJson(itemMap));
        } else if (type == 'serie') {
          series.add(Series.fromJson(itemMap));
        }
      } catch (e) {
        print('❌ Error processing search result: $e');
      }
    }

    print('🔍 Found: ${movies.length} movies, ${series.length} series');

    return UnifiedSearchResponse(
      movies: movies,
      series: series,
      count: json['count'] ?? data.length,
      total: json['total'] ?? data.length,
      limit: json['limit'] ?? 50,
      offset: json['offset'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'movies': movies.map((m) => m.toJson()).toList(),
      'series': series.map((s) => s.toJson()).toList(),
      'count': count,
      'total': total,
      'limit': limit,
      'offset': offset,
    };
  }
}
