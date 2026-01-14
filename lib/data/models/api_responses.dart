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
    final data = items.cast<Map<String, dynamic>>().map(fromJsonT).toList();

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

  bool get hasMore => offset + count < total;
  int get nextOffset => offset + limit;
  int get currentPage => (offset / limit).floor() + 1;
  int get totalPages => (total / limit).ceil();
}

class SearchResponse {
  final String query;
  final Map<String, dynamic>? filters;
  final List<dynamic> data;
  final int total;
  final int offset;
  final int limit;
  final int count;

  SearchResponse({
    required this.query,
    this.filters,
    required this.data,
    required this.total,
    required this.offset,
    required this.limit,
    required this.count,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    final items = json['data'] as List<dynamic>? ?? [];

    return SearchResponse(
      query: json['query'] ?? '',
      filters: json['filters'] as Map<String, dynamic>?,
      data: items,
      total: json['total'] ?? 0,
      offset: json['offset'] ?? 0,
      limit: json['limit'] ?? 50,
      count: json['count'] ?? items.length,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'filters': filters,
      'data': data,
      'total': total,
      'offset': offset,
      'limit': limit,
      'count': count,
    };
  }
}

class GenresResponse {
  final int total;
  final List<GenreItem> data;

  GenresResponse({
    required this.total,
    required this.data,
  });

  factory GenresResponse.fromJson(Map<String, dynamic> json) {
    final items = json['data'] as List<dynamic>? ?? [];

    return GenresResponse(
      total: json['total'] ?? 0,
      data: items
          .cast<Map<String, dynamic>>()
          .map((item) => GenreItem.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'data': data.map((item) => item.toJson()).toList(),
    };
  }
}

class GenreItem {
  final String name;
  final int count;

  GenreItem({
    required this.name,
    required this.count,
  });

  factory GenreItem.fromJson(Map<String, dynamic> json) {
    return GenreItem(
      name: json['name'] ?? '',
      count: json['count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'count': count,
    };
  }
}

class ActorsResponse {
  final int total;
  final List<ActorItem> data;

  ActorsResponse({
    required this.total,
    required this.data,
  });

  factory ActorsResponse.fromJson(Map<String, dynamic> json) {
    final items = json['data'] as List<dynamic>? ?? [];

    return ActorsResponse(
      total: json['total'] ?? 0,
      data: items
          .cast<Map<String, dynamic>>()
          .map((item) => ActorItem.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'data': data.map((item) => item.toJson()).toList(),
    };
  }
}

class ActorItem {
  final String name;
  final int count;

  ActorItem({
    required this.name,
    required this.count,
  });

  factory ActorItem.fromJson(Map<String, dynamic> json) {
    return ActorItem(
      name: json['name'] ?? '',
      count: json['count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'count': count,
    };
  }
}

class AutocompleteResponse {
  final String query;
  final int count;
  final List<AutocompleteSuggestion> suggestions;

  AutocompleteResponse({
    required this.query,
    required this.count,
    required this.suggestions,
  });

  factory AutocompleteResponse.fromJson(Map<String, dynamic> json) {
    final items = json['suggestions'] as List<dynamic>? ?? [];

    return AutocompleteResponse(
      query: json['query'] ?? '',
      count: json['count'] ?? 0,
      suggestions: items
          .cast<Map<String, dynamic>>()
          .map((item) => AutocompleteSuggestion.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'count': count,
      'suggestions': suggestions.map((s) => s.toJson()).toList(),
    };
  }
}

class AutocompleteSuggestion {
  final String id;
  final String title;
  final String? originalTitle;
  final String type;
  final String? year;
  final String? poster;

  AutocompleteSuggestion({
    required this.id,
    required this.title,
    this.originalTitle,
    required this.type,
    this.year,
    this.poster,
  });

  factory AutocompleteSuggestion.fromJson(Map<String, dynamic> json) {
    return AutocompleteSuggestion(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      originalTitle: json['original_title'],
      type: json['type'] ?? 'film',
      year: json['year'],
      poster: json['poster'],
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
    };
  }
}

class HealthResponse {
  final String status;
  final String timestamp;
  final UptimeData? uptimeData;
  final bool isScraping;
  final ApiStats? apiStats;

  HealthResponse({
    required this.status,
    required this.timestamp,
    this.uptimeData,
    required this.isScraping,
    this.apiStats,
  });

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(
      status: json['status'] ?? 'unknown',
      timestamp: json['timestamp'] ?? '',
      uptimeData: json['uptime_data'] != null
          ? UptimeData.fromJson(json['uptime_data'] as Map<String, dynamic>)
          : null,
      isScraping: json['is_scraping'] ?? false,
      apiStats: json['api_stats'] != null
          ? ApiStats.fromJson(json['api_stats'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'timestamp': timestamp,
      'uptime_data': uptimeData?.toJson(),
      'is_scraping': isScraping,
      'api_stats': apiStats?.toJson(),
    };
  }
}

class UptimeData {
  final int films;
  final int series;
  final String? lastUpdate;

  UptimeData({
    required this.films,
    required this.series,
    this.lastUpdate,
  });

  factory UptimeData.fromJson(Map<String, dynamic> json) {
    return UptimeData(
      films: json['films'] ?? 0,
      series: json['series'] ?? 0,
      lastUpdate: json['last_update'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'films': films,
      'series': series,
      'last_update': lastUpdate,
    };
  }
}

class ApiStats {
  final int requestsTotal;
  final double avgResponseTimeMs;
  final int errorsTotal;

  ApiStats({
    required this.requestsTotal,
    required this.avgResponseTimeMs,
    required this.errorsTotal,
  });

  factory ApiStats.fromJson(Map<String, dynamic> json) {
    return ApiStats(
      requestsTotal: json['requests_total'] ?? 0,
      avgResponseTimeMs:
          (json['avg_response_time_ms'] as num?)?.toDouble() ?? 0.0,
      errorsTotal: json['errors_total'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requests_total': requestsTotal,
      'avg_response_time_ms': avgResponseTimeMs,
      'errors_total': errorsTotal,
    };
  }
}

// ============================================================================
// ANNÉES
// ============================================================================

class YearItem {
  final String year;
  final int count;

  YearItem({
    required this.year,
    required this.count,
  });

  factory YearItem.fromJson(Map<String, dynamic> json) {
    return YearItem(
      year: json['year']?.toString() ?? '',
      count: json['count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'count': count,
    };
  }
}

class YearsResponse {
  final int total;
  final List<YearItem> data;

  YearsResponse({
    required this.total,
    required this.data,
  });

  factory YearsResponse.fromJson(Map<String, dynamic> json) {
    final items = json['data'] as List<dynamic>? ?? [];

    return YearsResponse(
      total: json['total'] ?? 0,
      data: items
          .cast<Map<String, dynamic>>()
          .map((item) => YearItem.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'data': data.map((item) => item.toJson()).toList(),
    };
  }
}

// ============================================================================
// QUALITÉS
// ============================================================================

class QualityItem {
  final String quality;
  final int count;

  QualityItem({
    required this.quality,
    required this.count,
  });

  factory QualityItem.fromJson(Map<String, dynamic> json) {
    return QualityItem(
      quality: json['quality'] ?? '',
      count: json['count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quality': quality,
      'count': count,
    };
  }
}

class QualitiesResponse {
  final int total;
  final List<QualityItem> data;

  QualitiesResponse({
    required this.total,
    required this.data,
  });

  factory QualitiesResponse.fromJson(Map<String, dynamic> json) {
    final items = json['data'] as List<dynamic>? ?? [];

    return QualitiesResponse(
      total: json['total'] ?? 0,
      data: items
          .cast<Map<String, dynamic>>()
          .map((item) => QualityItem.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'data': data.map((item) => item.toJson()).toList(),
    };
  }
}

// ============================================================================
// RÉALISATEURS
// ============================================================================

class DirectorItem {
  final String name;
  final int count;

  DirectorItem({
    required this.name,
    required this.count,
  });

  factory DirectorItem.fromJson(Map<String, dynamic> json) {
    return DirectorItem(
      name: json['name'] ?? '',
      count: json['count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'count': count,
    };
  }
}

class DirectorsResponse {
  final int total;
  final List<DirectorItem> data;

  DirectorsResponse({
    required this.total,
    required this.data,
  });

  factory DirectorsResponse.fromJson(Map<String, dynamic> json) {
    final items = json['data'] as List<dynamic>? ?? [];

    return DirectorsResponse(
      total: json['total'] ?? 0,
      data: items
          .cast<Map<String, dynamic>>()
          .map((item) => DirectorItem.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'data': data.map((item) => item.toJson()).toList(),
    };
  }
}

// ============================================================================
// RÉPONSES DE CONTENU (BROWSE)
// ============================================================================

class ContentListResponse {
  final List<dynamic> data;
  final int total;
  final int offset;
  final int limit;
  final int count;

  ContentListResponse({
    required this.data,
    required this.total,
    required this.offset,
    required this.limit,
    required this.count,
  });

  factory ContentListResponse.fromJson(
    Map<String, dynamic> json,
    dynamic Function(Map<String, dynamic>)? parser,
  ) {
    final items = json['data'] as List<dynamic>? ?? [];
    final data = parser != null
        ? items
            .cast<Map<String, dynamic>>()
            .map((item) => parser(item))
            .toList()
        : items;

    return ContentListResponse(
      data: data,
      total: json['total'] ?? 0,
      offset: json['offset'] ?? 0,
      limit: json['limit'] ?? 50,
      count: json['count'] ?? items.length,
    );
  }

  Map<String, dynamic> toJson(
    Map<String, dynamic> Function(dynamic)? serializer,
  ) {
    return {
      'data': serializer != null ? data.map(serializer).toList() : data,
      'total': total,
      'offset': offset,
      'limit': limit,
      'count': count,
    };
  }

  bool get hasMore => offset + count < total;
  int get nextOffset => offset + limit;
}

// ============================================================================
// RECHERCHE MULTI-CATÉGORIES
// ============================================================================

class MultiSearchResultCategory {
  final int count;
  final List<dynamic> data;

  MultiSearchResultCategory({
    required this.count,
    required this.data,
  });

  factory MultiSearchResultCategory.fromJson(Map<String, dynamic> json) {
    return MultiSearchResultCategory(
      count: json['count'] ?? 0,
      data: json['data'] as List<dynamic>? ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'data': data,
    };
  }
}

class MultiSearchResponse {
  final String query;
  final Map<String, MultiSearchResultCategory> results;

  MultiSearchResponse({
    required this.query,
    required this.results,
  });

  factory MultiSearchResponse.fromJson(Map<String, dynamic> json) {
    final resultsMap = json['results'] as Map<String, dynamic>? ?? {};
    final results = <String, MultiSearchResultCategory>{};

    resultsMap.forEach((key, value) {
      results[key] = MultiSearchResultCategory.fromJson(value);
    });

    return MultiSearchResponse(
      query: json['query'] ?? '',
      results: results,
    );
  }

  Map<String, dynamic> toJson() {
    final resultsMap = <String, dynamic>{};
    results.forEach((key, value) {
      resultsMap[key] = value.toJson();
    });

    return {
      'query': query,
      'results': resultsMap,
    };
  }
}

// ============================================================================
// ITEMS ALÉATOIRES
// ============================================================================

class RandomResponse {
  final String? typeFilter;
  final String? genreFilter;
  final int count;
  final List<dynamic> data;

  RandomResponse({
    this.typeFilter,
    this.genreFilter,
    required this.count,
    required this.data,
  });

  factory RandomResponse.fromJson(Map<String, dynamic> json) {
    final items = json['data'] as List<dynamic>? ?? [];

    return RandomResponse(
      typeFilter: json['type_filter'],
      genreFilter: json['genre_filter'],
      count: json['count'] ?? items.length,
      data: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type_filter': typeFilter,
      'genre_filter': genreFilter,
      'count': count,
      'data': data,
    };
  }
}

// ============================================================================
// RÉPONSES DÉTAILS
// ============================================================================

class ItemDetailsResponse {
  final String id;
  final String title;
  final String? originalTitle;
  final String type;
  final String year;
  final List<String> genres;
  final List<String> directors;
  final List<String> actors;
  final String? synopsis;
  final String? description;
  final String? poster;
  final double? rating;
  final int? ratingMax;
  final String? quality;
  final String? version;
  final String? language;
  final int? duration;
  final String url;
  final List<dynamic> watchLinks;
  final List<dynamic>? seasons;
  final int? seasonsCount;
  final int? episodesCount;
  final List<dynamic>? episodes;

  ItemDetailsResponse({
    required this.id,
    required this.title,
    this.originalTitle,
    required this.type,
    required this.year,
    required this.genres,
    required this.directors,
    required this.actors,
    this.synopsis,
    this.description,
    this.poster,
    this.rating,
    this.ratingMax,
    this.quality,
    this.version,
    this.language,
    this.duration,
    required this.url,
    required this.watchLinks,
    this.seasons,
    this.seasonsCount,
    this.episodesCount,
    this.episodes,
  });

  factory ItemDetailsResponse.fromJson(Map<String, dynamic> json) {
    return ItemDetailsResponse(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      originalTitle: json['original_title'],
      type: json['type'] ?? 'film',
      year: json['year']?.toString() ?? '',
      genres: List<String>.from(json['genres'] ?? []),
      directors: List<String>.from(json['directors'] ?? []),
      actors: List<String>.from(json['actors'] ?? []),
      synopsis: json['synopsis'],
      description: json['description'],
      poster: json['poster'],
      rating: (json['rating'] as num?)?.toDouble(),
      ratingMax: json['rating_max'],
      quality: json['quality'],
      version: json['version'],
      language: json['language'],
      duration: json['duration'],
      url: json['url'] ?? '',
      watchLinks: json['watch_links'] ?? [],
      seasons: json['seasons'] as List<dynamic>?,
      seasonsCount: json['seasons_count'],
      episodesCount: json['episodes_count'],
      episodes: json['episodes'] as List<dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'original_title': originalTitle,
      'type': type,
      'year': year,
      'genres': genres,
      'directors': directors,
      'actors': actors,
      'synopsis': synopsis,
      'description': description,
      'poster': poster,
      'rating': rating,
      'rating_max': ratingMax,
      'quality': quality,
      'version': version,
      'language': language,
      'duration': duration,
      'url': url,
      'watch_links': watchLinks,
      'seasons': seasons,
      'seasons_count': seasonsCount,
      'episodes_count': episodesCount,
      'episodes': episodes,
    };
  }

  bool get isSeries => type == 'serie';
  bool get isMovie => type == 'film';
}

// ============================================================================
// RÉPONSES ÉPISODES
// ============================================================================

class EpisodesResponse {
  final String seriesId;
  final String seriesTitle;
  final int? seasonFilter;
  final int totalEpisodes;
  final List<EpisodeDetail> episodes;

  EpisodesResponse({
    required this.seriesId,
    required this.seriesTitle,
    this.seasonFilter,
    required this.totalEpisodes,
    required this.episodes,
  });

  factory EpisodesResponse.fromJson(Map<String, dynamic> json) {
    final episodesData = json['episodes'] as List<dynamic>? ?? [];
    final episodes = episodesData
        .cast<Map<String, dynamic>>()
        .map((ep) => EpisodeDetail.fromJson(ep))
        .toList();

    return EpisodesResponse(
      seriesId: json['series_id'] ?? '',
      seriesTitle: json['series_title'] ?? '',
      seasonFilter: json['season_filter'],
      totalEpisodes: json['total_episodes'] ?? episodes.length,
      episodes: episodes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'series_id': seriesId,
      'series_title': seriesTitle,
      'season_filter': seasonFilter,
      'total_episodes': totalEpisodes,
      'episodes': episodes.map((ep) => ep.toJson()).toList(),
    };
  }
}

class EpisodeDetail {
  final String url;
  final int season;
  final int episode;
  final String title;
  final String? synopsis;
  final String? quality;
  final List<dynamic> watchLinks;

  EpisodeDetail({
    required this.url,
    required this.season,
    required this.episode,
    required this.title,
    this.synopsis,
    this.quality,
    required this.watchLinks,
  });

  factory EpisodeDetail.fromJson(Map<String, dynamic> json) {
    return EpisodeDetail(
      url: json['url'] ?? '',
      season: json['season'] ?? 1,
      episode: json['episode'] ?? 0,
      title: json['title'] ?? '',
      synopsis: json['synopsis'],
      quality: json['quality'],
      watchLinks: json['watch_links'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'season': season,
      'episode': episode,
      'title': title,
      'synopsis': synopsis,
      'quality': quality,
      'watch_links': watchLinks,
    };
  }
}

// ============================================================================
// RÉPONSES LIENS DE STREAMING
// ============================================================================

class WatchLinksResponse {
  final String id;
  final String title;
  final String type; // 'film' ou 'episode'
  final List<dynamic> watchLinks;
  final String? seriesTitle;
  final int? season;
  final int? episode;

  WatchLinksResponse({
    required this.id,
    required this.title,
    required this.type,
    required this.watchLinks,
    this.seriesTitle,
    this.season,
    this.episode,
  });

  factory WatchLinksResponse.fromJson(Map<String, dynamic> json) {
    return WatchLinksResponse(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      type: json['type'] ?? 'film',
      watchLinks: json['watch_links'] ?? [],
      seriesTitle: json['series_title'],
      season: json['season'],
      episode: json['episode'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'watch_links': watchLinks,
      'series_title': seriesTitle,
      'season': season,
      'episode': episode,
    };
  }

  bool get isEpisode => type == 'episode';
  bool get isFilm => type == 'film';
}
