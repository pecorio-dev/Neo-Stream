# NEO-Stream API Migration Summary

## 🎯 Vue d'Ensemble

Le service API NEO-Stream a été complètement mis à jour pour utiliser le **port 25825** au lieu de 25823, avec des améliorations majeures de fonctionnalités, de métadonnées et de endpoints.

---

## 🔄 Changements Principaux

### 1. Port API
- **Ancien**: `http://node.zenix.sg:25823`
- **Nouveau**: `http://node.zenix.sg:25825`

### 2. Endpoints Restructurés

#### Avant (Port 25823)
```
GET  /movies
GET  /series
GET  /series/compact
GET  /search
GET  /searchadvanced
GET  /movie/{id}
GET  /series/{id}
GET  /genres
GET  /stats
POST /reload
```

#### Après (Port 25825)
```
GET  /films                          # Liste des films
GET  /series                         # Liste des séries
GET  /search                         # Recherche avancée
GET  /filter                         # Filtrage sans recherche
GET  /autocomplete                   # Autocomplétion
GET  /multi-search                   # Recherche multi-catégorie

GET  /genres                         # Genres avec compteurs
GET  /actors                         # Acteurs avec compteurs
GET  /directors                      # Réalisateurs avec compteurs
GET  /years                          # Années disponibles
GET  /qualities                      # Qualités disponibles

GET  /by-genre/{genre}               # Items par genre
GET  /by-actor/{actor}               # Items par acteur
GET  /by-director/{director}         # Items par réalisateur
GET  /by-year/{year}                 # Items par année

GET  /top-rated                      # Meilleurs items
GET  /recent                         # Items récents
GET  /random                         # Items aléatoires

GET  /item/{id}                      # Détails complets
GET  /item/{id}/episodes             # Épisodes d'une série
GET  /item/{id}/watch-links          # Liens de streaming
GET  /item/{id}/episode/{s}/{e}      # Détails d'un épisode

GET  /suggest/actors                 # Suggestions d'acteurs
GET  /suggest/directors              # Suggestions de réalisateurs
GET  /suggest/genres                 # Suggestions de genres

GET  /health                         # Santé de l'API
GET  /stats                          # Statistiques
```

---

## 📊 Nouvelles Métadonnées Extraites

### Films & Séries
- ✅ `id` - Identifiant unique
- ✅ `title` - Titre français
- ✅ `original_title` - Titre original
- ✅ `type` - 'film' ou 'serie'
- ✅ `year` - Année de sortie
- ✅ `rating` - Note (ex: 7.4/10)
- ✅ `rating_max` - Note maximale (10)
- ✅ `genres` - Liste des genres
- ✅ `directors` - Liste des réalisateurs
- ✅ `actors` - Liste des acteurs
- ✅ `quality` - HD, CAM, etc.
- ✅ `version` - VF, VOSTFR
- ✅ `language` - Langue d'origine
- ✅ `duration` - Durée en minutes (films)
- ✅ `synopsis` - Description détaillée
- ✅ `poster` - URL du poster
- ✅ `watch_links` - Liens de streaming

### Séries Additionnelles
- ✅ `seasons` - URLs des saisons
- ✅ `seasons_count` - Nombre de saisons
- ✅ `episodes_count` - Nombre total d'épisodes
- ✅ `episodes` - Liste complète des épisodes

### Épisodes
- ✅ `season` - Numéro de saison
- ✅ `episode` - Numéro d'épisode
- ✅ `title` - Titre de l'épisode
- ✅ `original_title` - Titre original
- ✅ `synopsis` - Description
- ✅ `quality` - Qualité
- ✅ `directors` - Réalisateurs
- ✅ `actors` - Acteurs
- ✅ `watch_links` - Liens streaming

---

## 🚀 Nouvelles Fonctionnalités

### 1. Recherche Avancée
```dart
// Avant: paramètres limités
await api.search(query: 'batman');

// Après: filtres complets
await api.search(
  q: 'batman',
  type: 'film',
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
);
```

### 2. Filtrage Sans Recherche Textuelle
```dart
// Nouveau: filtrer sans requête de texte
await api.filter(
  genre: 'action',
  actor: 'Tom Cruise',
  ratingMin: 8.0,
  sortBy: 'rating',
  sortOrder: 'desc',
);
```

### 3. Autocomplétion
```dart
// Suggestions rapides pour barre de recherche
await api.autocomplete(q: 'bat', limit: 10);

// Suggestions par catégorie
await api.suggestActors(q: 'tom', limit: 10);
await api.suggestDirectors(q: 'spiel', limit: 10);
await api.suggestGenres(q: 'act', limit: 10);
```

### 4. Recherche Multi-Catégorie
```dart
// Une seule requête pour films, séries, acteurs, genres, réalisateurs
await api.multiSearch(q: 'batman', limit: 10);
```

### 5. Parcourir par Catégorie
```dart
// Nouveaux endpoints directs
await api.getByGenre('Action');
await api.getByActor('Tom Cruise');
await api.getByDirector('Christopher Nolan');
await api.getByYear('2024');
```

### 6. Métadonnées Énumérées
```dart
// Obtenir les listes avec compteurs
await api.getGenres();
await api.getActors();
await api.getDirectors();
await api.getYears();
await api.getQualities();
```

### 7. Découverte
```dart
// Top notés
await api.getTopRated(type: 'film', minRating: 7.0);

// Récents
await api.getRecent(type: 'film', year: '2024');

// Aléatoires
await api.getRandom(type: 'film', genre: 'action', count: 10);
```

---

## 📱 Code Migration Guide

### Avant (Port 25823)
```dart
class ZenixApiService {
  static const String baseUrl = 'http://node.zenix.sg:25823';
  
  Future<SearchResponse> search({
    required String query,
    String type = 'all',
    String fields = 'title,original_title',
    bool consolidated = true,
  }) async {
    // Logique simple
  }
}
```

### Après (Port 25825)
```dart
class ZenixApiService {
  static const String baseUrl = 'http://node.zenix.sg:25825';
  
  Future<SearchResponse> search({
    required String q,
    String? type,
    String? genre,
    String? actor,
    String? director,
    String? year,
    int? yearMin,
    int? yearMax,
    double? ratingMin,
    double? ratingMax,
    String? quality,
    String? version,
    String? language,
    int limit = 50,
    int offset = 0,
  }) async {
    // Logique enrichie avec tous les filtres
  }
  
  // Nouveau: filtrage sans recherche
  Future<FilterResponse> filter({...}) async { }
  
  // Nouveau: autocomplétion
  Future<AutocompleteResponse> autocomplete({...}) async { }
  
  // Nouveau: recherche multi-catégorie
  Future<MultiSearchResponse> multiSearch({...}) async { }
  
  // Nouveau: parcours par catégorie
  Future<ApiResponse<Movie>> getByGenre(...) async { }
  Future<ApiResponse<Movie>> getByActor(...) async { }
  Future<ApiResponse<Movie>> getByDirector(...) async { }
  Future<ApiResponse<Movie>> getByYear(...) async { }
  
  // Nouveau: métadonnées
  Future<ActorsResponse> getActors({...}) async { }
  Future<DirectorsResponse> getDirectors({...}) async { }
  
  // Nouveau: épisodes et liens
  Future<EpisodesResponse> getEpisodes(...) async { }
  Future<WatchLinksResponse> getWatchLinks(...) async { }
}
```

---

## 🔧 Extensions Helper Nouvelles

```dart
// Recherche simple
await api.quickSearch('batman');

// Recherche par catégorie
await api.searchByActor('Tom Cruise');
await api.searchByDirector('Nolan');
await api.searchByGenre('Action');

// Filtres rapides
await api.actionMovies();
await api.topSeries();
await api.hdFilmsCurrentYear('2024');

// Découverte
await api.discoverTopMovies();
await api.discoverNewSeries();
await api.discoverRandom(genre: 'action');

// Suggestions
await api.suggestActorNames('tom');
await api.suggestDirectorNames('nolan');

// Métadonnées
await api.getAllGenres();
await api.getPopularActors();
await api.searchActors('Tom');

// Séries
await api.getSeriesAllEpisodes('seriesId');
await api.getSeasonEpisodes('seriesId', 1);

// Streaming
await api.getStreamLinks('itemId');
await api.getBestStreamServer('itemId');
await api.getEpisodeStreamLinks('seriesId', 1, 1);
```

---

## 📈 Performance Améliorations

### Scraper Python
- **Concurrence**: 900 requêtes/listing, 600 détails, 450 épisodes
- **Vitesse**: 131 req/sec pour ~2000 films
- **Métadonnées complètes**: Acteurs, réalisateurs, genres, synopsis, qualité, version, langage
- **Fusion de données**: Écrase sans supprimer les fichiers JSON

### Flutter App
- **Extensions API**: Accès simplifié aux endpoints
- **Suggestions en temps réel**: Autocomplétion rapide
- **Parallélisation**: Requêtes parallèles optimisées
- **Cache local**: Support de mise en cache côté client
- **Gestion d'erreurs**: Intercepteurs Dio configurés

---

## 🔐 Response Models

### Nouveaux Response Types
```dart
FilterResponse          // Résultats de filtrage
AutocompleteResponse    // Suggestions d'autocomplétion
MultiSearchResponse     // Résultats multi-catégorie
ActorsResponse          // Liste des acteurs avec compteurs
DirectorsResponse       // Liste des réalisateurs
GenreItem              // Genre avec compteur
ActorItem              // Acteur avec compteur
DirectorItem           // Réalisateur avec compteur
EpisodesResponse       // Tous les épisodes d'une série
Episode                // Détails d'un épisode
WatchLinksResponse     // Liens de streaming
SuggestionsResponse    // Suggestions (acteurs/réalisateurs/genres)
HealthResponse         // Santé de l'API
```

---

## 📚 Documentation Complète

### Fichiers Créés
1. **API_INTEGRATION_GUIDE.md** - Guide d'intégration complet
2. **API_USAGE_EXAMPLES.md** - Exemples d'utilisation détaillés
3. **api_extensions/api_helpers.dart** - Extensions helper pour accès facile
4. **zenix_api_service.dart** - Service API entièrement refondu

### Points Clés de Documentation
- Configuration rapide
- Tous les endpoints disponibles
- Cas d'usage courants
- Modèles de données complets
- Gestion d'erreurs
- Tips et astuces
- Dépannage

---

## ✅ Checklist Migration

- [x] Mettre à jour le port (25825)
- [x] Refactoriser les endpoints
- [x] Ajouter filtrage avancé
- [x] Implémenter autocomplétion
- [x] Ajouter recherche multi-catégorie
- [x] Créer endpoints de parcours par catégorie
- [x] Ajouter métadonnées énumérées
- [x] Implémenter découverte
- [x] Créer extensions helper
- [x] Documenter tous les endpoints
- [x] Fournir exemples complets
- [x] Gérer les erreurs Dio
- [x] Supporter pagination complète
- [x] Cacher les réponses

---

## 🎓 Formation Rapide

Pour commencer:

```dart
// 1. Initialiser
final api = ZenixApi().api;

// 2. Rechercher
final results = await api.search(q: 'batman');

// 3. Filtrer
final filtered = await api.filter(
  type: 'film',
  genre: 'action',
  ratingMin: 7.0,
);

// 4. Découvrir
final top = await api.getTopRated();

// 5. Détails
final item = await api.getItemDetails('itemId');

// 6. Épisodes (si série)
final episodes = await api.getEpisodes('seriesId');

// 7. Liens
final links = await api.getWatchLinks('itemId');
```

---

## 🆘 Support

Pour toute question ou problème:
1. Consulter `API_INTEGRATION_GUIDE.md`
2. Vérifier `API_USAGE_EXAMPLES.md`
3. Utiliser les extensions dans `api_helpers.dart`
4. Vérifier `/health` endpoint pour la santé du serveur

---

## 📊 Statistiques

### Données Scrapées (par scrape complet)
- **Films**: ~2000
- **Séries**: ~200
- **Épisodes**: ~8733
- **Liens streaming**: ~18439+
- **Temps**: ~2-3 minutes
- **Vitesse**: ~130 req/sec

### Endpoint Totaux
- **Endpoints publics**: 25+
- **Extensions helper**: 40+
- **Modèles de réponse**: 15+

---

**Version**: 2.0 (Migration 25823 → 25825)  
**Date**: 2024  
**Status**: ✅ Production Ready