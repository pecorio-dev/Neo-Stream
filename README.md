<div align="center">

# Neo-Stream

**Application de streaming gratuite et multiplateforme**

Films, Series, Animes — sur tous vos appareils.

[![Android](https://img.shields.io/badge/Android-APK-3DDC84?logo=android&logoColor=white)](https://github.com/pecorio-dev/Neo-Stream/releases/latest)
[![Windows](https://img.shields.io/badge/Windows-Installer-0078D4?logo=windows&logoColor=white)](https://github.com/pecorio-dev/Neo-Stream/releases/latest)
[![Linux](https://img.shields.io/badge/Linux-AppImage-FCC624?logo=linux&logoColor=black)](https://github.com/pecorio-dev/Neo-Stream/releases/latest)


</div>

---

## 100% Gratuit

Neo-Stream est **entierement gratuit**. Pas de compte premium obligatoire, pas de paywall pour regarder vos films et series.

Seule la **TV en direct** (chaines IPTV HD) est une option payante a partir de 5,83 EUR/mois.

---

## Disponible sur tous vos appareils

| Plateforme | Format | Lien |
|---|---|---|
| Android / Android TV | APK | [Telecharger](https://github.com/pecorio-dev/Neo-Stream/releases/latest) |
| Windows 10/11 | Installateur .exe | [Telecharger](https://github.com/pecorio-dev/Neo-Stream/releases/latest) |
| Linux | AppImage | [Telecharger](https://github.com/pecorio-dev/Neo-Stream/releases/latest) |

---

## Fonctionnalites

- Catalogue complet de films, series et animes
- Lecteur video integre avec reprise automatique
- Historique et favoris
- Interface responsive (telephone, tablette, desktop, TV)
- Navigation telecommande complete (Android TV)
- Design glassmorphisme moderne noir/blanc
- Profils et sous-comptes

---

## TV en Direct (optionnel, payant)

L'acces aux chaines TV en direct est la seule option payante :

| Plan | Prix |
|---|---|
| Mensuel | 9,99 EUR/mois |
| Annuel | 69,99 EUR/an (soit 5,83 EUR/mois) |

Sans engagement, resiliable a tout moment. Paiement securise via PayPal.

---

## Build depuis les sources

### Prerequis
- Flutter 3.32+
- JDK 17 (Android)

```bash
cd app/app
flutter pub get
flutter run
```

### Builds release

```bash
# Android
flutter build apk --release

# Linux (necessite libmpv-dev)
flutter build linux --release

# Windows
flutter build windows --release
```

---

## Licence

Projet prive — usage personnel.
