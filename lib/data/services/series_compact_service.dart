import 'package:dio/dio.dart';
import '../models/series_compact.dart';

/// Classe pour représenter la progression du chargement des séries
class SeriesLoadingProgress {
  final List<SeriesCompact> series;
  final int total;
  final double progress; // 0.0 à 1.0
  final bool isCompleted;
  final bool hasError;
  final String? errorMessage;

  SeriesLoadingProgress._({
    required this.series,
    required this.total,
    required this.progress,
    required this.isCompleted,
    this.hasError = false,
    this.errorMessage,
  });

  factory SeriesLoadingProgress.initial(List<SeriesCompact> series, int total) {
    return SeriesLoadingProgress._(
      series: series,
      total: total,
      progress: 0.0,
      isCompleted: false,
    );
  }

  factory SeriesLoadingProgress.progress(List<SeriesCompact> series, int total, double progress) {
    return SeriesLoadingProgress._(
      series: series,
      total: total,
      progress: progress.clamp(0.0, 1.0),
      isCompleted: false,
    );
  }

  factory SeriesLoadingProgress.completed(List<SeriesCompact> series, int total, double progress) {
    return SeriesLoadingProgress._(
      series: series,
      total: total,
      progress: 1.0,
      isCompleted: true,
    );
  }

  factory SeriesLoadingProgress.error(String message) {
    return SeriesLoadingProgress._(
      series: [],
      total: 0,
      progress: 0.0,
      isCompleted: false,
      hasError: true,
      errorMessage: message,
    );
  }
}

/// Service pour récupérer les séries compactes selon l'API Zenix.sg
class SeriesCompactService {
  static const String baseUrl = 'http://node.zenix.sg:25825';

  final Dio _dio;
  final Map<String, Map<String, dynamic>> _enrichmentCache = {};

  SeriesCompactService(this._dio);

  /// Nettoie le cache d'enrichissement
  void clearCache() {
    _enrichmentCache.clear();
    print('SeriesCompactService: Cache cleared');
  }

  /// Nettoie le cache automatiquement (garde seulement les éléments récents)
  void optimizeCache({int maxSize = 200}) {
    if (_enrichmentCache.length <= maxSize) return;

    // Garder seulement les maxSize éléments les plus récemment utilisés
    final entries = _enrichmentCache.entries.toList();
    // Dans une vraie implémentation, on utiliserait un LRU cache
    // Pour l'instant, on garde les premiers maxSize
    final optimizedCache = Map<String, Map<String, dynamic>>.fromEntries(
      entries.take(maxSize)
    );

    _enrichmentCache.clear();
    _enrichmentCache.addAll(optimizedCache);

    print('SeriesCompactService: Cache optimized, kept $maxSize entries');
  }

  /// Statistiques du cache
  Map<String, dynamic> getCacheStats() {
    return {
      'total_entries': _enrichmentCache.length,
      'error_entries': _enrichmentCache.values.where((v) => v.containsKey('error')).length,
      'valid_entries': _enrichmentCache.values.where((v) => !v.containsKey('error')).length,
    };
  }

  /// Version progressive du chargement - utilise directement les données de /series
  Stream<SeriesLoadingProgress> getSeriesCompactProgressive({
    int limit = 50,
    int offset = 0,
    String? genre,
    String? sortBy,
    bool enrichData = false, // Désactivé par défaut pour éviter les appels individuels
  }) async* {
    try {
      // 1. Charger les données depuis l'endpoint /series (pagination optimisée)
      final response = await _dio.get('/series', queryParameters: {
        'limit': limit,
        'offset': offset,
        if (genre != null) 'genre': genre,
        if (sortBy != null) 'sort': sortBy,
      });

      final List<dynamic> rawData = response.data['data'] ?? response.data ?? [];
      final total = response.data['total'] ?? rawData.length;

      if (rawData.isEmpty) {
        yield SeriesLoadingProgress.completed([], total, 0);
        return;
      }

      // 2. Convertir les données (elles contiennent déjà seasons_count, episodes_count, etc.)
      final series = rawData.map((item) => SeriesCompact.fromJson(item as Map<String, dynamic>)).toList();

      yield SeriesLoadingProgress.initial(series, total);

      // Pas d'enrichissement nécessaire - les données de /series sont complètes
      yield SeriesLoadingProgress.completed(series, total, 1.0);

    } catch (e) {
      print('SeriesCompactService: ❌ Error in progressive loading: $e');
      yield SeriesLoadingProgress.error('Erreur de chargement: $e');
    }
  }

  /// Récupère la liste des séries compactes (endpoint /series)
  Future<SeriesCompactResponse> getSeriesCompact({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/series',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );

      // L'API retourne {"data": [...], "count": X, "total": Y, "limit": Z, "offset": W}
      final responseData = response.data;
      late List<Map<String, dynamic>> data;

      if (responseData is Map<String, dynamic>) {
        data = (responseData['data'] as List? ?? []).cast<Map<String, dynamic>>();
      } else if (responseData is List) {
        // Fallback pour ancienne structure
        data = responseData.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Format de réponse inattendu: ${responseData.runtimeType}');
      }

      // Conversion directe sans enrichissement (les données de /series sont complètes)
      final series = data.map((item) => SeriesCompact.fromJson(item)).toList();

      return SeriesCompactResponse(
        series: series,
        count: responseData is Map ? (responseData['count'] ?? data.length) : data.length,
        total: responseData is Map ? (responseData['total'] ?? 0) : 0,
        limit: responseData is Map ? (responseData['limit'] ?? limit) : limit,
        offset: responseData is Map ? (responseData['offset'] ?? offset) : offset,
      );
    } catch (e) {
      print('Erreur getSeriesCompact: $e');
      rethrow;
    }
  }

  /// Recherche dans les séries compactes (endpoint /search)
  Future<SeriesCompactResponse> searchSeriesCompact({
    required String query,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/search',
        queryParameters: {
          'q': query,
          'type': 'series',
          'consolidated': 'true',
          'limit': limit,
          'offset': offset,
        },
      );

      // Traiter la réponse de recherche
      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        final results = responseData['results'] as List? ?? [];
        return SeriesCompactResponse(
          series: results
              .map((json) =>
                  SeriesCompact.fromJson(json as Map<String, dynamic>))
              .toList(),
          count: results.length,
          total: responseData['total'] ?? results.length,
          limit: responseData['limit'] ?? limit,
          offset: responseData['offset'] ?? offset,
        );
      }

      return SeriesCompactResponse(
        series: [],
        count: 0,
        total: 0,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      print('Erreur searchSeriesCompact: $e');
      rethrow;
    }
  }

  /// Recherche avancée dans les séries (endpoint /searchadvanced)
  Future<SeriesCompactResponse> searchAdvancedSeriesCompact({
    String? query,
    double? minRating,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'type': 'series',
        'consolidated': 'true',
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

      // Traiter la réponse de recherche avancée
      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        final results = responseData['results'] as List? ?? [];
        return SeriesCompactResponse(
          series: results
              .map((json) =>
                  SeriesCompact.fromJson(json as Map<String, dynamic>))
              .toList(),
          count: results.length,
          total: responseData['total'] ?? results.length,
          limit: responseData['limit'] ?? limit,
          offset: responseData['offset'] ?? offset,
        );
      }

      return SeriesCompactResponse(
        series: [],
        count: 0,
        total: 0,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      print('Erreur searchAdvancedSeriesCompact: $e');
      rethrow;
    }
  }

  /// Récupère une série spécifique par son URL/ID
  Future<SeriesCompact?> getSeriesById(String seriesId) async {
    try {
      final response = await getSeriesCompact();

      // Chercher la série par URL ou titre
      for (final series in response.series) {
        if (series.url.contains(seriesId) ||
            series.id == seriesId ||
            series.title.toLowerCase().contains(seriesId.toLowerCase())) {
          return series;
        }
      }

      return null;
    } catch (e) {
      print('Erreur getSeriesById: $e');
      return null;
    }
  }

  /// Recherche des séries par titre
  Future<List<SeriesCompact>> searchSeries(String query) async {
    try {
      final response = await getSeriesCompact();

      final searchQuery = query.toLowerCase();
      return response.series.where((series) {
        return series.title.toLowerCase().contains(searchQuery) ||
            series.mainTitle.toLowerCase().contains(searchQuery) ||
            series.originalTitle.toLowerCase().contains(searchQuery) ||
            series.genres
                .any((genre) => genre.toLowerCase().contains(searchQuery));
      }).toList();
    } catch (e) {
      print('Erreur searchSeries: $e');
      return [];
    }
  }

  /// Récupère les séries par genre
  Future<List<SeriesCompact>> getSeriesByGenre(String genre) async {
    try {
      final response = await getSeriesCompact();

      return response.series.where((series) {
        return series.genres
            .any((g) => g.toLowerCase().contains(genre.toLowerCase()));
      }).toList();
    } catch (e) {
      print('Erreur getSeriesByGenre: $e');
      return [];
    }
  }

  /// Récupère les séries les mieux notées
  Future<List<SeriesCompact>> getTopRatedSeries({int limit = 20}) async {
    try {
      final response = await getSeriesCompact();

      final sortedSeries = List<SeriesCompact>.from(response.series);
      sortedSeries.sort((a, b) => b.numericRating.compareTo(a.numericRating));

      return sortedSeries.take(limit).toList();
    } catch (e) {
      print('Erreur getTopRatedSeries: $e');
      return [];
    }
  }

  /// Récupère les séries avec le plus d'épisodes
  Future<List<SeriesCompact>> getSeriesWithMostEpisodes(
      {int limit = 20}) async {
    try {
      final response = await getSeriesCompact();

      final sortedSeries = List<SeriesCompact>.from(response.series);
      sortedSeries.sort((a, b) => b.totalEpisodes.compareTo(a.totalEpisodes));

      return sortedSeries.take(limit).toList();
    } catch (e) {
      print('Erreur getSeriesWithMostEpisodes: $e');
      return [];
    }
  }

  /// Récupère les statistiques des séries
  Future<Map<String, dynamic>> getSeriesStats() async {
    try {
      final response = await getSeriesCompact();

      int totalSeries = response.series.length;
      int totalSeasons =
          response.series.fold(0, (sum, series) => sum + series.totalSeasons);
      int totalEpisodes =
          response.series.fold(0, (sum, series) => sum + series.totalEpisodes);

      // Genres les plus populaires
      Map<String, int> genreCount = {};
      for (final series in response.series) {
        for (final genre in series.genres) {
          genreCount[genre] = (genreCount[genre] ?? 0) + 1;
        }
      }

      final topGenres = genreCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'totalSeries': totalSeries,
        'totalSeasons': totalSeasons,
        'totalEpisodes': totalEpisodes,
        'topGenres': topGenres
            .take(10)
            .map((e) => {
                  'genre': e.key,
                  'count': e.value,
                })
            .toList(),
        'averageRating': response.series.isNotEmpty
            ? response.series
                    .fold(0.0, (sum, series) => sum + series.numericRating) /
                totalSeries
            : 0.0,
      };
    } catch (e) {
      print('Erreur getSeriesStats: $e');
      return {};
    }
  }

  /// Enrichit les données des séries avec les vraies informations de saisons
  Future<List<SeriesCompact>> _enrichSeriesWithRealData(List<Map<String, dynamic>> seriesData) async {
    final enrichedSeries = <SeriesCompact>[];
    final seriesToEnrich = <String, Map<String, dynamic>>{};

    // Collecter les IDs des séries qui ont besoin d'enrichissement
    for (final serieData in seriesData) {
      final seriesId = serieData['id'] as String?;
      if (seriesId == null) {
        // Si pas d'ID, utiliser les données originales
        enrichedSeries.add(SeriesCompact.fromJson(serieData));
        continue;
      }

      // Vérifier le cache d'abord
      if (_enrichmentCache.containsKey(seriesId)) {
        final cachedData = _enrichmentCache[seriesId]!;
        final enrichedData = Map<String, dynamic>.from(serieData);
        enrichedData.addAll(cachedData);
        enrichedSeries.add(SeriesCompact.fromJson(enrichedData));
        print('SeriesCompactService: ✅ Used cached data for $seriesId');
        continue;
      }

      seriesToEnrich[seriesId] = serieData;
    }

    // Enrichir les séries non cachées par lots de 8 pour optimiser le parallélisme
    final seriesIds = seriesToEnrich.keys.toList();
    const batchSize = 8; // Augmenté de 3 à 8 pour plus de parallélisme

    for (var i = 0; i < seriesIds.length; i += batchSize) {
      final endIndex = i + batchSize > seriesIds.length ? seriesIds.length : i + batchSize;
      final batchIds = seriesIds.sublist(i, endIndex);
      final batchFutures = batchIds.map((seriesId) => _enrichSingleSeries(seriesId, seriesToEnrich[seriesId]!));

      try {
        final batchResults = await Future.wait(batchFutures);
        enrichedSeries.addAll(batchResults);
        print('SeriesCompactService: ✅ Processed batch ${i ~/ batchSize + 1}/${(seriesIds.length / batchSize).ceil()}: ${batchResults.length} series enriched');
      } catch (e) {
        print('SeriesCompactService: ⚠️ Batch timeout/error, processing individually: $e');
        // En cas d'erreur de lot, traiter individuellement avec timeout plus court
        for (final seriesId in batchIds) {
          try {
            final result = await _enrichSingleSeries(seriesId, seriesToEnrich[seriesId]!).timeout(const Duration(seconds: 3));
            enrichedSeries.add(result);
          } catch (e) {
            print('SeriesCompactService: ❌ Failed to enrich $seriesId: $e');
            // En cas d'échec individuel, utiliser les données originales
            enrichedSeries.add(SeriesCompact.fromJson(seriesToEnrich[seriesId]!));
          }
        }
      }

      // Délai minimal pour éviter la surcharge complète de l'API
      if (i + batchSize < seriesIds.length) {
        await Future.delayed(const Duration(milliseconds: 50)); // Réduit de 200ms à 50ms
      }
    }

    return enrichedSeries;
  }

  /// Enrichit une seule série avec timeout optimisé
  Future<SeriesCompact> _enrichSingleSeries(String seriesId, Map<String, dynamic> serieData) async {
    try {
      // Timeout plus court pour éviter de bloquer le lot entier
      final detailsResponse = await _dio.get('/item/$seriesId').timeout(const Duration(seconds: 5));
      final detailsJson = detailsResponse.data as Map<String, dynamic>?;

      if (detailsJson != null) {
        // Créer une nouvelle map avec les données enrichies
        final enrichedData = Map<String, dynamic>.from(serieData);

        // Utiliser les vraies données de saisons si disponibles
        if (detailsJson['seasons_count'] != null) {
          enrichedData['seasons_count'] = detailsJson['seasons_count'];
        }
        if (detailsJson['episodes_count'] != null) {
          enrichedData['episodes_count'] = detailsJson['episodes_count'];
        }

        // Mettre en cache les données enrichies
        final cacheData = {
          'seasons_count': detailsJson['seasons_count'],
          'episodes_count': detailsJson['episodes_count'],
        };
        _enrichmentCache[seriesId] = cacheData;

        return SeriesCompact.fromJson(enrichedData);
      } else {
        // Si pas de détails, utiliser les données originales
        return SeriesCompact.fromJson(serieData);
      }
    } catch (e) {
      // En cas d'erreur ou timeout, utiliser les données originales
      // et mettre en cache pour éviter de réessayer immédiatement
      _enrichmentCache[seriesId] = {'error': true};
      return SeriesCompact.fromJson(serieData);
    }
  }
}
