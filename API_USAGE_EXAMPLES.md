# NEO-Stream API - Exemples d'Utilisation Complets

## 🚀 Démarrage Rapide

### Initialisation
```dart
import 'package:neostream/data/services/zenix_api_service.dart';

// Créer l'instance API
final zenixApi = ZenixApi();
final api = zenixApi.api;

// À la fin, nettoyer
zenixApi.dispose();
```

## 📺 Exemples Films

### 1. Charger tous les films avec pagination
```dart
Future<void> loadMovies() async {
  try {
    // Première page
    final response = await api.getMovies(limit: 50, offset: 0);
    
    print('Total: ${response.total}');
    print('Films reçus: ${response.count}');
    
    for (final film in response.results) {
      print('${film.title} - ${film.rating}');
    }
    
    // Charger page suivante
    final page2 = await api.getMovies(limit: 50, offset: 50);
  } catch (e) {
    print('Erreur: $e');
  }
}
```

### 2. Rechercher un film
```dart
Future<void> searchMovie() async {
  final results = await api.search(q: 'batman');
  
  for (final result in results.data) {
    print('${result['title']} (${result['year']})');
    print('  Genres: ${result['genres'].join(', ')}');
    print('  Note: ${result['rating']}');
  }
}
```

### 3. Recherche avancée avec filtres
```dart
Future<void> advancedMovieSearch() async {
  final results = await api.search(
    q: 'batman',
    type: 'film',
    genre: 'action',
    director: 'Christopher Nolan',
    yearMin: 2000,
    yearMax: 2024,
    ratingMin: 7.0,
    quality: 'HD',
    limit: 20,
  );
  
  print('Trouvé ${results.total} films');
  for (final film in results.data) {
    print('${film['title']} - ${film['directors'].join(", ")}');
  }
}
```

### 4. Filtrer films par genre
```dart
Future<void> actionMovies() async {
  final filtered = await api.filter(
    type: 'film',
    genre: 'action',
    ratingMin: 7.0,
    sortBy: 'rating',
    sortOrder: 'desc',
    limit: 10,
  );
  
  print('Top ${filtered.count} films d\'action:');
  for (final film in filtered.data) {
    print('  ${film['title']} - ${film['rating']}');
  }
}
```

### 5. Meilleurs films
```dart
Future<void> topMovies() async {
  final top = await api.getTopRated(
    type: 'film',
    minRating: 8.0,
    limit: 10,
  );
  
  for (var i = 0; i < top.results.length; i++) {
    final film = top.results[i];
    print('${i + 1}. ${film['title']} - ${film['rating']}');
  }
}
```

### 6. Films récents
```dart
Future<void> recentMovies() async {
  final recent = await api.getRecent(
    type: 'film',
    year: '2024',
    limit: 20,
  );
  
  print('${recent.count} nouveaux films en 2024');
}
```

### 7. Films aléatoires
```dart
Future<void> randomMovies() async {
  final random = await api.getRandom(
    type: 'film',
    genre: 'action',
    count: 5,
  );
  
  print('5 films d\'action aléatoires:');
  for (final film in random.results) {
    print('  - ${film['title']}');
  }
}
```

## 📺 Exemples Séries

### 1. Charger toutes les séries
```dart
Future<void> loadSeries() async {
  final response = await api.getSeries(limit: 30, offset: 0);
  
  print('Total: ${response.total} séries');
  
  for (final serie in response.results) {
    print('${serie['title']} - ${serie['seasons_count']} saisons');
  }
}
```

### 2. Rechercher une série
```dart
Future<void> searchSeries() async {
  final results = await api.search(
    q: 'stranger things',
    type: 'serie',
  );
  
  for (final serie in results.data) {
    print('${serie['title']} - ${serie['year']}');
  }
}
```

### 3. Meilleures séries
```dart
Future<void> topSeries() async {
  final top = await api.getTopRated(
    type: 'serie',
    minRating: 8.0,
    limit: 5,
  );
  
  for (final serie in top.results) {
    print('${serie['title']} - ${serie['rating']}');
  }
}
```

### 4. Obtenir tous les épisodes d'une série
```dart
Future<void> getSeriesEpisodes() async {
  final episodes = await api.getEpisodes('seriesId');
  
  print('${episodes.totalEpisodes} épisodes en ${episodes.seriesTitle}');
  
  for (final ep in episodes.episodes) {
    print('S${ep.season}E${ep.episode}: ${ep.title}');
  }
}
```

### 5. Obtenir les épisodes d'une saison
```dart
Future<void> getSeasonEpisodes() async {
  final season = await api.getEpisodes(
    'seriesId',
    season: 1,
  );
  
  print('${season.episodes.length} épisodes en saison 1');
  for (final ep in season.episodes) {
    print('Épisode ${ep.episode}: ${ep.title}');
    print('  ${ep.synopsis}');
  }
}
```

## 🎭 Exemples par Acteur/Réalisateur

### 1. Tous les films d'un acteur
```dart
Future<void> actorFilmography() async {
  final filmography = await api.getByActor('Tom Cruise');
  
  print('Films avec Tom Cruise:');
  for (final film in filmography.results) {
    print('  ${film['title']} (${film['year']})');
  }
}
```

### 2. Films d'un réalisateur
```dart
Future<void> directorWorks() async {
  final works = await api.getByDirector('Christopher Nolan');
  
  print('Films de Christopher Nolan:');
  for (final film in works.results) {
    print('  ${film['title']} - ${film['year']}');
  }
}
```

### 3. Rechercher des acteurs
```dart
Future<void> searchActors() async {
  final actors = await api.getActors(
    q: 'tom',
    limit: 20,
  );
  
  print('Acteurs trouvés:');
  for (final actor in actors.data) {
    print('  ${actor.name} (${actor.count} films)');
  }
}
```

### 4. Suggestions d'acteurs pour autocomplétion
```dart
Future<void> actorAutoComplete() async {
  final suggestions = await api.suggestActors(
    q: 'chris',
    limit: 5,
  );
  
  print('Suggestions:');
  for (final name in suggestions.suggestions) {
    print('  - $name');
  }
}
```

## 🔍 Exemples Recherche & Autocomplétion

### 1. Autocomplétion simple
```dart
Future<void> autoComplete() async {
  final suggestions = await api.autocomplete(
    q: 'bat',
    limit: 10,
  );
  
  print('Suggestions pour "bat":');
  for (final suggestion in suggestions.suggestions) {
    print('  ${suggestion['title']}');
  }
}
```

### 2. Recherche multi-catégorie
```dart
Future<void> multiCategorySearch() async {
  final results = await api.multiSearch(
    q: 'batman',
    limit: 5,
  );
  
  // Films
  print('Films:');
  for (final film in results.results['films']['data'] ?? []) {
    print('  ${film['title']}');
  }
  
  // Séries
  print('Séries:');
  for (final serie in results.results['series']['data'] ?? []) {
    print('  ${serie['title']}');
  }
  
  // Acteurs
  print('Acteurs:');
  for (final actor in results.results['actors']['data'] ?? []) {
    print('  ${actor['name']}');
  }
}
```

### 3. Suggestions rapides pour barre de recherche
```dart
// Dans un TextFormField avec onChanged
TextField(
  onChanged: (query) {
    if (query.length > 2) {
      _getSuggestions(query);
    }
  },
)

Future<void> _getSuggestions(String query) async {
  final suggestions = await api.quickSuggestions(query);
  
  // Afficher suggestions dans dropdown
  setState(() {
    _suggestions = suggestions;
  });
}
```

## 💎 Exemples Métadonnées

### 1. Obtenir tous les genres
```dart
Future<void> getGenres() async {
  final genres = await api.getGenres();
  
  print('Genres disponibles:');
  for (final genre in genres.genres) {
    print('  ${genre.name} (${genre.count} films)');
  }
}
```

### 2. Obtenir les acteurs populaires
```dart
Future<void> popularActors() async {
  final actors = await api.getActors(limit: 50);
  
  print('Top 50 acteurs:');
  for (final actor in actors.data) {
    print('  ${actor.name} - ${actor.count} films');
  }
}
```

### 3. Obtenir les réalisateurs populaires
```dart
Future<void> popularDirectors() async {
  final directors = await api.getDirectors(limit: 50);
  
  print('Top réalisateurs:');
  for (final director in directors.data) {
    print('  ${director.name} - ${director.count} films');
  }
}
```

## 📄 Exemples Détails Complets

### 1. Obtenir tous les détails d'un film
```dart
Future<void> getMovieDetails() async {
  final movie = await api.getItemDetails('movieId');
  
  print('=== ${movie.title} ===');
  print('Titre original: ${movie.originalTitle}');
  print('Année: ${movie.releaseDate}');
  print('Note: ${movie.rating}');
  print('Genres: ${movie.genres.join(", ")}');
  print('Réalisateur: ${movie.director}');
  print('Acteurs: ${movie.actors.join(", ")}');
  print('Qualité: ${movie.quality}');
  print('Version: ${movie.version}');
  print('Langage: ${movie.language}');
  print('');
  print('Synopsis:');
  print(movie.synopsis);
  print('');
  print('Liens streaming:');
  for (final link in movie.watchLinks) {
    print('  ${link.server}: ${link.url}');
  }
}
```

### 2. Obtenir tous les détails d'une série
```dart
Future<void> getSeriesDetails() async {
  final series = await api.getSeriesDetails('seriesId');
  
  print('=== ${series.title} ===');
  print('Saisons: ${series.seasons_count}');
  print('Épisodes: ${series.episodes.length}');
  
  // Afficher par saison
  var currentSeason = 0;
  for (final ep in series.episodes) {
    if (ep.season != currentSeason) {
      currentSeason = ep.season;
      print('');
      print('--- Saison $currentSeason ---');
    }
    print('E${ep.episode}: ${ep.title}');
  }
}
```

### 3. Obtenir les liens de streaming
```dart
Future<void> getStreamLinks() async {
  final links = await api.getWatchLinks('itemId');
  
  print('Liens pour: ${links.title}');
  for (final link in links.watchLinks) {
    print('  ${link.server}: ${link.url}');
  }
  
  // Trouver le meilleur serveur
  final bestServer = await api.getBestStreamServer('itemId');
  if (bestServer != null) {
    print('Meilleur serveur: ${bestServer.server}');
    launchURL(bestServer.url);
  }
}
```

## 🎯 Cas d'Usage Avancés

### 1. Page de Découverte
```dart
Future<void> discoveryPage() async {
  // Top films
  final topMovies = await api.discoverTopMovies(minRating: 8.0);
  
  // Nouveaux films
  final newMovies = await api.discoverNewMovies();
  
  // Top séries
  final topSeries = await api.discoverTopSeries();
  
  // Films aléatoires d'action
  final randomAction = await api.discoverRandom(
    type: 'film',
    genre: 'action',
  );
  
  // Afficher tout dans la UI
  // ...
}
```

### 2. Page de Recherche Avancée
```dart
class AdvancedSearchState extends State {
  String? selectedType;
  String? selectedGenre;
  String? selectedActor;
  String? selectedYear;
  double? minRating;
  
  Future<void> search() async {
    final results = await api.advancedFilter(
      type: selectedType,
      genre: selectedGenre,
      actor: selectedActor,
      year: selectedYear,
      ratingMin: minRating,
      sortBy: 'rating',
      sortOrder: 'desc',
      limit: 50,
    );
    
    setState(() {
      searchResults = results.data;
    });
  }
}
```

### 3. Lecteur Vidéo avec Épisodes
```dart
Future<void> playSeriesEpisode() async {
  // Charger les épisodes
  final episodes = await api.getEpisodes('seriesId', season: 1);
  
  // Utilisateur sélectionne un épisode
  final selectedEpisode = episodes.episodes[0];
  
  // Obtenir les liens
  final links = await api.getWatchLinks(selectedEpisode.url);
  
  // Lancer le meilleur serveur
  final bestLink = links.watchLinks.first;
  
  // Ouvrir le lecteur vidéo
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VideoPlayer(url: bestLink.url),
    ),
  );
}
```

### 4. Système de Recommandations
```dart
Future<void> getRecommendations() async {
  // Basé sur le genre préféré
  final recommendations = await api.getRandom(
    genre: userPreferredGenre,
    type: 'film',
    count: 10,
  );
  
  // Basé sur la note minimale
  final topRated = await api.getTopRated(
    minRating: 8.0,
    limit: 10,
  );
  
  // Mélanger et afficher
  // ...
}
```

## ⚡ Optimisations

### 1. Mise en Cache Local
```dart
class CachedApiService {
  final api = ZenixApi().api;
  final _cache = <String, dynamic>{};
  
  Future<dynamic> cachedCall(
    String key,
    Future<dynamic> Function() apiCall,
  ) async {
    if (_cache.containsKey(key)) {
      return _cache[key];
    }
    
    final result = await apiCall();
    _cache[key] = result;
    return result;
  }
  
  // Utilisation
  Future<void> getGenresWithCache() async {
    final genres = await cachedCall(
      'genres',
      () => api.getGenres(),
    );
  }
}
```

### 2. Pagination Efficace
```dart
class PaginatedList {
  final api = ZenixApi().api;
  List<dynamic> items = [];
  int offset = 0;
  const limit = 50;
  bool hasMore = true;
  
  Future<void> loadMore() async {
    if (!hasMore) return;
    
    final response = await api.getMovies(
      limit: limit,
      offset: offset,
    );
    
    items.addAll(response.results);
    offset += limit;
    hasMore = offset < response.total;
  }
}
```

### 3. Parallel Requests
```dart
Future<void> loadDashboard() async {
  // Charger plusieurs endpoints en parallèle
  final results = await Future.wait([
    api.getTopRated(type: 'film', minRating: 8.0),
    api.getRecent(type: 'film'),
    api.getGenres(),
    api.getActors(limit: 20),
  ]);
  
  final topFilms = results[0];
  final newFilms = results[1];
  final genres = results[2];
  final actors = results[3];
  
  // Afficher tout
}
```

## 🔐 Gestion d'Erreurs

```dart
Future<void> safeApiCall() async {
  try {
    final results = await api.search(q: 'batman');
  } on DioException catch (e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      print('Timeout de connexion');
    } else if (e.type == DioExceptionType.receiveTimeout) {
      print('Timeout de réception');
    } else if (e.response?.statusCode == 404) {
      print('Ressource non trouvée');
    } else {
      print('Erreur API: ${e.message}');
    }
  } catch (e) {
    print('Erreur inattendue: $e');
  }
}
```
