import 'package:dio/dio.dart';
import '../models/series.dart';
import '../models/api_responses.dart';
import '../../core/constants/app_constants.dart';
import 'dio_client.dart';

class SeriesApiService {
  static const String _tag = 'SeriesApiService';

  static Dio get _dio => DioClient.instance;

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

  // Cache simple
  static ApiResponse<Series>? _cachedSeries;
  static DateTime? _lastFetchTime;

/// Récupère les séries avec pagination
  static Future<ApiResponse<Series>> getSeries({
    bool forceRefresh = false,
    int? limit,
    int offset = 0,
    String? year,
    String? sort = 'episodes', // 'title', 'year', 'episodes' - default to episodes to get real counts
  }) async {
    // Vérifier le cache
    if (!forceRefresh && _cachedSeries != null && _lastFetchTime != null) {
      final timeDiff = DateTime.now().difference(_lastFetchTime!);
      if (timeDiff < AppConstants.cacheExpiration) {
        print('$_tag: Returning cached series');
        return _cachedSeries!;
      }
    }

    try {
      print(
          '$_tag: Fetching series from API with limit=$limit, offset=$offset...');

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

      final apiResponse = ApiResponse.fromJson(
        response.data,
        (json) => Series.fromJson(json),
      );

      // Les données de /series contiennent déjà seasons_count et episodes_count
      // Pas besoin d'enrichissement pour la liste - uniquement pour les détails
      print('$_tag: Series data already contains season counts');

      // Mettre en cache
      _cachedSeries = apiResponse;
      _lastFetchTime = DateTime.now();

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

/// Récupère les détails d'une série spécifique
  static Future<Series> getSeriesDetails(String seriesId) async {
    try {
      print('$_tag: Fetching series details for ID: $seriesId');

      final cleanId = _extractCleanId(seriesId);
      final response = await _dio.get('/item/$cleanId');
      print('$_tag: Raw response type: ${response.data.runtimeType}');
      print('$_tag: Raw response keys: ${response.data is Map ? (response.data as Map).keys.toString() : 'Not a map'}');
      
      // Handle wrapped response
      final data = response.data is Map<String, dynamic>
          ? (response.data as Map<String, dynamic>)
          : response.data;
      
      print('$_tag: Processing data with keys: ${data is Map ? (data as Map).keys.toString() : 'Not a map'}');
      
      // Log des nouveaux champs pour debugging
      if (data is Map) {
        print('$_tag: episodes_by_season present: ${data.containsKey('episodes_by_season')}');
        print('$_tag: episodes count: ${(data['episodes'] as List?)?.length ?? 0}');
        print('$_tag: seasons_count: ${data['seasons_count']}');
        print('$_tag: episodes_count: ${data['episodes_count']}');
      }
      
      final series = Series.fromJson(data);

      print('$_tag: Successfully fetched series details: ${series.title}');
      print('$_tag: Seasons count: ${series.seasonsCount}, Episodes count: ${series.episodesCount}');
      print('$_tag: Actual seasons: ${series.seasons?.length ?? 0}');
      print('$_tag: Has episodes_by_season: ${data.containsKey('episodes_by_season')}');
      print('$_tag: Has seasons: ${data.containsKey('seasons')}');
      print('$_tag: Has episodes: ${data.containsKey('episodes')}');

      return series;
    } catch (e) {
      print('$_tag: Error fetching series details: $e');
      rethrow;
    }
  }

/// Charge les épisodes d'une saison spécifique
  static Future<List<Episode>> getSeasonEpisodes(String seriesId, int seasonNumber) async {
    try {
      print('$_tag: Fetching episodes for series $seriesId, season $seasonNumber');

      final cleanId = _extractCleanId(seriesId);
      // Essayer d'abord avec l'endpoint /item/$cleanId qui contient episodes_by_season
      final seriesResponse = await _dio.get('/item/$cleanId');
      final seriesData = seriesResponse.data as Map<String, dynamic>;
      
      if (seriesData['episodes_by_season'] != null) {
        final episodesBySeason = seriesData['episodes_by_season'] as Map<String, dynamic>;
        final seasonKey = seasonNumber.toString();
        
        if (episodesBySeason.containsKey(seasonKey)) {
          final episodesData = episodesBySeason[seasonKey] as List<dynamic>;
          final episodes = episodesData
              .map((e) => Episode.fromJson(e as Map<String, dynamic>))
              .toList();
          
          print('$_tag: Successfully fetched ${episodes.length} episodes for season $seasonNumber from episodes_by_season');
          return episodes;
        }
      }
      
      // Fallback à l'ancien endpoint
      final response = await _dio.get('/item/$cleanId/season/$seasonNumber');
      final episodes = (response.data['episodes'] as List<dynamic>? ?? [])
          .map((e) => Episode.fromJson(e as Map<String, dynamic>))
          .toList();

      print('$_tag: Successfully fetched ${episodes.length} episodes for season $seasonNumber from fallback endpoint');
      return episodes;
    } catch (e) {
      print('$_tag: Error fetching season episodes: $e');
      return [];
    }
  }

  /// Recherche de séries
  static Future<List<Series>> searchSeries({
    required String query,
    bool consolidated = true,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      print('$_tag: Searching series with query: $query');

      final queryParams = {
        'q': query.trim(),
        'type': 'series',
        'consolidated': consolidated.toString(),
      };

      final response = await _dio.get(
        '/search',
        queryParameters: queryParams,
      );

      final results = (response.data['results'] as List<dynamic>? ?? [])
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

  /// Récupère les séries populaires (basé sur la note)
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

  /// Récupère les séries récentes (basé sur l'année de sortie)
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

  /// Récupère les séries en cours
  static Future<List<Series>> getOngoingSeries() async {
    try {
      final allSeries = await getSeries();
      return allSeries.data.where((series) => series.isOngoing).toList();
    } catch (e) {
      print('$_tag: Error getting ongoing series: $e');
      rethrow;
    }
  }

  /// Récupère les séries terminées
  static Future<List<Series>> getCompletedSeries() async {
    try {
      final allSeries = await getSeries();
      return allSeries.data.where((series) => series.isCompleted).toList();
    } catch (e) {
      print('$_tag: Error getting completed series: $e');
      rethrow;
    }
  }

  /// Enrichit les données des séries avec les vraies informations de saisons
  static Future<List<Series>> _enrichSeriesWithRealData(List<Series> series) async {
    final enrichedSeries = <Series>[];

    for (final serie in series) {
      try {
        print('$_tag: Enriching series ${serie.title} (${serie.id})');

        // Essayer de récupérer les détails complets
        final detailsResponse = await _dio.get('/item/${serie.id}');
        final detailsJson = detailsResponse.data;

        if (detailsJson != null) {
          // Créer une nouvelle série avec les vraies données
          final enrichedSerie = Series(
            id: serie.id,
            title: serie.title,
            originalTitle: serie.originalTitle,
            type: serie.type,
            year: serie.year,
            poster: serie.poster,
            url: serie.url,
            genres: serie.genres,
            rating: serie.rating,
            ratingMax: serie.ratingMax,
            quality: serie.quality,
            version: serie.version,
            actors: serie.actors,
            directors: serie.directors,
            synopsis: serie.synopsis,
            description: detailsJson['description'] ?? serie.description,
            watchLinksCount: serie.watchLinksCount,
            // Utiliser les vraies données de saisons si disponibles
            seasonsCount: detailsJson['seasons_count'] ?? serie.seasonsCount,
            episodesCount: detailsJson['episodes_count'] ?? serie.episodesCount,
            seasons: detailsJson['seasons'] != null
                ? (detailsJson['seasons'] as List<dynamic>)
                    .map((s) => Season.fromJson(s as Map<String, dynamic>))
                    .toList()
                : serie.seasons,
            language: detailsJson['language'] ?? serie.language,
            status: detailsJson['status'] ?? serie.status,
            watchLinks: detailsJson['watch_links'] != null
                ? (detailsJson['watch_links'] as List<dynamic>)
                    .map((link) => WatchLink.fromJson(link as Map<String, dynamic>))
                    .toList()
                : serie.watchLinks,
            duration: detailsJson['duration'] ?? serie.duration,
            releaseDateString: detailsJson['release_date'] ?? serie.releaseDateString,
          );

          enrichedSeries.add(enrichedSerie);
          print('$_tag: ✅ Enriched ${serie.title}: ${enrichedSerie.seasonsCount} seasons, ${enrichedSerie.episodesCount} episodes');
        } else {
          // Si pas de détails, utiliser les données originales
          enrichedSeries.add(serie);
          print('$_tag: ⚠️ No details found for ${serie.title}, using original data');
        }
      } catch (e) {
        print('$_tag: ❌ Error enriching ${serie.title}: $e');
        // En cas d'erreur, utiliser les données originales
        enrichedSeries.add(serie);
      }

      // Petite pause pour éviter de surcharger l'API
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return enrichedSeries;
  }

  /// Déclenche un refresh général des données de séries
  static Future<bool> refreshSeriesData() async {
    try {
      print('$_tag: Triggering general series data refresh');

      // Appeler l'endpoint refresh pour déclencher un scraping incrémental
      final response = await _dio.post(
        '/refresh',
        queryParameters: {
          'incremental': 'true',
          'max_pages_films': '0',  // Pas de films
          'max_pages_series': '5', // Quelques pages de séries
        },
      );

      if (response.statusCode == 200) {
        print('$_tag: Successfully triggered general refresh');
        return true;
      } else {
        print('$_tag: Failed to trigger refresh: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('$_tag: Error triggering refresh: $e');
      return false;
    }
  }

  /// Vérifie le statut du scraping en cours
  static Future<Map<String, dynamic>?> getScrapingStatus() async {
    try {
      final response = await _dio.get('/debug/progress');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      print('$_tag: Error getting scraping status: $e');
    }
    return null;
  }

  /// Vide le cache
  static void clearCache() {
    _cachedSeries = null;
    _lastFetchTime = null;
    print('$_tag: Cache cleared');
  }

  /// Vérifie si le cache est valide
  static bool get isCacheValid {
    if (_cachedSeries == null || _lastFetchTime == null) return false;
    final timeDiff = DateTime.now().difference(_lastFetchTime!);
    return timeDiff < AppConstants.cacheExpiration;
  }

  /// Obtient les statistiques du cache
  static Map<String, dynamic> getCacheStats() {
    return {
      'has_cache': _cachedSeries != null,
      'cache_time': _lastFetchTime?.toIso8601String(),
      'cache_valid': isCacheValid,
      'series_count': _cachedSeries?.count ?? 0,
    };
  }
}
