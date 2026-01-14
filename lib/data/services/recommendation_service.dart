import 'dart:async';
import 'dart:math';
import '../models/movie.dart';
import '../models/series.dart';
import 'movies_api_service.dart';
import 'series_api_service.dart';

/// Service avancé de recommandation basé sur la similarité
/// avec une hiérarchie précise de priorité
class RecommendationService {
  static const String _tag = 'RecommendationService';
  static const int _defaultPageSize = 50;
  static const int _maxPages = 5; // Nombre de pages à récupérer
  static const double _minScore = 0.15; // Score minimum requis

  /// Hiérarchie de similarité (ordre de priorité décroissante):
  /// 1. Même titre (1.0)
  /// 2. Même réalisateur (0.9)
  /// 3. Mêmes acteurs (0.7)
  /// 4. Similarité du synopsis (0.5)
  /// 5. Mêmes genres (0.4)
  /// 6. Même année (0.1)

  /// Obtient des recommandations pour un film
  static Future<List<Movie>> getMovieRecommendations(
    Movie baseMovie, {
    int limit = 20,
    bool verbose = false,
  }) async {
    try {
      if (verbose) {
        print('$_tag: Fetching movie recommendations for: ${baseMovie.title}');
      }

      final allCandidates = <String, _ScoredMovie>{};
      final seenIds = <String>{baseMovie.id};

      // Récupérer depuis plusieurs pages en parallèle
      final futures = <Future<void>>[];
      for (int page = 0; page < _maxPages; page++) {
        futures.add(_fetchAndScoreMovies(
          baseMovie,
          page,
          allCandidates,
          seenIds,
          verbose,
        ));
      }

      // Attendre toutes les requêtes
      await Future.wait(futures);

      // Trier par score décroissant
      final sorted = allCandidates.values.toList();
      sorted.sort((a, b) => b.score.compareTo(a.score));

      if (verbose) {
        print('$_tag: Found ${sorted.length} movie recommendations');
      }

      // Retourner le nombre limite de résultats
      return sorted.take(limit).map((sm) => sm.movie).toList();
    } catch (e) {
      print('$_tag: Error getting movie recommendations: $e');
      return [];
    }
  }

  /// Obtient des recommandations pour une série
  static Future<List<Series>> getSeriesRecommendations(
    Series baseSeries, {
    int limit = 20,
    bool verbose = false,
  }) async {
    try {
      if (verbose) {
        print(
            '$_tag: Fetching series recommendations for: ${baseSeries.title}');
      }

      final allCandidates = <String, _ScoredSeries>{};
      final seenIds = <String>{baseSeries.id};

      // Récupérer depuis plusieurs pages en parallèle
      final futures = <Future<void>>[];
      for (int page = 0; page < _maxPages; page++) {
        futures.add(_fetchAndScoreSeries(
          baseSeries,
          page,
          allCandidates,
          seenIds,
          verbose,
        ));
      }

      // Attendre toutes les requêtes
      await Future.wait(futures);

      // Trier par score décroissant
      final sorted = allCandidates.values.toList();
      sorted.sort((a, b) => b.score.compareTo(a.score));

      if (verbose) {
        print('$_tag: Found ${sorted.length} series recommendations');
      }

      // Retourner le nombre limite de résultats
      return sorted.take(limit).map((ss) => ss.series).toList();
    } catch (e) {
      print('$_tag: Error getting series recommendations: $e');
      return [];
    }
  }

  /// Obtient des recommandations mixtes (films et séries)
  static Future<RecommendationResult> getMixedRecommendations(
    dynamic baseContent, {
    int movieLimit = 10,
    int seriesLimit = 10,
    bool verbose = false,
  }) async {
    try {
      final movies = <Movie>[];
      final series = <Series>[];

      if (baseContent is Movie) {
        final movieRecs = await getMovieRecommendations(
          baseContent,
          limit: movieLimit,
          verbose: verbose,
        );
        movies.addAll(movieRecs);
      } else if (baseContent is Series) {
        final seriesRecs = await getSeriesRecommendations(
          baseContent,
          limit: seriesLimit,
          verbose: verbose,
        );
        series.addAll(seriesRecs);
      }

      return RecommendationResult(movies: movies, series: series);
    } catch (e) {
      print('$_tag: Error getting mixed recommendations: $e');
      return RecommendationResult(movies: [], series: []);
    }
  }

  /// Récupère et score les films pour une page donnée
  static Future<void> _fetchAndScoreMovies(
    Movie baseMovie,
    int page,
    Map<String, _ScoredMovie> allCandidates,
    Set<String> seenIds,
    bool verbose,
  ) async {
    try {
      final offset = page * _defaultPageSize;
      if (verbose) {
        print('$_tag: Fetching movies page $page (offset: $offset)');
      }

      final response = await MoviesApiService.getMovies(
        limit: _defaultPageSize,
        offset: offset,
        forceRefresh: true,
      );

      for (final movie in response.data) {
        if (seenIds.contains(movie.id)) continue;

        final score = _calculateMovieSimilarity(baseMovie, movie);
        if (score >= _minScore) {
          if (!allCandidates.containsKey(movie.id) ||
              score > allCandidates[movie.id]!.score) {
            allCandidates[movie.id] = _ScoredMovie(movie, score);
          }
          seenIds.add(movie.id);
        }
      }
    } catch (e) {
      if (verbose) {
        print('$_tag: Error fetching movies page $page: $e');
      }
    }
  }

  /// Récupère et score les séries pour une page donnée
  static Future<void> _fetchAndScoreSeries(
    Series baseSeries,
    int page,
    Map<String, _ScoredSeries> allCandidates,
    Set<String> seenIds,
    bool verbose,
  ) async {
    try {
      final offset = page * _defaultPageSize;
      if (verbose) {
        print('$_tag: Fetching series page $page (offset: $offset)');
      }

      final response = await SeriesApiService.getSeries(
        limit: _defaultPageSize,
        offset: offset,
        forceRefresh: true,
      );

      for (final series in response.data) {
        if (seenIds.contains(series.id)) continue;

        final score = _calculateSeriesSimilarity(baseSeries, series);
        if (score >= _minScore) {
          if (!allCandidates.containsKey(series.id) ||
              score > allCandidates[series.id]!.score) {
            allCandidates[series.id] = _ScoredSeries(series, score);
          }
          seenIds.add(series.id);
        }
      }
    } catch (e) {
      if (verbose) {
        print('$_tag: Error fetching series page $page: $e');
      }
    }
  }

  /// Calcule la similarité entre deux films avec hiérarchie précise
  static double _calculateMovieSimilarity(Movie movie1, Movie movie2) {
    double score = 0.0;

    // 1. Même titre (priorité maximale: 1.0)
    if (movie1.title.toLowerCase() == movie2.title.toLowerCase()) {
      return 1.0;
    }

    // 2. Même réalisateur/producteur (0.9)
    final directorScore =
        _calculateDirectorSimilarity(movie1.directors, movie2.directors);
    score += directorScore * 0.25;

    // 3. Mêmes acteurs (0.7)
    final actorScore = _calculateActorSimilarity(movie1.actors, movie2.actors);
    score += actorScore * 0.25;

    // 4. Similarité du synopsis (0.5)
    final synopsisScore =
        _calculateSynopsisSimilarity(movie1.synopsis, movie2.synopsis);
    score += synopsisScore * 0.25;

    // 5. Mêmes genres (0.4)
    final genreScore =
        _calculateGenreSimilarity(movie1.cleanGenres, movie2.cleanGenres);
    score += genreScore * 0.15;

    // 6. Même année (0.1)
    final yearScore =
        _calculateYearSimilarity(movie1.releaseYear, movie2.releaseYear);
    score += yearScore * 0.05;

    // Bonus pour note similaire
    final ratingScore =
        _calculateRatingSimilarity(movie1.numericRating, movie2.numericRating);
    score += ratingScore * 0.05;

    return score.clamp(0.0, 1.0);
  }

  /// Calcule la similarité entre deux séries avec hiérarchie précise
  static double _calculateSeriesSimilarity(Series series1, Series series2) {
    double score = 0.0;

    // 1. Même titre (priorité maximale: 1.0)
    if (series1.title.toLowerCase() == series2.title.toLowerCase()) {
      return 1.0;
    }

    // 2. Même réalisateur/producteur (0.9)
    final directorScore =
        _calculateDirectorSimilarity(series1.directors, series2.directors);
    score += directorScore * 0.25;

    // 3. Mêmes acteurs (0.7)
    final actorScore =
        _calculateActorSimilarity(series1.actors, series2.actors);
    score += actorScore * 0.25;

    // 4. Similarité du synopsis (0.5)
    final synopsisScore =
        _calculateSynopsisSimilarity(series1.synopsis, series2.synopsis);
    score += synopsisScore * 0.25;

    // 5. Mêmes genres (0.4)
    final genreScore =
        _calculateGenreSimilarity(series1.cleanGenres, series2.cleanGenres);
    score += genreScore * 0.15;

    // 6. Même année (0.1)
    final yearScore =
        _calculateYearSimilarity(series1.releaseYear, series2.releaseYear);
    score += yearScore * 0.05;

    // Bonus pour note similaire
    final ratingScore = _calculateRatingSimilarity(
        series1.numericRating, series2.numericRating);
    score += ratingScore * 0.05;

    return score.clamp(0.0, 1.0);
  }

  /// Calcule la similarité entre deux réalisateurs (producteurs)
  static double _calculateDirectorSimilarity(
      List<String> directors1, List<String> directors2) {
    if (directors1.isEmpty || directors2.isEmpty) return 0.0;

    final set1 = directors1.map((d) => _normalizeName(d)).toSet();
    final set2 = directors2.map((d) => _normalizeName(d)).toSet();

    final intersection = set1.intersection(set2);
    if (intersection.isNotEmpty) {
      return 1.0; // Exact match
    }

    // Vérifier les correspondances partielles
    for (final d1 in set1) {
      for (final d2 in set2) {
        if (_stringSimilarity(d1, d2) > 0.8) {
          return 0.7; // Partial match
        }
      }
    }

    return 0.0;
  }

  /// Calcule la similarité entre deux listes d'acteurs
  static double _calculateActorSimilarity(
      List<String> actors1, List<String> actors2) {
    if (actors1.isEmpty || actors2.isEmpty) return 0.0;

    final set1 = actors1.map((a) => _normalizeName(a)).toSet();
    final set2 = actors2.map((a) => _normalizeName(a)).toSet();

    final intersection = set1.intersection(set2);
    if (intersection.isEmpty) return 0.0;

    // Score basé sur le nombre d'acteurs en commun
    final matchRatio = intersection.length / max(set1.length, set2.length);
    return matchRatio.clamp(0.0, 1.0);
  }

  /// Calcule la similarité entre deux synopsis (utilise la distance Levenshtein)
  static double _calculateSynopsisSimilarity(
      String? synopsis1, String? synopsis2) {
    if (synopsis1 == null ||
        synopsis2 == null ||
        synopsis1.isEmpty ||
        synopsis2.isEmpty) {
      return 0.0;
    }

    // Si les synopsis sont trop courts, on ne peut pas faire de comparaison fiable
    if (synopsis1.length < 20 || synopsis2.length < 20) {
      return 0.0;
    }

    // Utiliser la similarité basée sur les mots
    final similarity = _wordBasedSimilarity(synopsis1, synopsis2);

    // Retourner un score basé sur le niveau de similarité
    if (similarity > 0.7) {
      return 0.8; // High similarity
    } else if (similarity > 0.5) {
      return 0.4; // Moderate similarity
    } else if (similarity > 0.3) {
      return 0.15; // Weak similarity
    }

    return 0.0;
  }

  /// Normalise un nom pour la comparaison
  static String _normalizeName(String name) {
    return name.toLowerCase().trim().replaceAll(RegExp(r'[\s-]'), '');
  }

  /// Calcule la similarité entre deux listes de genres
  static double _calculateGenreSimilarity(
      List<String> genres1, List<String> genres2) {
    if (genres1.isEmpty || genres2.isEmpty) return 0.0;

    final set1 = genres1.map((g) => g.toLowerCase()).toSet();
    final set2 = genres2.map((g) => g.toLowerCase()).toSet();

    final intersection = set1.intersection(set2);
    final union = set1.union(set2);

    // Coefficient de Jaccard
    return union.isEmpty ? 0.0 : intersection.length / union.length;
  }

  /// Calcule la similarité d'année
  static double _calculateYearSimilarity(int year1, int year2) {
    if (year1 == 0 || year2 == 0) return 0.0;

    final diff = (year1 - year2).abs();
    if (diff == 0) return 1.0;
    if (diff <= 1) return 0.9;
    if (diff <= 2) return 0.7;
    if (diff <= 3) return 0.5;
    if (diff <= 5) return 0.3;
    if (diff <= 10) return 0.1;
    return 0.0;
  }

  /// Calcule la similarité de note/rating
  static double _calculateRatingSimilarity(double rating1, double rating2) {
    if (rating1 == 0.0 || rating2 == 0.0) return 0.0;

    final diff = (rating1 - rating2).abs();
    if (diff <= 0.5) return 1.0;
    if (diff <= 1.0) return 0.7;
    if (diff <= 2.0) return 0.4;
    return 0.0;
  }

  /// Calcule la similarité basée sur les mots (0.0 à 1.0)
  static double _wordBasedSimilarity(String s1, String s2) {
    // Tokeniser en mots
    final words1 = s1
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final words2 = s2
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Filtrer les mots courts communs
    final commonStopWords = {
      'le',
      'la',
      'les',
      'un',
      'une',
      'des',
      'et',
      'ou',
      'est',
      'sont',
      'the',
      'a',
      'an',
      'and',
      'or',
      'is',
      'are',
      'of',
      'in',
      'on'
    };

    final filtered1 = words1
        .where((w) => w.length >= 3 && !commonStopWords.contains(w))
        .toSet();
    final filtered2 = words2
        .where((w) => w.length >= 3 && !commonStopWords.contains(w))
        .toSet();

    if (filtered1.isEmpty || filtered2.isEmpty) return 0.0;

    final intersection = filtered1.intersection(filtered2);
    final union = filtered1.union(filtered2);

    // Coefficient de Jaccard basé sur les mots
    return union.isEmpty ? 0.0 : intersection.length / union.length;
  }

  /// Calcule la similarité entre deux chaînes de caractères (0.0 à 1.0)
  static double _stringSimilarity(String s1, String s2) {
    s1 = s1.toLowerCase().trim();
    s2 = s2.toLowerCase().trim();

    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final maxLen = max(s1.length, s2.length);
    final distance = _levenshteinDistance(s1, s2);

    return 1.0 - (distance / maxLen);
  }

  /// Calcule la distance de Levenshtein entre deux chaînes
  static int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;

    final d = List<List<int>>.generate(
      len1 + 1,
      (i) => List<int>.filled(len2 + 1, 0),
    );

    for (int i = 0; i <= len1; i++) d[i][0] = i;
    for (int j = 0; j <= len2; j++) d[0][j] = j;

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1, // deletion
          d[i][j - 1] + 1, // insertion
          d[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return d[len1][len2];
  }
}

/// Film scoré pour le tri
class _ScoredMovie {
  final Movie movie;
  final double score;

  _ScoredMovie(this.movie, this.score);
}

/// Série scorée pour le tri
class _ScoredSeries {
  final Series series;
  final double score;

  _ScoredSeries(this.series, this.score);
}

/// Résultat de recommandation avec catégorisation par score
class RecommendationResult {
  final List<Movie> movies;
  final List<Series> series;

  RecommendationResult({
    required this.movies,
    required this.series,
  });

  bool get isEmpty => movies.isEmpty && series.isEmpty;
  int get totalCount => movies.length + series.length;
}
