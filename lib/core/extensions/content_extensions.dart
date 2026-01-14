import '../../data/models/movie.dart';
import '../../data/models/series.dart';

/// Extensions pour Movie
extension MovieExtensions on Movie {
  /// Retourne le titre d'affichage (original si présent, sinon titre)
  String get displayTitle =>
      originalTitle?.isNotEmpty == true ? originalTitle! : title;

  /// Retourne le titre principal
  String get mainTitle => title;

  /// Retourne l'année en tant que nombre (pour les comparaisons)
  int? get releaseYear {
    try {
      return int.tryParse(year);
    } catch (e) {
      return null;
    }
  }

  /// Retourne la date de sortie formatée
  String get releaseDate => year;

  /// Retourne la note numérique (0 si null)
  double get numericRating => rating ?? 0.0;

  /// Vérifie si le poster est valide
  bool get hasValidPoster => poster != null && poster!.isNotEmpty;

  /// Retourne les genres nettoyés
  List<String> get cleanGenres =>
      genres.map((g) => g.trim()).where((g) => g.isNotEmpty).toList();

  /// Retourne le premier réalisateur
  String? get director => directors.isNotEmpty ? directors.first : null;

  /// Retourne la langue
  String? get language => null; // N/A pour movies

  /// Retourne la langue d'origine
  String get languageCode => 'en';

  /// Retourne les liens de streaming (si disponibles)
  List<dynamic> get watchLinks => []; // À implémenter si nécessaire

  /// Retourne le statut
  String get status => 'Released';

  /// Vérifie si le film a des genres
  bool get hasGenres => genres.isNotEmpty;

  /// Compte les genres
  int get genreCount => genres.length;

  /// Compte les acteurs
  int get actorCount => actors.length;

  /// Compte les réalisateurs
  int get directorCount => directors.length;

  /// Format d'affichage: "Titre (Année)"
  String get displayFormat => '$displayTitle ($year)';

  /// Format d'affichage court
  String get shortFormat => displayTitle;

  /// Format long avec détails
  String get longFormat =>
      '$displayTitle ($year) - ${rating?.toStringAsFixed(1) ?? "N/A"}/10';

  /// Vérifie si c'est un film récent (dernières 5 ans)
  bool get isRecent {
    final releaseYearInt = releaseYear;
    if (releaseYearInt == null) return false;
    return DateTime.now().year - releaseYearInt <= 5;
  }

  /// Vérifie si c'est un classique (avant 2000)
  bool get isClassic {
    final releaseYearInt = releaseYear;
    if (releaseYearInt == null) return false;
    return releaseYearInt < 2000;
  }

  /// Vérifie si bien noté (>= 7.0)
  bool get isHighRated => numericRating >= 7.0;

  /// Vérifie si très bien noté (>= 8.0)
  bool get isVeryHighRated => numericRating >= 8.0;

  /// Vérifie si excellent (>= 9.0)
  bool get isExcellent => numericRating >= 9.0;

  /// Retourne la qualité (avec défaut)
  String get qualityDisplay => quality ?? 'Unknown';

  /// Retourne la version (avec défaut)
  String get versionDisplay => version ?? 'Original';

  /// Retourne le synopsis tronqué
  String get shortSynopsis {
    if (synopsis == null || synopsis!.isEmpty) return 'No synopsis available';
    return synopsis!.length > 200
        ? '${synopsis!.substring(0, 200)}...'
        : synopsis!;
  }

  /// Retourne le synopsis complet
  String get fullSynopsis => synopsis ?? 'No synopsis available';

  /// Retourne les genres formatés
  String get genresString => genres.join(', ');

  /// Retourne les acteurs formatés
  String get actorsString => actors.join(', ');

  /// Retourne les réalisateurs formatés
  String get directorsString => directors.join(', ');

  /// Crée une copie avec modifications
  Movie copyWith({
    String? id,
    String? title,
    String? originalTitle,
    String? type,
    String? year,
    String? poster,
    String? url,
    List<String>? genres,
    double? rating,
    String? quality,
    String? version,
    List<String>? actors,
    List<String>? directors,
    String? synopsis,
    int? watchLinksCount,
  }) {
    return Movie(
      id: id ?? this.id,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      type: type ?? this.type,
      year: year ?? this.year,
      poster: poster ?? this.poster,
      url: url ?? this.url,
      genres: genres ?? this.genres,
      rating: rating ?? this.rating,
      quality: quality ?? this.quality,
      version: version ?? this.version,
      actors: actors ?? this.actors,
      directors: directors ?? this.directors,
      synopsis: synopsis ?? this.synopsis,
      watchLinksCount: watchLinksCount ?? this.watchLinksCount,
    );
  }
}

/// Extensions pour Series
extension SeriesExtensions on Series {
  /// Retourne le titre d'affichage
  String get displayTitle =>
      originalTitle?.isNotEmpty == true ? originalTitle! : title;

  /// Retourne le titre principal
  String get mainTitle => title;

  /// Retourne l'année en tant que nombre
  int? get releaseYear {
    try {
      return int.tryParse(year);
    } catch (e) {
      return null;
    }
  }

  /// Retourne la date de sortie
  String get releaseDate => year;

  /// Retourne la note numérique
  double get numericRating => rating ?? 0.0;

  /// Vérifie si le poster est valide
  bool get hasValidPoster => poster != null && poster!.isNotEmpty;

  /// Retourne les genres nettoyés
  List<String> get cleanGenres =>
      genres.map((g) => g.trim()).where((g) => g.isNotEmpty).toList();

  /// Retourne le premier réalisateur
  String? get director => directors.isNotEmpty ? directors.first : null;

  /// Retourne la langue
  String? get language => null; // À implémenter si nécessaire

  /// Retourne les saisons (si disponibles dans le modèle)
  List<dynamic>? get seasons => null; // À implémenter si nécessaire

  /// Retourne le statut (en cours ou terminé)
  String get status => isOngoing ? 'Ongoing' : 'Completed';

  /// Vérifie si la série est en cours
  bool get isOngoing => true; // À déterminer dynamiquement

  /// Vérifie si la série est terminée
  bool get isCompleted => !isOngoing;

  /// Retourne le nombre total de saisons (avec défaut)
  int get totalSeasons => seasonsCount;

  /// Retourne le nombre total d'épisodes (avec défaut)
  int get totalEpisodes => episodesCount;

  /// Retourne le nombre réel de saisons
  int get actualTotalSeasons => seasonsCount;

  /// Retourne le nombre réel d'épisodes
  int get actualTotalEpisodes => episodesCount;

  /// Vérifie si c'est une série récente
  bool get isRecent {
    final releaseYearInt = releaseYear;
    if (releaseYearInt == null) return false;
    return DateTime.now().year - releaseYearInt <= 5;
  }

  /// Vérifie si c'est une série classique
  bool get isClassic {
    final releaseYearInt = releaseYear;
    if (releaseYearInt == null) return false;
    return releaseYearInt < 2000;
  }

  /// Vérifie si bien notée
  bool get isHighRated => numericRating >= 7.0;

  /// Vérifie si très bien notée
  bool get isVeryHighRated => numericRating >= 8.0;

  /// Vérifie si excellente
  bool get isExcellent => numericRating >= 9.0;

  /// Retourne la qualité avec défaut
  String get qualityDisplay => quality ?? 'Unknown';

  /// Retourne la version avec défaut
  String get versionDisplay => version ?? 'Original';

  /// Retourne le synopsis tronqué
  String get shortSynopsis {
    if (synopsis == null || synopsis!.isEmpty) return 'No synopsis available';
    return synopsis!.length > 200
        ? '${synopsis!.substring(0, 200)}...'
        : synopsis!;
  }

  /// Retourne le synopsis complet
  String get fullSynopsis => synopsis ?? 'No synopsis available';

  /// Retourne les genres formatés
  String get genresString => genres.join(', ');

  /// Retourne les acteurs formatés
  String get actorsString => actors.join(', ');

  /// Retourne les réalisateurs formatés
  String get directorsString => directors.join(', ');

  /// Format d'affichage: "Titre (Année)"
  String get displayFormat => '$displayTitle ($year)';

  /// Format court
  String get shortFormat => displayTitle;

  /// Format long avec détails
  String get longFormat =>
      '$displayTitle ($year) - S$actualTotalSeasons E$actualTotalEpisodes - ${numericRating.toStringAsFixed(1)}/10';

  /// Récupère une saison par numéro
  dynamic getSeason(int seasonNumber) {
    // À implémenter si les données de saisons sont disponibles
    return null;
  }

  /// Vérifie si la série a des genres
  bool get hasGenres => genres.isNotEmpty;

  /// Compte les genres
  int get genreCount => genres.length;

  /// Compte les acteurs
  int get actorCount => actors.length;

  /// Compte les réalisateurs
  int get directorCount => directors.length;

  /// Crée une copie avec modifications
  Series copyWith({
    String? id,
    String? title,
    String? originalTitle,
    String? type,
    String? year,
    String? poster,
    String? url,
    List<String>? genres,
    double? rating,
    String? quality,
    String? version,
    List<String>? actors,
    List<String>? directors,
    String? synopsis,
    int? watchLinksCount,
    int? seasonsCount,
    int? episodesCount,
  }) {
    return Series(
      id: id ?? this.id,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      type: type ?? this.type,
      year: year ?? this.year,
      poster: poster ?? this.poster,
      url: url ?? this.url,
      genres: genres ?? this.genres,
      rating: rating ?? this.rating,
      quality: quality ?? this.quality,
      version: version ?? this.version,
      actors: actors ?? this.actors,
      directors: directors ?? this.directors,
      synopsis: synopsis ?? this.synopsis,
      watchLinksCount: watchLinksCount ?? this.watchLinksCount,
      seasonsCount: seasonsCount ?? this.seasonsCount,
      episodesCount: episodesCount ?? this.episodesCount,
    );
  }
}

/// Extensions pour Episode
extension EpisodeExtensions on Episode {
  /// Retourne le titre d'affichage
  String get displayTitle =>
      title.isNotEmpty ? title : 'Episode ${episode ?? 0}';

  /// Retourne le format S01E01
  String get episodeFormat =>
      'S${season?.toString().padLeft(2, '0') ?? '00'}E${episode?.toString().padLeft(2, '0') ?? '00'}';

  /// Format complet: S01E01 - Titre
  String get fullFormat => '$episodeFormat - $displayTitle';

  /// Vérifie si l'épisode a une date de diffusion
  bool get hasAirDate => airDate != null && airDate!.isNotEmpty;
}

/// Extensions pour affichage général
extension ContentExtensions on dynamic {
  /// Retourne le titre d'affichage pour n'importe quel contenu
  String getDisplayTitle() {
    if (this is Movie) {
      return (this as Movie).displayTitle;
    } else if (this is Series) {
      return (this as Series).displayTitle;
    }
    return 'Unknown';
  }

  /// Retourne l'année pour n'importe quel contenu
  String? getYear() {
    if (this is Movie) {
      return (this as Movie).year;
    } else if (this is Series) {
      return (this as Series).year;
    }
    return null;
  }

  /// Retourne la note pour n'importe quel contenu
  double? getRating() {
    if (this is Movie) {
      return (this as Movie).rating;
    } else if (this is Series) {
      return (this as Series).rating;
    }
    return null;
  }

  /// Retourne les genres pour n'importe quel contenu
  List<String> getGenres() {
    if (this is Movie) {
      return (this as Movie).genres;
    } else if (this is Series) {
      return (this as Series).genres;
    }
    return [];
  }

  /// Retourne le poster pour n'importe quel contenu
  String? getPoster() {
    if (this is Movie) {
      return (this as Movie).poster;
    } else if (this is Series) {
      return (this as Series).poster;
    }
    return null;
  }

  /// Retourne le type de contenu
  String getType() {
    if (this is Movie) {
      return 'film';
    } else if (this is Series) {
      return 'serie';
    }
    return 'unknown';
  }
}
