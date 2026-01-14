/// Modèles pour les séries compactes avec saisons et épisodes détaillés
///
/// Ces modèles sont spécifiquement conçus pour les données compactes des séries
/// et utilisent WatchLinkCompact au lieu de WatchLink pour éviter les conflits
class SeriesCompact {
  final String url;
  final String title;
  final String type;
  final String mainTitle;
  final String originalTitle;
  final List<String> genres;
  final String director;
  final List<String> actors;
  final String synopsis;
  final String rating;
  final String releaseDate;
  final String poster;
  final List<SeasonCompact> seasons;
  final int seasonsCount;
  final int episodesCount;

  SeriesCompact({
    required this.url,
    required this.title,
    required this.type,
    required this.mainTitle,
    this.originalTitle = '',
    required this.genres,
    this.director = '',
    required this.actors,
    this.synopsis = '',
    this.rating = '0.0',
    this.releaseDate = '',
    this.poster = '',
    required this.seasons,
    this.seasonsCount = 0,
    this.episodesCount = 0,
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

// Getters calculés optimisés
  String get id => url;
  String get displayTitle => mainTitle.isNotEmpty ? mainTitle : title;
  double get numericRating => _parseRating(rating);
  String get formattedRating => numericRating.toStringAsFixed(1);
  
  // Getters simplifiés pour éviter les calculs complexes qui ralentissent le chargement
  int get totalSeasons => seasonsCount;
  int get totalEpisodes => episodesCount;
  
String get formattedInfo {
    // Affichage simplifié pour optimiser le chargement
    // Plus de calcul de saisons/épisodes pour éviter les lenteurs
    if (genres.isNotEmpty) {
      return genres.first;
    }
    return 'Série';
  }

  factory SeriesCompact.fromJson(Map<String, dynamic> json) {
    // Handle seasons parsing
    List<SeasonCompact> seasons = [];
    if (json['seasons'] != null && json['seasons'] is List) {
      final seasonsData = json['seasons'] as List<dynamic>;
      if (seasonsData.isNotEmpty) {
        if (seasonsData.first is Map) {
          seasons = seasonsData
              .map((season) => SeasonCompact.fromJson(season as Map<String, dynamic>))
              .toList();
        }
        // If they are Strings (URLs), we can't easily create SeasonCompact here 
        // because SeasonCompact requires a list of episodes.
        // We'll rely on seasonsCount/episodesCount.
      }
    }

    return SeriesCompact(
      url: json['url'] ?? '',
      title: json['title'] ?? '',
      type: json['type'] ?? 'series',
      mainTitle: json['main_title'] ?? json['title'] ?? '',
      originalTitle: json['original_title'] ?? '',
      genres: List<String>.from(json['genres'] ?? []).where((g) => g.isNotEmpty).toList(),
      director: json['director'] ?? '',
      actors: List<String>.from(json['actors'] ?? []),
      synopsis: json['synopsis'] ?? '',
      rating: json['rating']?.toString() ?? '0.0',
      releaseDate: json['release_date'] ?? '',
      poster: json['poster'] ?? '',
      seasons: seasons,
      seasonsCount: _toInt(json['seasons_count']) ?? seasons.length,
      episodesCount: _toInt(json['episodes_count']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'type': type,
      'main_title': mainTitle,
      'original_title': originalTitle,
      'genres': genres,
      'director': director,
      'actors': actors,
      'synopsis': synopsis,
      'rating': rating,
      'release_date': releaseDate,
      'poster': poster,
      'seasons': seasons.map((s) => s.toJson()).toList(),
      'seasons_count': seasonsCount,
      'episodes_count': episodesCount,
    };
  }

  static double _parseRating(String rating) {
    if (rating.contains('/')) {
      final parts = rating.split('/');
      if (parts.isNotEmpty) {
        return double.tryParse(parts[0]) ?? 0.0;
      }
    }
    return double.tryParse(rating) ?? 0.0;
  }
}

/// Modèle pour une saison compacte
class SeasonCompact {
  final String url;
  final String title;
  final int seasonNumber;
  final List<EpisodeCompact> episodes;

  SeasonCompact({
    required this.url,
    required this.title,
    required this.seasonNumber,
    required this.episodes,
  });

  String get displayTitle => title.isNotEmpty ? title : 'Saison $seasonNumber';
  int get episodeCount => episodes.length;
  bool get hasEpisodes => episodes.isNotEmpty;
  
  String get formattedInfo {
    if (episodeCount == 0) return 'Aucun épisode disponible';
    return '$episodeCount épisode${episodeCount > 1 ? 's' : ''}';
  }

  factory SeasonCompact.fromJson(Map<String, dynamic> json) {
    return SeasonCompact(
      url: json['url'] ?? '',
      title: json['title'] ?? '',
      seasonNumber: json['season_number'] ?? 0,
      episodes: (json['episodes'] as List<dynamic>?)
          ?.map((episode) => EpisodeCompact.fromJson(episode as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'season_number': seasonNumber,
      'episodes': episodes.map((e) => e.toJson()).toList(),
    };
  }
}

/// Modèle pour un épisode compact
class EpisodeCompact {
  final String url;
  final int episodeNumber;
  final String title;
  final String synopsis;
  final List<WatchLinkCompact> watchLinks;

  EpisodeCompact({
    required this.url,
    required this.episodeNumber,
    this.title = '',
    this.synopsis = '',
    required this.watchLinks,
  });

  String get displayTitle => title.isNotEmpty ? title : 'Épisode $episodeNumber';
  bool get hasWatchLinks => watchLinks.isNotEmpty;
  int get serverCount => watchLinks.length;
  
  String get formattedInfo {
    if (serverCount == 0) return 'Aucun serveur disponible';
    return '$serverCount serveur${serverCount > 1 ? 's' : ''} disponible${serverCount > 1 ? 's' : ''}';
  }

  factory EpisodeCompact.fromJson(Map<String, dynamic> json) {
    return EpisodeCompact(
      url: json['url'] ?? '',
      episodeNumber: json['episode_number'] ?? 0,
      title: json['title'] ?? '',
      synopsis: json['synopsis'] ?? '',
      watchLinks: (json['watch_links'] as List<dynamic>? ?? [])
          .map((link) => WatchLinkCompact.fromJson(link as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'episode_number': episodeNumber,
      'title': title,
      'synopsis': synopsis,
      'watch_links': watchLinks.map((link) => link.toJson()).toList(),
    };
  }
}

/// Modèle pour un lien de visionnage compact
class WatchLinkCompact {
  final String url;
  final String server;
  final String type;

  WatchLinkCompact({
    required this.url,
    required this.server,
    required this.type,
  });

  String get displayServer => server.isNotEmpty ? server : 'Serveur inconnu';
  bool get isStreamLink => type == 'stream';

  factory WatchLinkCompact.fromJson(Map<String, dynamic> json) {
    return WatchLinkCompact(
      url: json['url'] ?? '',
      server: json['server'] ?? '',
      type: json['type'] ?? 'stream',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'server': server,
      'type': type,
    };
  }
}

/// Réponse de l'API pour les séries compactes avec pagination
class SeriesCompactResponse {
  final List<SeriesCompact> series;
  final int count;
  final int total;
  final int limit;
  final int offset;

  SeriesCompactResponse({
    required this.series,
    this.count = 0,
    this.total = 0,
    this.limit = 50,
    this.offset = 0,
  });

  bool get hasMore => offset + count < total;
  int get nextOffset => offset + limit;
  int get currentPage => (offset / limit).floor() + 1;
  int get totalPages => (total / limit).ceil();

  factory SeriesCompactResponse.fromJson(Map<String, dynamic> json) {
    return SeriesCompactResponse(
      series: (json['series'] as List<dynamic>?)
          ?.map((series) => SeriesCompact.fromJson(series as Map<String, dynamic>))
          .toList() ?? [],
      count: json['count'] ?? 0,
      total: json['total'] ?? 0,
      limit: json['limit'] ?? 50,
      offset: json['offset'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'series': series.map((s) => s.toJson()).toList(),
      'count': count,
      'total': total,
      'limit': limit,
      'offset': offset,
    };
  }
}