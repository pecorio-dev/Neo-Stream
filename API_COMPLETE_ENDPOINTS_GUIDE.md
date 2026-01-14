# NEO-Stream API - Complete Endpoints Guide

**API Version:** 2.1.0  
**Base URL:** `http://node.zenix.sg:25825`  
**Status:** Running ✅  

---

## Table of Contents

1. [Root & Health](#root--health)
2. [Data Endpoints](#data-endpoints)
3. [Search & Filter](#search--filter)
4. [Browse by Criteria](#browse-by-criteria)
5. [Metadata Endpoints](#metadata-endpoints)
6. [Autocomplete & Suggestions](#autocomplete--suggestions)
7. [Item Details](#item-details)
8. [Scraping & Refresh](#scraping--refresh)
9. [Statistics & Debug](#statistics--debug)

---

## Root & Health

### GET `/`
Root endpoint with API information and available endpoints.

**Response:**
```json
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

### GET `/health`
Health check with detailed status information.

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2025-01-15T10:30:45.123456",
  "uptime_data": {
    "films": 15884,
    "series": 360,
    "last_update": "2025-01-15T10:30:00.000000"
  },
  "is_scraping": false,
  "api_stats": {
    "requests_total": 1250,
    "avg_response_time_ms": 45.32,
    "errors_total": 2
  }
}
```

---

## Data Endpoints

### GET `/films`
Get list of films with pagination and filters.

**Query Parameters:**
- `limit` (integer, 1-1000, optional): Results per page
- `offset` (integer, ≥0, default: 0): Pagination offset
- `year` (string, optional): Filter by exact year (e.g., "2024")
- `sort` (string, optional): Sort by "title", "year", or "watch_links"

**Example:**
```
GET /films?limit=10&offset=0&year=2024&sort=year
```

**Response:**
```json
{
  "total": 1250,
  "offset": 0,
  "limit": 10,
  "count": 10,
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
      "synopsis": "Description du film...",
      "watch_links_count": 3
    }
  ]
}
```

---

### GET `/series`
Get list of series with pagination and filters.

**Query Parameters:**
- `limit` (integer, 1-1000, optional): Results per page
- `offset` (integer, ≥0, default: 0): Pagination offset
- `year` (string, optional): Filter by exact year
- `sort` (string, optional): Sort by "title", "year", or "episodes"

**Example:**
```
GET /series?limit=10&offset=0
```

**Response:**
```json
{
  "total": 360,
  "offset": 0,
  "limit": 10,
  "count": 10,
  "data": [
    {
      "id": "29419-the-last-frontier",
      "title": "The Last Frontier",
      "original_title": "The Last Frontier",
      "type": "serie",
      "year": "2025",
      "poster": "https://www.cpasmieux.is/poster/the-last-frontier.jpg",
      "url": "https://www.cpasmieux.is/29419-the-last-frontier.html",
      "genres": ["Action", "Drama"],
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

---

## Search & Filter

### GET `/search`
Advanced search across films and series with full filtering.

**Query Parameters:**
- `q` (string, required, 1-100 chars): Search query
- `type` (string, optional): "film" or "serie" (default: both)
- `genre` (string, optional): Filter by genre
- `actor` (string, optional): Filter by actor
- `director` (string, optional): Filter by director
- `year` (string, optional): Filter by exact year
- `year_min` (integer, optional): Minimum year (1900-2100)
- `year_max` (integer, optional): Maximum year (1900-2100)
- `rating_min` (float, optional): Minimum rating (0-10)
- `quality` (string, optional): Filter by quality (HD, CAM, etc.)
- `limit` (integer, 1-200, default: 50): Results per page
- `offset` (integer, ≥0, default: 0): Pagination offset

**Search Fields:**
- title
- original_title
- synopsis
- description
- actors
- directors
- genres

**Example:**
```
GET /search?q=batman&type=film&rating_min=7.0&limit=20&offset=0
```

**Response:**
```json
{
  "query": "batman",
  "filters": {
    "type": "film",
    "genre": null,
    "actor": null,
    "director": null,
    "year": null,
    "year_min": null,
    "year_max": null,
    "rating_min": 7.0,
    "quality": null
  },
  "total": 38,
  "offset": 0,
  "limit": 20,
  "count": 20,
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
      "actors": ["Michael Keaton", "Jack Nicholson"],
      "directors": ["Tim Burton"],
      "synopsis": "...",
      "watch_links_count": 2
    }
  ]
}
```

---

### GET `/filter`
Filter content without text search using multiple criteria.

**Query Parameters:**
- `type` (string, optional): "film" or "serie"
- `genre` (string, optional): Filter by genre
- `actor` (string, optional): Filter by actor
- `director` (string, optional): Filter by director
- `year` (string, optional): Filter by exact year
- `year_min` (integer, optional): Minimum year
- `year_max` (integer, optional): Maximum year
- `rating_min` (float, optional): Minimum rating (0-10)
- `rating_max` (float, optional): Maximum rating (0-10)
- `quality` (string, optional): Filter by quality
- `version` (string, optional): Filter by version (VF, VOSTFR)
- `language` (string, optional): Filter by language
- `sort_by` (string, optional): "title", "year", "rating" (default: "title")
- `sort_order` (string, optional): "asc" or "desc" (default: "asc")
- `limit` (integer, 1-200, default: 50): Results per page
- `offset` (integer, ≥0, default: 0): Pagination offset

**Example:**
```
GET /filter?genre=Action&year_min=2020&rating_min=7.0&sort_by=rating&sort_order=desc
```

**Response:**
```json
{
  "filters": {
    "type": null,
    "genre": "Action",
    "actor": null,
    "director": null,
    "year": null,
    "year_min": 2020,
    "year_max": null,
    "rating_min": 7.0,
    "rating_max": null,
    "quality": null,
    "version": null,
    "language": null
  },
  "sort": {
    "by": "rating",
    "order": "desc"
  },
  "total": 245,
  "offset": 0,
  "limit": 50,
  "count": 50,
  "data": [...]
}
```

---

## Browse by Criteria

### GET `/by-genre/{genre}`
Get all items of a specific genre.

**Parameters:**
- `genre` (path, required): Genre name (case-insensitive)
- `type` (query, optional): "film" or "serie"
- `limit` (query, 1-200, default: 50): Results per page
- `offset` (query, ≥0, default: 0): Pagination offset

**Example:**
```
GET /by-genre/Action?type=film&limit=30
```

**Response:**
```json
{
  "genre": "Action",
  "type_filter": "film",
  "total": 456,
  "offset": 0,
  "limit": 30,
  "count": 30,
  "data": [...]
}
```

---

### GET `/by-actor/{actor}`
Get all items with a specific actor.

**Parameters:**
- `actor` (path, required): Actor name (case-insensitive partial match)
- `type` (query, optional): "film" or "serie"
- `limit` (query, 1-200, default: 50): Results per page
- `offset` (query, ≥0, default: 0): Pagination offset

**Example:**
```
GET /by-actor/Tom%20Cruise?type=film
```

---

### GET `/by-director/{director}`
Get all items by a specific director.

**Parameters:**
- `director` (path, required): Director name (case-insensitive partial match)
- `type` (query, optional): "film" or "serie"
- `limit` (query, 1-200, default: 50): Results per page
- `offset` (query, ≥0, default: 0): Pagination offset

---

### GET `/by-year/{year}`
Get all items from a specific year.

**Parameters:**
- `year` (path, required): Year as string (e.g., "2024")
- `type` (query, optional): "film" or "serie"
- `limit` (query, 1-200, default: 50): Results per page
- `offset` (query, ≥0, default: 0): Pagination offset

---

### GET `/top-rated`
Get highest-rated items.

**Query Parameters:**
- `type` (string, optional): "film" or "serie"
- `min_rating` (float, default: 7.0): Minimum rating threshold (0-10)
- `limit` (integer, 1-200, default: 50): Results per page
- `offset` (integer, ≥0, default: 0): Pagination offset

**Example:**
```
GET /top-rated?type=film&min_rating=8.5&limit=20
```

---

### GET `/recent`
Get recent items (current year by default).

**Query Parameters:**
- `type` (string, optional): "film" or "serie"
- `year` (string, optional): Specific year (default: current year)
- `limit` (integer, 1-200, default: 50): Results per page
- `offset` (integer, ≥0, default: 0): Pagination offset

**Example:**
```
GET /recent?year=2024&limit=30
```

---

### GET `/random`
Get random items with optional genre filter.

**Query Parameters:**
- `type` (string, optional): "film" or "serie"
- `genre` (string, optional): Filter by genre
- `count` (integer, 1-50, default: 10): Number of random items

**Example:**
```
GET /random?type=film&genre=Action&count=10
```

**Response:**
```json
{
  "type_filter": "film",
  "genre_filter": "Action",
  "count": 10,
  "data": [...]
}
```

---

## Metadata Endpoints

### GET `/genres`
Get all available genres with item counts.

**Query Parameters:**
- `type` (string, optional): "film" or "serie" (default: both)

**Response:**
```json
{
  "total": 45,
  "data": [
    {
      "name": "Action",
      "count": 3245
    },
    {
      "name": "Drama",
      "count": 2891
    }
  ]
}
```

---

### GET `/actors`
Get all available actors with appearance counts.

**Query Parameters:**
- `type` (string, optional): "film" or "serie" (default: both)
- `q` (string, optional, min 2 chars): Search actor by name
- `limit` (integer, 1-500, default: 100): Max results

**Example:**
```
GET /actors?q=tom&limit=20
```

---

### GET `/directors`
Get all available directors with work counts.

**Query Parameters:**
- `type` (string, optional): "film" or "serie" (default: both)
- `q` (string, optional, min 2 chars): Search director by name
- `limit` (integer, 1-500, default: 100): Max results

---

### GET `/years`
Get all available years with item counts.

**Query Parameters:**
- `type` (string, optional): "film" or "serie" (default: both)

**Response:**
```json
{
  "total": 75,
  "data": [
    {
      "year": "2025",
      "count": 124
    },
    {
      "year": "2024",
      "count": 856
    }
  ]
}
```

---

### GET `/qualities`
Get all available qualities with item counts.

**Query Parameters:**
- `type` (string, optional): "film" or "serie" (default: both)

**Response:**
```json
{
  "total": 8,
  "data": [
    {
      "quality": "HD",
      "count": 12450
    },
    {
      "quality": "CAM",
      "count": 1234
    }
  ]
}
```

---

## Autocomplete & Suggestions

### GET `/autocomplete`
Fast autocomplete suggestions based on title.

**Query Parameters:**
- `q` (string, required, 1-50 chars): Search query
- `type` (string, optional): "film" or "serie"
- `limit` (integer, 1-20, default: 10): Max suggestions

**Response:**
```json
{
  "query": "bat",
  "count": 10,
  "suggestions": [
    {
      "id": "1117-batman-1989",
      "title": "Batman",
      "original_title": "Batman",
      "type": "film",
      "year": "1989",
      "poster": "https://..."
    }
  ]
}
```

---

### GET `/suggest/actors`
Actor suggestions for autocomplete.

**Query Parameters:**
- `q` (string, required, min 2 chars): Search query
- `limit` (integer, 1-30, default: 10): Max suggestions

**Response:**
```json
{
  "query": "tom",
  "count": 8,
  "suggestions": ["Tom Cruise", "Tom Hardy", "Tom Hanks"]
}
```

---

### GET `/suggest/directors`
Director suggestions for autocomplete.

**Query Parameters:**
- `q` (string, required, min 2 chars): Search query
- `limit` (integer, 1-30, default: 10): Max suggestions

---

### GET `/suggest/genres`
Genre suggestions for autocomplete.

**Query Parameters:**
- `q` (string, required, min 1 char): Search query
- `limit` (integer, 1-30, default: 10): Max suggestions

---

### GET `/multi-search`
Search across multiple categories simultaneously.

**Query Parameters:**
- `q` (string, required, 1-100 chars): Search query
- `limit` (integer, 1-50, default: 10): Max results per category

**Response:**
```json
{
  "query": "batman",
  "results": {
    "films": {
      "count": 12,
      "data": [...]
    },
    "series": {
      "count": 2,
      "data": [...]
    },
    "actors": {
      "count": 3,
      "data": ["Actor Name"]
    },
    "directors": {
      "count": 1,
      "data": ["Director Name"]
    },
    "genres": {
      "count": 0,
      "data": []
    }
  }
}
```

---

## Item Details

### GET `/item/{item_id}`
Get complete details of a film or series.

**Parameters:**
- `item_id` (path, required): Item ID, slug, or URL portion (case-insensitive)

**Response:**
```json
{
  "id": "1117-batman-1989",
  "title": "Batman",
  "original_title": "Batman",
  "type": "film",
  "year": "1989",
  "genres": ["Action", "Crime", "Fantasy"],
  "directors": ["Tim Burton"],
  "actors": ["Michael Keaton", "Jack Nicholson"],
  "synopsis": "Full description...",
  "description": "Extended description...",
  "poster": "https://...",
  "rating": 9.6,
  "rating_max": 10,
  "quality": "HD",
  "version": "TrueFrench",
  "language": "English",
  "duration": 126,
  "url": "https://...",
  "watch_links": [
    {
      "server": "UQLOAD",
      "url": "https://...",
      "quality": "HD"
    }
  ]
}
```

---

### GET `/item/{item_id}/episodes`
Get episodes of a series, optionally filtered by season.

**Parameters:**
- `item_id` (path, required): Series ID
- `season` (query, optional): Filter by season number (≥1)

**Response:**
```json
{
  "series_id": "29419-the-last-frontier",
  "series_title": "The Last Frontier",
  "season_filter": null,
  "total_episodes": 4,
  "episodes": [
    {
      "url": "https://...",
      "season": 1,
      "episode": 1,
      "title": "Episode Title",
      "synopsis": "Episode description",
      "quality": "HD",
      "watch_links": [
        {
          "server": "UQLOAD",
          "url": "https://..."
        }
      ]
    }
  ]
}
```

---

### GET `/item/{item_id}/watch-links`
Get only watch/streaming links for an item.

**Parameters:**
- `item_id` (path, required): Item ID

**Response:**
```json
{
  "id": "1117-batman-1989",
  "title": "Batman",
  "type": "film",
  "watch_links": [
    {
      "server": "UQLOAD",
      "url": "https://uqload.com/...",
      "quality": "HD"
    },
    {
      "server": "STREAMTAPE",
      "url": "https://streamtape.com/...",
      "quality": "HD"
    }
  ]
}
```

---

### GET `/item/{item_id}/episode/{season}/{episode}`
Get details of a specific episode.

**Parameters:**
- `item_id` (path, required): Series ID
- `season` (path, required): Season number
- `episode` (path, required): Episode number

**Response:**
```json
{
  "serie_id": "29419-the-last-frontier",
  "serie_title": "The Last Frontier",
  "season": 1,
  "episode": 1,
  "title": "Episode Title",
  "url": "https://...",
  "watch_links": [...]
}
```

---

## Scraping & Refresh

### POST `/refresh`
Start scraping in background with real-time data injection.

**Query Parameters:**
- `incremental` (boolean, default: true): Merge with existing data (true) or replace (false)
- `max_pages_films` (integer, 1-1000, default: 100): Max pages to scrape for films
- `max_pages_series` (integer, 1-600, default: 50): Max pages to scrape for series

**Example:**
```
POST /refresh?incremental=true&max_pages_films=200&max_pages_series=100
```

**Response:**
```json
{
  "status": "started",
  "mode": "incremental",
  "max_pages_films": 200,
  "max_pages_series": 100,
  "message": "Scraping démarré en arrière-plan. Utilisez /debug/progress pour suivre l'avancement."
}
```

---

### GET `/refresh/status`
Get current scraping status.

**Response:**
```json
{
  "is_scraping": false,
  "progress": {
    "status": "completed",
    "started_at": "2025-01-15T10:00:00",
    "completed_at": "2025-01-15T10:45:30",
    "films_scraped": 15884,
    "series_scraped": 360,
    "total_films": 15884,
    "total_series": 360
  },
  "current_data": {
    "films": 15884,
    "series": 360,
    "episodes": 5171,
    "watch_links": 31159
  }
}
```

---

## Statistics & Debug

### GET `/stats`
Get detailed statistics.

**Response:**
```json
{
  "data": {
    "films": 15884,
    "series": 360,
    "episodes": 5171,
    "watch_links": 31159,
    "last_update": "2025-01-15T10:45:30"
  },
  "cache": {
    "search_cache_size": 42,
    "search_cache_max": 1000
  },
  "api": {
    "requests_total": 2450,
    "errors_total": 3,
    "avg_response_time_ms": 48.5,
    "top_endpoints": {
      "/search": 850,
      "/films": 620,
      "/series": 450
    }
  },
  "scraping": {
    "is_running": false,
    "last_progress": {...}
  }
}
```

---

### GET `/debug`
Complete debug information.

**Response:**
```json
{
  "system": {
    "timestamp": "2025-01-15T10:45:30",
    "is_scraping": false
  },
  "data_state": {
    "films_count": 15884,
    "series_count": 360,
    "episodes_count": 5171,
    "watch_links_count": 31159,
    "films_index_size": 15884,
    "series_index_size": 360
  },
  "cache_state": {
    "search_cache_size": 42
  },
  "api_stats": {
    "requests_total": 2450,
    "errors_total": 3,
    "avg_response_time_ms": 48.5,
    "requests_by_endpoint": {...},
    "unique_ips": 127
  },
  "scraping_state": {
    "is_running": false,
    "progress": {...},
    "errors_count": 0,
    "last_errors": []
  },
  "scraper_metrics": {...}
}
```

---

### GET `/debug/logs`
Get API and scraper logs.

**Query Parameters:**
- `limit` (integer, 1-1000, default: 100): Number of logs to return
- `level` (string, optional): Filter by "DEBUG", "INFO", "WARNING", "ERROR"

**Response:**
```json
{
  "total": 5432,
  "filtered": 100,
  "level_filter": "INFO",
  "logs": [
    {
      "timestamp": "2025-01-15T10:45:30",
      "level": "INFO",
      "message": "API prête",
      "films": 15884,
      "series": 360
    }
  ]
}
```

---

### GET `/debug/metrics`
Get scraper metrics from last run.

**Response:**
```json
{
  "scraper_metrics": {
    "total_films_scraped": 15884,
    "total_series_scraped": 360,
    "total_episodes_scraped": 5171,
    "duration_seconds": 2700,
    "items_per_second": 7.8
  },
  "scraper_logs_count": 342,
  "scraper_logs_last": [...]
}
```

---

### GET `/debug/progress`
Get real-time scraping progress.

**Response:**
```json
{
  "is_scraping": true,
  "progress": {
    "status": "running",
    "started_at": "2025-01-15T10:00:00",
    "films_scraped": 8942,
    "series_scraped": 245
  },
  "current_totals": {
    "films": 15884,
    "series": 360,
    "episodes": 5171,
    "watch_links": 31159
  },
  "errors": []
}
```

---

### POST `/debug/clear-cache`
Clear the search cache.

**Response:**
```json
{
  "status": "ok",
  "cleared": 42
}
```

---

### POST `/debug/reload`
Reload data from JSON files.

**Response:**
```json
{
  "status": "ok",
  "films": 15884,
  "series": 360,
  "episodes": 5171
}
```

---

## Common Patterns

### Pagination
All list endpoints support pagination using `limit` and `offset`:
```
GET /films?limit=20&offset=0    # First 20
GET /films?limit=20&offset=20   # Next 20
GET /films?limit=20&offset=40   # And so on...
```

### Filtering
Most endpoints support filtering by:
- Genre
- Actor
- Director
- Year (exact or range: year_min, year_max)
- Rating (rating_min, rating_max)
- Quality
- Version (VF, VOSTFR, etc.)

### Response Structure
All data endpoints follow this structure:
```json
{
  "total": 1234,           // Total items in database
  "offset": 0,             // Pagination offset
  "limit": 50,             // Items per page
  "count": 50,             // Items in this response
  "data": [...]            // Array of items
}
```

### Rate Limiting
- `/search`, `/filter`, `/films`, `/series`: 60 requests/minute
- `/autocomplete`: 120 requests/minute (double limit)
- `/refresh`: 5 requests/minute
- Other endpoints: 30 requests/minute

### Error Responses
```json
{
  "detail": "Item 'invalid-id' non trouvé"
}
```
HTTP Status: 404 (or appropriate error code)

---

## Example Flutter Service

```dart
class NeoStreamApiService {
  static const String baseUrl = 'http://node.zenix.sg:25825';
  final Dio _dio;

  Future<ApiResponse<Movie>> getMovies({
    int limit = 50,
    int offset = 0,
    String? year,
    String? sort,
  }) async {
    final response = await _dio.get(
      '/films',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (year != null) 'year': year,
        if (sort != null) 'sort': sort,
      },
    );
    return ApiResponse.fromJson(response.data, (json) => Movie.fromJson(json));
  }

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
    final response = await _dio.get(
      '/search',
      queryParameters: {
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
      },
    );
    return ApiResponse.fromJson(response.data, (json) => Movie.fromJson(json));
  }
}
```

---

**Last Updated:** January 15, 2025  
**API Version:** 2.1.0  
**Status:** Complete & Verified ✅