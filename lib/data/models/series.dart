class Series {
  final String id;
  final String title;
  final String? originalTitle;
  final String type; // "serie"
  final String year; // String, not int
  final String? poster;
  final String? url;
  final List<String> genres;
  final double? rating; // Can be null
  final double? ratingMax; // From /item endpoint
  final String? quality;
  final String? version;
  final List<String> actors;
  final List<String> directors;
  final String? synopsis;
  final String? description; // From /item endpoint
  final int? watchLinksCount; // From /series endpoint (count only)
  final int seasonsCount; // NOT totalSeasons
  final int episodesCount; // NOT totalEpisodes
  final List<Season>? seasons;
  final String? language;
  final String? status;
  final List<WatchLink>? watchLinks; // From /item endpoint (full objects)
  final int? duration; // From /item endpoint
  final String? releaseDateString; // Additional field from /item endpoint

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
    this.ratingMax,
    this.quality,
    this.version,
    required this.actors,
    required this.directors,
    this.synopsis,
    this.description,
    this.watchLinksCount,
    required this.seasonsCount,
    required this.episodesCount,
    this.seasons,
    this.language,
    this.status,
    this.watchLinks,
    this.duration,
    this.releaseDateString,
  });

  /// Convertit une valeur en entier, retourne null si la conversion échoue
  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      try {
        return int.tryParse(value);
      } catch (e) {
        return null;
      }
    }
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return null;
  }

factory Series.fromJson(Map<String, dynamic> json) {
    // Handle seasons parsing - API returns seasons as array of URLs or detailed objects
    List<Season>? seasons;
    
    // Priorité au nouveau format episodes_by_season
    if (json['episodes_by_season'] != null) {
      final episodesBySeasonJson = json['episodes_by_season'] as Map<String, dynamic>;
      seasons = episodesBySeasonJson.entries
          .map((entry) {
            final seasonNumber = int.tryParse(entry.key) ?? 0;
            final episodesData = entry.value as List<dynamic>;
            final episodes = episodesData
                .map((e) => Episode.fromJson(e as Map<String, dynamic>))
                .toList();
            return Season(seasonNumber: seasonNumber, episodes: episodes);
          })
          .toList()
        ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
    }
    // Fallback à l'ancien format avec seasons comme URLs
    else if (json['seasons'] != null) {
      final seasonsData = json['seasons'] as List<dynamic>;
      if (seasonsData.isNotEmpty) {
        // Check if seasons are URLs (strings) or objects
        if (seasonsData.first is String) {
          // API returns seasons as URLs - we need to organize episodes by season
          final episodes = (json['episodes'] as List<dynamic>? ?? [])
              .map((e) => Episode.fromJson(e as Map<String, dynamic>))
              .toList();

          // Group episodes by season number
          final Map<int, List<Episode>> episodesBySeason = {};
          for (final episode in episodes) {
            final seasonNum = episode.season ?? 1;
            episodesBySeason.putIfAbsent(seasonNum, () => []).add(episode);
          }

          // Create Season objects
          seasons = episodesBySeason.entries
              .map((entry) => Season(
                    seasonNumber: entry.key,
                    episodes: entry.value,
                  ))
              .toList()
            ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
        } else {
          // Standard parsing for seasons as objects
          seasons = seasonsData
              .map((s) => Season.fromJson(s as Map<String, dynamic>))
              .toList();
        }
      }
    }

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
      ratingMax: (json['rating_max'] as num?)?.toDouble(),
      quality: json['quality'],
      version: json['version'],
      actors: List<String>.from(json['actors'] ?? []),
      directors: List<String>.from(json['directors'] ?? []),
      synopsis: json['synopsis'],
      description: json['description'],
      watchLinksCount: json['watch_links_count'],
      seasonsCount: _toInt(json['seasons_count']) ?? 
          seasons?.length ?? 
          _toInt(json['total_seasons']) ?? 
          (json['seasons'] is List ? (json['seasons'] as List).length : 0),
      episodesCount: _toInt(json['episodes_count']) ?? 
          _toInt(json['total_episodes']) ?? 
          (seasons?.fold<int>(0, (sum, s) => sum + s.episodes.length) ?? 0),
      seasons: seasons,
      language: json['language'],
      status: json['status'],
      watchLinks: (json['watch_links'] as List<dynamic>? ?? [])
              .map((link) => WatchLink.fromJson(link as Map<String, dynamic>))
              .toList()
              .isEmpty
          ? null
          : (json['watch_links'] as List<dynamic>)
              .map((link) => WatchLink.fromJson(link as Map<String, dynamic>))
              .toList(),
      duration: json['duration'],
      releaseDateString: json['release_date'],
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
      'rating_max': ratingMax,
      'quality': quality,
      'version': version,
      'actors': actors,
      'directors': directors,
      'synopsis': synopsis,
      'description': description,
      'watch_links_count': watchLinksCount,
      'seasons_count': seasonsCount,
      'episodes_count': episodesCount,
      'seasons': seasons?.map((s) => s.toJson()).toList(),
      'language': language,
      'status': status,
      'watch_links': watchLinks?.map((w) => w.toJson()).toList(),
      'duration': duration,
      'release_date': releaseDateString,
    };
  }

  // Computed properties for compatibility
  int get releaseYear {
    try {
      return int.parse(year);
    } catch (e) {
      return 0;
    }
  }

  /// Check if this is from grid endpoint (has watchLinksCount but no watchLinks)
  bool get isGridData {
    return watchLinksCount != null &&
        (watchLinks == null || watchLinks!.isEmpty);
  }

  /// Check if this is from details endpoint (has watchLinks)
  bool get isDetailData {
    return watchLinks != null && watchLinks!.isNotEmpty;
  }

  double get numericRating => rating ?? 0.0;

  List<String> get cleanGenres {
    return genres.map((g) => g.trim()).where((g) => g.isNotEmpty).toList();
  }

  String get director => directors.isNotEmpty ? directors.first : '';

  bool get hasValidPoster => poster != null && poster!.isNotEmpty;

  String get displayTitle =>
      originalTitle?.isNotEmpty == true ? '$title ($originalTitle)' : title;

  int get totalSeasons => seasons?.length ?? seasonsCount;

  int get totalEpisodes => episodesCount;

  int get actualTotalSeasons => seasons?.length ?? seasonsCount;

  int get actualTotalEpisodes {
    if (seasons == null) return episodesCount;
    int total = 0;
    for (var season in seasons!) {
      total += season.episodes.length;
    }
    return total;
  }

  bool get isOngoing =>
      status?.toLowerCase() == 'ongoing' || status?.toLowerCase() == 'airing';

  bool get isCompleted =>
      status?.toLowerCase() == 'completed' ||
      status?.toLowerCase() == 'finished';

  String get releaseDate => year;

  Season? getSeason(int seasonNumber) {
    if (seasons == null) return null;
    try {
      return seasons!.firstWhere((s) => s.seasonNumber == seasonNumber);
    } catch (e) {
      return null;
    }
  }

  String get formattedInfo {
    final totalSeasons = this.totalSeasons;
    final totalEpisodes = this.totalEpisodes;

    // Si la série a des liens de streaming, elle est disponible
    if (watchLinks != null && watchLinks!.isNotEmpty) {
      if (totalSeasons == 0 && totalEpisodes == 0) {
        return 'Disponible en streaming';
      }
      return '$totalSeasons saison${totalSeasons > 1 ? 's' : ''} • $totalEpisodes épisodes';
    }

    if (totalSeasons == 0 && totalEpisodes == 0) {
      // Vérifier si c'est une série récente (moins de 2 ans)
      final currentYear = DateTime.now().year;
      final seriesYear = releaseYear;

      if (seriesYear >= currentYear - 1) {
        return 'Données en cours de récupération';
      } else {
        return 'Épisodes non disponibles';
      }
    }

    return '$totalSeasons saison${totalSeasons > 1 ? 's' : ''} • $totalEpisodes épisodes';
  }

  /// Vérifie si la série a des données complètes
  bool get hasCompleteData => seasonsCount > 0 || episodesCount > 0;

  /// Vérifie si c'est une série récente
  bool get isRecentSeries {
    final currentYear = DateTime.now().year;
    return releaseYear >= currentYear - 1;
  }

  /// Message d'état pour les séries sans données
  String get dataStatusMessage {
    if (hasCompleteData) return '';

    if (isRecentSeries) {
      return 'Cette série est récente. Les données d\'épisodes sont en cours de récupération.';
    } else {
      return 'Les données de cette série ne sont pas encore disponibles.';
    }
  }

  @override
  String toString() {
    return 'Series(id: $id, title: $title, year: $year, seasons: $seasonsCount, episodes: $episodesCount)';
  }
}

class Season {
  final int seasonNumber;
  final List<Episode> episodes;

  Season({
    required this.seasonNumber,
    required this.episodes,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      seasonNumber: json['season_number'] ?? json['number'] ?? 0,
      episodes: (json['episodes'] ?? json['items'] ?? [])
          .map<Episode>((e) => Episode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'season_number': seasonNumber,
      'episodes': episodes.map((e) => e.toJson()).toList(),
    };
  }

  Episode? getEpisode(int episodeNumber) {
    try {
      return episodes.firstWhere((e) => e.episodeNumber == episodeNumber);
    } catch (e) {
      return null;
    }
  }
}

class Episode {
  final int episodeNumber;
  final String title;
  final String? airDate;
  final String? synopsis;
  final String? url;
  final int? season;
  final int? episode;
  final String? quality;
  final List<WatchLink>? watchLinks;

  Episode({
    required this.episodeNumber,
    required this.title,
    this.airDate,
    this.synopsis,
    this.url,
    this.season,
    this.episode,
    this.quality,
    this.watchLinks,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    // Try to get episode number from multiple fields
    final episode = json['episode'] ?? json['episode_number'] ?? json['number'] ?? 0;
    final season = json['season'] ?? 0;
    
    return Episode(
      episodeNumber: episode is int ? episode : int.tryParse(episode.toString()) ?? 0,
      title: json['title'] ?? '',
      airDate: json['air_date'],
      synopsis: json['synopsis'],
      url: json['url'],
      season: season is int ? season : int.tryParse(season.toString()) ?? 0,
      episode: episode is int ? episode : int.tryParse(episode.toString()) ?? 0,
      quality: json['quality'],
      watchLinks: (json['watch_links'] as List<dynamic>? ?? [])
          .map((link) => WatchLink.fromJson(link as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'episode_number': episodeNumber,
      'title': title,
      'air_date': airDate,
      'synopsis': synopsis,
      'url': url,
      'season': season,
      'episode': episode,
      'quality': quality,
      'watch_links': watchLinks?.map((w) => w.toJson()).toList(),
    };
  }

  String get displayTitle =>
      'S${season?.toString().padLeft(2, '0')}E${episode?.toString().padLeft(2, '0')} - $title';
}

class SeriesResponse {
  final List<Series> series;

  SeriesResponse({required this.series});

  factory SeriesResponse.fromJson(Map<String, dynamic> json) {
    return SeriesResponse(
      series: (json['series'] as List<dynamic>?)
              ?.map((serie) => Series.fromJson(serie as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'series': series.map((s) => s.toJson()).toList(),
    };
  }
}

class WatchLink {
  final String server;
  final String url;
  final String? quality;
  final String? type;

  WatchLink({
    required this.server,
    required this.url,
    this.quality,
    this.type,
  });

  factory WatchLink.fromJson(Map<String, dynamic> json) {
    return WatchLink(
      server: json['server'] ?? '',
      url: json['url'] ?? '',
      quality: json['quality'],
      type: json['type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'server': server,
      'url': url,
      'quality': quality,
      'type': type,
    };
  }
}
