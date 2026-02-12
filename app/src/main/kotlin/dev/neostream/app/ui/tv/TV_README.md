# 📺 NeoStream TV Interface

Interface TV complète pour NeoStream, optimisée pour navigation D-pad (télécommande).

## 🎮 CONTRÔLES CLAVIER (TEST)

### Navigation de base
| Touche | Action |
|--------|--------|
| **W** ou **↑** | Haut |
| **S** ou **↓** | Bas |
| **A** ou **←** | Gauche |
| **D** ou **→** | Droite |
| **Enter** ou **Space** | Sélectionner/OK |
| **Backspace** ou **Esc** | Retour |
| **H** | Accueil |
| **M** | Menu |
| **Ctrl+F** | Recherche |

## 📁 ARCHITECTURE

```
ui/tv/
├── screens/           # Écrans TV
│   ├── TvHomeScreen.kt
│   ├── TvMoviesScreen.kt
│   ├── TvSeriesScreen.kt
│   ├── TvDetailScreen.kt
│   ├── TvSearchScreen.kt
│   ├── TvFavoritesScreen.kt
│   └── TvSettingsScreen.kt
│
├── components/        # Composants TV
│   ├── TvFocusable.kt          # Base focus D-pad
│   ├── TvCard.kt               # Cartes média
│   ├── TvRow.kt                # Rangées horizontales
│   ├── TvSidebar.kt            # Menu latéral
│   ├── TvButton.kt             # Boutons
│   └── TvKeyEventHandler.kt    # Gestion clavier
│
└── navigation/        # Navigation TV
    └── TvNavGraph.kt
```

## 🎨 DESIGN PRINCIPLES

### 1. Navigation D-pad First
- Tout est accessible au D-pad uniquement
- Pas de scroll, navigation par focus
- Aucun "focus trap" - toujours un moyen de sortir

### 2. Focus visuel clair
- Border glow cyan quand focusé
- Scale 1.1x pour les cartes
- Animations fluides (200-300ms)

### 3. Tailles adaptées TV (10-foot UI)
- Cartes: 200-280dp de large
- Texte minimum: 18sp
- Espacement généreux: 24-48dp
- Lisible à 3 mètres de distance

### 4. Performance
- 60fps constant
- Pas de scroll lourd
- LazyRows pour performance

## 🗺️ NAVIGATION FLOW

```
TvHomeScreen (Point central)
    ├─→ TvMoviesScreen
    │   └─→ TvDetailScreen (film)
    │       └─→ VideoPlayerActivity
    │
    ├─→ TvSeriesScreen
    │   └─→ TvDetailScreen (série)
    │       └─→ VideoPlayerActivity
    │
    ├─→ TvFavoritesScreen
    │   └─→ TvDetailScreen
    │
    ├─→ TvSearchScreen
    │   └─→ TvDetailScreen
    │
    └─→ TvSettingsScreen
```

## 🧪 TEST DEPUIS MOBILE

1. **Forcer mode TV** : 
   - Modifier `PlatformDetector` pour retourner `Platform.TV`
   - OU utiliser émulateur Android TV

2. **Navigation clavier** :
   - WASD ou Arrow keys pour naviguer
   - Enter/Space pour sélectionner
   - Backspace/Esc pour retour

3. **Test complet** :
   ```
   ✓ Navigation complète au clavier
   ✓ Focus toujours visible
   ✓ Pas de blocage de focus
   ✓ BACK fonctionne partout
   ✓ Performance fluide
   ```

## 📋 SCREENS DÉTAILLÉS

### TvHomeScreen
- Sidebar gauche avec menu
- Rows de contenu (Continuer, Populaires, etc.)
- Navigation horizontale dans rows, verticale entre rows

### TvMoviesScreen / TvSeriesScreen
- Sidebar + grille de contenus
- Filtrage par genre
- Rows par catégorie

### TvDetailScreen
- Backdrop flou en fond
- Poster + infos détaillées
- Boutons action (Lecture, Favoris)
- Sélecteur saisons/épisodes (séries)
- Recommandations

### TvSearchScreen
- Clavier virtuel navigable au D-pad
- Résultats en grille
- Recherche temps réel

### TvFavoritesScreen
- Grille de favoris
- Tri et filtres

### TvSettingsScreen
- Liste de paramètres
- Statistiques de visionnage
- Lien Ko-fi

## 🔧 COMPOSANTS CLÉS

### TvFocusable
Composant de base pour focus D-pad avec animations.

```kotlin
TvFocusable(
    onClick = { /* action */ },
    scaleOnFocus = 1.1f,
    borderColor = AccentCyan
) { isFocused ->
    // Votre contenu
}
```

### TvCard
Carte média optimisée TV (280x420dp).

```kotlin
TvCard(
    title = "Film",
    posterUrl = "...",
    onClick = { /* open detail */ },
    rating = 8.5f,
    year = "2024"
)
```

### TvRow
Rangée horizontale de contenus.

```kotlin
TvRow(
    title = "🔥 Populaires",
    items = movies,
    onItemClick = { movie -> /* action */ }
)
```

## ✅ CHECKLIST VALIDATION

Chaque screen doit passer :
- [ ] Navigation complète au clavier
- [ ] Focus toujours visible et clair
- [ ] Pas de "focus trap"
- [ ] BACK fonctionne toujours
- [ ] Éléments minimum 48dp
- [ ] Texte lisible à 3m
- [ ] Performance 60fps
- [ ] Aucune dépendance au code mobile

## 🚀 PROCHAINES AMÉLIORATIONS

1. **Animations avancées**
   - Parallax sur backdrop
   - Transitions entre écrans
   - Ripple effects

2. **Sons** (optionnel)
   - Feedback sonore navigation
   - Confirmation sélection

3. **Personnalisation**
   - Thèmes
   - Tailles de texte
   - Vitesse animations

4. **Accessibilité**
   - Navigation vocale
   - Contraste élevé
   - Sous-titres par défaut

## 📝 NOTES DÉVELOPPEMENT

- **ViewModels partagés** : Les ViewModels (mobile) sont réutilisés
- **Séparation totale** : Aucun code TV dans mobile/, vice-versa
- **Test keyboard** : Toujours testable avec WASD/Arrows depuis mobile
- **Performance** : LazyRows/Grids pour listes longues
- **Focus management** : Compose Focus API + custom handlers
