# Changelog — Neo-Stream

## v1.4.0 (pré-release) — 8 août 2026

### Nouveautés
- **Téléchargements hors-ligne** : films, épisodes de séries et anime téléchargeables depuis les fiches (par épisode, saison ou série entière) — extraction via le moteur existant, MP4 direct ou HLS concaténé ; écran Téléchargements dédié (progression, reprise, lecture hors-ligne)
- **Épisode suivant automatique** : carte façon Netflix avec compte à rebours 10 s et enchaînement (lecteur natif Android inclus) + bouton « épisode suivant » manuel
- **Sélecteur de source dans le lecteur** : choix manuel du serveur pendant la lecture (téléphone tactile, TV D-pad, desktop)
- **Vitesse de lecture** : 0.5x → 2x, mémorisée (natif Android + desktop)
- **Minuteur de sommeil** : 15/30/45/60 min, pause automatique
- **Recherche avancée** : historique local + filtres Films / Séries / Anime / ⭐ 7+
- **Catalogue hors-ligne** : cache local accueil + listes (démarrage instantané, repli sans réseau)

### Corrections
- **Blanc sur blanc** : fix complet (~40 cas) — bouton Connexion, avatars, sélecteurs, snackbars, sheets PayPal, focus TV, tous les thèmes clair/sombre
- **Live TV** : retries natifs quand le flux HLS tourne/saute au lieu d'une page d'erreur ; tentative de rafraîchissement automatique quand toutes les sources échouent
- **Fausses vidéos « troll »** : détecteur à l'extraction (clip < 120 s / MP4 < 8 Mo écartés automatiquement)
- **API** : accueil ~20-40x plus rapide (cache global 10 min partagé), gzip, search/détail/anime cachés, `ensureExtendedSchema` limité à 1×/jour, corrections requêtes (plages de dates indexables, suppression `ORDER BY RAND()`)

---

## v1.3.2 — 29 juillet 2026

### Corrections
- **Focus recherche TV** : le focus ne s'échappe plus vers la sidebar en appuyant sur gauche pendant la recherche de films/séries/anime sur Android TV
- Piégeage des touches directionnelles aux bords de la grille de résultats
- Auto-focus sur le premier résultat de recherche en mode TV
- Fix extraction vidéo, lecteur, favoris, perfs (correctifs v1.3.1 rétrosportés)

### Améliorations
- 12 captures d'écran ajoutées au repo depuis neo-stream.eu
- README enrichi avec la galerie de screenshots complète

---

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
