import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class AISearchService {
  static const String _searchServerUrl = 'http://127.0.0.1:8081';
  static const String _llmUrl = 'http://127.0.0.1:8080';

  static final AISearchService _instance = AISearchService._internal();
  factory AISearchService() => _instance;
  AISearchService._internal();

  bool _isAvailable = false;

  bool get isAvailable => _isAvailable;

  Future<bool> checkAvailability() async {
    try {
      final response = await http
          .get(Uri.parse('$_searchServerUrl/ai/health'))
          .timeout(const Duration(seconds: 2));
      _isAvailable = response.statusCode == 200;
    } catch (_) {
      _isAvailable = false;
    }
    return _isAvailable;
  }

  Future<bool> checkLLMAvailability() async {
    try {
      final response = await http
          .get(Uri.parse('$_llmUrl/v1/models'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<AIActivityResult> analyzeQuery(String userQuery) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_searchServerUrl/ai/search'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'query': userQuery, 'top_k': 20}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return AIActivityResult.fromJson(data);
      } else {
        return AIActivityResult(
          query: userQuery,
          parsed: AIQueryParams(keywords: [userQuery], contentType: 'any', genres: [], yearRange: YearRange(min: 0, max: 9999), quality: 'any', language: 'any', exclusions: []),
          results: [],
          count: 0,
          error: 'Serveur erreur: ${response.statusCode}',
        );
      }
    } catch (e) {
      return AIActivityResult(
        query: userQuery,
        parsed: AIQueryParams(keywords: [userQuery], contentType: 'any', genres: [], yearRange: YearRange(min: 0, max: 9999), quality: 'any', language: 'any', exclusions: []),
        results: [],
        count: 0,
        error: 'Serveur IA non disponible: $e',
      );
    }
  }
}

class AIActivityResult {
  final String query;
  final AIQueryParams parsed;
  final List<AIContentResult> results;
  final int count;
  final String? error;

  AIActivityResult({
    required this.query,
    required this.parsed,
    required this.results,
    required this.count,
    this.error,
  });

  factory AIActivityResult.fromJson(Map<String, dynamic> json) {
    return AIActivityResult(
      query: json['query'] ?? '',
      parsed: AIQueryParams.fromJson(json['parsed'] ?? {}),
      results: (json['results'] as List?)?.map((e) => AIContentResult.fromJson(e)).toList() ?? [],
      count: json['count'] ?? 0,
      error: json['error'],
    );
  }
}

class AIQueryParams {
  final List<String> keywords;
  final String contentType;
  final List<String> genres;
  final YearRange yearRange;
  final String quality;
  final String language;
  final List<String> exclusions;

  AIQueryParams({
    required this.keywords,
    required this.contentType,
    required this.genres,
    required this.yearRange,
    required this.quality,
    required this.language,
    required this.exclusions,
  });

  factory AIQueryParams.fromJson(Map<String, dynamic> json) {
    return AIQueryParams(
      keywords: (json['keywords'] as List?)?.map((e) => e.toString()).toList() ?? [],
      contentType: json['content_type'] ?? 'any',
      genres: (json['genres'] as List?)?.map((e) => e.toString()).toList() ?? [],
      yearRange: YearRange(
        min: (json['year_range']?['min'] as int?) ?? 0,
        max: (json['year_range']?['max'] as int?) ?? 9999,
      ),
      quality: json['quality'] ?? 'any',
      language: json['language'] ?? 'any',
      exclusions: (json['exclusions'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  String get contentTypeLabel {
    switch (contentType) {
      case 'movie':
        return 'Film';
      case 'series':
        return 'Série';
      case 'anime':
        return 'Anime';
      default:
        return 'Tout';
    }
  }
}

class YearRange {
  final int min;
  final int max;

  YearRange({required this.min, required this.max});
}

class AIContentResult {
  final int id;
  final String title;
  final String? altTitle;
  final String? description;
  final String type;
  final List<String> genres;
  final int? year;
  final double? rating;
  final List<String> languages;
  final String? posterUrl;
  final double? score;
  final int? totalEpisodes;
  final int? totalSeasons;

  AIContentResult({
    required this.id,
    required this.title,
    this.altTitle,
    this.description,
    required this.type,
    required this.genres,
    this.year,
    this.rating,
    required this.languages,
    this.posterUrl,
    this.score,
    this.totalEpisodes,
    this.totalSeasons,
  });

  factory AIContentResult.fromJson(Map<String, dynamic> json) {
    return AIContentResult(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      altTitle: json['alt_title'],
      description: json['description'],
      type: json['type'] ?? 'movie',
      genres: (json['genres'] as List?)?.map((e) => e.toString()).toList() ?? [],
      year: json['year'] is int ? json['year'] : null,
      rating: (json['rating'] as num?)?.toDouble(),
      languages: (json['languages'] as List?)?.map((e) => e.toString()).toList() ?? [],
      posterUrl: json['poster_url'],
      score: (json['score'] as num?)?.toDouble(),
      totalEpisodes: json['total_episodes'],
      totalSeasons: json['total_seasons'],
    );
  }

  String get displayTitle => altTitle != null && altTitle!.isNotEmpty ? '$title ($altTitle)' : title;

  String get typeLabel {
    switch (type) {
      case 'movie':
        return 'Film';
      case 'series':
        return 'Série';
      case 'anime':
        return 'Anime';
      default:
        return type;
    }
  }
}