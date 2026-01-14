class Movie {
  final String id;
  final String title;
  final String? originalTitle;
  final String type; // "film"
  final String year; // String, not int
  final String? poster;
  final String? url;
  final List<String> genres;
  final double? rating; // Can be null
  final double? ratingMax; // From /item endpoint
  final String? quality; // HD, SD, 4K
  final String? version; // French, English, TrueFrench, etc.
  final List<String> actors;
  final List<String> directors;
  final String? synopsis;
  final String? description; // From /item endpoint
  final int? watchLinksCount; // From /films endpoint (count only)
  final String? language;
  final List<WatchLink>? watchLinks; // From /item endpoint (full objects)
  final int? duration; // From /item endpoint
  final String? releaseDate; // Additional field

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
    this.ratingMax,
    this.quality,
    this.version,
    required this.actors,
    required this.directors,
    this.synopsis,
    this.description,
    this.watchLinksCount,
    this.language,
    this.watchLinks,
    this.duration,
    this.releaseDate,
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
      ratingMax: (json['rating_max'] as num?)?.toDouble(),
      quality: json['quality'],
      version: json['version'],
      actors: List<String>.from(json['actors'] ?? []),
      directors: List<String>.from(json['directors'] ?? []),
      synopsis: json['synopsis'],
      description: json['description'],
      watchLinksCount: json['watch_links_count'],
      language: json['language'],
      watchLinks: (json['watch_links'] as List<dynamic>? ?? [])
              .map((link) => WatchLink.fromJson(link as Map<String, dynamic>))
              .toList()
              .isEmpty
          ? null
          : (json['watch_links'] as List<dynamic>)
              .map((link) => WatchLink.fromJson(link as Map<String, dynamic>))
              .toList(),
      duration: json['duration'],
      releaseDate: json['release_date'],
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
      'language': language,
      'watch_links': watchLinks?.map((w) => w.toJson()).toList(),
      'duration': duration,
      'release_date': releaseDate,
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

  double get numericRating => rating ?? 0.0;

  List<String> get cleanGenres {
    return genres.map((g) => g.trim()).where((g) => g.isNotEmpty).toList();
  }

  String get director {
    return directors.isNotEmpty ? directors.first : '';
  }

  bool get hasValidPoster {
    return poster != null && poster!.isNotEmpty;
  }

  String get displayTitle {
    return originalTitle?.isNotEmpty == true
        ? '$title ($originalTitle)'
        : title;
  }

  @override
  String toString() {
    return 'Movie(id: $id, title: $title, year: $year, rating: $rating)';
  }
}

class MoviesResponse {
  final List<Movie> movies;

  MoviesResponse({required this.movies});

  factory MoviesResponse.fromJson(Map<String, dynamic> json) {
    return MoviesResponse(
      movies: (json['movies'] as List<dynamic>?)
              ?.map((movie) => Movie.fromJson(movie as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'movies': movies.map((m) => m.toJson()).toList(),
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
      if (quality != null) 'quality': quality,
      if (type != null) 'type': type,
    };
  }
}
