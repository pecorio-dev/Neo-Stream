# NEO-Stream Design System Guide

## 🎨 Vue d'ensemble du Design System

NEO-Stream utilise un design system cohérent basé sur une esthétique **Cyberpunk/Neon** avec des animations spectaculaires et fluides.

---

## 🎯 Principes de Design

### 1. **Futuriste et Immersif**
- Utiliser des couleurs neon vives
- Ajouter des effets de glow et de neon
- Créer une atmosphère cinématique

### 2. **Accessible et Intuitif**
- Contraste suffisant pour la lisibilité
- Interactions claires et prévisibles
- Feedback visuel et haptique

### 3. **Performance et Fluidité**
- Animations optimisées (60fps)
- Transitions fluides et naturelles
- Pas de lag ou de blocage

---

## 🌈 Système de Couleurs

### Couleurs Primaires

#### Neon Cyan (Primaire)
```
Couleur: #00D4FF
Utilisation: Boutons principaux, accents, highlights
Code: ColorSystem.neonCyan
```

#### Neon Purple (Secondaire)
```
Couleur: #8B5CF6
Utilisation: Éléments secondaires, alternance avec cyan
Code: ColorSystem.neonPurple
```

#### Neon Pink (Accent)
```
Couleur: #FF006E
Utilisation: Appels à l'action, erreurs, attention
Code: ColorSystem.neonPink
```

#### Neon Green (Succès)
```
Couleur: #00FF41
Utilisation: Statut succès, confirmations
Code: ColorSystem.neonGreen
```

### Couleurs de Fond

```
Primaire (Très sombre):    #0A0A0F
Secondaire (Sombre):       #1A1A24
Tertiaire (Gris sombre):   #2A2A3A
Surface (Panneau):         #3A3A4A
```

### Couleurs de Texte

```
Primaire (Blanc):          #FFFFFF
Secondaire (Gris clair):   #B3B3B3
Tertiaire (Gris moyen):    #808080
Désactivé (Gris foncé):    #4D4D4D
```

---

## 🎬 Système d'Animations

### Durées Standard

```dart
ultraShort:  150ms
short:       300ms
medium:      500ms
long:        800ms
veryLong:    1200ms
```

### Courbes d'Animation

#### Courbes Principales
- `easeInOutCubic` - Animations lisses et naturelles
- `easeOutQuint` - Animations rapides qui ralentissent
- `elasticOut` - Effet élastique avec rebond
- `bounceOut` - Effet de rebond cinématique

#### Courbes Cyberpunk
- `neonPulse` - Pulsation neon (breathing effect)
- `cyberSlide` - Slide futuriste
- `laserFlash` - Flash rapide

### Types d'Animations

#### 1. Fade In
```dart
AnimationSystem.fadeIn(controller)
// Utilisé pour: Apparition d'éléments
// Durée: 300-500ms
```

#### 2. Scale with Bounce
```dart
AnimationSystem.scaleWithBounce(controller)
// Utilisé pour: Cartes, boutons
// Durée: 500ms
```

#### 3. Slide Animations
```dart
AnimationSystem.slideFromLeft(controller)
AnimationSystem.slideFromRight(controller)
AnimationSystem.slideFromTop(controller)
AnimationSystem.slideFromBottom(controller)
// Utilisé pour: Navigation, transitions
// Durée: 500ms
```

#### 4. Rotation
```dart
AnimationSystem.rotate360(controller)
// Utilisé pour: Chargement, refresh
// Durée: 1000-2000ms
```

#### 5. Pulse (Breathing)
```dart
AnimationSystem.pulse(controller)
// Utilisé pour: Indicateurs actifs
// Durée: Infini (repeat)
```

#### 6. Glow
```dart
AnimationSystem.glow(controller)
// Utilisé pour: Effets neon
// Durée: 600-1000ms
```

---

## 🎨 Dégradés Prédéfinis

### Dégradés Disponibles

```dart
// Cyan -> Purple
ColorSystem.cyanPurpleGradient

// Purple -> Pink
ColorSystem.purplePinkGradient

// Cyan -> Pink
ColorSystem.cyanPinkGradient

// Cyan -> Green
ColorSystem.cyanGreenGradient

// Fond vertical
ColorSystem.backgroundGradient

// Diagonal principal
ColorSystem.primaryDiagonalGradient

// Diagonal secondaire
ColorSystem.secondaryDiagonalGradient
```

---

## 🧩 Widgets Animés Disponibles

### 1. AnimatedNeonCard

Carte avec glow effect et hover animation.

```dart
AnimatedNeonCard(
  child: YourWidget(),
  onTap: () {},
  glowColor: ColorSystem.neonCyan,
  showGlow: true,
  animationDuration: Duration(milliseconds: 300),
)
```

**Caractéristiques:**
- Glow effect neon
- Scale animation au hover
- Border gradient
- Shadow dynamique

### 2. AnimatedNeonText

Texte avec gradient et fade-in.

```dart
AnimatedNeonText(
  'Votre texte',
  textStyle: TextStyle(
    color: ColorSystem.neonCyan,
    fontSize: 24,
  ),
  duration: Duration(milliseconds: 800),
)
```

**Caractéristiques:**
- Fade-in automatique
- Gradient shader
- Animations lisses

### 3. AnimatedNeonButton

Bouton avec effets neon et hover animation.

```dart
AnimatedNeonButton(
  label: 'CLIQUEZ',
  onPressed: () {},
  color: ColorSystem.neonCyan,
  hoverColor: ColorSystem.neonPurple,
  showGlow: true,
)
```

**Caractéristiques:**
- Changement de couleur au hover
- Glow dynamique
- Scale animation
- Feedback haptique

### 4. NeonLoadingIndicator

Indicateur de chargement avec style neon.

```dart
NeonLoadingIndicator(
  color: ColorSystem.neonCyan,
  size: 50,
  duration: Duration(seconds: 2),
)
```

**Caractéristiques:**
- Rotation continue
- Pulsation d'échelle
- Glow effect

### 5. AnimatedStaggeredList

Liste avec effet stagger.

```dart
AnimatedStaggeredList(
  children: [
    Widget1(),
    Widget2(),
    Widget3(),
  ],
  itemDelay: Duration(milliseconds: 100),
)
```

**Caractéristiques:**
- Apparition progressive
- Fade + Slide combinés
- Délai configurable entre items

---

## 🚀 Transitions de Page

### Disponibles

#### Fade Transition
```dart
PageTransitions.fadeTransition(page)
// Simple, fade-in/out
// Durée: 300ms
```

#### Slide Right Transition
```dart
PageTransitions.slideRightTransition(page)
// Slide depuis la droite
// Durée: 500ms
```

#### Scale Transition
```dart
PageTransitions.scaleTransition(page)
// Scale + Fade combinés
// Durée: 500ms
```

#### Rotate Transition
```dart
PageTransitions.rotateTransition(page)
// Scale + Rotate combinés
// Durée: 600ms
```

#### Spectacular Transition
```dart
PageTransitions.spectacularTransition(page)
// Slide + Scale + Fade épique
// Durée: 700ms
```

---

## 📱 Composants Recommandés

### Pour les Listes
- `AnimatedStaggeredList` avec `itemDelay: 100ms`
- Utilisez `slideFromBottom` pour l'animation

### Pour les Cartes
- `AnimatedNeonCard` avec `glowColor: ColorSystem.neonCyan`
- Ajouter `AnimatedNeonButton` pour les CTA

### Pour les Modales
- `PageTransitions.spectacularTransition`
- Durée: 700ms

### Pour le Chargement
- `NeonLoadingIndicator`
- Ajouter `shimmer` optionnel

---

## 🎬 Patterns d'Animation Recommandés

### Pattern 1: Apparition Progressive

```dart
CustomScrollView(
  slivers: [
    // Header
    SliverAppBar(
      flexibleSpace: FadeTransition(
        opacity: headerAnimation,
        child: SlideTransition(
          position: slideAnimation,
          child: Header(),
        ),
      ),
    ),
    
    // Contenu avec stagger
    AnimatedStaggeredList(
      children: contentItems,
      itemDelay: Duration(milliseconds: 50),
    ),
  ],
)
```

### Pattern 2: Cascade d'Animations

```dart
@override
void initState() {
  _mainController = AnimationController(duration: Duration(ms: 1500));
  _headerController = AnimationController(duration: Duration(ms: 800));
  _contentController = AnimationController(duration: Duration(ms: 1200));
  
  _mainController.forward();
  Future.delayed(Duration(ms: 200), () => _headerController.forward());
  Future.delayed(Duration(ms: 400), () => _contentController.forward());
}
```

### Pattern 3: Hover Effects

```dart
MouseRegion(
  onEnter: (_) => _controller.forward(),
  onExit: (_) => _controller.reverse(),
  child: ScaleTransition(
    scale: _scaleAnimation,
    child: GlowEffect(child: Widget()),
  ),
)
```

---

## 🎯 Checklist de Conception

### Pour chaque écran:
- [ ] Header avec animation spectaculaire
- [ ] Titre avec `AnimatedNeonText`
- [ ] Grille avec `AnimatedStaggeredList`
- [ ] Cartes avec `AnimatedNeonCard`
- [ ] Boutons avec `AnimatedNeonButton`
- [ ] Indicateur de chargement neon
- [ ] Transitions de page fluides

### Pour chaque interaction:
- [ ] Feedback visuel immédiat
- [ ] Animation de 200-500ms
- [ ] Feedback haptique optionnel
- [ ] État hover/focus clair

---

## 🔧 Configuration par Défaut

```dart
// Animations
const cardAnimationDuration = Duration(milliseconds: 500);
const listItemDuration = Duration(milliseconds: 300);
const transitionDuration = Duration(milliseconds: 500);

// Couleurs
const primaryColor = ColorSystem.neonCyan;
const secondaryColor = ColorSystem.neonPurple;
const accentColor = ColorSystem.neonPink;

// Texte
const headingStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontSize: 24,
  letterSpacing: 1.5,
);
```

---

## 📚 Ressources d'Inspiration

- **Animation**: Flutter docs (PageRouteBuilder, AnimatedBuilder)
- **Couleurs**: Cyberpunk aesthetic, Neon design
- **Typographie**: Google Fonts (Orbitron, Rajdhani)

---

## 🚀 Prochaines Étapes

1. Appliquer le design system à tous les écrans
2. Ajouter animations custom où nécessaire
3. Tester les performances (60fps)
4. Recueillir les retours utilisateurs
5. Affiner et optimiser

---

**Version**: 1.0  
**Date**: 2024  
**Statut**: ✅ Production Ready