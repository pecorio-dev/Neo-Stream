# Changelog — Neo-Stream

## v1.0.0 — 13 mai 2026

Première version publique de Neo-Stream.

### Plateformes
- Windows 10/11 (x64) — installeur `NeoStream-Setup-v1.0.0.exe`
- Android — APK universel (`app-release.apk`)
- Android TV — navigation directionnelle complète

### Fonctionnalités
- Catalogue films, séries et animés avec fiches détaillées
- Lecture via 15+ hébergeurs : VOE, Doodstream, Filemoon, Uqload, Streamtape, Vidoza, Mixdrop, Netu, Vidzy, Uptostream, MultiUp, et plus
- Extraction vidéo côté client (Dart) calquée exactement sur le backend PHP
- Qualités multiples : sélection automatique ou manuelle du serveur
- Reprise de lecture (continue watching) avec barre de progression
- Recherche intégrée avec filtres par type (film / série / anime)
- Navigation TV A-Z au D-Pad : focus directionnel, scroll automatique sur la carte active, pas de nœud fantôme
- Retry automatique ×2 sur erreur de lecture (ré-extraction de l'URL, pas simple re-ouverture)
- Thème sombre adaptatif (mobile, tablette, TV, Windows)

### Notes techniques
- Accès via licence lifetime (10 €) — authentification JWT 30 jours
- Aucune donnée personnelle collectée au-delà du compte
- Backend PHP hébergé sur `neo-stream.eu`

---

*Les versions suivantes seront listées ici au fil des mises à jour.*
