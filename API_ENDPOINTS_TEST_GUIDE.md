# Guide de Test Complet - API Zenix v2.1

## Vue d'ensemble
Ce guide couvre le test de tous les endpoints de l'API Zenix à `http://node.zenix.sg:25825` avec des exemples curl et des vérifications attendues.

---

## 1. ENDPOINTS RACINE ET SANTÉ

### 1.1 GET `/` - Info API
```bash
curl -X GET "http://node.zenix.sg:25825/"
```

**Réponse attendue:**
```json
{
  "name": "NeoStream API",
  "version": "2.1.0",
  "status": "running",
  "data": {
    "films": <number>,
    "series": <number>,
    "episodes": <number>,
    "watch_links": <number>
  },
  "endpoints": { ... }
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ Contient "version": "2.1.0"
- ✅ Contient les compteurs de données

---

### 1.2 GET `/health` - Health Check
```bash
curl -X GET "http://node.zenix.sg:25825/health"
```

**Réponse attendue:**
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "uptime_data": {
    "films": <number>,
    "series": <number>,
    "last_update": "2024-01-15T10:00:00.000Z"
  },
  "is_scraping": false,
  "api_stats": {
    "requests_total": <number>,
    "avg_response_time_ms": <float>,
    "errors_total": <number>
  }
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ Status = "ok"
- ✅ is_scraping boolean
- ✅ api_stats présentes

---

## 2. ENDPOINTS DONNÉES - LISTES

### 2.1 GET `/films` - Liste des Films
```bash
# Sans pagination (retourne tous les films)
curl -X GET "http://node.zenix.sg:25825/films"

# Avec pagination
curl -X GET "http://node.zenix.sg:25825/films?limit=50&offset=0"

# Avec filtres
curl -X GET "http://node.zenix.sg:25825/films?year=2023&sort=title&limit=20"

# Tri par nombre de liens
curl -X GET "http://node.zenix.sg:25825/films?sort=watch_links&limit=10"
```

**Réponse attendue:**
```json
{
  "total": <number>,
  "offset": <number>,
  "limit": <number>,
  "count": <number>,
  "data": [
    {
      "id": "string",
      "title": "string",
      "original_title": "string|null",
      "type": "film",
      "year": "2023",
      "poster": "url|null",
      "url": "url",
      "genres": ["Action", "Drama"],
      "rating": 8.5,
      "quality": "HD",
      "version": "VF",
      "actors": ["Actor1", "Actor2"],
      "directors": ["Director1"],
      "synopsis": "Brief description...",
      "watch_links_count": 5
    }
  ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ total ≥ count
- ✅ offset = paramètre offset
- ✅ count ≤ limit
- ✅ year est string, pas int
- ✅ rating peut être null
- ✅ watch_links_count est int

**Cas d'erreur:**
```bash
# Limite invalide
curl -X GET "http://node.zenix.sg:25825/films?limit=2000"
# Doit retourner 422 ou limiter à 1000
```

---

### 2.2 GET `/series` - Liste des Séries
```bash
# Sans pagination
curl -X GET "http://node.zenix.sg:25825/series"

# Avec pagination et tri
curl -X GET "http://node.zenix.sg:25825/series?limit=30&offset=0&sort=episodes"

# Par année
curl -X GET "http://node.zenix.sg:25825/series?year=2023"
```

**Réponse attendue:**
```json
{
  "total": <number>,
  "offset": <number>,
  "limit": <number>,
  "count": <number>,
  "data": [
    {
      "id": "string",
      "title": "string",
      "original_title": "string|null",
      "type": "serie",
      "year": "2023",
      "poster": "url|null",
      "url": "url",
      "genres": ["Action", "Drama"],
      "rating": 8.0,
      "quality": "HD",
      "version": "VF",
      "actors": ["Actor1"],
      "directors": ["Director1"],
      "synopsis": "Brief...",
      "watch_links_count": 15,
      "seasons_count": 3,
      "episodes_count": 24
    }
  ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ type = "serie"
- ✅ seasons_count et episodes_count présents
- ✅ Même structure que films sauf pour les compteurs séries

---

## 3. ENDPOINTS RECHERCHE ET FILTRAGE

### 3.1 GET `/search` - Recherche Avancée
```bash
# Recherche simple
curl -X GET "http://node.zenix.sg:25825/search?q=action"

# Recherche avec filtres multiples
curl -X GET "http://node.zenix.sg:25825/search?q=actor&type=film&genre=Action&year=2023&limit=20"

# Recherche par année min/max
curl -X GET "http://node.zenix.sg:25825/search?q=action&year_min=2020&year_max=2024"

# Recherche avec note minimum
curl -X GET "http://node.zenix.sg:25825/search?q=movie&rating_min=8.0"

# Recherche par qualité
curl -X GET "http://node.zenix.sg:25825/search?q=film&quality=HD"

# Recherche avec pagination
curl -X GET "http://node.zenix.sg:25825/search?q=action&limit=50&offset=50"
```

**Réponse attendue:**
```json
{
  "query": "action",
  "filters": {
    "type": "film|null",
    "genre": "Action|null",
    "actor": null,
    "director": null,
    "year": "2023|null",
    "year_min": 2020,
    "year_max": 2024,
    "rating_min": 8.0,
    "quality": "HD|null"
  },
  "total": <number>,
  "offset": <number>,
  "limit": <number>,
  "count": <number>,
  "data": [ ... ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ query matche le paramètre q
- ✅ filters reflètent les paramètres envoyés
- ✅ Résultats paginés correctement
- ✅ year_min et year_max appliqués
- ✅ rating_min appliqué (items avec rating >= rating_min)

**Cas d'erreur:**
```bash
# q manquant
curl -X GET "http://node.zenix.sg:25825/search"
# Doit retourner 422 - q requis

# q trop court
curl -X GET "http://node.zenix.sg:25825/search?q=a"
# Doit retourner 422 - min 1 char (généralement ok)
```

---

### 3.2 GET `/filter` - Filtrage sans Recherche Textuelle
```bash
# Filtrer par genre uniquement
curl -X GET "http://node.zenix.sg:25825/filter?genre=Action"

# Filtrer par acteur et réalisateur
curl -X GET "http://node.zenix.sg:25825/filter?actor=Tom%20Hanks&director=Steven%20Spielberg"

# Filtrer par année et qualité
curl -X GET "http://node.zenix.sg:25825/filter?year=2023&quality=HD"

# Filtrer avec tri
curl -X GET "http://node.zenix.sg:25825/filter?genre=Drama&sort_by=rating&sort_order=desc"

# Filtrer par plage d'années
curl -X GET "http://node.zenix.sg:25825/filter?year_min=2020&year_max=2023&type=film"
```

**Réponse attendue:**
```json
{
  "filters": {
    "type": "film|null",
    "genre": "Action|null",
    "actor": null,
    "director": null,
    "year": null,
    "year_min": 2020,
    "year_max": 2023,
    "rating_min": null,
    "rating_max": null,
    "quality": "HD|null",
    "version": null,
    "language": null
  },
  "sort": {
    "by": "title",
    "order": "asc"
  },
  "total": <number>,
  "offset": <number>,
  "limit": <number>,
  "count": <number>,
  "data": [ ... ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ Pas de paramètre q required
- ✅ Filtres appliqués correctement
- ✅ Tri appliqué (title|year|rating, asc|desc)
- ✅ Résultats non triés sans sort_by

---

## 4. ENDPOINTS NAVIGATION

### 4.1 GET `/by-genre/{genre}` - Par Genre
```bash
curl -X GET "http://node.zenix.sg:25825/by-genre/Action"
curl -X GET "http://node.zenix.sg:25825/by-genre/Drama?type=film"
curl -X GET "http://node.zenix.sg:25825/by-genre/Comedy?limit=20&offset=0"
```

**Réponse attendue:**
```json
{
  "genre": "Action",
  "type_filter": "film|null",
  "total": <number>,
  "offset": <number>,
  "limit": <number>,
  "count": <number>,
  "data": [ ... ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ genre reflète le paramètre path
- ✅ type_filter reflète le paramètre query
- ✅ Tous les items contiennent le genre

---

### 4.2 GET `/by-actor/{actor}` - Par Acteur
```bash
curl -X GET "http://node.zenix.sg:25825/by-actor/Tom%20Hanks"
curl -X GET "http://node.zenix.sg:25825/by-actor/Meryl%20Streep?type=film&limit=10"
```

**Réponse attendue:**
```json
{
  "actor": "Tom Hanks",
  "type_filter": "film|null",
  "total": <number>,
  "offset": <number>,
  "limit": <number>,
  "count": <number>,
  "data": [ ... ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ actor est décodé correctement
- ✅ Tous les items contiennent l'acteur dans la liste

---

### 4.3 GET `/by-director/{director}` - Par Réalisateur
```bash
curl -X GET "http://node.zenix.sg:25825/by-director/Christopher%20Nolan"
curl -X GET "http://node.zenix.sg:25825/by-director/Quentin%20Tarantino?limit=5"
```

**Réponse attendue:**
```json
{
  "director": "Christopher Nolan",
  "type_filter": "film|null",
  "total": <number>,
  "offset": <number>,
  "limit": <number>,
  "count": <number>,
  "data": [ ... ]
}
```

---

### 4.4 GET `/by-year/{year}` - Par Année
```bash
curl -X GET "http://node.zenix.sg:25825/by-year/2023"
curl -X GET "http://node.zenix.sg:25825/by-year/2022?type=serie"
curl -X GET "http://node.zenix.sg:25825/by-year/2021?limit=30&offset=10"
```

**Réponse attendue:**
```json
{
  "year": "2023",
  "type_filter": "film|null",
  "total": <number>,
  "offset": <number>,
  "limit": <number>,
  "count": <number>,
  "data": [ ... ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ year est string
- ✅ Tous les items ont year == "2023"

---

### 4.5 GET `/top-rated` - Mieux Notés
```bash
# Note minimum 7.0
curl -X GET "http://node.zenix.sg:25825/top-rated"

# Note minimum personnalisée
curl -X GET "http://node.zenix.sg:25825/top-rated?min_rating=8.5"

# Séries mieux notées
curl -X GET "http://node.zenix.sg:25825/top-rated?type=serie&min_rating=8.0"

# Avec pagination
curl -X GET "http://node.zenix.sg:25825/top-rated?min_rating=7.5&limit=10&offset=0"
```

**Réponse attendue:**
```json
{
  "min_rating": 7.5,
  "type_filter": "film|null",
  "total": <number>,
  "offset": <number>,
  "limit": <number>,
  "count": <number>,
  "data": [ ... ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ Tous les items ont rating >= min_rating
- ✅ Triés par rating décroissant
- ✅ Items avec rating null exclus

---

### 4.6 GET `/recent` - Récents
```bash
# Année courante par défaut
curl -X GET "http://node.zenix.sg:25825/recent"

# Année spécifique
curl -X GET "http://node.zenix.sg:25825/recent?year=2022"

# Séries récentes
curl -X GET "http://node.zenix.sg:25825/recent?type=serie&year=2023"

# Avec pagination
curl -X GET "http://node.zenix.sg:25825/recent?limit=20&offset=0"
```

**Réponse attendue:**
```json
{
  "year": "2023",
  "type_filter": "film|null",
  "total": <number>,
  "offset": <number>,
  "limit": <number>,
  "count": <number>,
  "data": [ ... ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ year par défaut = année courante (2024 ou 2023)
- ✅ Tous les items ont year == "2023" (ou paramètre)

---

### 4.7 GET `/random` - Aléatoires
```bash
# 10 items aléatoires (défaut)
curl -X GET "http://node.zenix.sg:25825/random"

# 20 items aléatoires
curl -X GET "http://node.zenix.sg:25825/random?count=20"

# Films aléatoires d'un genre
curl -X GET "http://node.zenix.sg:25825/random?genre=Action&count=5"

# Séries aléatoires
curl -X GET "http://node.zenix.sg:25825/random?type=serie&count=15"
```

**Réponse attendue:**
```json
{
  "type_filter": "film|null",
  "genre_filter": "Action|null",
  "count": 10,
  "data": [ ... ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ count ≤ paramètre count
- ✅ Résultats varient à chaque appel
- ✅ Si genre: tous les items contiennent le genre
- ✅ Si type: tous les items du type spécifié

---

## 5. ENDPOINTS MÉTADONNÉES

### 5.1 GET `/genres` - Liste des Genres
```bash
# Tous les genres
curl -X GET "http://node.zenix.sg:25825/genres"

# Genres de films uniquement
curl -X GET "http://node.zenix.sg:25825/genres?type=film"

# Genres de séries uniquement
curl -X GET "http://node.zenix.sg:25825/genres?type=serie"
```

**Réponse attendue:**
```json
{
  "total": <number>,
  "data": [
    {
      "name": "Action",
      "count": 150
    },
    {
      "name": "Drama",
      "count": 200
    }
  ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ total = nombre de genres
- ✅ Triés par count décroissant
- ✅ count > 0 pour chaque genre

---

### 5.2 GET `/actors` - Liste des Acteurs
```bash
# Tous les acteurs
curl -X GET "http://node.zenix.sg:25825/actors"

# Acteurs de films
curl -X GET "http://node.zenix.sg:25825/actors?type=film&limit=50"

# Rechercher des acteurs
curl -X GET "http://node.zenix.sg:25825/actors?q=tom&limit=20"

# Acteurs avec limite personnalisée
curl -X GET "http://node.zenix.sg:25825/actors?limit=500"
```

**Réponse attendue:**
```json
{
  "total": <number>,
  "data": [
    {
      "name": "Tom Hanks",
      "count": 15
    },
    {
      "name": "Meryl Streep",
      "count": 20
    }
  ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ Triés par count décroissant
- ✅ Si q: tous les noms contiennent "tom" (case-insensitive)
- ✅ count > 0

---

### 5.3 GET `/directors` - Liste des Réalisateurs
```bash
# Tous les réalisateurs
curl -X GET "http://node.zenix.sg:25825/directors"

# Réalisateurs de films
curl -X GET "http://node.zenix.sg:25825/directors?type=film"

# Rechercher des réalisateurs
curl -X GET "http://node.zenix.sg:25825/directors?q=spielberg&limit=10"
```

**Réponse attendue:**
```json
{
  "total": <number>,
  "data": [
    {
      "name": "Steven Spielberg",
      "count": 25
    }
  ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ Même structure que /actors

---

### 5.4 GET `/years` - Liste des Années
```bash
# Toutes les années
curl -X GET "http://node.zenix.sg:25825/years"

# Années de films
curl -X GET "http://node.zenix.sg:25825/years?type=film"

# Années de séries
curl -X GET "http://node.zenix.sg:25825/years?type=serie"
```

**Réponse attendue:**
```json
{
  "total": <number>,
  "data": [
    {
      "year": "2023",
      "count": 150
    },
    {
      "year": "2022",
      "count": 120
    }
  ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ year est string
- ✅ Triés par année décroissante (2023, 2022, 2021...)
- ✅ count > 0

---

### 5.5 GET `/qualities` - Liste des Qualités
```bash
# Toutes les qualités
curl -X GET "http://node.zenix.sg:25825/qualities"

# Qualités disponibles (HD, SD, 4K, CAM, etc.)
curl -X GET "http://node.zenix.sg:25825/qualities?type=film"
```

**Réponse attendue:**
```json
{
  "total": <number>,
  "data": [
    {
      "quality": "HD",
      "count": 500
    },
    {
      "quality": "SD",
      "count": 300
    },
    {
      "quality": "4K",
      "count": 100
    }
  ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ Triés par count décroissant
- ✅ Qualités typiques (HD, SD, 4K, FULL HD, CAM, etc.)

---

## 6. ENDPOINTS AUTOCOMPLÉTION

### 6.1 GET `/autocomplete` - Autocomplétion Rapide
```bash
# Autocomplétion simple
curl -X GET "http://node.zenix.sg:25825/autocomplete?q=action"

# Avec limite
curl -X GET "http://node.zenix.sg:25825/autocomplete?q=the&limit=5"

# Filtrer par type
curl -X GET "http://node.zenix.sg:25825/autocomplete?q=breaking&type=serie"
```

**Réponse attendue:**
```json
{
  "query": "action",
  "count": 10,
  "suggestions": [
    {
      "id": "action-movie-2023",
      "title": "Action Movie",
      "original_title": "Original Title",
      "type": "film",
      "year": "2023",
      "poster": "url|null"
    }
  ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ query = paramètre q
- ✅ count ≤ limit
- ✅ Suggestions triées par pertinence
- ✅ Tous les items contiennent le terme

---

### 6.2 GET `/suggest/actors` - Suggestions d'Acteurs
```bash
curl -X GET "http://node.zenix.sg:25825/suggest/actors?q=tom"
curl -X GET "http://node.zenix.sg:25825/suggest/actors?q=meryl&limit=15"
```

**Réponse attendue:**
```json
{
  "query": "tom",
  "count": 5,
  "suggestions": [
    "Tom Hanks",
    "Tom Cruise",
    "Tom Hardy",
    "Tom Holland",
    "Tom Hiddleston"
  ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ Résultats triés par pertinence (commence par > contient)
- ✅ count ≤ limit

---

### 6.3 GET `/suggest/directors` - Suggestions de Réalisateurs
```bash
curl -X GET "http://node.zenix.sg:25825/suggest/directors?q=spiel"
curl -X GET "http://node.zenix.sg:25825/suggest/directors?q=chris&limit=10"
```

**Réponse attendue:**
```json
{
  "query": "spiel",
  "count": 3,
  "suggestions": [
    "Steven Spielberg",
    "Spielberg Martin"
  ]
}
```

---

### 6.4 GET `/suggest/genres` - Suggestions de Genres
```bash
curl -X GET "http://node.zenix.sg:25825/suggest/genres?q=act"
curl -X GET "http://node.zenix.sg:25825/suggest/genres?q=dra"
```

**Réponse attendue:**
```json
{
  "query": "act",
  "count": 2,
  "suggestions": [
    "Action",
    "Activity"
  ]
}
```

---

### 6.5 GET `/multi-search` - Recherche Multi-catégories
```bash
curl -X GET "http://node.zenix.sg:25825/multi-search?q=matrix&limit=5"
curl -X GET "http://node.zenix.sg:25825/multi-search?q=action&limit=10"
```

**Réponse attendue:**
```json
{
  "query": "matrix",
  "results": {
    "films": {
      "count": 3,
      "data": [ ... ]
    },
    "series": {
      "count": 1,
      "data": [ ... ]
    },
    "actors": {
      "count": 5,
      "data": ["Actor1", "Actor2", ...]
    },
    "directors": {
      "count": 2,
      "data": ["Director1", "Director2"]
    },
    "genres": {
      "count": 3,
      "data": ["Action", "Sci-Fi", "Thriller"]
    }
  }
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ Résultats groupés par catégorie
- ✅ Chaque catégorie a count et data
- ✅ count ≤ limit

---

## 7. ENDPOINTS DÉTAILS

### 7.1 GET `/item/{id}` - Détails Complets
```bash
# Par slug URL
curl -X GET "http://node.zenix.sg:25825/item/the-matrix-1999"

# Par ID trouvé dans une liste
curl -X GET "http://node.zenix.sg:25825/item/matrix"

# Vérifier le type (film ou série)
curl -X GET "http://node.zenix.sg:25825/item/breaking-bad"
```

**Réponse attendue (Film):**
```json
{
  "id": "the-matrix",
  "title": "The Matrix",
  "original_title": "The Matrix",
  "type": "film",
  "year": "1999",
  "genres": ["Action", "Sci-Fi"],
  "directors": ["Wachowski"],
  "actors": ["Keanu Reeves", "Laurence Fishburne"],
  "synopsis": "Full description here...",
  "description": null,
  "poster": "url",
  "rating": 8.7,
  "rating_max": 10,
  "quality": "HD",
  "version": "VF",
  "language": "English",
  "duration": 136,
  "url": "https://...",
  "watch_links": [
    {
      "server": "GoVideo",
      "url": "https://...",
      "quality": "1080p"
    }
  ]
}
```

**Réponse attendue (Série):**
```json
{
  "id": "breaking-bad",
  "title": "Breaking Bad",
  "original_title": "Breaking Bad",
  "type": "serie",
  "year": "2008",
  "genres": ["Drama", "Crime"],
  "directors": ["Vince Gilligan"],
  "actors": ["Bryan Cranston", "Aaron Paul"],
  "synopsis": "Full description...",
  "poster": "url",
  "rating": 9.5,
  "quality": "HD",
  "version": "VOSTFR",
  "url": "https://...",
  "watch_links": [],
  "seasons": [
    {
      "number": 1,
      "episodes": [...]
    }
  ],
  "seasons_count": 5,
  "episodes_count": 62,
  "episodes": [
    {
      "url": "...",
      "season": 1,
      "episode": 1,
      "title": "Pilot",
      "original_title": null,
      "synopsis": "...",
      "quality": "HD",
      "actors": [],
      "directors": [],
      "watch_links": [...]
    }
  ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ Type = "film" ou "serie"
- ✅ Tous les champs attendus présents
- ✅ watch_links array
- ✅ Pour séries: seasons, episodes présents

**Cas d'erreur:**
```bash
# Item inexistant
curl -X GET "http://node.zenix.sg:25825/item/inexistant-film-1234"
# Doit retourner 404
```

---

### 7.2 GET `/item/{id}/episodes` - Episodes d'une Série
```bash
# Tous les épisodes
curl -X GET "http://node.zenix.sg:25825/item/breaking-bad/episodes"

# Episodes d'une saison spécifique
curl -X GET "http://node.zenix.sg:25825/item/breaking-bad/episodes?season=1"

# Saison 2
curl -X GET "http://node.zenix.sg:25825/item/breaking-bad/episodes?season=2"
```

**Réponse attendue:**
```json
{
  "series_id": "breaking-bad",
  "series_title": "Breaking Bad",
  "season_filter": 1,
  "total_episodes": 7,
  "episodes": [
    {
      "url": "https://...",
      "season": 1,
      "episode": 1,
      "title": "Pilot",
      "synopsis": "...",
      "quality": "HD",
      "watch_links": [
        {
          "server": "GoVideo",
          "url": "https://...",
          "quality": "1080p"
        }
      ]
    }
  ]
}
```

**Vérifications:**
- ✅ Statut 200
- ✅ series_id et series_title présents
- ✅ season_filter = paramètre season ou null
- ✅ total_episodes = nombre d'épisodes retournés (ou filtrés)
- ✅ Chaque épisode a season, episode, title, watch_links

---

### 7.3 GET `/item/{id}/watch-links` - Liens de