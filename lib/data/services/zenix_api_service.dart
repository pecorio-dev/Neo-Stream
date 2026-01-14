import 'package:dio/dio.dart';
import '../models/movie.dart';
import '../models/series.dart';
import '../models/api_responses.dart';

/// Service API pour Zenix.sg - Conforme à l'API réelle v2.1.0
class ZenixApiService {
  static const String baseUrl = 'http://node.zenix.sg:25825';

  final Dio _dio;

  ZenixApiService(this._dio);

  // ============================================================================
  // LISTES PRINCIPALES
  // ============================================================================

  /// Récupère la liste des films avec pagination et filtres
  Future<ApiResponse<Movie>> getMovies({
    int? limit,
    int offset = 0,
    String? year,
    String? sort, // 'title', 'year', 'watch_links'
  }) async {
    try {
      final queryParams = {
        'offset': offset,
        if (limit != null) 'limit': limit,
        if (year != null) 'year': year,
        if (sort != null) 'sort': sort,
      };

      final response = await _dio.get(
        '/films',
        queryParameters: queryParams,
      );

      return ApiResponse.fromJson(
        response.data,
        (json) => Movie.fromJson(json),
      );
    } catch (e) {
      print('Erreur getMovies: $e');
      rethrow;
    }
  }

  /// Récupère la liste des séries avec pagination et filtres
  Future<ApiResponse<Series>> getSeries({
    int? limit,
    int offset = 0,
    String? year,
    String? sort, // 'title', 'year', 'episodes'
  }) async {
    try {
      final queryParams = {
        'offset': offset,
        if (limit != null) 'limit': limit,
        if (year != null) 'year': year,
        if (sort != null) 'sort': sort,
      };

      final response = await _dio.get(
        '/series',
        queryParameters: queryParams,
      );

      return ApiResponse.fromJson(
        response.data,
        (json) => Series.fromJson(json),
      );
    } catch (e) {
      print('Erreur getSeries: $e');
      rethrow;
    }
  }

  // ============================================================================
  // RECHERCHE ET FILTRAGE
  // ============================================================================

  /// Recherche avancée dans films et séries
  Future<SearchResponse> search({
    required String q,
    String? type, // 'film' ou 'serie'
    String? genre,
    String? actor,
    String? director,
    String? year,
    int? yearMin,
    int? yearMax,
    double? ratingMin,
    String? quality,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'q': q,
        'limit': limit,
        'offset': offset,
        if (type != null) 'type': type,
        if (genre != null) 'genre': genre,
        if (actor != null) 'actor': actor,
        if (director != null) 'director': director,
        if (year != null) 'year': year,
        if (yearMin != null) 'year_min': yearMin,
        if (yearMax != null) 'year_max': yearMax,
        if (ratingMin != null) 'rating_min': ratingMin,
        if (quality != null) 'quality': quality,
      };

      final response = await _dio.get(
        '/search',
        queryParameters: queryParams,
      );

      return SearchResponse.fromJson(response.data);
    } catch (e) {
      print('Erreur search: $e');
      rethrow;
    }
  }

  /// Filtrage sans recherche textuelle
  Future<ContentListResponse> filter({
    String? type,
    String? genre,
    String? actor,
    String? director,
    String? year,
    int? yearMin,
    int? yearMax,
    double? ratingMin,
    double? ratingMax,
    String? quality,
    String? version,
    String? language,
    String? sortBy, // 'title', 'year', 'rating'
    String? sortOrder, // 'asc', 'desc'
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'limit': limit,
        'offset': offset,
        if (type != null) 'type': type,
        if (genre != null) 'genre': genre,
        if (actor != null) 'actor': actor,
        if (director != null) 'director': director,
        if (year != null) 'year': year,
        if (yearMin != null) 'year_min': yearMin,
        if (yearMax != null) 'year_max': yearMax,
        if (ratingMin != null) 'rating_min': ratingMin,
        if (ratingMax != null) 'rating_max': ratingMax,
        if (quality != null) 'quality': quality,
        if (version != null) 'version': version,
        if (language != null) 'language': language,
        if (sortBy != null) 'sort_by': sortBy,
        if (sortOrder != null) 'sort_order': sortOrder,
      };

      final response = await _dio.get(
        '/filter',
        queryParameters: queryParams,
      );

      return ContentListResponse.fromJson(response.data, null);
    } catch (e) {
      print('Erreur filter: $e');
      rethrow;
    }
  }

  // ============================================================================
  // NAVIGATION PAR CRITÈRES
  // ============================================================================

  /// Parcourir par genre
  Future<ContentListResponse> getByGenre({
    required String genre,
    String? type,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'limit': limit,
        'offset': offset,
        if (type != null) 'type': type,
      };

      final response = await _dio.get(
        '/by-genre/$genre',
        queryParameters: queryParams,
      );

      return ContentListResponse.fromJson(response.data, null);
    } catch (e) {
      print('Erreur getByGenre: $e');
      rethrow;
    }
  }

  /// Parcourir par acteur
  Future<ContentListResponse> getByActor({
    required String actor,
    String? type,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'limit': limit,
        'offset': offset,
        if (type != null) 'type': type,
      };

      final response = await _dio.get(
        '/by-actor/$actor',
        queryParameters: queryParams,
      );

      return ContentListResponse.fromJson(response.data, null);
    } catch (e) {
      print('Erreur getByActor: $e');
      rethrow;
    }
  }

  /// Parcourir par réalisateur
  Future<ContentListResponse> getByDirector({
    required String director,
    String? type,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'limit': limit,
        'offset': offset,
        if (type != null) 'type': type,
      };

      final response = await _dio.get(
        '/by-director/$director',
        queryParameters: queryParams,
      );

      return ContentListResponse.fromJson(response.data, null);
    } catch (e) {
      print('Erreur getByDirector: $e');
      rethrow;
    }
  }

  /// Parcourir par année
  Future<ContentListResponse> getByYear({
    required String year,
    String? type,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'limit': limit,
        'offset': offset,
        if (type != null) 'type': type,
      };

      final response = await _dio.get(
        '/by-year/$year',
        queryParameters: queryParams,
      );

      return ContentListResponse.fromJson(response.data, null);
    } catch (e) {
      print('Erreur getByYear: $e');
      rethrow;
    }
  }

  /// Top notés
  Future<ContentListResponse> getTopRated({
    String? type,
    double minRating = 7.0,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'min_rating': minRating,
        'limit': limit,
        'offset': offset,
        if (type != null) 'type': type,
      };

      final response = await _dio.get(
        '/top-rated',
        queryParameters: queryParams,
      );

      return ContentListResponse.fromJson(response.data, null);
    } catch (e) {
      print('Erreur getTopRated: $e');
      rethrow;
    }
  }

  /// Récents
  Future<ContentListResponse> getRecent({
    String? type,
    String? year,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'limit': limit,
        'offset': offset,
        if (type != null) 'type': type,
        if (year != null) 'year': year,
      };

      final response = await _dio.get(
        '/recent',
        queryParameters: queryParams,
      );

      return ContentListResponse.fromJson(response.data, null);
    } catch (e) {
      print('Erreur getRecent: $e');
      rethrow;
    }
  }

  /// Aléatoires
  Future<RandomResponse> getRandom({
    String? type,
    String? genre,
    int count = 10,
  }) async {
    try {
      final queryParams = {
        'count': count,
        if (type != null) 'type': type,
        if (genre != null) 'genre': genre,
      };

      final response = await _dio.get(
        '/random',
        queryParameters: queryParams,
      );

      return RandomResponse.fromJson(response.data);
    } catch (e) {
      print('Erreur getRandom: $e');
      rethrow;
    }
  }

  // ============================================================================
  // MÉTADONNÉES
  // ============================================================================

  /// Liste des genres
  Future<GenresResponse> getGenres({String? type}) async {
    try {
      final queryParams = {
        if (type != null) 'type': type,
      };

      final response = await _dio.get(
        '/genres',
        queryParameters: queryParams,
      );

      return GenresResponse.fromJson(response.data);
    } catch (e) {
      print('Erreur getGenres: $e');
      rethrow;
    }
  }

  /// Liste des acteurs
  Future<ActorsResponse> getActors({
    String? type,
    String? q,
    int limit = 100,
  }) async {
    try {
      final queryParams = {
        'limit': limit,
        if (type != null) 'type': type,
        if (q != null) 'q': q,
      };

      final response = await _dio.get(
        '/actors',
        queryParameters: queryParams,
      );

      return ActorsResponse.fromJson(response.data);
    } catch (e) {
      print('Erreur getActors: $e');
      rethrow;
    }
  }

  /// Liste des réalisateurs
  Future<DirectorsResponse> getDirectors({
    String? type,
    String? q,
    int limit = 100,
  }) async {
    try {
      final queryParams = {
        'limit': limit,
        if (type != null) 'type': type,
        if (q != null) 'q': q,
      };

      final response = await _dio.get(
        '/directors',
        queryParameters: queryParams,
      );

      return DirectorsResponse.fromJson(response.data);
    } catch (e) {
      print('Erreur getDirectors: $e');
      rethrow;
    }
  }

  /// Liste des années
  Future<YearsResponse> getYears({String? type}) async {
    try {
      final queryParams = {
        if (type != null) 'type': type,
      };

      final response = await _dio.get(
        '/years',
        queryParameters: queryParams,
      );

      return YearsResponse.fromJson(response.data);
    } catch (e) {
      print('Erreur getYears: $e');
      rethrow;
    }
  }

  /// Liste des qualités
  Future<QualitiesResponse> getQualities({String? type}) async {
    try {
      final queryParams = {
        if (type != null) 'type': type,
      };

      final response = await _dio.get(
        '/qualities',
        queryParameters: queryParams,
      );

      return QualitiesResponse.fromJson(response.data);
    } catch (e) {
      print('Erreur getQualities: $e');
      rethrow;
    }
  }

  // ============================================================================
  // AUTOCOMPLÉTION ET SUGGESTIONS
  // ============================================================================

  /// Autocomplétion rapide
  Future<AutocompleteResponse> autocomplete({
    required String q,
    String? type,
    int limit = 10,
  }) async {
    try {
      final queryParams = {
        'q': q,
        'limit': limit,
        if (type != null) 'type': type,
      };

      final response = await _dio.get(
        '/autocomplete',
        queryParameters: queryParams,
      );

      return AutocompleteResponse.fromJson(response.data);
    } catch (e) {
      print('Erreur autocomplete: $e');
      rethrow;
    }
  }

  /// Suggestions d'acteurs
  Future<List<String>> suggestActors({
    required String q,
    int limit = 10,
  }) async {
    try {
      final queryParams = {
        'q': q,
        'limit': limit,
      };

      final response = await _dio.get(
        '/suggest/actors',
        queryParameters: queryParams,
      );

      final suggestions = response.data['suggestions'] as List<dynamic>? ?? [];
      return suggestions.cast<String>();
    } catch (e) {
      print('Erreur suggestActors: $e');
      return [];
    }
  }

  /// Suggestions de réalisateurs
  Future<List<String>> suggestDirectors({
    required String q,
    int limit = 10,
  }) async {
    try {
      final queryParams = {
        'q': q,
        'limit': limit,
      };

      final response = await _dio.get(
        '/suggest/directors',
        queryParameters: queryParams,
      );

      final suggestions = response.data['suggestions'] as List<dynamic>? ?? [];
      return suggestions.cast<String>();
    } catch (e) {
      print('Erreur suggestDirectors: $e');
      return [];
    }
  }

  /// Suggestions de genres
  Future<List<String>> suggestGenres({
    required String q,
    int limit = 10,
  }) async {
    try {
      final queryParams = {
        'q': q,
        'limit': limit,
      };

      final response = await _dio.get(
        '/suggest/genres',
        queryParameters: queryParams,
      );

      final suggestions = response.data['suggestions'] as List<dynamic>? ?? [];
      return suggestions.cast<String>();
    } catch (e) {
      print('Erreur suggestGenres: $e');
      return [];
    }
  }

  /// Recherche multi-catégorie
  Future<MultiSearchResponse> multiSearch({
    required String q,
    int limit = 10,
  }) async {
    try {
      final queryParams = {
        'q': q,
        'limit': limit,
      };

      final response = await _dio.get(
        '/multi-search',
        queryParameters: queryParams,
      );

      return MultiSearchResponse.fromJson(response.data);
    } catch (e) {
      print('Erreur multiSearch: $e');
      rethrow;
    }
  }

  // ============================================================================
  // DÉTAILS ET ÉPISODES
  // ============================================================================

  /// Détails complets d'un item
  Future<ItemDetailsResponse> getItemDetails(String itemId) async {
    try {
      final response = await _dio.get('/item/$itemId');
      return ItemDetailsResponse.fromJson(response.data);
    } catch (e) {
      print('Erreur getItemDetails: $e');
      rethrow;
    }
  }

  /// Épisodes d'une série avec filtrage optionnel par saison
  Future<EpisodesResponse> getEpisodes(
    String itemId, {
    int? season,
  }) async {
    try {
      final queryParams = {
        if (season != null) 'season': season,
      };

      final response = await _dio.get(
        '/item/$itemId/episodes',
        queryParameters: queryParams,
      );

      return EpisodesResponse.fromJson(response.data);
    } catch (e) {
      print('Erreur getEpisodes: $e');
      rethrow;
    }
  }

  /// Liens de streaming d'un item
  Future<WatchLinksResponse> getWatchLinks(String itemId) async {
    try {
      final response = await _dio.get('/item/$itemId/watch-links');
      return WatchLinksResponse.fromJson(response.data);
    } catch (e) {
      print('Erreur getWatchLinks: $e');
      rethrow;
    }
  }

  /// Détails d'un épisode spécifique
  Future<Map<String, dynamic>?> getEpisodeDetails(
    String itemId,
    int season,
    int episode,
  ) async {
    try {
      final response = await _dio.get(
        '/item/$itemId/episode/$season/$episode',
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Erreur getEpisodeDetails: $e');
      return null;
    }
  }

  // ============================================================================
  // SANTÉ ET STATISTIQUES
  // ============================================================================

  /// Health check
  Future<HealthResponse?> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return HealthResponse.fromJson(response.data);
    } catch (e) {
      print('Erreur healthCheck: $e');
      return null;
    }
  }

  /// Statistiques
  Future<Map<String, dynamic>?> getStats() async {
    try {
      final response = await _dio.get('/stats');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Erreur getStats: $e');
      return null;
    }
  }

  /// Debug info
  Future<Map<String, dynamic>?> getDebugInfo() async {
    try {
      final response = await _dio.get('/debug');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Erreur getDebugInfo: $e');
      return null;
    }
  }

  /// Debug logs
  Future<Map<String, dynamic>?> getDebugLogs({
    int limit = 100,
    String? level,
  }) async {
    try {
      final queryParams = {
        'limit': limit,
        if (level != null) 'level': level,
      };

      final response = await _dio.get(
        '/debug/logs',
        queryParameters: queryParams,
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Erreur getDebugLogs: $e');
      return null;
    }
  }

  /// Debug metrics
  Future<Map<String, dynamic>?> getDebugMetrics() async {
    try {
      final response = await _dio.get('/debug/metrics');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Erreur getDebugMetrics: $e');
      return null;
    }
  }

  /// Debug progress
  Future<Map<String, dynamic>?> getDebugProgress() async {
    try {
      final response = await _dio.get('/debug/progress');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Erreur getDebugProgress: $e');
      return null;
    }
  }

  /// Refresh status
  Future<Map<String, dynamic>?> getRefreshStatus() async {
    try {
      final response = await _dio.get('/refresh/status');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Erreur getRefreshStatus: $e');
      return null;
    }
  }

  // ============================================================================
  // ADMINISTRATION
  // ============================================================================

  /// Lancer le scraping en arrière-plan
  Future<Map<String, dynamic>?> postRefresh({
    bool incremental = true,
    int maxPagesFilms = 100,
    int maxPagesSeries = 50,
  }) async {
    try {
      final queryParams = {
        'incremental': incremental,
        'max_pages_films': maxPagesFilms,
        'max_pages_series': maxPagesSeries,
      };

      final response = await _dio.post(
        '/refresh',
        queryParameters: queryParams,
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Erreur postRefresh: $e');
      rethrow;
    }
  }

  /// Vider le cache
  Future<Map<String, dynamic>?> clearCache() async {
    try {
      final response = await _dio.post('/debug/clear-cache');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Erreur clearCache: $e');
      return null;
    }
  }

  /// Recharger les données
  Future<Map<String, dynamic>?> reloadData() async {
    try {
      final response = await _dio.post('/debug/reload');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Erreur reloadData: $e');
      return null;
    }
  }
}
