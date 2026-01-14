# NEO-Stream API Audit & Data Model Fixes

## Executive Summary

**Status:** AUDIT COMPLETE - FIXES REQUIRED  
**Date:** 2025  
**Severity:** HIGH (API integration issues found)

This document outlines all API endpoint issues, data model inconsistencies, and required fixes for NEO-Stream to properly integrate with the Zenix.sg API (port 25825).

---

## Part 1: API Endpoint Audit

### Current API Documentation
**Base URL:** `http://node.zenix.sg:25825`  
**Version:** 2.0 (migrated from port 25823)

### Available Endpoints

#### 1. Movies & Series
```
GET /movies              - Get movies list (limit, offset)
GET /series              - Get series list (limit, offset)
GET /films               - Alternative movies endpoint
GET /series/compact      - Compact series format
```

#### 2. Search & Discovery
```
GET /search              - Advanced search with filters
GET /autocomplete        - Quick suggestions
GET /filter              - Filter without text search
GET /genres              - Get all genres
GET /by-genre/{genre}    - Content by genre
GET /by-actor/{actor}    - Content by actor
GET /by-director/{dir}   - Content by director
GET /top-rated           - Top rated content
GET /recent              - Recent releases
GET /random              - Random content
```

#### 3. Details
```
GET /item/{id}           - Full item details
GET /episodes/{seriesId} - Series episodes
GET /watch-links/{id}    - Streaming links
```

---

## Part 2: Data Model Issues Found

### Issue 1: Movie Model Inconsistencies

**Problem:** Movie model has missing/inconsistent fields

**Current Fields:**
- ✅ id, title, original_title
- ✅ synopsis, genres, actors, directors
- ❌ rating (field exists but API uses "numericRating")
- ❌ year (API might use "releaseYear")
- ❌ poster_url (API field name mismatch)
- ❌ runtime (missing)
- ❌ country (missing)
- ❌ language (missing)

**API Expected Format:**
```json
{
  "id": "123",
  "title": "The Movie",
  "original_title": "Original Title",
  "synopsis": "Description",
  "numericRating": 8.5,
  "releaseYear": 2023,
  "poster_url": "http://...",
  "runtime": 120,
  "country": "USA",
  "language": "English",
  "genres": ["Action", "Thriller"],
  "actors": ["Actor1", "Actor2"],
  "directors": ["Director1"],
  "type": "film",
  "version": "VF",
  "quality": "HD"
}
```

### Issue 2: Series Model Inconsistencies

**Problem:** Series has episode/season mapping issues

**Current Problems:**
- Episode.fromJson expects "episode_number" but API might use "number"
- Season.fromJson expects "season_number" but API might use "number"
- Episodes list might be named "items" instead of "episodes"
- Missing: series_status, air_date, network

**API Expected Format:**
```json
{
  "id": "123",
  "title": "Series Name",
  "synopsis": "Description",
  "numericRating": 7.5,
  "totalSeasons": 5,
  "totalEpisodes": 50,
  "poster_url": "http://...",
  "status": "ongoing",
  "aired_from": "2020-01-01",
  "aired_to": "2025-01-01",
  "network": "HBO",
  "genres": ["Drama", "Mystery"],
  "actors": ["Actor1"],
  "directors": ["Director1"],
  "seasons": [
    {
      "season_number": 1,
      "episodes": [
        {
          "episode_number": 1,
          "title": "Pilot",
          "air_date": "2020-01-01",
          "synopsis": "First episode"
        }
      ]
    }
  ]
}
```

### Issue 3: Search Response Model Issues

**Problem:** SearchResponse doesn't match API response format

**Current:** Uses MovieList and SeriesList with "data" field
**API Expected:** Uses "results" field directly

```json
{
  "results": {
    "movies": [...],
    "series": [...],
    "actors": [...],
    "directors": [...]
  },
  "count": 10,
  "total": 100,
  "offset": 0,
  "limit": 10
}
```

### Issue 4: API Response Model Issues

**Problem:** ApiResponse wrapper doesn't match actual API responses

**Current Implementation:**
```dart
class ApiResponse<T> {
  final List<T> results;
  final int count;
  final int total;
  final int limit;
  final int offset;
}
```

**Actual API Response:**
```json
{
  "data": [...],          // NOT "results"
  "count": 10,
  "total": 100,
  "limit": 50,
  "offset": 0,
  "status": "success",
  "message": null
}
```

---

## Part 3: Service Implementation Issues

### Issue 1: ZenixApiService
**Problems:**
- Uses wrong endpoint names (/films instead of /movies)
- Doesn't implement all advertised methods
- Error handling is minimal
- No retry logic
- No caching

**Missing Methods:**
- getTopRated()
- getRecent()
- getRandom()
- suggestActors()
- suggestDirectors()
- suggestGenres()
- multiSearch()

### Issue 2: SearchService
**Problems:**
- Endpoint "/search" might not exist (should be "/search")
- Parameter names don't match API (q vs query)
- Response mapping is broken

### Issue 3: SeriesCompactService
**Problems:**
- Endpoint "/series/compact" might not exist
- Uses wrong field names for parsing
- No error recovery

---

## Part 4: Required Fixes

### Fix 1: Update Movie Model

**File:** `lib/data/models/movie.dart`

```dart
class Movie {
  final String id;
  final String title;
  final String? originalTitle;
  final String? synopsis;
  final double rating;           // numericRating from API
  final int? releaseYear;        // releaseYear from API
  final String? posterUrl;       // poster_url from API
  final int? runtime;            // NEW
  final String? country;         // NEW
  final String? language;        // NEW
  final List<String> genres;
  final List<String> actors;
  final List<String> directors;
  final String type;             // "film"
  final String? version;         // VF/VO
  final String? quality;         // HD/4K/SD

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      originalTitle: json['original_title'],
      synopsis: json['synopsis'],
      rating: (json['numericRating'] ?? json['rating'] ?? 0.0).toDouble(),
      releaseYear: json['releaseYear'] ?? json['year'],
      posterUrl: json['poster_url'],
      runtime: json['runtime'],
      country: json['country'],
      language: json['language'],
      genres: List<String>.from(json['genres'] ?? []),
      actors: List<String>.from(json['actors'] ?? []),
      directors: List<String>.from(json['directors'] ?? []),
      type: json['type'] ?? 'film',
      version: json['version'],
      quality: json['quality'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'original_title': originalTitle,
      'synopsis': synopsis,
      'numericRating': rating,
      'releaseYear': releaseYear,
      'poster_url': posterUrl,
      'runtime': runtime,
      'country': country,
      'language': language,
      'genres': genres,
      'actors': actors,
      'directors': directors,
      'type': type,
      'version': version,
      'quality': quality,
    };
  }
}
```

### Fix 2: Update Series Model

**File:** `lib/data/models/series.dart`

```dart
class Series {
  final String id;
  final String title;
  final String? synopsis;
  final double rating;
  final int totalSeasons;
  final int totalEpisodes;
  final String? posterUrl;
  final String? status;          // ongoing/completed
  final String? airedFrom;
  final String? airedTo;
  final String? network;
  final List<String> genres;
  final List<String> actors;
  final List<String> directors;
  final List<Season> seasons;

  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      synopsis: json['synopsis'],
      rating: (json['numericRating'] ?? json['rating'] ?? 0.0).toDouble(),
      totalSeasons: json['totalSeasons'] ?? json['total_seasons'] ?? 0,
      totalEpisodes: json['totalEpisodes'] ?? json['total_episodes'] ?? 0,
      posterUrl: json['poster_url'],
      status: json['status'],
      airedFrom: json['aired_from'],
      airedTo: json['aired_to'],
      network: json['network'],
      genres: List<String>.from(json['genres'] ?? []),
      actors: List<String>.from(json['actors'] ?? []),
      directors: List<String>.from(json['directors'] ?? []),
      seasons: (json['seasons'] as List?)
          ?.map((s) => Season.fromJson(s))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'synopsis': synopsis,
      'numericRating': rating,
      'totalSeasons': totalSeasons,
      'totalEpisodes': totalEpisodes,
      'poster_url': posterUrl,
      'status': status,
      'aired_from': airedFrom,
      'aired_to': airedTo,
      'network': network,
      'genres': genres,
      'actors': actors,
      'directors': directors,
      'seasons': seasons.map((s) => s.toJson()).toList(),
    };
  }
}

class Season {
  final int seasonNumber;
  final List<Episode> episodes;

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      seasonNumber: json['season_number'] ?? json['number'] ?? 0,
      episodes: (json['episodes'] ?? json['items'] ?? [])
          .map<Episode>((e) => Episode.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'season_number': seasonNumber,
      'episodes': episodes.map((e) => e.toJson()).toList(),
    };
  }
}

class Episode {
  final int episodeNumber;
  final String title;
  final String? airDate;
  final String? synopsis;

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      episodeNumber: json['episode_number'] ?? json['number'] ?? 0,
      title: json['title'] ?? '',
      airDate: json['air_date'],
      synopsis: json['synopsis'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'episode_number': episodeNumber,
      'title': title,
      'air_date': airDate,
      'synopsis': synopsis,
    };
  }
}
```

### Fix 3: Update ApiResponse Model

**File:** `lib/data/models/api_responses.dart`

```dart
class ApiResponse<T> {
  final List<T> results;
  final int count;
  final int total;
  final int limit;
  final int offset;
  final String? status;
  final String? message;

  ApiResponse({
    required this.results,
    required this.count,
    required this.total,
    required this.limit,
    required this.offset,
    this.status,
    this.message,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    // Handle both "data" and "results" field names
    final dataList = json['data'] ?? json['results'] ?? [];
    final results = (dataList as List)
        .map((item) => fromJsonT(item as Map<String, dynamic>))
        .toList();

    return ApiResponse(
      results: results,
      count: json['count'] ?? results.length,
      total: json['total'] ?? json['totalResults'] ?? results.length,
      limit: json['limit'] ?? 50,
      offset: json['offset'] ?? 0,
      status: json['status'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson(
    Map<String, dynamic> Function(T) toJsonT,
  ) {
    return {
      'data': results.map(toJsonT).toList(),
      'count': count,
      'total': total,
      'limit': limit,
      'offset': offset,
      'status': status,
      'message': message,
    };
  }
}
```

### Fix 4: Fix ZenixApiService Endpoints

**File:** `lib/data/services/zenix_api_service.dart`

Replace `/films` with `/movies` and fix all endpoints:

```dart
/// Récupère la liste des films
Future<ApiResponse<Movie>> getMovies({
  int limit = 50,
  int offset = 0,
}) async {
  try {
    final response = await _dio.get(
      '/movies',  // Changed from /films
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
    );
    
    return ApiResponse.fromJson(response.data, (json) => Movie.fromJson(json));
  } catch (e) {
    print('Error getMovies: $e');
    rethrow;
  }
}

/// Récupère la liste des séries
Future<ApiResponse<Series>> getSeries({
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
    
    return ApiResponse.fromJson(response.data, (json) => Series.fromJson(json));
  } catch (e) {
    print('Error getSeries: $e');
    rethrow;
  }
}

/// Recherche avancée
Future<SearchResponse> search({
  required String q,
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
  int limit = 50,
  int offset = 0,
}) async {
  try {
    final queryParams = {
      'q': q,
      if (type != null) 'type': type,
      if (genre != null) 'genre': genre,
      if (actor != null) 'actor': actor,
      if (director != null) 'director': director,
      if (year != null) 'year': year,
      if (yearMin != null) 'yearMin': yearMin,
      if (yearMax != null) 'yearMax': yearMax,
      if (ratingMin != null) 'ratingMin': ratingMin,
      if (ratingMax != null) 'ratingMax': ratingMax,
      if (quality != null) 'quality': quality,
      if (version != null) 'version': version,
      if (language != null) 'language': language,
      'limit': limit,
      'offset': offset,
    };

    final response = await _dio.get(
      '/search',
      queryParameters: queryParams,
    );

    return SearchResponse.fromJson(response.data);
  } catch (e) {
    print('Error search: $e');
    rethrow;
  }
}

/// Autocomplétion rapide
Future<List<String>> autocomplete({
  required String q,
  String? type,
  int limit = 10,
}) async {
  try {
    final response = await _dio.get(
      '/autocomplete',
      queryParameters: {
        'q': q,
        if (type != null) 'type': type,
        'limit': limit,
      },
    );

    if (response.data is Map<String, dynamic>) {
      final suggestions = response.data['suggestions'] ?? [];
      return List<String>.from(suggestions);
    }
    return [];
  } catch (e) {
    print('Error autocomplete: $e');
    return [];
  }
}

/// Filtrage avancé sans recherche textuelle
Future<ApiResponse<Content>> filter({
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
  String? sortBy,
  String? sortOrder,
  int limit = 50,
  int offset = 0,
}) async {
  try {
    final queryParams = {
      if (type != null) 'type': type,
      if (genre != null) 'genre': genre,
      if (actor != null) 'actor': actor,
      if (director != null) 'director': director,
      if (year != null) 'year': year,
      if (yearMin != null) 'yearMin': yearMin,
      if (yearMax != null) 'yearMax': yearMax,
      if (ratingMin != null) 'ratingMin': ratingMin,
      if (ratingMax != null) 'ratingMax': ratingMax,
      if (quality != null) 'quality': quality,
      if (sortBy != null) 'sortBy': sortBy,
      if (sortOrder != null) 'sortOrder': sortOrder,
      'limit': limit,
      'offset': offset,
    };

    final response = await _dio.get(
      '/filter',
      queryParameters: queryParams,
    );

    return ApiResponse.fromJson(response.data, (json) => Content.fromJson(json));
  } catch (e) {
    print('Error filter: $e');
    rethrow;
  }
}

/// Contenu par genre
Future<ApiResponse<Content>> getByGenre({
  required String genre,
  String? type,
  int limit = 50,
  int offset = 0,
}) async {
  try {
    final response = await _dio.get(
      '/by-genre/$genre',
      queryParameters: {
        if (type != null) 'type': type,
        'limit': limit,
        'offset': offset,
      },
    );

    return ApiResponse.fromJson(response.data, (json) => Content.fromJson(json));
  } catch (e) {
    print('Error getByGenre: $e');
    rethrow;
  }
}

/// Contenu par acteur
Future<ApiResponse<Content>> getByActor({
  required String actor,
  String? type,
  int limit = 50,
  int offset = 0,
}) async {
  try {
    final response = await _dio.get(
      '/by-actor/$actor',
      queryParameters: {
        if (type != null) 'type': type,
        'limit': limit,
        'offset': offset,
      },
    );

    return ApiResponse.fromJson(response.data, (json) => Content.fromJson(json));
  } catch (e) {
    print('Error getByActor: $e');
    rethrow;
  }
}

/// Top notés
Future<ApiResponse<Content>> getTopRated({
  String? type,
  double minRating = 7.0,
  int limit = 20,
}) async {
  try {
    final response = await _dio.get(
      '/top-rated',
      queryParameters: {
        if (type != null) 'type': type,
        'minRating': minRating,
        'limit': limit,
      },
    );

    return ApiResponse.fromJson(response.data, (json) => Content.fromJson(json));
  } catch (e) {
    print('Error getTopRated: $e');
    rethrow;
  }
}

/// Récents
Future<ApiResponse<Content>> getRecent({
  String? type,
  String? year,
  int limit = 20,
}) async {
  try {
    final response = await _dio.get(
      '/recent',
      queryParameters: {
        if (type != null) 'type': type,
        if (year != null) 'year': year,
        'limit': limit,
      },
    );

    return ApiResponse.fromJson(response.data, (json) => Content.fromJson(json));
  } catch (e) {
    print('Error getRecent: $e');
    rethrow;
  }
}

/// Aléatoires
Future<ApiResponse<Content>> getRandom({
  String? type,
  String? genre,
  int count = 10,
}) async {
  try {
    final response = await _dio.get(
      '/random',
      queryParameters: {
        if (type != null) 'type': type,
        if (genre != null) 'genre': genre,
        'count': count,
      },
    );

    return ApiResponse.fromJson(response.data, (json) => Content.fromJson(json));
  } catch (e) {
    print('Error getRandom: $e');
    rethrow;
  }
}

/// Détails d'un item
Future<Content?> getItemDetails(String itemId) async {
  try {
    final response = await _dio.get('/item/$itemId');
    
    if (response.data is Map<String, dynamic>) {
      return Content.fromJson(response.data);
    }
    return null;
  } catch (e) {
    print('Error getItemDetails: $e');
    return null;
  }
}

/// Episodes d'une série
Future<List<Episode>> getEpisodes(
  String seriesId, {
  int? season,
}) async {
  try {
    final endpoint = season != null ? '/episodes/$seriesId/$season' : '/episodes/$seriesId';
    final response = await _dio.get(endpoint);
    
    final data = response.data;
    if (data is List) {
      return data.map((e) => Episode.fromJson(e)).toList();
    } else if (data is Map<String, dynamic> && data.containsKey('episodes')) {
      return (data['episodes'] as List)
          .map((e) => Episode.fromJson(e))
          .toList();
    }
    return [];
  } catch (e) {
    print('Error getEpisodes: $e');
    return [];
  }
}

/// Liens de streaming
Future<List<String>> getWatchLinks(String itemId) async {
  try {
    final response = await _dio.get('/watch-links/$itemId');
    
    if (response.data is List) {
      return List<String>.from(response.data);
    } else if (response.data is Map<String, dynamic> && response.data.containsKey('links')) {
      return List<String>.from(response.data['links']);
    }
    return [];
  } catch (e) {
    print('Error getWatchLinks: $e');
    return [];
  }
}
```

### Fix 5: Update SearchResponse Model

**File:** `lib/data/models/search_response.dart`

```dart
class SearchResponse {
  final List<Movie> movies;
  final List<Series> series;
  final List<String> actors;
  final List<String> directors;
  final int count;
  final int total;

  SearchResponse({
    required this.movies,
    required this.series,
    required this.actors,
    required this.directors,
    required this.count,
    required this.total,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    final results = json['results'] ?? json['data'] ?? {};
    
    final movies = ((results['movies'] ?? []) as List)
        .map((m) => Movie.fromJson(m))
        .toList();
    
    final series = ((results['series'] ?? []) as List)
        .map((s) => Series.fromJson(s))
        .toList();
    
    final actors = List<String>.from(results['actors'] ?? []);
    final directors = List<String>.from(results['directors'] ?? []);

    return SearchResponse(
      movies: movies,
      series: series,
      actors: actors,
      directors: directors,
      count: json['count'] ?? movies.length + series.length,
      total: json['total'] ?? movies.length + series.length,
    );
  }
}
```

---

## Summary of Changes

| Component | Change | Priority |
|-----------|--------|----------|
| Movie.dart | Add runtime, country, language; fix rating field | HIGH |
| Series.dart | Fix episode/season mapping; add status, network | HIGH |
| ApiResponse.dart | Handle both "data" and "results" fields | HIGH |
| ZenixApiService.dart | Fix endpoints, add missing methods | HIGH |
| SearchResponse.dart | Fix response structure | HIGH |
| SearchService.dart | Update parameter names | HIGH |
| SeriesCompactService.dart | Update field mappings | MEDIUM |

---

## Compilation Status After Fixes

Expected: 0 errors, 0 warnings

---

## Testing Checklist

- [ ] Fetch movies list successfully
- [ ] Fetch series list successfully
- [ ] Search works with all filters
- [ ] Autocomplete returns suggestions
- [ ] Get episode details
- [ ] Get watch links
- [ ] Handle missing fields gracefully
- [ ] All error messages display correctly

---

**Status:** AUDIT COMPLETE - IMPLEMENTATION REQUIRED  
**Next Step:** Apply all fixes and test with actual API