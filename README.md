# 🎬 NEO-Stream

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.6+-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.6+-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-7.1+-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Android%20|%20TV-blueviolet?style=for-the-badge)

**🌟 L'avenir du streaming est maintenant 🌟**

*Une application de streaming moderne avec une interface cyberpunk néon époustouflante*

[📥 Télécharger](#installation) • [✨ Fonctionnalités](#fonctionnalités) • [📸 Captures](#captures-décran) • [🛠️ Build](#build)

</div>

---

## 🚀 À propos

**NEO-Stream** est une application de streaming élégante et performante développée avec Flutter. Elle offre une expérience utilisateur futuriste avec un design cyberpunk unique, compatible avec les smartphones Android et les Android TV (incluant Freebox Mini 4K).

### 🎯 Points forts

- 🎨 **Design Cyberpunk** - Interface néon avec animations fluides
- 📺 **Multi-plateforme** - Mobile Android & Android TV
- 👥 **Multi-profils** - Gestion de profils utilisateurs avec avatars personnalisés
- 🔍 **Recherche intelligente** - Films et séries avec filtres avancés
- ⏯️ **Reprise automatique** - Continuez où vous vous êtes arrêté
- 📊 **Suivi de progression** - Historique de visionnage complet
- ⭐ **Favoris** - Sauvegardez vos contenus préférés
- 🎮 **Navigation TV** - Support complet télécommande D-pad

---

## ✨ Fonctionnalités

### 📱 Interface Utilisateur
- Design Material 3 avec thème cyberpunk personnalisé
- Animations fluides avec Flutter Animate
- Fonts Orbitron & Rajdhani pour l'esthétique futuriste
- Mode sombre optimisé avec accents néon cyan/violet

### 🎬 Streaming
- Lecteur vidéo intégré avec contrôles complets
- Support des headers personnalisés pour les streams
- Extraction automatique des liens vidéo (UQLoad, etc.)
- Sauvegarde automatique de la progression

### 👤 Gestion des Profils
- Création de profils multiples
- 12 avatars personnalisés inclus
- Données séparées par profil (favoris, progression)
- Protection par question secrète (optionnel)

### 📺 Support TV
- Navigation D-pad complète
- Focus visuel adapté aux grands écrans
- Clavier virtuel optimisé TV
- Compatible Freebox Mini 4K (Android 7.1+)

### 🔧 Technique
- Architecture clean avec Riverpod
- Système de cache intelligent
- DNS Quad9 pour contournement géographique
- Proxy d'images pour optimisation

---

## 📋 Prérequis

- Flutter SDK 3.6+
- Dart SDK 3.6+
- Android SDK (API 25+)

---

## 🛠️ Build

### Cloner le projet

```bash
git clone https://github.com/pecorio-dev/Neo-Stream.git
cd Neo-Stream
```

### Installer les dépendances

```bash
flutter pub get
```

### Générer le code (Riverpod, Freezed, Hive)

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Build APK Release

```bash
flutter build apk --release
```

L'APK sera disponible dans `build/app/outputs/flutter-apk/app-release.apk`

### Build APK Debug

```bash
flutter build apk --debug
```

---

## 📥 Installation

### Téléchargement direct

Téléchargez la dernière version depuis la page [Releases](https://github.com/pecorio-dev/Neo-Stream/releases).

### Installation manuelle

1. Activez "Sources inconnues" dans les paramètres Android
2. Téléchargez le fichier APK
3. Ouvrez le fichier et suivez les instructions

---

## 🏗️ Architecture

```
lib/
├── core/                    # Services et utilitaires de base
│   ├── constants/           # Constantes de l'application
│   ├── design_system/       # Système de couleurs et animations
│   ├── initialization/      # Initialisation de l'app
│   ├── navigation/          # Système de navigation
│   ├── services/            # Services (DNS, Cast, etc.)
│   ├── theme/               # Thème Material
│   ├── tv/                  # Support Android TV
│   └── utils/               # Utilitaires divers
├── data/                    # Couche données
│   ├── extractors/          # Extracteurs de liens vidéo
│   ├── models/              # Modèles de données
│   ├── repositories/        # Repositories
│   └── services/            # Services API et stockage
├── presentation/            # Couche UI
│   ├── providers/           # Providers Riverpod
│   ├── screens/             # Écrans de l'application
│   └── widgets/             # Widgets réutilisables
└── main.dart                # Point d'entrée
```

---

## 🎨 Palette de Couleurs

| Couleur | Hex | Usage |
|---------|-----|-------|
| Background Primary | `#0A0A0F` | Fond principal |
| Background Secondary | `#1A1A24` | Fond secondaire |
| Neon Cyan | `#00D4FF` | Accent principal |
| Neon Purple | `#8B5CF6` | Accent secondaire |
| Text Primary | `#FFFFFF` | Texte principal |
| Text Secondary | `#B3B3B3` | Texte secondaire |

---

## 📦 Dépendances principales

| Package | Usage |
|---------|-------|
| `flutter_riverpod` | State management |
| `video_player` | Lecteur vidéo |
| `dio` | Client HTTP |
| `hive_flutter` | Base de données locale |
| `cached_network_image` | Cache images |
| `flutter_animate` | Animations |
| `google_fonts` | Polices personnalisées |

---

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :

1. Fork le projet
2. Créer une branche (`git checkout -b feature/AmazingFeature`)
3. Commit vos changements (`git commit -m 'Add AmazingFeature'`)
4. Push sur la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

---

## ⚠️ Disclaimer

Cette application est fournie à des fins éducatives et de démonstration uniquement. L'utilisation de cette application pour accéder à du contenu protégé par le droit d'auteur sans autorisation est interdite. Les utilisateurs sont responsables de s'assurer qu'ils respectent toutes les lois applicables en matière de droits d'auteur.

---

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

---

## 👤 Auteur

**Pecorio Dev**

- GitHub: [@pecorio-dev](https://github.com/pecorio-dev)

---

<div align="center">

**⭐ Si vous aimez ce projet, n'hésitez pas à lui donner une étoile !**

![Made with Flutter](https://img.shields.io/badge/Made%20with-Flutter-02569B?style=flat-square&logo=flutter)
![Made with Love](https://img.shields.io/badge/Made%20with-❤️-red?style=flat-square)

</div>

---

## 🔑 Keywords

`flutter` `streaming` `android` `android-tv` `video-player` `movies` `series` `cyberpunk` `neon-ui` `dart` `riverpod` `material-design` `open-source` `freebox` `iptv` `media-player` `flutter-app` `streaming-app` `entertainment` `vod` `video-streaming` `mobile-app` `tv-app`
