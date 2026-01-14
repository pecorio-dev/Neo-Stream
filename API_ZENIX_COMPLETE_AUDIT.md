# API Zenix Complete Audit - NEO-Stream

**Date**: 2024
**Version API**: 2.1.0
**Port**: 25825
**Base URL**: http://node.zenix.sg:25825

---

## 1. ANALYSE COMPLÈTE DE LA STRUCTURE API

### 1.1 Format de Réponse Standard

Tous les endpoints retournent un format cohérent:

```json
{
  "total": 1000,           // Nombre total d'items (sans pagination)
  "offset": 0,             // Position de départ
  "limit": 50,             // Nombre max par page
  "count": 50,             // Nombre réel d'items retournés
  "data": [...]            // Array des items
}
```

### 1.2 Structure des Items (Films et Séries)

#### Liste (optimize_item_list):
```json
{
  "id": "string",                    // URL slug ou titre en minuscules
  "title": "string",
  "original_title": "string | null",
  "type": "film" | "serie",
  "year": "string",                  // IMPORTANT: String, not int
  "poster": "string | null",
  "url": "string",
  "genres": ["string"],
  "rating": "number | null",         // Note entre 0-10
  "quality": "string | null",        // HD, SD, 4K, CAM, etc.
  "version": "string | null",        // VF, VOSTFR, TrueFrench, etc.
  "actors": ["string"],              // Top 5 pour la liste
  "directors": ["string"],
  "synopsis": "string",              // Tronqué à 200 chars
  "watch_links_count": "number",
  
  // Séries uniquement:
  "seasons_count": "number",
  "episodes_count": "number"
}
```

#### Détails complets (optimize_item_full):
```json
{
  "id": "string",
  "title": "string",
  "original_title": "string | null",
  "type": "film" | "serie",
  "year": "string",
  "genres": ["string"],
  "directors": ["string"],
  "actors": ["string"],              // Tous les acteurs
  "synopsis": "string",              // Complet
  "description": "string | null",
  "poster": "string | null",
  "rating": "number | null",
  "rating_max": 10,
  "quality": "string | null",
  "version": "string | null",
  "language": "string | null",
  "duration": "number | null",
  "url": "string",
  "watch_links": [
    {
      "server": "string",
      "url": "string",
      "quality": "string | null"
    }
  ],
  
  // Séries uniquement:
  "seasons": ["object"],             // Données saisonnières complètes
  "seasons_count": "number",
  "episodes_count": "number",
  "episodes": [
    {
      "url": "string",
      "season": "number",
      "episode": "number",
      "title": "string",
      "original_title": "string | null",
      "synopsis": "string",
      "quality": "string | null",
      "actors": ["string"],
      "directors": ["string"],
      "watch_links": [...]
    }
  ]
}
```

### 1.3 Response Models Manquants/Mal Typés

#### ✅ Implémentés correctement:
- `ApiResponse<T>` - Réponse générique paginée
- `Movie` - Modèle film
- `Series` - Modèle série
- `Episode` - Modèle épisode
- `WatchLink` - Lien de streaming
- `SearchResponse` - Résultats de recherche
- `HealthResponse` - Health check

#### ⚠️ À créer/corriger:
- `GenreItem` / `GenresResponse` ✓ Existe
- `ActorItem` / `ActorsResponse` ✓ Existe
- Response models pour /years, /qualities, /directors
- Response model pour /by-genre/{genre}, /by-actor/{actor}, etc.
- Response model pour /random
- Response model pour /autocomplete (corrections de typage)
- Response model pour /suggest/* endpoints
- Response model pour /multi-search
- Response model pour /item/{id}/episodes (correction)

---

## 2. ENDPOINTS DÉTAILLÉS - CHECKLIST DE CONFORMITÉ

### Endpoints Racine et Santé

#### ✅ GET `/`
- **Paramètres**: Aucun
- **Réponse**: Informations API + liste des endpoints
- **Statut Flutter**: OK

#### ✅ GET `/health`
- **Paramètres**: Aucun
- **Réponse**:
  ```json
  {
    "status": "ok",
    "timestamp": "ISO8601",
    "uptime_data": { "films": 0, "series": 0, "last_update": "ISO8601" },
    "is_scraping": false,
    "api_stats": { "requests_total": 0, "avg_response_time_ms": 0, "errors_total": 0 }
  }
  ```
- **Statut Flutter**: ✅ `HealthResponse.fromJson()` OK

---

### Endpoints de Données - Listes

#### ✅ GET `/films`
- **Paramètres**: 
  - `limit` (1-1000, défaut: null)
  - `offset` (≥0, défaut: 0)
  - `year` (string)
  - `sort` (title|year|watch_links)
- **Réponse**: `ApiResponse<Movie>`
- **Statut Flutter**: ✅ `getMovies()` OK

#### ✅ GET `/series`
- **Paramètres**: 
  - `limit` (1-1000, défaut: null)
  - `offset` (≥0, défaut: 0)
  - `year` (string)
  - `sort` (title|year|episodes)
- **Réponse**: `ApiResponse<Series>`
- **Statut Flutter**: ✅ `getSeries()` OK

---

### Endpoints de Recherche et Filtrage

#### ✅ GET `/search`
- **Paramètres**:
  - `q` (required, 1-100 chars)
  - `type` (film|serie)
  - `genre`, `actor`, `director` (string)
  - `year` (exact), `year_min`, `year_max` (int, 1900-2100)
  - `rating_min` (0-10), `quality` (string)
  - `limit` (50, 1-200), `offset` (0)
- **Réponse**:
  ```json
  {
    "query": "string",
    "filters": { ...applied filters... },
    "total": 0, "offset": 0, "limit": 50, "count": 0,
    "data": [Movie|Series array]
  }
  ```
- **Statut Flutter**: ✅ `search()` OK

#### ⚠️ GET `/filter`
- **Paramètres**: Identiques à /search mais sans `q`
- **Réponse**: Format similaire à /search
- **Statut Flutter**: ⚠️ `filter()` retourne `ApiResponse<dynamic>` - À typer correctement

#### ✅ GET `/by-genre/{genre}`
- **Paramètres**: 
  - `{genre}` (path param)
  - `type` (film|serie)
  - `limit` (50, 1-200)
  - `offset` (0)
- **Réponse**: `ApiResponse<Movie|Series>`
- **Statut Flutter**: ⚠️ `getByGenre()` retourne `dynamic` - À corriger

#### ✅ GET `/by-actor/{actor}`
- **Paramètres**: Identiques à /by-genre
- **Réponse**: `ApiResponse<Movie|Series>`
- **Statut Flutter**: ⚠️ `getByActor()` retourne `dynamic` - À corriger

#### ✅ GET `/by-director/{director}`
- **Paramètres**: Identiques à /by-genre
- **Réponse**: `ApiResponse<Movie|Series>`
- **Statut Flutter**: ⚠️ `getByDirector()` retourne `dynamic` - À corriger

#### ✅ GET `/by-year/{year}`
- **Paramètres**: Identiques à /by-genre
- **Réponse**: `ApiResponse<Movie|Series>`
- **Statut Flutter**: ⚠️ `getByYear()` retourne `dynamic` - À corriger

#### ✅ GET `/top-rated`
- **Paramètres**:
  - `type` (film|serie)
  - `min_rating` (7.0, 0-10)
  - `limit` (50, 1-200)
  - `offset` (0)
- **Réponse**: `ApiResponse<Movie|Series>`
- **Statut Flutter**: ⚠️ `getTopRated()` retourne `dynamic` - À corriger

#### ✅ GET `/recent`
- **Paramètres**:
  - `type` (film|serie)
  - `year` (défaut: année courante)
  - `limit` (50, 1-200)
  - `offset` (0)
- **Réponse**: `ApiResponse<Movie|Series>`
- **Statut Flutter**: ⚠️ `getRecent()` retourne `dynamic` - À corriger

#### ✅ GET `/random`
- **Paramètres**:
  - `type` (film|serie)
  - `genre` (optionnel)
  - `count` (10, 1-50)
- **Réponse**:
  ```json
  {
    "type_filter": "film|serie|null",
    "genre_filter": "string|null",
    "count": 0,
    "data": [Movie|Series array]
  }
  ```
- **Statut Flutter**: ⚠️ `getRandom()` retourne `List<dynamic>` - À corriger

---

### Endpoints Méta (Genres, Acteurs, etc.)

#### ✅ GET `/genres`
- **Paramètres**: `type` (film|serie)
- **Réponse**:
  ```json
  {
    "total": 0,
    "data": [
      { "name": "string", "count": 0 }
    ]
  }
  ```
- **Statut Flutter**: ✅ `getGenres()` retourne `GenresResponse`

#### ✅ GET `/actors`
- **Paramètres**: 
  - `type` (film|serie)
  - `q` (search string)
  - `limit` (100, 1-500)
- **Réponse**: Identique à /genres mais avec "actors"
- **Statut Flutter**: ✅ `getActors()` retourne `ActorsResponse`

#### ✅ GET `/directors`
- **Paramètres**: Identiques à /actors
- **Réponse**: Identique à /genres mais avec "directors"
- **Statut Flutter**: ⚠️ `getDirectors()` retourne `dynamic` - À typer

#### ✅ GET `/years`
- **Paramètres**: `type` (film|serie)
- **Réponse**:
  ```json
  {
    "total": 0,
    "data": [
      { "year": "string", "count": 0 }
    ]
  }
  ```
- **Statut Flutter**: ⚠️ `getYears()` retourne `dynamic` - À typer

#### ✅ GET `/qualities`
- **Paramètres**: `type` (film|serie)
- **Réponse**:
  ```json
  {
    "total": 0,
    "data": [
      { "quality": "string", "count": 0 }
    ]
  }
  ```
- **Statut Flutter**: ⚠️ `getQualities()` retourne `dynamic` - À typer

---

### Endpoints Autocomplétion et Suggestions

#### ✅ GET `/autocomplete`
- **Paramètres**:
  - `q` (required, 1-50 chars)
  - `type` (film|serie)
  - `limit` (10, 1-20)
- **Réponse**:
  ```json
  {
    "query": "string",
    "count": 0,
    "suggestions": [
      {
        "id": "string",
        "title": "string",
        "original_title": "string|null",
        "type": "film|serie",
        "year": "string|null",
        "poster": "string|null"
      }
    ]
  }
  ```
- **Statut Flutter**: ✅ `autocomplete()` retourne `AutocompleteResponse`

#### ✅ GET `/suggest/actors`
- **Paramètres**:
  - `q` (required, 2-50 chars)
  - `limit` (10, 1-30)
- **Réponse**:
  ```json
  {
    "query": "string",
    "count": 0,
    "suggestions": ["string"]
  }
  ```
- **Statut Flutter**: ✅ `suggestActors()` retourne `List<String>`

#### ✅ GET `/suggest/directors`
- **Paramètres**: Identiques à /suggest/actors
- **Réponse**: Identique à /suggest/actors
- **Statut Flutter**: ✅ `suggestDirectors()` retourne `List<String>`

#### ✅ GET `/suggest/genres`
- **Paramètres**: Identiques à /suggest/actors
- **Réponse**: Identique à /suggest/actors
- **Statut Flutter**: ✅ `suggestGenres()` retourne `List<String>`

#### ✅ GET `/multi-search`
- **Paramètres**:
  - `q` (required, 1-100 chars)
  - `limit` (10, 1-50) par catégorie
- **Réponse**:
  ```json
  {
    "query": "string",
    "results": {
      "films": { "count": 0, "data": [Movie array] },
      "series": { "count": 0, "data": [Series array] },
      "actors": { "count": 0, "data": [string array] },
      "directors": { "count": 0, "data": [string array] },
      "genres": { "count": 0, "data": [string array] }
    }
  }
  ```
- **Statut Flutter**: ⚠️ `multiSearch()` retourne `Map<String, dynamic>` - À typer

---

### Endpoints Détails et Épisodes

#### ✅ GET `/item/{item_id}`
- **Paramètres**: 
  - `{item_id}` (URL slug ou titre)
- **Réponse**: Item complet (Movie ou Series avec tous les détails)
- **Statut Flutter**: ✅ `getItemDetails()` retourne `Map<String, dynamic>?`

#### ✅ GET `/item/{item_id}/episodes`
- **Paramètres**:
  - `{item_id}` (URL slug)
  - `season` (optionnel, filtrer par saison)
- **Réponse**:
  ```json
  {
    "series_id": "string",
    "series_title": "string",
    "season_filter": "number|null",
    "total_episodes": 0,
    "episodes": [
      {
        "url": "string",
        "season": 0,
        "episode": 0,
        "title": "string",
        "synopsis": "string",
        "quality": "string",
        "watch_links": [...]
      }
    ]
  }
  ```
- **Statut Flutter**: ✅ `getEpisodes()` retourne `Map<String, dynamic>?`

#### ✅ GET `/item/{item_id}/watch-links`
- **Paramètres**: `{item_id}`
- **Réponse**:
  ```json
  {
    "id": "string",
    "title": "string",
    "type": "film|episode",
    "watch_links": [...]
  }
  ```
  Ou pour épisode:
  ```json
  {
    "id": "string",
    "series_title": "string",
    "season": 0,
    "episode": 0,
    "title": "string",
    "type": "episode",
    "watch_links": [...]
  }
  ```
- **Statut Flutter**: ✅ `getWatchLinks()` retourne `List<WatchLink>`

#### ✅ GET `/item/{item_id}/episode/{season}/{episode}`
- **Paramètres**:
  - `{item_id}` (URL slug)
  - `{season}` (numéro de saison)
  - `{episode}` (numéro d'épisode)
- **Réponse**:
  ```json
  {
    "serie_id": "string",
    "serie_title": "string",
    "season": 0,
    "episode": 0,
    "title": "string",
    "url": "string",
    "watch_links": [...]
  }
  ```
- **Statut Flutter**: ✅ `getEpisodeDetails()` retourne `Map<String, dynamic>?`

---

### Endpoints Administration et Débogage

#### ✅ GET `/stats`
- **Paramètres**: Aucun
- **Réponse**: Statistiques détaillées
- **Statut Flutter**: ⚠️ `getStats()` retourne `Map<String, dynamic>?`

#### ✅ GET `/debug`
- **Paramètres**: Aucun
- **Réponse**: Informations de débogage complètes
- **Statut Flutter**: ✅ `getDebugInfo()` retourne `Map<String, dynamic>?`

#### ✅ GET `/debug/logs`
- **Paramètres**: 
  - `limit` (100, 1-1000)
  - `level` (DEBUG|INFO|WARNING|ERROR)
- **Réponse**:
  ```json
  {
    "total": 0,
    "filtered": 0,
    "level_filter": "string|null",
    "logs": [...]
  }
  ```
- **Statut Flutter**: ✅ `getDebugLogs()` retourne `Map<String, dynamic>?`

#### ✅ GET `/debug/metrics`
- **Paramètres**: Aucun
- **Réponse**: Métriques du scraper
- **Statut Flutter**: ❌ Pas implémenté

#### ✅ GET `/debug/progress`
- **Paramètres**: Aucun
- **Réponse**: Progression du scraping en temps réel
- **Statut Flutter**: ❌ Pas implémenté

#### ✅ POST `/debug/clear-cache`
- **Paramètres**: Aucun
- **Réponse**: `{ "status": "ok", "cleared": 0 }`
- **Statut Flutter**: ❌ Pas implémenté

#### ✅ POST `/debug/reload`
- **Paramètres**: Aucun
- **Réponse**: `{ "status": "ok", "films": 0, "series": 0, "episodes": 0 }`
- **Statut Flutter**: ❌ Pas implémenté

---

### Endpoints Scraping

#### ✅ POST `/refresh`
- **Paramètres**:
  - `incremental` (bool, défaut: true)
  - `max_pages_films` (100, 1-1000)
  - `max_pages_series` (50, 1-600)
- **Réponse**:
  ```json
  {
    "status": "started",
    "mode": "incremental|full",
    "max_pages_films": 0,
    "max_pages_series": 0,
    "message": "..."
  }
  ```
- **Statut Flutter**: ❌ Pas implémenté

#### ✅ GET `/refresh/status`
- **Paramètres**: Aucun
- **Réponse**:
  ```json
  {
    "is_scraping": false,
    "progress": { ... },
    "current_data": { "films": 0, "series": 0, "episodes": 0, "watch_links": 0 }
  }
  ```
- **Statut Flutter**: ✅ `getRefreshStatus()` retourne `Map<String, dynamic>?`

---

## 3. RÉSUMÉ DES CORRECTIONS REQUISES

### 3.1 Modèles de Données - À Créer/Corriger

| Modèle | Statut | Action |
|--------|--------|--------|
| `Movie` | ✅ OK | Aucune |
| `Series` | ✅ OK | Aucune |
| `Episode` | ✅ OK | Aucune |
| `WatchLink` | ✅ OK | Aucune |
| `ApiResponse<T>` | ✅ OK | Aucune |
| `SearchResponse` | ✅ OK | Aucune |
| `HealthResponse` | ✅ OK | Aucune |
| `GenreItem` / `GenresResponse` | ✅ OK | Aucune |
| `ActorItem` / `ActorsResponse` | ✅ OK | Aucune |
| `YearItem` / `YearsResponse` | ⚠️ Manquant | **À créer** |
| `QualityItem` / `QualitiesResponse` | ⚠️ Manquant | **À créer** |
| `DirectorItem` / `DirectorsResponse` | ⚠️ Manquant | **À créer** |
| `AutocompleteResponse` | ✅ OK | Aucune |
| `AutocompleteSuggestion` | ✅ OK | Aucune |
| `MultiSearchResponse` | ⚠️ Manquant | **À créer** |
| `MultiSearchResult` | ⚠️ Manquant | **À créer** |
| `ContentResponse` | ⚠️ Manquant | **À créer** (par-genre, par-acteur, etc.) |
| `EpisodeDetailResponse` | ⚠️ Manquant | **À créer** |
| `WatchLinksResponse` | ⚠️ Manquant | **À créer** |

### 3.2 Service API - À Corriger

| Méthode | Problème | Action |
|---------|----------|--------|
| `getMovies()` | ✅ OK | Aucune |
| `getSeries()` | ✅ OK | Aucune |
| `search()` | ✅ OK | Aucune |
| `filter()` | ⚠️ Retourne `dynamic` | Typer correctement |
| `getByGenre()` | ⚠️ Retourne `dynamic` | Créer `ContentResponse<T>` |
| `getByActor()` | ⚠️ Retourne `dynamic` | Créer `ContentResponse<T>` |
| `getByDirector()` | ⚠️ Retourne `dynamic` | Créer `ContentResponse<T>` |
| `getByYear()` | ⚠️ Retourne `dynamic` | Créer `ContentResponse<T>` |
| `getTopRated()` | ⚠️ Retourne `dynamic` | Créer `ContentResponse<T>` |
| `getRecent()` | ⚠️ Retourne `dynamic` | Créer `ContentResponse<T>` |
| `getRandom()` | ⚠️ Retourne `List<dynamic>` | Créer `RandomResponse` |
| `getGenres()` | ✅ OK | Aucune |
| `getActors()` | ✅ OK | Aucune |
| `getDirectors()` | ⚠️ Retourne `dynamic` | Créer `DirectorsResponse` |
| `getYears()` | ⚠️ Retourne `dynamic` | Créer `YearsResponse` |
| `getQualities()` | ⚠️ Retourne `dynamic` | Créer `QualitiesResponse` |
| `autocomplete()` | ✅ OK | Aucune |
| `suggestActors()` | ✅ OK | Aucune |
| `suggestDirectors()` | ✅ OK | Aucune |
| `suggestGenres()` | ✅ OK | Aucune |
| `multiSearch()` | ⚠️ Retourne `Map` | Créer `MultiSearchResponse` |
| `getItemDetails()` | ✅ OK (retourne `Map?`) | Considérer un modèle spécifique |
| `getEpisodes()` | ✅ OK (retourne `Map?`) | Considérer un modèle spécifique |
| `getWatchLinks()` | ✅ OK | Aucune |
| `getEpisodeDetails()` | ✅ OK (retourne `Map?`) | Considérer un modèle spécifique |
| `getStats()` | ✅ OK (retourne `Map?`) | Considérer un modèle spécifique |
| `getDebugInfo()` | ✅ OK | Aucune |
| `getDebugLogs()` | ✅ OK | Aucune |
| Missing: `getDebugMetrics()` | ❌ Manquante | **À ajouter** |
| Missing: `getDebugProgress()` | ❌ Manquante | **À ajouter** |
| Missing: `clearCache()` | ❌ Manquante | **À ajouter** |
| Missing: `reloadData()` | ❌ Manquante | **À ajouter** |
| Missing: `postRefresh()` | ❌ Manquante | **À ajouter** |

### 3.3 Priorité des Corrections

**P1 - CRITIQUE** (Blockers):
1. ✅ Modèles Movie, Series, Episode, WatchLink
2. ✅ ApiResponse<T>, SearchResponse
3. ⚠️ Créer ContentResponse<T> pour /by-genre, /by-actor, etc.
4. ⚠️ Créer YearsResponse, QualitiesResponse, DirectorsResponse

**P2 - IMPORTANTE** (Fonctionnalité):
1. ⚠️ Créer MultiSearchResponse avec structure typée
2. ⚠️ Créer RandomResponse
3. ⚠️ Typer complètement les réponses de /filter
4. ❌ Ajouter endpoints debug manquants

**P3 - OPTIMISATION** (Nice-to-have):
1. Créer des modèles spécifiques pour détails (ItemDetailsResponse)
2. Créer des modèles spécifiques pour épisodes (EpisodesResponse)
3. Ajouter validations côté client

---

## 4. PLAN D'ACTION DÉTAILLÉ

### Étape 1: Créer les modèles manquants (30 min)
- [ ] YearsResponse, QualityItem, QualitiesResponse
- [ ] DirectorItem, DirectorsResponse
- [ ] ContentResponse<T> (générique pour browse endpoints)
- [ ] RandomResponse, MultiSearchResponse

### Étape 2: Corriger ZenixApiService (45 min)
- [ ] Typer les return types correctement
- [ ] Ajouter les endpoints manquants
- [ ] Ajouter la gestion d'erreurs robuste

### Étape 3: Tester tous les endpoints (1 h)
- [ ] Teste local avec curl/Postman
- [ ] Valide les réponses pour chaque endpoint
- [ ] Documente les anomalies

### Étape 4: Mettre à jour les providers (30 min)
- [ ] Adapter les appels aux nouveaux types
- [ ] Gérer les erreurs correctement

### Étape 5: Mettre à jour les UI (1 h)
- [ ] Vérifier que les UI reçoivent les bonnes données
- [ ] Tester sur device réel

---

## 5. TESTS RECOMMANDÉS

Créer `test/zenix_api_test.dart` avec:

```dart
group('ZenixApiService - Endpoints', () {
  late ZenixApiService service;

  setUp(() {
    // Initialize with mock Dio or real client
    service = ZenixApiService(dioClient);
  });

  // Films & Series
  test('getMovies returns paginated ApiResponse<Movie>', () async { ... });
  test('getSeries returns paginated ApiResponse<Series>', () async { ... });
  
  // Search & Filter
  test('search returns SearchResponse with filtered results', () async { ... });
  test('filter returns ContentResponse<dynamic> with results', () async { ... });
  
  // Browse
  test('getByGenre returns ContentResponse<Movie|Series>', () async { ... });
  test('getByActor returns ContentResponse<Movie|Series>', () async { ... });
  test('getByYear returns ContentResponse<Movie|Series>', () async { ... });
  test('getTopRated returns ContentResponse<Movie|Series>', () async { ... });
  test('getRecent returns ContentResponse<Movie|Series>', () async { ... });
  
  // Meta endpoints
  test('getGenres returns GenresResponse', () async { ... });
  test('getActors returns ActorsResponse', () async { ... });
  test('getYears returns YearsResponse', () async { ... });
  test('getQualities returns QualitiesResponse', () async { ... });
  
  // Suggestions
  test('autocomplete returns AutocompleteResponse', () async { ... });
  test('suggestActors returns List<String>', () async { ... });
  test('multiSearch returns MultiSearchResponse', () async { ... });
  
  // Details
  test('getItemDetails returns full movie/series data', () async { ... });
  test('getEpisodes returns episodes list', () async { ... });
  test('getEpisodeDetails returns specific episode', () async { ... });
  
  // Admin
  test('getStats returns statistics', () async { ... });
  test('healthCheck returns HealthResponse', () async { ... });
  test('getDebugInfo returns debug data', () async { ... });
  test('getDebugLogs returns logs with optional level filter', () async { ... });
});
```

---

## 6. POINTS D'ATTENTION PARTICULIERS

### 6.1 Différences Subtiles
- **year**: TOUJOURS string, pas int
- **rating**: Peut être null
- **watch_links_count**: Int dans les listes
- **watch_links**: Array complet dans les détails
- **synopsis**: Tronqué à 200 chars en liste, complet en détails

### 6.2 Pagination
- Toutes les listes paginées utilisent: `total`, `offset`, `limit