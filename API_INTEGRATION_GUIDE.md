# NEO-Stream API Integration Guide

## 🚀 Configuration Rapide

### 1. Base URL
```dart
// Port: 25825
http://node.zenix.sg:25825
```

### 2. Initialisation du Service
```dart
import 'package:neostream/data/services/zenix_api_service.dart';

// Créer l'instance
final zenixApi = ZenixApi();

// Accéder au service
final apiService = zenixApi.api;
```

### 3. Fermeture Propre
```dart
zenixApi.dispose();
```

---

## 📋 Endpoints Disponibles

### A. Listes Principales

#### Récupérer les Films
```dart
final response = await apiService.getMovies(
  limit: 50,
  offset: 0,
);
// Retourne: ApiResponse<Movie>
```

#### Récupérer les Séries
```dart
final response = await apiService.getSeries(
  limit: 50,
  offset: 0,
);
// Retourne: ApiResponse<Series>
```

---

### B. Recherche

#### Recherche Simple
```dart
final results = await apiService.quickSearch('batman', limit: 20);
// Retourne: SearchResponse
```

#### Recherche Avancée (avec tous les filtres)
```dart
final results = await apiService.search(
  q: 'batman',
  type: 'film',                    // 'film', 'serie', ou null (tous)
  genre: 'action',
  actor: 'Christian Bale',
  director: 'Christopher Nolan',
  year: '2008',
  yearMin: 2000,
  yearMax: 2024,
  ratingMin: 7.0,
  ratingMax: 10.0,
  quality: 'HD',
  version: 'VF',
  language: 'Anglais',
  limit: 50,
  offset: 0,
);
```

#### Autocomplétion
```dart
// Autocomplétion rapide pour la barre de recherche
final suggestions = await apiService.autocomplete(
  q: 'bat',
  type: null,  // optionnel: 'film' ou 'serie'
  limit: 10,
);
// Retourne: AutocompleteResponse avec suggestions

// Ou avec extension
final suggestions = await apiService.quickSuggestions('bat');
```

#### Recherche Multi-Catégorie
```dart
// Retourne films, séries, acteurs, genres, réalisateurs
final results = await apiService.multiSearch(
  q: 'batman',
  limit: 10,  // par catégorie
);
// Retourne: MultiSearchResponse
```

---

### C. Filtrage Avancé

#### Filtrer sans Recherche Textuelle
```dart
final results = await apiService.filter(
  type: 'film',
  genre: 'action',
  actor: 'Tom Cruise',
  director: 'Steven Spielberg',
  year: '2024',
  yearMin: 2020,
  yearMax: 2024,
  ratingMin: 7.0,
  ratingMax: 10.0,
  quality: 'HD',
  version: 'VF',
  language: 'Anglais',
  sortBy: 'title',        // 'title', 'year', 'rating'
  sortOrder: 'asc',       // 'asc' ou 'desc'
  limit: 50,
  offset: 0,
);
// Retourne: FilterResponse
```

---

### D. Parcourir par Catégorie

#### Par Genre
```dart
final films = await apiService.getByGenre(
  'Action',
  type: 'film',
  limit: 50,
);
```

#### Par Acteur
```dart
final filmography = await apiService.getByActor(
  'Tom Cruise',
  type: 'film',
);
```

#### Par Réalisateur
```dart
final works = await apiService.getByDirector(
  'Christopher Nolan',
  type: 'film',
);
```

#### Par Année
```dart
final films2024 = await apiService.getByYear(
  '2024',
  type: 'film',
);
```

---

### E. Découverte

#### Top Notés
```dart
final topMovies = await apiService.getTopRated(
  type: 'film',
  minRating: 7.0,
  limit: 20,
);
```

#### Récents
```dart
final newReleases = await apiService.getRecent(
  type: 'film',
  year: '2024',
  limit: 20,
);
```

#### Aléatoires
```dart
final randomContent = await apiService.getRandom(
  type: 'film',
  genre: 'action',
  count: 10,
);
```

---

### F. Métadonnées

#### Liste des Genres
```dart
final genres = await apiService.getGenres(
  type: 'film',  // optionnel
);
// Retourne: GenresResponse avec compteurs
```

#### Liste des Acteurs
```dart
final actors = await apiService.getActors(
  type: 'film',
  q: 'tom',      // recherche optionnelle
  limit: 100,
);
// Retourne: ActorsResponse
```

#### Liste des Réalisateurs
```dart
final directors = await apiService.getDirectors(
  type: 'film',
  q: 'spielberg',
  limit: 100,
);
```

---

### G. Suggestions pour Autocomplétion

#### Acteurs
```dart
final suggestions = await apiService.suggestActors(
  q: 'tom',
  limit: 10,
);
```

#### Réalisateurs
```dart
final suggestions = await apiService.suggestDirectors(
  q: 'spiel',
  limit: 10,
);
```

#### Genres
```dart
final suggestions = await apiService.suggestGenres(
  q: 'act',
  limit: 10,
);
```

---

### H. Détails Complets

#### Détails d'un Film/Série
```dart
final item = await apiService.getItemDetails('itemId');
// Retourne: Movie avec toutes les métadonnées
```

#### Épisodes d'une Série
```dart
// Tous les épisodes
final response = await apiService.getEpisodes('seriesId');

// Épisodes d'une saison spécifique
final response = await apiService.getEpisodes(
  'seriesId',
  season: 2,
);
// Retourne: EpisodesResponse
```

#### Liens de Streaming
```dart
final links = await apiService.getWatchLinks('itemId');
// Retourne: WatchLinksResponse avec liste de WatchLink
```

---

## 🎯 Cas d'Usage Courants

### 1. Barre de Recherche avec Autocomplétion
```dart
// En temps réel pendant la frappe
final suggestions = await apiService.quickSuggestions('bat');
// Affiche: ['Batman', 'Batman Begins', 'Batman Returns', ...]
```

### 2. Page de Détails avec Tous les Infos
```dart
final complete = await apiService.getItemComplete('itemId');
// Contient: détails, épisodes (si série), liens streaming
```

### 3. Filtrage Avancé dans une UI
```dart
// L'utilisateur sélectionne des filtres
final filtered = await apiService.advancedFilter(
  type: selectedType,
  genre: selectedGenre,
  actor: selectedActor,
  ratingMin: selectedMinRating,
  sortBy: 'rating',
  sortOrder: 'desc',
);
```

### 4. Découverte Personnalisée
```dart
// Meilleurs films récents
final topNew = await apiService.discoverNewMovies(limit: 20);

// Top séries
final topSeries = await apiService.discoverTopSeries(minRating: 8.0);

// Contenu aléatoire du genre préféré
final random = await apiService.discoverRandom(
  genre: 'action',
  type: 'film',
  count: 10,
);
```

### 5. Filmographie Complète d'un Acteur
```dart
final filmography = await apiService.getByActor('Tom Cruise');
// Liste tous les films/séries avec Tom Cruise
```

---

## 📊 Modèles de Données

### Movie
```dart
Movie(
  id: String,
  url: String,
  title: String,
  originalTitle: String,
  type: String,           // 'film' ou 'serie'
  rating: String,         // ex: "8.5/10"
  releaseDate: String,    // ex: "2024"
  quality: String,        // 'HD', 'CAM', etc.
  version: String,        // 'VF', 'VOSTFR'
  language: String,       // 'Anglais', 'Français'
  genres: List<String>,
  director: String,
  actors: List<String>,
  synopsis: String,
  watchLinks: List<WatchLink>,
  poster: String,
)
```

### WatchLink
```dart
WatchLink(
  url: String,            // URL du lecteur
  server: String,         // 'VIDZY', 'UQLOAD', etc.
)
```

### Episode
```dart
Episode(
  url: String,
  season: int,
  episode: int,
  title: String,
  synopsis: String,
  quality: String,
  watchLinks: List<WatchLink>,
)
```

---

## ⚙️ Configuration Avancée

### Custom Dio Configuration
```dart
final zenixApi = ZenixApi();
// L'API gère automatiquement:
// - Timeout: 15000ms
// - Headers: Content-Type, User-Agent, etc.
// - Intercepteurs: logs et gestion d'erreurs
```

### Gestion des Erreurs
```dart
try {
  final results = await apiService.search(q: 'batman');
} on DioException catch (e) {
  print('Erreur API: ${e.message}');
  if (e.type == DioExceptionType.connectionTimeout) {
    print('Timeout de connexion');
  }
} catch (e) {
  print('Erreur: $e');
}
```

---

## 🔍 Parametres de Pagination

Tous les endpoints qui retournent des listes supportent:
```dart
limit: 50,      // Nombre de résultats (1-200)
offset: 0,      // Décalage pour la pagination
```

Exemple:
```dart
// Page 1
final page1 = await apiService.getMovies(limit: 50, offset: 0);

// Page 2
final page2 = await apiService.getMovies(limit: 50, offset: 50);

// Page 3
final page3 = await apiService.getMovies(limit: 50, offset: 100);
```

---

## 💡 Tips & Astuces

1. **Utiliser les Extensions** pour plus de clarté:
   ```dart
   // Au lieu de
   await apiService.search(q: 'batman', actor: 'christian bale');
   
   // Utiliser
   await apiService.searchByActor('Christian Bale');
   ```

2. **Cache Local** pour les métadonnées qui ne changent pas souvent:
   ```dart
   // Genres peuvent être mis en cache
   final genres = await apiService.getGenres();
   // Utiliser localement sans refaire la requête
   ```

3. **Pagination Efficace**:
   ```dart
   // Charger au fur et à mesure au lieu de tout charger
   int currentOffset = 0;
   const limit = 50;
   
   final firstBatch = await apiService.getMovies(limit: limit);
   // Quand utilisateur scroll
   currentOffset += limit;
   final nextBatch = await apiService.getMovies(offset: currentOffset, limit: limit);
   ```

4. **Multi-Search pour l'expérience utilisateur**:
   ```dart
   // Une seule requête pour obtenir films, séries, acteurs, etc.
   final results = await apiService.multiSearch(q: 'batman');
   // Afficher plusieurs sections à la fois
   ```

---

## 📝 Notes Importantes

- **Port**: 25825 (non 25823)
- **Base URL**: http://node.zenix.sg:25825
- **Timeout**: 15 secondes par défaut
- **Rate Limit**: Respecter les limites du serveur
- **User-Agent**: Automatiquement défini à "NEO-STREAM/1.0.0 (Flutter)"

---

## 🆘 Dépannage

### Erreur de Connexion
```
Vérifier: La connexion réseau, le pare-feu, l'URL correcte (port 25825)
```

### Timeout
```
Augmenter le timeout si la connexion est lente:
- Actuellement: 15000ms
- À ajuster dans ZenixApi._configureDio()
```

### Pas de Résultats
```
- Vérifier l'orthographe de la recherche
- Essayer avec des filtres moins restrictifs
- Vérifier que les données existent sur l'API
```

---

## 📚 Ressources

- [API Server](http://node.zenix.sg:25825)
- [Documentation FastAPI](http://node.zenix.sg:25825/docs)
- [Code Source](NEO-Stream/lib/data/services/)
