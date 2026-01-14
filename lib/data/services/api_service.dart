import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/movie.dart';
import '../models/search_response.dart';
import '../../core/constants/app_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();

  // Cache pour éviter les appels répétés
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  Future<T?> _makeRequest<T>(
    String url,
    T Function(Map<String, dynamic>) fromJson, {
    Duration? cacheDuration,
  }) async {
    try {
      // Vérifier le cache
      if (cacheDuration != null && _cache.containsKey(url)) {
        final timestamp = _cacheTimestamps[url];
        if (timestamp != null &&
            DateTime.now().difference(timestamp) < cacheDuration) {
          return fromJson(_cache[url]);
        }
      }

      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        // Mettre en cache si demandé
        if (cacheDuration != null) {
          _cache[url] = jsonData;
          _cacheTimestamps[url] = DateTime.now();
        }

        return fromJson(jsonData);
      } else {
        throw ApiException(
          'Erreur HTTP ${response.statusCode}',
          response.statusCode,
        );
      }
    } on SocketException {
      throw const ApiException('Pas de connexion internet', 0);
    } on HttpException {
      throw const ApiException('Erreur de connexion', 0);
    } on FormatException {
      throw const ApiException('Réponse invalide du serveur', 0);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Erreur inconnue: $e', 0);
    }
  }

  /// Récupère la liste de tous les films
  Future<List<Movie>> getMovies() async {
    final response = await _makeRequest<MoviesResponse>(
      ApiEndpoints.movies(),
      (json) => MoviesResponse.fromJson(json),
      cacheDuration: AppConstants.cacheExpiration,
    );

    return response?.movies ?? [];
  }

  /// Recherche de films/séries
  Future<SearchResponse> search({
    required String query,
    SearchType type = SearchType.all,
    bool consolidated = false,
  }) async {
    if (query.trim().isEmpty) {
      return SearchResponse(
        query: query,
        type: type.value,
        consolidated: consolidated,
        results: [],
        count: 0,
      );
    }

    final response = await _makeRequest<SearchResponse>(
      ApiEndpoints.search(
        query: query.trim(),
        type: type.value,
        consolidated: consolidated,
      ),
      (json) => SearchResponse.fromJson(json),
      // Pas de cache pour les recherches pour avoir des résultats frais
    );

    return response ??
        SearchResponse(
          query: query,
          type: type.value,
          consolidated: consolidated,
          results: [],
          count: 0,
        );
  }

  /// Récupère la liste des genres disponibles
  Future<List<String>> getGenres() async {
    try {
      final response = await _makeRequest<Map<String, dynamic>>(
        ApiEndpoints.genres(),
        (json) => json,
        cacheDuration: const Duration(hours: 24), // Cache long pour les genres
      );

      if (response != null && response['genres'] is List) {
        final genres = List<String>.from(response['genres'])
            .where((genre) => genre.toString().trim().isNotEmpty)
            .map((genre) => genre.toString().trim())
            .toSet() // Supprimer les doublons
            .toList();

        genres.sort(); // Trier alphabétiquement
        return genres;
      }

      return [];
    } catch (e) {
      // En cas d'erreur, retourner une liste de genres par défaut
      return [
        'Action',
        'Animation',
        'Aventure',
        'Comédie',
        'Crime',
        'Documentaire',
        'Drame',
        'Familial',
        'Fantastique',
        'Guerre',
        'Histoire',
        'Horreur',
        'Musique',
        'Mystère',
        'Romance',
        'Science-Fiction',
        'Thriller',
        'Western'
      ];
    }
  }

  /// Recherche avancée avec filtres
  Future<SearchResponse> advancedSearch({
    String? query,
    SearchType type = SearchType.all,
    List<String>? genres,
    int? minYear,
    int? maxYear,
    double? minRating,
    String? language,
    SortOption sort = SortOption.relevance,
  }) async {
    // Pour l'instant, utiliser la recherche simple et filtrer côté client
    // TODO: Implémenter l'endpoint /search/advanced quand il sera disponible

    final searchQuery = query?.trim() ?? '';
    final baseResults = await search(
      query:
          searchQuery.isEmpty ? 'action' : searchQuery, // Recherche par défaut
      type: type,
    );

    var filteredResults = baseResults.results;

    // Appliquer les filtres côté client
    if (genres != null && genres.isNotEmpty) {
      filteredResults = filteredResults
          .where((movie) => movie.genres.any((movieGenre) => genres.any(
              (filterGenre) => movieGenre
                  .toLowerCase()
                  .contains(filterGenre.toLowerCase()))))
          .toList();
    }

    if (minYear != null) {
      filteredResults = filteredResults
          .where((movie) => movie.releaseYear >= minYear)
          .toList();
    }

    if (maxYear != null) {
      filteredResults = filteredResults
          .where((movie) => movie.releaseYear <= maxYear)
          .toList();
    }

    if (minRating != null) {
      filteredResults = filteredResults
          .where((movie) => movie.numericRating >= minRating)
          .toList();
    }

    if (language != null && language.isNotEmpty) {
      filteredResults = filteredResults
          .where((movie) =>
              (movie.language?.toLowerCase().contains(language.toLowerCase()) ??
                  false) ||
              (movie.version?.toLowerCase().contains(language.toLowerCase()) ??
                  false))
          .toList();
    }

    // Appliquer le tri
    switch (sort) {
      case SortOption.rating:
        filteredResults
            .sort((a, b) => b.numericRating.compareTo(a.numericRating));
        break;
      case SortOption.year:
        filteredResults.sort((a, b) => b.releaseYear.compareTo(a.releaseYear));
        break;
      case SortOption.title:
        filteredResults.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortOption.relevance:
      default:
        // Garder l'ordre de pertinence original
        break;
    }

    return SearchResponse(
      query: searchQuery,
      type: type.value,
      consolidated: false,
      results: filteredResults,
      count: filteredResults.length,
    );
  }

  /// Nettoie le cache
  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  /// Ferme le client HTTP
  void dispose() {
    _client.close();
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  const ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException: $message (Code: $statusCode)';
}
