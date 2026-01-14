# NEO-Stream Real API Structure & Required Fixes

## 1. Real API Endpoints (Verified)

### Base URL
```
http://node.zenix.sg:25825
```

### Root Endpoint
```
GET /
Response:
{
  "name": "NeoStream API",
  "version": "2.1.0",
  "status": "running",
  "data": {
    "films": 15884,
    "series": 360,
    "episodes": 5171,
    "watch_links": 31159
  },
  "endpoints": {
    "/films": "Liste des films (GET)",
    "/series": "Liste des séries (GET)",
    "/search": "Recherche (GET, param: q)",
    "/item/{id}": "Détails d'un film/série (GET)",
    "/item/{id}/episode/{season}/{episode}": "Détails d'un épisode (GET)",
    "/refresh": "Rafraîchir les données (POST)",
    "/stats": "Statistiques (GET)",
    "/debug": "Informations de débogage (GET)",
    "/debug/logs": "Logs de l'API (GET)",
    "/debug/metrics": "Métriques du scraper (GET)",
    "/health": "Health check (GET)"
  }
}
```

### Available Endpoints

#### 1. Films (Movies)
```
GET /films?limit=50&offset=0

Response:
{
  "total": 15884,
  "offset": 0,
  "limit": 2,
  "count": 2,
  "data": [
    {
      "id": "29080-vie-prive",
      "title": "Vie privée",
      "original_title": "Vie privée",
      "type": "film",
      "year": "2025",
      "poster": "https://www.cpasmieux.is/poster/vie-prive.jpg",
      "url": "https://www.cpasmieux.is/29080-vie-prive.html",
      "genres": ["Drame"],
      "rating": 4.3,
      "quality": "HD",
      "version": "French",
      "actors": ["Jodie Foster", "Daniel Auteuil"],
      "directors": ["Rebecca Zlotowski"],
      "synopsis": "Description courte...",
      "watch_links_count": 3
    }
  ]
}
```

#### 2. Series (TV Shows)
```
GET /series?limit=50&offset=0

Response:
{
  "total": 360,
  "offset": 0,
  "limit": 1,
  "count": 1,
  "data": [
    {
      "id": "29419-the-last-frontier",
      "title": "The Last Frontier",
      "original_title": "The Last Frontier",
      "type": "serie",
      "year": "2025",
      "poster": "https://www.cpasmieux.is/poster/the-last-frontier.jpg",
      "url": "https://www.cpasmieux.is/29419-the-last-frontier.html",
      "genres": ["Action"],
      "rating": 8.5,
      "quality": "HD",
      "version": "English",
      "actors": ["Jason Clarke", "Haley Bennett"],
      "directors": ["Director Name"],
      "synopsis": "Description...",
      "watch_links_count": 10,
      "seasons_count": 1,
      "episodes_count": 4
    }
  ]
}
```

#### 3. Search
```
GET /search?q=batman&limit=50&offset=0

Query Parameters:
- q: Search query (required)
- type: 'film' or 'serie' (optional)
- genre: Filter by genre (optional)
- actor: Filter by actor (optional)
- director: Filter by director (optional)
- year: Filter by year (optional)
- year_min: Minimum year (optional)
- year_max: Maximum year (optional)
- rating_min: Minimum rating (optional)
- quality: HD, SD, 4K (optional)
- limit: Results per page (default 50)
- offset: Pagination offset (default 0)

Response:
{
  "query": "batman",
  "filters": {
    "type": null,
    "genre": null,
    "actor": null,
    "director": null
  },
  "total": 38,
  "offset": 0,
  "limit": 2,
  "count": 2,
  "data": [
    {
      "id": "1117-batman-1989",
      "title": "Batman",
      "original_title": "Batman",
      "type": "film",
      "year": "1989",
      "poster": "https://...",
      "url": "https://...",
      "genres": ["Action", "Thriller"],
      "rating": 9.6,
      "quality": "HD",
      "version": "TrueFrench",
      "actors": ["Michael Keaton"],
      "directors": ["Tim Burton"],
      "synopsis": "...",
      "watch_links_count": 2
    }
  ]
}
```

#### 4. Item Details
```
GET /item/{id}

Example: GET /item/29080-vie-prive

Response: Full item details (same structure as above)
```

#### 5. Episode Details
```
GET /item/{id}/episode/{season}/{episode}

Example: GET /item/29419-the-last-frontier/episode/1/1

Response: Episode details
```

---

## 2. Real Data Structure Issues Found

### Issue 1: Movie/Film Model
**Current Problem:** App expects fields that don't exist in API

**API Actually Returns:**
- id, title, original_title
- type (always "film")
- year (string, not releaseYear)
- poster (URL)
- url (source URL)
- genres (array)
- rating (numeric or null)
- quality (HD, SD, 4K)
- version (French, English, TrueFrench, etc.)
- actors (array)
- directors (array)
- synopsis (short description)
- watch_links_count (number, not watch_links array)

**DOES NOT RETURN:**
- ❌ numericRating (uses "rating")
- ❌ releaseYear (uses "year" as string)
- ❌ posterUrl (uses "poster")
- ❌ runtime
- ❌ country
- ❌ language
- ❌ watchLinks array (only count)

### Issue 2: Series Model
**API Actually Returns:**
- id, title, original_title
- type (always "serie")
- year (string)
- poster, url
- genres, rating, quality, version
- actors, directors
- synopsis
- watch_links_count
- seasons_count (number)
- episodes_count (number)

**DOES NOT RETURN:**
- ❌ Individual seasons/episodes in main list (need separate call)
- ❌ status (ongoing/completed)
- ❌ airedFrom, airedTo
- ❌ network
- ❌ totalSeasons (uses seasons_count)
- ❌ totalEpisodes (uses episodes_count)

### Issue 3: Response Structure
**API Consistently Returns:**
```json
{
  "total": number,
  "offset": number,
  "limit": number,
  "count": number,
  "data": [ items ]
}
```

NOT:
- ❌ "results" field
- ❌ "status" field
- ❌ "message" field

---

## 3. Required Fixes to App

### Fix 1: Update Movie.dart

```dart
class Movie {
  final String id;
  final String title;
  final String? originalTitle;
  final String type;  // "film"
  final String year;  // String, not int
  final String? poster;
  final String? url;
  final List<String> genres;
  final double? rating;  // Can be null
  final String? quality;  // HD, SD, 4K
  final String? version;  // French, English, etc.
  final List<String> actors;
  final List<String> directors;
  final String? synopsis;
  final int? watchLinksCount;  // Not array

  Movie({
    required this.id,
    required this.title,
    this.originalTitle,
    required this.type,
    required this.year,
    this.poster,
    this.url,
    required this.genres,
    this.rating,
    this.quality,
    this.version,
    required this.actors,
    required this.directors,
    this.synopsis,
    this.watchLinksCount,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      originalTitle: json['original_title'],
      type: json['type'] ?? 'film',
      year: json['year']?.toString() ?? '',
      poster: json['poster'],
      url: json['url'],
      genres: List<String>.from(json['genres'] ?? []),
      rating: (json['rating'] as num?)?.toDouble(),
      quality: json['quality'],
      version: json['version'],
      actors: List<String>.from(json['actors'] ?? []),
      directors: List<String>.from(json['directors'] ?? []),
      synopsis: json['synopsis'],
      watchLinksCount: json['watch_links_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'original_title': originalTitle,
      'type': type,
      'year': year,
      'poster': poster,
      'url': url,
      'genres': genres,
      'rating': rating,
      'quality': quality,
      'version': version,
      'actors': actors,
      'directors': directors,
      'synopsis': synopsis,
      'watch_links_count': watchLinksCount,
    };
  }
}
```

### Fix 2: Update Series.dart

```dart
class Series {
  final String id;
  final String title;
  final String? originalTitle;
  final String type;  // "serie"
  final String year;
  final String? poster;
  final String? url;
  final List<String> genres;
  final double? rating;
  final String? quality;
  final String? version;
  final List<String> actors;
  final List<String> directors;
  final String? synopsis;
  final int? watchLinksCount;
  final int seasonsCount;  // NOT totalSeasons
  final int episodesCount;  // NOT totalEpisodes

  Series({
    required this.id,
    required this.title,
    this.originalTitle,
    required this.type,
    required this.year,
    this.poster,
    this.url,
    required this.genres,
    this.rating,
    this.quality,
    this.version,
    required this.actors,
    required this.directors,
    this.synopsis,
    this.watchLinksCount,
    required this.seasonsCount,
    required this.episodesCount,
  });

  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      originalTitle: json['original_title'],
      type: json['type'] ?? 'serie',
      year: json['year']?.toString() ?? '',
      poster: json['poster'],
      url: json['url'],
      genres: List<String>.from(json['genres'] ?? []),
      rating: (json['rating'] as num?)?.toDouble(),
      quality: json['quality'],
      version: json['version'],
      actors: List<String>.from(json['actors'] ?? []),
      directors: List<String>.from(json['directors'] ?? []),
      synopsis: json['synopsis'],
      watchLinksCount: json['watch_links_count'],
      seasonsCount: json['seasons_count'] ?? 0,
      episodesCount: json['episodes_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'original_title': originalTitle,
      'type': type,
      'year': year,
      'poster': poster,
      'url': url,
      'genres': genres,
      'rating': rating,
      'quality': quality,
      'version': version,
      'actors': actors,
      'directors': directors,
      'synopsis': synopsis,
      'watch_links_count': watchLinksCount,
      'seasons_count': seasonsCount,
      'episodes_count': episodesCount,
    };
  }
}
```

### Fix 3: Create ApiResponse.dart (Unified)

```dart
class ApiResponse<T> {
  final List<T> data;
  final int total;
  final int offset;
  final int limit;
  final int count;

  ApiResponse({
    required this.data,
    required this.total,
    required this.offset,
    required this.limit,
    required this.count,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final items = json['data'] as List<dynamic>? ?? [];
    final data = items
        .cast<Map<String, dynamic>>()
        .map(fromJsonT)
        .toList();

    return ApiResponse(
      data: data,
      total: json['total'] ?? 0,
      offset: json['offset'] ?? 0,
      limit: json['limit'] ?? 50,
      count: json['count'] ?? items.length,
    );
  }

  Map<String, dynamic> toJson(
    Map<String, dynamic> Function(T) toJsonT,
  ) {
    return {
      'data': data.map(toJsonT).toList(),
      'total': total,
      'offset': offset,
      'limit': limit,
      'count': count,
    };
  }
}
```

### Fix 4: Update ZenixApiService.dart

```dart
class ZenixApiService {
  static const String baseUrl = 'http://node.zenix.sg:25825';
  
  final Dio _dio;

  ZenixApiService(this._dio);

  /// Get movies list
  Future<ApiResponse<Movie>> getMovies({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/films',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );

      return ApiResponse.fromJson(
        response.data,
        (json) => Movie.fromJson(json),
      );
    } catch (e) {
      print('Error getMovies: $e');
      rethrow;
    }
  }

  /// Get series list
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

      return ApiResponse.fromJson(
        response.data,
        (json) => Series.fromJson(json),
      );
    } catch (e) {
      print('Error getSeries: $e');
      rethrow;
    }
  }

  /// Search for movies and series
  Future<ApiResponse<dynamic>> search({
    required String q,
    String? type,
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
        if (type != null) 'type': type,
        if (genre != null) 'genre': genre,
        if (actor != null) 'actor': actor,
        if (director != null) 'director': director,
        if (year != null) 'year': year,
        if (yearMin != null) 'year_min': yearMin,
        if (yearMax != null) 'year_max': yearMax,
        if (ratingMin != null) 'rating_min': ratingMin,
        if (quality != null) 'quality': quality,
        'limit': limit,
        'offset': offset,
      };

      final response = await _dio.get(
        '/search',
        queryParameters: queryParams,
      );

      return ApiResponse.fromJson(
        response.data,
        (json) {
          final itemType = json['type'];
          if (itemType == 'film') {
            return Movie.fromJson(json);
          } else if (itemType == 'serie') {
            return Series.fromJson(json);
          }
          return Movie.fromJson(json);
        },
      );
    } catch (e) {
      print('Error search: $e');
      rethrow;
    }
  }

  /// Get item details
  Future<dynamic> getItemDetails(String itemId) async {
    try {
      final response = await _dio.get('/item/$itemId');
      final data = response.data as Map<String, dynamic>;
      final itemType = data['type'];

      if (itemType == 'film') {
        return Movie.fromJson(data);
      } else if (itemType == 'serie') {
        return Series.fromJson(data);
      }

      return Movie.fromJson(data);
    } catch (e) {
      print('Error getItemDetails: $e');
      rethrow;
    }
  }

  /// Get episode details
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
      print('Error getEpisodeDetails: $e');
      return null;
    }
  }

  /// Health check
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      print('Error healthCheck: $e');
      return false;
    }
  }

  /// Get API stats
  Future<Map<String, dynamic>?> getStats() async {
    try {
      final response = await _dio.get('/stats');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('Error getStats: $e');
      return null;
    }
  }
}
```

---

## 4. Summary of Changes

| Issue | Fix | Priority |
|-------|-----|----------|
| Movie model has wrong fields | Use actual API fields | HIGH |
| Series model incomplete | Add seasons_count, episodes_count | HIGH |
| ApiResponse wrong structure | Use "data" field directly | HIGH |
| Wrong endpoints (/series/compact) | Use /films, /series, /search | HIGH |
| WatchLinks as array | Use watchLinksCount only | HIGH |
| Type field mismatch | "film" vs "movie", "serie" vs "series" | HIGH |

---

## 5. Testing Checklist

- [ ] GET /films returns movies with correct fields
- [ ] GET /series returns series with correct fields  
- [ ] GET /search?q=batman works
- [ ] Movie.fromJson() parses correctly
- [ ] Series.fromJson() parses correctly
- [ ] Rating can be null
- [ ] Year is string, not int
- [ ] No runtime/country/language fields in Movie
- [ ] No individual seasons in Series response
- [ ] watchLinksCount is number, not array

---

**Status:** REAL API STRUCTURE VERIFIED  
**Date:** 2025