# NEO-Stream Model Migration Guide

## Overview
This guide documents all breaking changes made to align the data models with the real API (v2.1.0) and provides migration paths for all affected code.

## Breaking Changes Summary

### 1. Movie Model Changes

#### Old Structure
```dart
class Movie {
  final String id;
  final String url;
  final String title;
  final String type;
  final String mainTitle;
  final String originalTitle;
  final double rating;  // numeric string like "8.5/10"
  final int? releaseYear;
  final String? releaseDate;
  final String? quality;
  final String? version;
  final String? language;
  final List<String> genres;
  final String? director;  // single string
  final List<String> actors;
  final String? synopsis;
  final List<WatchLink>? watchLinks;  // full array
  final String? poster;
  final String? posterUrl;
  final int? runtime;
  final String? country;
}
```

#### New Structure
```dart
class Movie {
  final String id;
  final String title;
  final String? originalTitle;
  final String type;  // "film"
  final String year;  // string, not int
  final String? poster;
  final String? url;
  final List<String> genres;
  final double? rating;  // numeric double or null
  final String? quality;
  final String? version;
  final List<String> actors;
  final List<String> directors;  // array, not single string
  final String? synopsis;
  final int? watchLinksCount;  // count only, not full array
}
```

#### Migration Steps

**Step 1: Update field access**
```dart
// OLD
movie.releaseYear  // was int or null
movie.rating      // was string like "8.5"
movie.director    // was string or null
movie.watchLinks  // was List<WatchLink>

// NEW
int.parse(movie.year)  // parse year string to int
movie.rating           // now direct double or null
movie.directors        // now List<String>
movie.watchLinksCount  // now int or null - fetch full links via API
```

**Step 2: Update Movie.fromJson() calls**
```dart
// OLD: fromJson expected poster_url and watch_links array
movie = Movie.fromJson(data);

// NEW: fromJson expects poster and watch_links_count
movie = Movie.fromJson(data);
// Same method, different keys handled internally
```

**Step 3: Update display logic**
```dart
// OLD: Display watch link count from array
Text('${movie.watchLinks?.length ?? 0} links')

// NEW: Use count directly
Text('${movie.watchLinksCount ?? 0} links')

// OLD: Get director name
Text(movie.director ?? 'Unknown')

// NEW: Get first director or all
Text(movie.directors.isNotEmpty ? movie.directors.first : 'Unknown')
Text(movie.directors.join(', '))
```

---

### 2. Series Model Changes

#### Old Structure
```dart
class Series {
  final String id;
  final String url;
  final String title;
  final String originalTitle;
  final String mainTitle;
  final String rating;  // string
  final String releaseDate;
  final String quality;
  final String version;
  final String language;
  final List<String> genres;
  final String director;  // single
  final List<String> actors;
  final String synopsis;
  final String poster;
  final List<Season> seasons;  // full season/episode data
  final String status;
  final int totalSeasons;
  final int totalEpisodes;
}
```

#### New Structure
```dart
class Series {
  final String id;
  final String title;
  final String? originalTitle;
  final String type;  // "serie"
  final String year;  // string
  final String? poster;
  final String? url;
  final List<String> genres;
  final double? rating;  // numeric or null
  final String? quality;
  final String? version;
  final List<String> actors;
  final List<String> directors;  // array
  final String? synopsis;
  final int? watchLinksCount;
  final int seasonsCount;  // count only
  final int episodesCount;  // count only
  // seasons data must be fetched separately via getEpisodes()
}
```

#### Migration Steps

**Step 1: Update field references**
```dart
// OLD
series.totalSeasons     // was int
series.totalEpisodes    // was int
series.seasons          // was List<Season>
series.director         // was string
series.status           // was string

// NEW
series.seasonsCount     // int
series.episodesCount    // int
// seasons must be fetched separately
series.directors        // List<String>
// status not provided by API
```

**Step 2: Fetch episodes separately**
```dart
// OLD: Episodes included in Series model
for (var season in series.seasons) {
  for (var episode in season.episodes) {
    // use episode
  }
}

// NEW: Fetch via API
final episodes = await apiService.getEpisodes(seriesId);
if (episodes != null) {
  // parse episodes from response
}
```

**Step 3: Update UI references**
```dart
// OLD
Text('${series.totalSeasons} seasons')
Text('${series.totalEpisodes} episodes')
series.seasons.length

// NEW
Text('${series.seasonsCount} seasons')
Text('${series.episodesCount} episodes')
series.seasonsCount
```

---

### 3. ApiResponse Model Changes

#### Old Structure
```dart
class ApiResponse<T> {
  final List<T>? movies;
  final List<T>? series;
  final List<T>? results;
  final int count;
  final int total;
  final int limit;
  final int offset;
  final String? note;

  List<T> get data {
    if (movies != null) return movies!;
    if (series != null) return series!;
    if (results != null) return results!;
    return [];
  }
}
```

#### New Structure
```dart
class ApiResponse<T> {
  final List<T> data;      // always "data" field
  final int total;         // total in database
  final int offset;        // pagination offset
  final int limit;         // items per page
  final int count;         // items in this response

  bool get hasMore => offset + count < total;
  int get nextOffset => offset + limit;
  int get currentPage => (offset / limit).floor() + 1;
  int get totalPages => (total / limit).ceil();
}
```

#### Migration Steps

**Step 1: Update response parsing**
```dart
// OLD
final response = ApiResponse<Movie>.fromJson(data, Movie.fromJson);
final movies = response.data;  // called getter

// NEW
final response = ApiResponse<Movie>.fromJson(data, Movie.fromJson);
final movies = response.data;  // now always a field
```

**Step 2: Update pagination**
```dart
// OLD
if (response.count < response.limit) {
  // last page
}

// NEW
if (!response.hasMore) {
  // last page
}

// OLD
int nextOffset = response.offset + response.limit;

// NEW
int nextOffset = response.nextOffset;
```

**Step 3: Update type conversions**
```dart
// OLD: Had to handle multiple possible fields
List<T> items = response.movies ?? response.series ?? response.results ?? [];

// NEW: Always use data
List<T> items = response.data;
```

---

### 4. SearchResponse Model Changes

#### Old Structure
```dart
class SearchResponse {
  final String query;
  final String type;
  final String fields;
  final bool consolidated;
  final List<SearchResult> results;
  final int count;
  final int total;
  final int limit;
  final int offset;
}
```

#### New Structure
```dart
class SearchResponse {
  final String query;
  final Map<String, dynamic>? filters;  // filter parameters echoed
  final List<dynamic> data;             // raw results
  final int total;
  final int offset;
  final int limit;
  final int count;
}
```

#### Migration Steps

```dart
// OLD: Type-safe results
for (var result in response.results) {
  final content = result.toContent();  // movie or series
}

// NEW: Need to determine type and parse
for (var item in response.data) {
  final type = item['type'];  // 'film' or 'serie'
  if (type == 'film') {
    final movie = Movie.fromJson(item);
  } else if (type == 'serie') {
    final series = Series.fromJson(item);
  }
}
```

---

### 5. WatchLink Model Changes

#### Old Structure
```dart
class WatchLink {
  final String url;
  final String server;
  final String type;
}
```

#### New Structure
```dart
class WatchLink {
  final String server;
  final String url;
  final String? quality;  // HD, SD, 4K, etc.
}
```

#### Migration
```dart
// OLD
link.type  // was string

// NEW
link.quality  // now optional string for quality info
```

---

## Files Requiring Updates

### Services
- `lib/data/services/zenix_api_service.dart` - ✅ Updated
- `lib/data/services/search_service.dart` - Needs update
- `lib/data/services/series_api_service.dart` - Needs update
- `lib/data/services/movies_api_service.dart` - Needs update
- `lib/data/services/recommendation_service.dart` - Needs update

### Providers
- `lib/presentation/providers/movies_provider.dart` - Needs update
- `lib/presentation/providers/series_provider.dart` - Needs update
- `lib/presentation/providers/search_provider.dart` - Needs update

### Screens
- `lib/presentation/screens/movie_details_screen.dart` - Needs update
- `lib/presentation/screens/series_details_screen.dart` - Needs update
- `lib/presentation/screens/enhanced_series_details_screen.dart` - Needs update
- `lib/presentation/screens/movies_screen.dart` - Needs update
- `lib/presentation/screens/search_screen.dart` - Needs update

### Widgets
- `lib/presentation/widgets/movie_card.dart` - Needs update
- `lib/presentation/widgets/dynamic_movie_card.dart` - Needs update
- `lib/presentation/widgets/series_card.dart` - Needs update
- `lib/presentation/widgets/dynamic_series_card.dart` - Needs update
- `lib/presentation/widgets/content_card.dart` - Needs update

### Models
- `lib/data/models/search_result.dart` - Needs removal or refactoring
- `lib/data/models/search_response.dart` - ✅ Updated
- `lib/data/models/favorite_item.dart` - Needs update

---

## API Endpoint Changes

### Key Changes

**All responses now follow this structure:**
```json
{
  "total": 1234,      // total in database
  "offset": 0,        // pagination offset
  "limit": 50,        // items per page
  "count": 50,        // items in this response
  "data": [...]       // array of items
}
```

**Old multiple response fields (movies/series/results) → Single "data" field**

### Endpoint-Specific Changes

| Endpoint | Old Response | New Response |
|----------|--------------|--------------|
| `/films` | `{data: [...], count, total, limit, offset}` | Same (unchanged) |
| `/series` | `{data: [...], count, total, limit, offset}` | Same (unchanged) |
| `/search` | `{results: [...], ...}` | `{data: [...], filters: {...}, ...}` |
| `/by-genre/{genre}` | `{data: [...]}` | `{data: [...], total, offset, limit, count}` |
| `/autocomplete` | `{suggestions: [...], count}` | `{suggestions: [...], count, query}` |
| `/item/{id}` | Full nested data | Full nested data (same) |
| `/item/{id}/episodes` | `{episodes: [...]}` | `{episodes: [...], series_id, series_title}` |

---

## Step-by-Step Migration Order

### Phase 1: Core Models (✅ DONE)
- [x] Update Movie model
- [x] Update Series model
- [x] Update Episode model
- [x] Update WatchLink model
- [x] Update ApiResponse model
- [x] Update ZenixApiService

### Phase 2: Data Layer (TODO)
- [ ] Update SearchService
- [ ] Update MoviesApiService
- [ ] Update SeriesApiService
- [ ] Update RecommendationService

### Phase 3: Presentation Layer (TODO)
- [ ] Update MoviesProvider
- [ ] Update SeriesProvider
- [ ] Update SearchProvider

### Phase 4: UI Layer (TODO)
- [ ] Update MovieCard & DynamicMovieCard
- [ ] Update SeriesCard & DynamicSeriesCard
- [ ] Update MoviesScreen
- [ ] Update SearchScreen
- [ ] Update Details screens

---

## Testing Checklist

- [ ] All models serialize/deserialize correctly with new API responses
- [ ] Pagination works (hasMore, nextOffset, etc.)
- [ ] Search filters are properly applied
- [ ] Episodes are fetched correctly for series details
- [ ] Watch links are displayed with correct server/quality info
- [ ] Director names are displayed (from array)
- [ ] Rating displays correctly (double vs string)
- [ ] Year displays correctly (string)
- [ ] All screens compile without errors
- [ ] All providers work with new models
- [ ] Integration tests pass

---

## Common Pitfalls to Avoid

1. ❌ Don't use `movie.rating.split('/')` - it's now a `double?`
2. ❌ Don't access `series.totalSeasons` - use `seasonsCount`
3. ❌ Don't expect `series.seasons` to be populated - fetch via API
4. ❌ Don't access `movie.director` as string - use `directors` list
5. ❌ Don't access `response.movies/series/results` - use `response.data`
6. ❌ Don't forget episodes need separate API call
7. ✅ Always check for null on optional fields (rating, quality, etc.)

---

## Quick Reference

### Rating
```dart
// OLD: "8.5/10"
double rating = double.parse(movie.rating.split('/').first);

// NEW: 8.5 (or null)
double? rating = movie.rating;
```

### Director(s)
```dart
// OLD: "Tim Burton" or null
String director = movie.director ?? 'Unknown';

// NEW: ["Tim Burton"]
String directors = movie.directors.join(', ');
```

### Year
```dart
// OLD: 2024 (int)
int year = movie.releaseYear ?? 0;

// NEW: "2024" (string)
int year = int.parse(movie.year);
```

### Episodes
```dart
// OLD: In Series model
series.seasons.first.episodes

// NEW: Via API
final response = await apiService.getEpisodes(seriesId);
final episodes = response?.episodes ?? [];
```

### Pagination
```dart
// OLD: Calculate manually
bool isLastPage = response.count < response.limit;

// NEW: Use helper
bool isLastPage = !response.hasMore;
int nextPage = response.currentPage + 1;
int nextOffset = response.nextOffset;
```

---

## Document History

- **v1.0** - Initial migration guide (2025-01-15)
- Models updated from old API structure to v2.1.0 specification
```
