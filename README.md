# 🎬 NEO-Stream
# new release (Full working)
Application Android moderne de streaming multimédia (Films & Séries) avec support **Mobile** et **Android TV**.

## 📋 Table des matières

- [Aperçu](#-aperçu)
- [Fonctionnalités](#-fonctionnalités)
- [Architecture](#-architecture)
- [Technologies](#-technologies)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Structure du projet](#-structure-du-projet)
- [Développement](#-développement)
- [Build & Déploiement](#-build--déploiement)
- [API Backend](#-api-backend)

---

## 🎯 Aperçu

**NEO-Stream** est une application de streaming développée en **Kotlin** avec **Jetpack Compose**, offrant :
- Une interface **Mobile** fluide et moderne
- Une interface **Android TV** complète (Leanback)
- Support des films et séries
- Lecture vidéo HLS avec ExoPlayer (Media3)
- Gestion des favoris et progression de visionnage
- Recommandations intelligentes basées sur l'historique
- Support multi-comptes
- DNS-over-HTTPS pour contourner les restrictions FAI

---

## ✨ Fonctionnalités

### 📱 Mobile
- **Navigation par onglets** : Accueil, Films, Séries, Favoris
- **Cartes adaptatives** : FeaturedCard, WideCard, CompactCard, MovieCard
- **Détails enrichis** : Synopsis, casting, notes, genres, durée
- **Lecteur vidéo** : ExoPlayer avec contrôles personnalisés
- **Recherche avancée** : Autocomplete, filtres par type
- **Favoris** : Sauvegarde locale avec Room
- **Progression** : Reprise de lecture automatique
- **Thème sombre** : Interface optimisée avec Material 3

### 📺 Android TV
- **Navigation D-Pad** : Interface complète au clavier/télécommande
- **Écrans dédiés** : Home, Films, Séries, Recherche, Favoris, Paramètres
- **Focus Management** : Gestion automatique du focus
- **Sidebar** : Menu latéral avec navigation rapide
- **Cartes TV** : TvCard avec animations de focus
- **Player TV** : Contrôles adaptés à la télécommande

### 🔐 Sécurité & Réseau
- **DNS-over-HTTPS** : Cloudflare (1.1.1.1) + Google (8.8.8.8)
- **Headers personnalisés** : User-Agent, Referer, CORS
- **Retry automatique** : Gestion des erreurs réseau
- **Cache intelligent** : Coil3 avec politiques de cache

---

## 🏗️ Architecture

```
app/
├── data/
│   ├── api/          # Client HTTP (Ktor)
│   ├── extractor/    # Extracteurs de liens vidéo (Uqload)
│   ├── local/        # Base de données Room (Favoris, Comptes, Progression)
│   ├── model/        # Data classes (MediaItem, ApiResponse)
│   └── repository/   # Repositories (Media, WatchProgress, Recommendations)
├── player/           # PlayerManager (ExoPlayer/Media3)
├── ui/
│   ├── mobile/       # Interface Mobile (Compose)
│   │   ├── components/
│   │   ├── navigation/
│   │   └── screens/
│   ├── tv/           # Interface TV (Compose TV)
│   │   ├── components/
│   │   ├── navigation/
│   │   └── screens/
│   ├── player/       # VideoPlayerActivity
│   └── theme/        # Thème Material 3
└── util/             # Utilitaires (PlatformDetector, TvKeyHandler)
```

### Patterns utilisés
- **MVVM** : ViewModel + StateFlow/State
- **Repository Pattern** : Abstraction de la source de données
- **Dependency Injection** : Manuel via Singletons
- **Clean Architecture** : Séparation data/domain/ui

---

## 🛠️ Technologies

| Catégorie | Librairie | Version |
|-----------|-----------|---------|
| **UI** | Jetpack Compose | BOM 2024.12.01 |
| **TV** | Compose TV (Foundation + Material) | 1.0.0 |
| **Navigation** | Navigation Compose | 2.8.5 |
| **Réseau** | Ktor Client (OkHttp) | 3.0.3 |
| **Images** | Coil3 (Compose + OkHttp) | 3.0.4 |
| **Vidéo** | Media3 (ExoPlayer + HLS) | 1.5.1 |
| **BDD** | Room (Runtime + KTX) | 2.6.1 |
| **Coroutines** | Kotlinx Coroutines | 1.9.0 |
| **Sérialisation** | Kotlinx Serialization JSON | 1.7.3 |
| **Lifecycle** | Lifecycle ViewModel/Runtime | 2.8.7 |
| **DNS-over-HTTPS** | OkHttp DoH | 4.12.0 |
| **Build** | Gradle (Kotlin DSL) | 8.11.1 |
| **AGP** | Android Gradle Plugin | 8.7.3 |
| **Kotlin** | Kotlin + Compose Compiler | 2.1.0 |

---

## 📦 Installation

### Prérequis
- **JDK 17** ou supérieur
- **Android Studio** Koala (2024.1.1) ou plus récent
- **Android SDK 35** (compileSdk)
- **Gradle 8.11.1** (inclus via wrapper)

### Cloner le projet
```bash
git clone https://github.com/pecorio-dev/NEO-Stream.git
cd NEO-Stream
```

### Build l'application
```bash
# Debug APK
./gradlew assembleDebug

# Release APK (avec ProGuard)
./gradlew assembleRelease

# Installer sur appareil connecté
./gradlew installDebug
```

---

## ⚙️ Configuration

### 1. URL de l'API Backend
Modifier l'URL dans `app/build.gradle.kts` :
```kotlin
buildConfigField("String", "API_BASE_URL", "\"http://votre-serveur:port\"")
```

### 2. Mode TV forcé (Debug)
Pour tester l'interface TV sur téléphone/tablette :
```kotlin
// Dans PlatformDetector.kt
fun isForceTvMode(context: Context): Boolean {
    return true // Force le mode TV
}
```

### 3. ProGuard (Release)
Les règles sont dans `app/proguard-rules.pro`. Pour désactiver :
```kotlin
// app/build.gradle.kts
buildTypes {
    release {
        isMinifyEnabled = false
        isShrinkResources = false
    }
}
```

### 4. Network Security Config
Le fichier `network_security_config.xml` autorise le trafic HTTP en clair (dev uniquement) :
```xml
<network-security-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
</network-security-config>
```
⚠️ **En production, utilisez HTTPS uniquement !**

---

## 📁 Structure du projet

```
NEO-Stream/
├── app/
│   ├── src/main/
│   │   ├── kotlin/dev/neostream/app/
│   │   │   ├── MainActivity.kt           # Point d'entrée (Mobile/TV)
│   │   │   ├── NeoStreamApp.kt           # Application (Coil config)
│   │   │   ├── data/
│   │   │   │   ├── api/
│   │   │   │   │   └── NeoStreamApi.kt   # Client API (Ktor)
│   │   │   │   ├── extractor/
│   │   │   │   │   └── UqloadExtractor.kt # Extraction liens vidéo
│   │   │   │   ├── local/
│   │   │   │   │   ├── NeoStreamDatabase.kt
│   │   │   │   │   ├── FavoriteDao/Entity.kt
│   │   │   │   │   ├── AccountDao/Entity.kt
│   │   │   │   │   ├── WatchProgressDao/Entity.kt
│   │   │   │   │   └── SessionManager.kt
│   │   │   │   ├── model/
│   │   │   │   │   ├── MediaItem.kt
│   │   │   │   │   └── ApiResponse.kt
│   │   │   │   └── repository/
│   │   │   │       ├── MediaRepository.kt
│   │   │   │       ├── WatchProgressRepository.kt
│   │   │   │       ├── RecommendationEngine.kt
│   │   │   │       └── ViewingStatsCalculator.kt
│   │   │   ├── player/
│   │   │   │   └── PlayerManager.kt      # ExoPlayer singleton
│   │   │   ├── ui/
│   │   │   │   ├── mobile/
│   │   │   │   │   ├── components/       # Cartes, Headers, Badges
│   │   │   │   │   ├── navigation/       # NavGraph, BottomNavBar, Screen
│   │   │   │   │   └── screens/          # Home, Movies, Series, Detail, Favorites, Profile
│   │   │   │   ├── tv/
│   │   │   │   │   ├── TV_README.md      # Guide développeur TV
│   │   │   │   │   ├── TvDimens.kt       # Dimensions TV
│   │   │   │   │   ├── components/       # TvCard, TvRow, TvSidebar, TvFocusable
│   │   │   │   │   ├── navigation/       # TvNavGraph
│   │   │   │   │   └── screens/          # Écrans TV
│   │   │   │   ├── player/
│   │   │   │   │   └── VideoPlayerActivity.kt
│   │   │   │   └── theme/
│   │   │   │       └── NeoStreamTheme.kt # Theme Material 3
│   │   │   └── util/
│   │   │       ├── PlatformDetector.kt   # Détection Mobile/TV
│   │   │       └── TvKeyHandler.kt       # Gestion touches TV
│   │   ├── res/
│   │   │   ├── drawable/logo.png
│   │   │   ├── values/
│   │   │   │   ├── strings.xml
│   │   │   │   └── themes.xml
│   │   │   └── xml/network_security_config.xml
│   │   └── AndroidManifest.xml
│   ├── build.gradle.kts                  # Config module app
│   └── proguard-rules.pro
├── gradle/
│   └── libs.versions.toml                # Catalogue de dépendances
├── build.gradle.kts                      # Config projet racine
├── settings.gradle.kts
└── README.md                             # Ce fichier
```

---

## 💻 Développement

### Ajouter un nouvel écran Mobile

1. **Créer le Screen** dans `Screen.kt` :
```kotlin
data object NewScreen : Screen(route = "new_screen", title = "Nouveau", icon = Icons.Default.Star)
```

2. **Créer le ViewModel** :
```kotlin
class NewViewModel : ViewModel() {
    private val _state = MutableStateFlow(NewState())
    val state = _state.asStateFlow()
}
```

3. **Créer le Composable** :
```kotlin
@Composable
fun NewScreen(navController: NavController, viewModel: NewViewModel = viewModel()) {
    val state by viewModel.state.collectAsState()
    // UI...
}
```

4. **Ajouter à NavGraph** :
```kotlin
composable(Screen.NewScreen.route) {
    NewScreen(navController)
}
```

### Ajouter un écran TV

Consulter `app/src/main/kotlin/dev/neostream/app/ui/tv/TV_README.md` pour le guide complet.

### Ajouter une nouvelle API endpoint

1. **Dans `NeoStreamApi.kt`** :
```kotlin
suspend fun getNewData(): Result<List<MediaItem>> = runCatching {
    client.get("/new-endpoint").body()
}
```

2. **Dans le Repository** :
```kotlin
suspend fun fetchNewData(): List<MediaItem> {
    return NeoStreamApi.getNewData().getOrElse { emptyList() }
}
```

3. **Dans le ViewModel** :
```kotlin
viewModelScope.launch {
    _state.update { it.copy(isLoading = true) }
    val data = repository.fetchNewData()
    _state.update { it.copy(data = data, isLoading = false) }
}
```

### Ajouter un nouvel extracteur vidéo

Créer une classe dans `data/extractor/` :
```kotlin
object NewExtractor {
    suspend fun extract(embedUrl: String): Result<String> = runCatching {
        // Logique d'extraction
        videoDirectUrl
    }
}
```

---

## 🚀 Build & Déploiement

### Build Debug
```bash
./gradlew assembleDebug
# APK généré : app/build/outputs/apk/debug/app-debug.apk
```

### Build Release
```bash
./gradlew assembleRelease
# APK généré : app/build/outputs/apk/release/app-release.apk
```

### Signer l'APK (Production)

1. **Créer un keystore** :
```bash
keytool -genkey -v -keystore neostream.jks -keyalg RSA -keysize 2048 -validity 10000 -alias neostream
```

2. **Configurer dans `app/build.gradle.kts`** :
```kotlin
android {
    signingConfigs {
        create("release") {
            storeFile = file("../neostream.jks")
            storePassword = "votre_password"
            keyAlias = "neostream"
            keyPassword = "votre_password"
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### Tester sur Android TV

1. **Émulateur Android TV** :
   - Android Studio > Device Manager > Create Virtual Device > TV > Pixel Tablet

2. **Appareil physique** :
   - Activer le mode développeur
   - Activer le débogage USB/ADB
   - `adb connect <IP_TV>:5555`
   - `./gradlew installDebug`

---

## 🌐 API Backend

L'application communique avec une API backend via Ktor. URL par défaut : `http://fr1.spaceify.eu:26160`

### Endpoints disponibles

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/films` | GET | Liste des films (pagination) |
| `/series` | GET | Liste des séries (pagination) |
| `/item/:id` | GET | Détails d'un média |
| `/search` | GET | Recherche (query, type, limit) |
| `/autocomplete` | GET | Suggestions de recherche |
| `/recent` | GET | Médias récents |
| `/random` | GET | Médias aléatoires (genre, type) |
| `/top-rated` | GET | Mieux notés (minRating, type) |
| `/genres` | GET | Liste des genres |
| `/genres/:genre` | GET | Médias d'un genre |

### Exemple de réponse `/films`
```json
{
  "data": [
    {
      "id": "12345",
      "title": "Film Title",
      "type": "film",
      "poster": "https://...",
      "backdrop": "https://...",
      "year": 2024,
      "rating": 8.5,
      "duration": "2h 15min",
      "genres": ["Action", "Thriller"],
      "synopsis": "Description...",
      "cast": ["Actor 1", "Actor 2"],
      "videoUrl": "https://uqload.to/embed-xxx.html"
    }
  ],
  "total": 1523,
  "offset": 0,
  "limit": 50
}
```

---

## 📝 Notes importantes

### DNS-over-HTTPS
L'application utilise Cloudflare DoH (1.1.1.1) pour contourner les blocages FAI. Configuration dans `NeoStreamApp.kt`.

### ExoPlayer
Le `PlayerManager` est un **singleton** pour réutiliser l'instance. Libérer avec `PlayerManager.release()` dans `onDestroy()`.

### Room Database
3 entités : `FavoriteEntity`, `AccountEntity`, `WatchProgressEntity`. Migration automatique désactivée (fallbackToDestructiveMigration).

### ProGuard
Règles pour éviter l'obfuscation de :
- Kotlinx Serialization
- Ktor
- Media3
- Room

### Performances TV
- Utiliser `TvLazyRow` au lieu de `LazyRow`
- Limiter les listes à ~100 éléments max
- Précharger les images avec Coil3
- Éviter les recompositions inutiles (remember, derivedStateOf)

---

## 🤝 Contribution

1. Fork le projet
2. Créer une branche (`git checkout -b feature/AmazingFeature`)
3. Commit les changements (`git commit -m 'Add AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

---

## 📄 Licence

Projet privé - Tous droits réservés

---

## 👨‍💻 Auteur

**Pecorio Dev** - [GitHub](https://github.com/pecorio-dev)

---

## 🆘 Support

Pour toute question ou problème :
- Ouvrir une [Issue](https://github.com/pecorio-dev/NEO-Stream/issues)
- Consulter le [TV_README.md](app/src/main/kotlin/dev/neostream/app/ui/tv/TV_README.md) pour l'interface TV

---

**Version actuelle** : 1.0.0  
**Dernière mise à jour** : 2026-02-12
