import 'movie.dart';
import '../../core/extensions/index.dart';

class SearchResponse {
  final String query;
  final String type;
  final List<dynamic>? fields;
  final bool consolidated;
  final List<Movie> results;
  final int count;

  SearchResponse({
    required this.query,
    required this.type,
    this.fields,
    required this.consolidated,
    required this.results,
    required this.count,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      query: json['query'] ?? '',
      type: json['type'] ?? '',
      fields: json['fields'],
      consolidated: json['consolidated'] ?? false,
      results: (json['results'] as List<dynamic>?)
              ?.map((result) => Movie.fromJson(result))
              .toList() ??
          [],
      count: json['count'] ?? (json['results'] as List<dynamic>?)?.length ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'type': type,
      'fields': fields,
      'consolidated': consolidated,
      'results': results.map((movie) => movie.toJson()).toList(),
      'count': count,
    };
  }

  // Helper methods
  bool get hasResults => results.isNotEmpty;
  bool get isEmpty => results.isEmpty;

  List<Movie> get movies => results.where((r) => r.type == 'movie').toList();
  List<Movie> get series => results.where((r) => r.type == 'series').toList();

  List<Movie> filterByGenre(String genre) {
    return results
        .where((movie) => movie.genres
            .any((g) => g.toLowerCase().contains(genre.toLowerCase())))
        .toList();
  }

  List<Movie> filterByRating(double minRating) {
    return results.where((movie) => movie.numericRating >= minRating).toList();
  }

  List<Movie> filterByYear(int year) {
    return results.where((movie) => movie.releaseYear == year).toList();
  }

  List<Movie> sortByRating({bool descending = true}) {
    final sorted = List<Movie>.from(results);
    sorted.sort((a, b) => descending
        ? b.numericRating.compareTo(a.numericRating)
        : a.numericRating.compareTo(b.numericRating));
    return sorted;
  }

  List<Movie> sortByYear({bool descending = true}) {
    final sorted = List<Movie>.from(results);
    sorted.sort((a, b) {
      final yearA = a.releaseYear;
      final yearB = b.releaseYear;
      return descending ? yearB.compareTo(yearA) : yearA.compareTo(yearB);
    });
    return sorted;
  }

  List<Movie> sortByTitle({bool ascending = true}) {
    final sorted = List<Movie>.from(results);
    sorted.sort((a, b) =>
        ascending ? a.title.compareTo(b.title) : b.title.compareTo(a.title));
    return sorted;
  }
}

enum SearchType {
  all,
  movies,
  series;

  String get value {
    switch (this) {
      case SearchType.all:
        return 'all';
      case SearchType.movies:
        return 'movies';
      case SearchType.series:
        return 'series';
    }
  }

  static SearchType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'movies':
        return SearchType.movies;
      case 'series':
        return SearchType.series;
      default:
        return SearchType.all;
    }
  }
}

enum SortOption {
  relevance,
  rating,
  year,
  title;

  String get displayName {
    switch (this) {
      case SortOption.relevance:
        return 'Pertinence';
      case SortOption.rating:
        return 'Note';
      case SortOption.year:
        return 'Année';
      case SortOption.title:
        return 'Titre';
    }
  }
}
