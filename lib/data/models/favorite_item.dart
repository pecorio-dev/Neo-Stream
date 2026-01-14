import 'movie.dart';
import 'series.dart';

class FavoriteItem {
  final String id;
  final String title;
  final String originalTitle;
  final String poster;
  final String type; // 'movie' or 'series'
  final String rating;
  final String releaseDate;
  final List<String> genres;
  final DateTime addedAt;
  final Movie? movieData; // Données complètes du film
  final Series? seriesData; // Données complètes de la série

  FavoriteItem({
    required this.id,
    required this.title,
    required this.originalTitle,
    required this.poster,
    required this.type,
    required this.rating,
    required this.releaseDate,
    required this.genres,
    required this.addedAt,
    this.movieData,
    this.seriesData,
  });

  factory FavoriteItem.fromMovie(Movie movie) {
    return FavoriteItem(
      id: movie.url.hashCode.toString(),
      title: movie.title,
      originalTitle: movie.originalTitle ?? '',
      poster: movie.poster ?? '',
      type: 'movie',
      rating: (movie.rating ?? 0.0).toString(),
      releaseDate: movie.year,
      genres: movie.genres,
      addedAt: DateTime.now(),
      movieData: movie,
      seriesData: null,
    );
  }

  factory FavoriteItem.fromSeries(Series series) {
    return FavoriteItem(
      id: series.url.hashCode.toString(),
      title: series.title,
      originalTitle: series.originalTitle ?? '',
      poster: series.poster ?? '',
      type: 'series',
      rating: (series.rating ?? 0.0).toString(),
      releaseDate: series.year,
      genres: series.genres,
      addedAt: DateTime.now(),
      movieData: null,
      seriesData: series,
    );
  }

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      originalTitle: json['original_title'] ?? '',
      poster: json['poster'] ?? '',
      type: json['type'] ?? '',
      rating: json['rating'] ?? '',
      releaseDate: json['release_date'] ?? '',
      genres: List<String>.from(json['genres'] ?? []),
      addedAt:
          DateTime.parse(json['added_at'] ?? DateTime.now().toIso8601String()),
      movieData: json['movie_data'] != null
          ? Movie.fromJson(json['movie_data'])
          : null,
      seriesData: json['series_data'] != null
          ? Series.fromJson(json['series_data'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'original_title': originalTitle,
      'poster': poster,
      'type': type,
      'rating': rating,
      'release_date': releaseDate,
      'genres': genres,
      'added_at': addedAt.toIso8601String(),
      'movie_data': movieData?.toJson(),
      'series_data': seriesData?.toJson(),
    };
  }

  // Helper methods
  double get numericRating {
    try {
      final ratingStr = rating.split('/').first;
      return double.parse(ratingStr);
    } catch (e) {
      return 0.0;
    }
  }

  int get releaseYear {
    try {
      return int.parse(releaseDate);
    } catch (e) {
      return 0;
    }
  }

  bool get hasValidPoster => poster.isNotEmpty && poster.startsWith('http');

  String get displayTitle => title.isNotEmpty ? title : originalTitle;

  String get formattedGenres => genres.take(3).join(', ');

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FavoriteItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
