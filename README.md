<div align="center">

<img src="app/app/assets/icon.png" width="120" alt="Neo-Stream logo"/>

# Neo-Stream

### Films &bull; Séries &bull; Anime &bull; TV en direct — gratuit, sans pub, multiplateforme

<p>
  <a href="https://github.com/pecorio-dev/Neo-Stream/releases/latest"><img src="https://img.shields.io/github/v/release/pecorio-dev/Neo-Stream?style=flat-square&logo=git&logoColor=white&label=Version" alt="Latest Release"></a>
  <img src="https://img.shields.io/github/downloads/pecorio-dev/Neo-Stream/total?style=flat-square&logo=github&logoColor=white&label=Downloads&color=blue" alt="Downloads">
  <img src="https://img.shields.io/github/stars/pecorio-dev/Neo-Stream?style=flat-square&logo=star&logoColor=white&color=yellow" alt="Stars">
  <img src="https://img.shields.io/github/forks/pecorio-dev/Neo-Stream?style=flat-square&logo=gitfork&logoColor=white&color=green" alt="Forks">
  <img src="https://img.shields.io/github/issues/pecorio-dev/Neo-Stream?style=flat-square&logo=github&logoColor=white&label=Issues" alt="Issues">
</p>

<p>
  <a href="https://github.com/pecorio-dev/Neo-Stream/actions/workflows/release.yml"><img src="https://img.shields.io/github/actions/workflow/status/pecorio-dev/Neo-Stream/release.yml?style=flat-square&logo=github-actions&logoColor=white&label=Release%20Build" alt="Release CI"></a>
  <a href="https://github.com/pecorio-dev/Neo-Stream/actions/workflows/build-all.yml"><img src="https://img.shields.io/github/actions/workflow/status/pecorio-dev/Neo-Stream/build-all.yml?style=flat-square&logo=github-actions&logoColor=white&label=All%20Platforms%20Build" alt="Build All CI"></a>
</p>

<p>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.44-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter"></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=flat-square&logo=dart&logoColor=white" alt="Dart"></a>
  <img src="https://img.shields.io/badge/Android-APK-3DDC84?style=flat-square&logo=android&logoColor=white" alt="Android">
  <img src="https://img.shields.io/badge/Android%20TV-%E2%9C%93-E50914?style=flat-square&logo=android&logoColor=white" alt="Android TV">
  <img src="https://img.shields.io/badge/Windows-%E2%9C%93-0078D4?style=flat-square&logo=windows&logoColor=white" alt="Windows">
  <img src="https://img.shields.io/badge/Linux-%E2%9C%93-FCC624?style=flat-square&logo=linux&logoColor=black" alt="Linux">
</p>

<p>
  <a href="https://neo-stream.eu">Site web</a> &bull;
  <a href="https://github.com/pecorio-dev/Neo-Stream/releases/latest">Télécharger</a> &bull;
  <a href="#installation">Installation</a> &bull;
  <a href="#fonctionnement-de-lextraction">Extraction vidéo</a> &bull;
  <a href="#build-depuis-les-sources">Build</a>
</p>

---

</div>

## Captures d'écran

<div align="center">
  <table>
    <tr>
      <td align="center"><b>Accueil — découverte</b></td>
      <td align="center"><b>Accueil — tendances</b></td>
    </tr>
    <tr>
      <td><img src="screenshots/home-01.jpg" alt="Accueil découverte" width="400"></td>
      <td><img src="screenshots/home-02.jpg" alt="Accueil tendances" width="400"></td>
    </tr>
    <tr>
      <td align="center"><b>Catalogue — grille</b></td>
      <td align="center"><b>Fiche contenu</b></td>
    </tr>
    <tr>
      <td><img src="screenshots/browse-01.jpg" alt="Catalogue grille" width="400"></td>
      <td><img src="screenshots/detail-01.jpg" alt="Fiche détaillée" width="400"></td>
    </tr>
    <tr>
      <td align="center"><b>Lecteur vidéo</b></td>
      <td align="center"><b>TV en direct</b></td>
    </tr>
    <tr>
      <td><img src="screenshots/detail-03.jpg" alt="Lecteur vidéo" width="400"></td>
      <td><img src="screenshots/live-01.jpg" alt="Direct chaînes TV" width="400"></td>
    </tr>
  </table>
</div>

---

## Statistiques

<div align="center">
  <a href="https://github.com/pecorio-dev/Neo-Stream">
    <img src="https://github-readme-stats.vercel.app/api?username=pecorio-dev&show_icons=true&theme=dark&hide_border=true" alt="Statistiques GitHub" width="48%">
  </a>
  <a href="https://github.com/pecorio-dev/Neo-Stream">
    <img src="https://github-readme-stats.vercel.app/api/pin/?username=pecorio-dev&repo=Neo-Stream&theme=dark&hide_border=true" alt="Carte du dépôt Neo-Stream" width="48%">
  </a>
  <a href="https://github.com/pecorio-dev/Neo-Stream">
    <img src="https://github-readme-stats.vercel.app/api/top-langs/?username=pecorio-dev&layout=compact&theme=dark&hide_border=true" alt="Langages principaux" width="48%">
  </a>
</div>

---

## Fonctionnalités

| Fonctionnalité | Description |
|---|---|
| **Catalogue complet** | Films, séries et anime avec fiches détaillées, saisons, épisodes |
| **TV en direct** | Chaînes IPTV HD françaises via proxy FSTV (option premium) |
| **Téléchargements hors-ligne** | Films, épisodes, saisons ou séries entières — extraction intégrée, lecture hors-ligne |
| **Enchaînement auto des épisodes** | Continuation façon Netflix avec compte à rebours (téléphone et TV) |
| **Vitesse de lecture** | 0.5x à 2x, mémorisée, plus minuteur de sommeil |
| **Lecteur universel** | ExoPlayer natif (Android), media_kit (Windows/Linux), sélecteur de source intégré |
| **Extraction anti-blocage** | Multi-extracteurs reverse-engineered, DoH, relais serveur, émulation navigateur (voir ci-dessous) |
| **Zéro pub** | URL directe HLS/MP4 — aucune pub des hébergeurs ne transite |
| **Reprise auto** | Continue exactement où vous vous êtes arrêté, synchronisé multi-appareils |
| **Recherche avancée** | Historique local, filtres Films / Séries / Anime / note 7+ |
| **Catalogue hors-ligne** | Cache local — démarrage instantané, repli sans réseau |
| **Favoris et historique** | Bibliothèque personnelle et historique de visionnage |
| **Multi-profils** | Jusqu'à 4 sous-comptes protégés par mot de passe optionnel |
| **Recherche IA** | Recherche en langage naturel optionnelle |
| **Multi-plateforme** | Android, Android TV (navigation D-pad complète), Windows, Linux |
| **Design cohérent** | Thème clair/sombre adaptatif, contraste contrôlé partout |
| **Mises à jour auto** | Vérification via GitHub Releases, téléchargement et installation intégrés |

---

## Fonctionnement de l'extraction

Neo-Stream lit les agrégateurs français (FrenchStream et assimilés) qui listent des pages embed hébergeurs (uqload, vidmoly, doodstream, filemoon, voe…), et transforme chaque page embed en **URL vidéo directe** (HLS `.m3u8` ou MP4 progressif) jouable par le moteur, avec téléchargement hors-ligne au passage.

### Chaîne complète

```
Fiche contenu (API /app/content/detail)
   └─ watch_links (urls embed, classées par score/langue)
        └─ Extraction serveur (o2switch, non bloqué par les FAI)
             ├─ succès → URL directe HLS/MP4 + headers requis
             ├─ échec/vide → extracteur local reverse-engineered
                  ├─ uqload      → unpack statique multi-éval (packer Dean Edwards)
                  ├─ voe         → décoder propriétaire (ROT13 → nettoyage opérateurs
                  │                → base64 → Caesar −3 → reverse → base64 → JSON)
                  ├─ doodstream  → chaîne /pass_md5 → préfixe CDN + token&expiry
                  ├─ filemoon    → pipeline API Byse : attestation ECDSA (P-256)
                  │                + proof-of-work sha256 + déchiffrement AES-256-GCM
                  ├─ vidmoly/savefiles/vidaraa/minochinos… → extracteurs dédiés
                  └─ Cloudflare / challengé : émulation navigateur (headless WebView)
                       et sniff réseau (performance API) pour récupérer l'URL réelle
        └─ Filtrage intelligible
             ├─ trolls confirmés (/troll/, bigbuckbunny, clips <300s, MP4 <15Mo)
             ├─ pages de parking (domaines expirés : multiup, 96ar…)
             └─ spams / trackers
        └─ Lecteur (natif) ou téléchargement
             └─ Blocage réseau résiduel : DoH + TLS/SNI sur IP résolue
                  + relais serveur o2switch (live_proxy) + proxy local 127.0.0.1
```

### Contournement des blocages réseau

| Terrain hostile | Contre-mesure |
|---|---|
| DNS de `neo-stream.eu` cassé | Repli automatique sur l'IP du serveur avec `Host:` forcé |
| DNS FAI empoisonné (hosters) | DoH interne (dns.google/Cloudflare) + TLS/SNI direct sur IP |
| Certificats hébergeurs incomplets | Client HTTP tolérant ciblé (hors domaine propre) |
| CDN refusant la connexion (RST) | Relais serveur `live_proxy` (segments réécrits) |
| Cloudflare Under-Attack | WebView headless + sniff `performance.getEntriesByType('resource')` |
| Blanc/reset intermittent sur live HLS | Retries natifs ExoPlayer + rafraîchissement des jetons |

Le même pipeline alimente **lecture** et **téléchargements** (segments HLS concaténés en `.ts`, MP4 streamé), avec failover automatique entre tous les liens candidats d'un épisode ou d'un film.

---

## Stack technique

| Couche | Technologies |
|---|---|
| **Frontend** | Flutter 3.x, Dart 3.x |
| **Lecteur vidéo** | ExoPlayer natif (Android), media_kit (Windows/Linux), WebView headless |
| **Extraction** | Reverse engineering Dart : p.a.c.k.e.d multi-éval, ECDSA P-256, PoW, AES-GCM, ROT13/Caesar/base64, DoH, TLS/SNI, relais |
| **State management** | Provider |
| **Backend** | PHP 8.x, JWT, MySQL, cache fichier, gzip |
| **CI/CD** | GitHub Actions (build multi-plateforme automatique) |
| **Distribution** | GitHub Releases, Inno Setup (Windows), AppImage + .deb (Linux), APK |

---

## Installation

| Plateforme | Format commun | Lien |
|---|---|---|
| Android (téléphones récents, arm64) | APK | [Releases](https://github.com/pecorio-dev/Neo-Stream/releases/latest) |
| Android (architectures anciennes) | APK armv7 | [Releases](https://github.com/pecorio-dev/Neo-Stream/releases/latest) |
| Android TV / émulateurs x86 | APK x86_64 | [Releases](https://github.com/pecorio-dev/Neo-Stream/releases/latest) |
| Windows 10/11 | Installateur `.exe` (Inno Setup) | [Releases](https://github.com/pecorio-dev/Neo-Stream/releases/latest) |
| Linux (AppImage universelle) | AppImage | [Releases](https://github.com/pecorio-dev/Neo-Stream/releases/latest) |
| Debian / Ubuntu / Zorin | `.deb` | [Releases](https://github.com/pecorio-dev/Neo-Stream/releases/latest) |
| Autres distributions | `.tar.gz` | [Releases](https://github.com/pecorio-dev/Neo-Stream/releases/latest) |

L'application se met à jour automatiquement via GitHub Releases.

---

## Build depuis les sources

### Prérequis

- Flutter 3.x (`flutter --version`)
- JDK 17 (pour Android)
- Linux : `libmpv-dev libgtk-3-dev ninja-build cmake clang pkg-config`

```bash
# Cloner
git clone https://github.com/pecorio-dev/Neo-Stream.git
cd Neo-Stream/app/app

# Dépendances
flutter pub get

# Build de développement
flutter run

# Builds release
flutter build apk --release        # Android
flutter build windows --release    # Windows
flutter build linux --release      # Linux
```

### Tests extracteurs (références indépendantes)

```bash
cd app/app
dart run bin/re_uqload.dart       # extracteur uqload (liens de test intégrés)
dart run bin/re_filemoon.dart     # pipeline Byse complet (crypto incluse)
dart run bin/re_voe.dart          # décodeur voe
dart run bin/re_dood.dart         # chaîne doodstream
dart bin/re_channels.dart         # état des portails FStream/Cloudflare
```

---

## Structure du projet

```
Neo-Stream/
├── .github/workflows/          CI/CD (build-all, build-windows, release)
├── app/
│   ├── app/                    Application Flutter
│   │   ├── lib/
│   │   │   ├── config/         Thème (sombre/clair), constantes
│   │   │   ├── models/         Content, Anime, User, SubAccount, WatchLink
│   │   │   ├── providers/      Theme, Auth, Content, Update
│   │   │   ├── screens/        Écrans mobile + TV, Téléchargements
│   │   │   │   └── tv/         Interface dédiée Android TV
│   │   │   ├── services/       API, VideoExtractor, extractors/ (RE prouvés),
│   │   │   │                  DownloadService, WebViewExtractor, ResilientHttp,
│   │   │   │                  LocalStreamProxy, DohResolver, DirectTlsFetch,
│   │   │   │                  AnimeExtractor, FSTV, PlayerPrefs, SearchHistory
│   │   │   ├── utils/          TVDetector, Semver, WatchLinkUtils, helpers
│   │   │   └── widgets/        ContentCard, HeroBanner, Shimmer, DownloadButton
│   │   ├── bin/                Extracteurs de test indépendants (références)
│   │   ├── android/            Kotlin : NativeVideoActivity (ExoPlayer TV/phone)
|   |   ├── assets/             Icônes, polices
│   │   └── pubspec.yaml        Dépendances (v1.4.0)
│   ├── neo_stream_setup.iss    Script Inno Setup (Windows)
│   └── CHANGELOG.md
├── screenshots/                Captures (utilisées par neo-stream.eu)
├── build.sh / make_appimage.sh Scripts de packaging Linux
└── README.md
```

---

## Tarification

> **10 € — une seule fois — accès à vie.**

L'accès aux films, séries et anime est **100 % gratuit**. Seule la TV en direct (IPTV HD) est une option premium. Paiement sécurisé via PayPal directement dans l'app.

---

## À propos

Je m'appelle **p3cori0**, j'ai 17 ans, et Neo-Stream est le projet le plus important de ma vie jusqu'ici.

Il y a deux ans, je ne savais pas coder. J'avais une idée — une vraie plateforme de streaming, propre, sans pub, accessible — et aucun moyen de la construire. Alors j'ai appris. Deux ans de soirées, de weekends, de recommencements.

Le but de Neo-Stream est simple : casser les codes. Une contribution minuscule — 10 € une seule fois — pour des films, séries et anime en 720p/1080p, sans pub, sur tous les appareils.

Neo-Stream existe, il tourne, des gens l'utilisent. Et ça, personne ne peut me l'enlever.

---

## Soutenir le projet

- Donner une étoile au dépôt — c'est gratuit et ça aide énormément
- Signaler un bug via les [Issues](https://github.com/pecorio-dev/Neo-Stream/issues)
- En parler autour de soi — le meilleur marketing
- Acheter une licence (10 € à vie) sur [neo-stream.eu](https://neo-stream.eu)

---

## Changelog

Voir [app/CHANGELOG.md](app/CHANGELOG.md) pour l'historique complet.

| Version | Date | Highlights |
|---|---|---|
| v1.4.0 | 08/08/2026 | Téléchargements hors-ligne, enchaînement auto épisodes, sélecteur de source dans le lecteur, vitesse de lecture mémorisée, minuteur de sommeil, recherche avancée, catálogue hors-ligne, extraction reverse-engineered multi-hébergeurs (uqload/filemoon/voe/doodstream), filtres anti-troll, anti-blocage réseau, fix contraste complet |
| v1.3.2 | 29/07/2026 | Fix focus recherche TV, extraction vidéo, lecteur, favoris, performances |
| v1.3.1 | 27/07/2026 | Migration Android TV ExoPlayer, fallback multi-source, correctifs IPTV |
| v1.2.2 | 19/07/2026 | Fix carousel thème clair, stop re-extraction Sibnet |
| v1.2.1 | 11/07/2026 | Fix thème clair illisible, stop re-extraction Sibnet |
| v1.0.0 | 13/05/2026 | Première version publique (Windows, Android, Android TV) |

---

<div align="center">

**Fait avec trop de café et beaucoup d'obstination** par [p3cori0](https://github.com/pecorio-dev) &bull; 17 ans &bull; France

*"Commence. Le reste vient."*

</div>
