import 'movie.dart';
import 'series.dart';
import '../../core/extensions/index.dart';

enum SearchResultType {
  movie,
  series,
}

class SearchResult {
  final String id;
  final String title;
  final String poster;
  final String synopsis;
  final List<String> genres;
  final double rating;
  final int releaseYear;
  final SearchResultType type;
  final Movie? movie;
  final Series? series;

  SearchResult({
    required this.id,
    required this.title,
    required this.poster,
    required this.synopsis,
    required this.genres,
    required this.rating,
    required this.releaseYear,
    required this.type,
    this.movie,
    this.series,
  });

  factory SearchResult.fromMovie(Movie movie) {
    return SearchResult(
      id: movie.id,
      title: movie.displayTitle,
      poster: movie.poster ?? '',
      synopsis: movie.synopsis ?? '',
      genres: movie.cleanGenres,
      rating: movie.numericRating,
      releaseYear: movie.releaseYear ?? 0,
      type: SearchResultType.movie,
      movie: movie,
      series: null,
    );
  }

  factory SearchResult.fromSeries(Series series) {
    return SearchResult(
      id: series.id,
      title: series.displayTitle,
      poster: series.poster ?? '',
      synopsis: series.synopsis ?? '',
      genres: series.cleanGenres,
      rating: series.numericRating,
      releaseYear: series.releaseYear ?? 0,
      type: SearchResultType.series,
      movie: null,
      series: series,
    );
  }

  bool get hasValidPoster => poster.isNotEmpty && poster.startsWith('http');

  String get displayTitle => title;

  List<String> get cleanGenres => genres.where((g) => g.isNotEmpty).toList();

  bool get isMovie => type == SearchResultType.movie;
  bool get isSeries => type == SearchResultType.series;
}
