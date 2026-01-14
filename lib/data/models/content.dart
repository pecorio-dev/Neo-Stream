import 'movie.dart';

/// Classe abstraite pour le contenu (films et séries)
abstract class Content {
  String get id;
  String get title;
  String get overview;
  String get posterPath;
  String get backdropPath;
  double get voteAverage;
  List<String> get genres;
  String get url;
  bool get isMovie;
  List<WatchLink> get watchLinks;
  
  // Getters calculés
  String get displayTitle => title;
  String get formattedRating => voteAverage.toStringAsFixed(1);
  double get numericRating => voteAverage;
  String get fullPosterUrl => posterPath.isNotEmpty ? posterPath : '';
  String get fullBackdropUrl => backdropPath.isNotEmpty ? backdropPath : '';
}

// Movie class is now defined in lib/data/models/movie.dart to avoid conflicts

/// Modèle pour les séries (correspond à l'API /series et /seriescompact)
class Series extends Content {
  @override
  final String id;
  
  final String mainTitle;
  
  @override
  final String title;
  
  final String originalTitle;
  
  @override
  final String url;
  
  @override
  final String overview;
  
  final String poster;
  
  final String backdrop;
  
  @override
  final List<String> genres;
  
  final String director;
  
  final List<String> actors;
  
  @override
  final double voteAverage;
  
  final List<Season> seasons;
  
  final String status;

  Series({
    required this.id,
    required this.mainTitle,
    required this.title,
    required this.originalTitle,
    required this.url,
    required this.overview,
    required this.poster,
    this.backdrop = '',
    required this.genres,
    this.director = '',
    required this.actors,
    required this.voteAverage,
    required this.seasons,
    this.status = '',
  });

  @override
  String get posterPath => poster;
  
  @override
  String get backdropPath => backdrop;
  
  @override
  bool get isMovie => false;
  
  @override
  List<WatchLink> get watchLinks => []; // Les séries n'ont pas de watchLinks directement
  
  @override
  String get displayTitle => mainTitle.isNotEmpty ? mainTitle : title;
  
  String get originalName => originalTitle;
  String get firstAirDate => '';
  
  int get numberOfSeasons => seasons.length;
  int get numberOfEpisodes => seasons.fold(0, (sum, season) => sum + season.episodesCount);
  
  String get formattedSeasons {
    final seasonCount = numberOfSeasons;
    final episodeCount = numberOfEpisodes;
    return '$seasonCount saison${seasonCount > 1 ? 's' : ''} • $episodeCount épisodes';
  }

  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      id: json['id'] ?? '',
      mainTitle: json['maintitle'] ?? json['title'] ?? '',
      title: json['title'] ?? '',
      originalTitle: json['originaltitle'] ?? json['original_title'] ?? json['title'] ?? '',
      url: json['url'] ?? '',
      overview: json['synopsis'] ?? json['overview'] ?? '',
      poster: json['poster'] ?? '',
      backdrop: json['backdrop'] ?? '',
      genres: List<String>.from(json['genres'] ?? []),
      director: json['director'] ?? '',
      actors: List<String>.from(json['actors'] ?? []),
      voteAverage: _parseRating(json['rating']),
      seasons: _parseSeasons(json['seasons']),
      status: json['status'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'maintitle': mainTitle,
      'title': title,
      'originaltitle': originalTitle,
      'url': url,
      'synopsis': overview,
      'poster': poster,
      'backdrop': backdrop,
      'genres': genres,
      'director': director,
      'actors': actors,
      'rating': voteAverage.toString(),
      'seasons': seasons.map((s) => s.toJson()).toList(),
      'status': status,
    };
  }

  static double _parseRating(dynamic rating) {
    if (rating is String) {
      return double.tryParse(rating) ?? 0.0;
    }
    if (rating is num) {
      return rating.toDouble();
    }
    return 0.0;
  }

  static List<Season> _parseSeasons(dynamic seasons) {
    if (seasons is List<int>) {
      // Format compact : [1, 2, 3, 4]
      return seasons.map((seasonNumber) => Season(
        seasonNumber: seasonNumber,
        episodesCount: 10, // Valeur par défaut
        episodes: [],
      )).toList();
    } else if (seasons is List) {
      // Format détaillé
      return seasons.map((season) => Season.fromJson(season as Map<String, dynamic>)).toList();
    }
    return [];
  }
}

/// Modèle pour les saisons
class Season {
  final int seasonNumber;
  final int episodesCount;
  final List<Episode> episodes;

  Season({
    required this.seasonNumber,
    required this.episodesCount,
    required this.episodes,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      seasonNumber: json['seasonnumber'] ?? json['season_number'] ?? 0,
      episodesCount: json['episodescount'] ?? json['episodes_count'] ?? 0,
      episodes: (json['episodes'] as List<dynamic>?)
          ?.map((e) => Episode.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seasonnumber': seasonNumber,
      'episodescount': episodesCount,
      'episodes': episodes.map((e) => e.toJson()).toList(),
    };
  }
}

/// Modèle pour les épisodes
class Episode {
  final int episodeNumber;
  final String title;
  final String synopsis;
  final String url;
  final List<WatchLink> watchLinks;

  Episode({
    required this.episodeNumber,
    required this.title,
    required this.synopsis,
    this.url = '',
    this.watchLinks = const [],
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      episodeNumber: json['episodenumber'] ?? json['episode_number'] ?? 0,
      title: json['title'] ?? '',
      synopsis: json['synopsis'] ?? json['overview'] ?? '',
      url: json['url'] ?? '',
      watchLinks: (json['watch_links'] as List<dynamic>? ?? [])
          .map((link) => WatchLink.fromJson(link as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'episodenumber': episodeNumber,
      'title': title,
      'synopsis': synopsis,
      'url': url,
      'watch_links': watchLinks.map((link) => link.toJson()).toList(),
    };
  }
}

// WatchLink class is now defined in lib/data/models/movie.dart to avoid conflicts