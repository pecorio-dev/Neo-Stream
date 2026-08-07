import 'package:flutter/material.dart';

import 'light_theme.dart';
import 'theme.dart';

/// Pont thème unifié : dispatch automatiquement vers [NeoTheme] (sombre)
/// ou [NeoLightTheme] (clair) selon [Theme.of] au runtime.
///
/// Les écrans n'ont qu'à remplacer `NeoTheme` par `Neo` : le bon thème est
/// sélectionné selon le `ThemeMode` actif dans [main.dart].
///
/// - Couleurs & décorations : getters statiques prenant un [BuildContext].
/// - Membres identiques entre les deux thèmes (radii, durations, helpers
///   responsive, genreColors) : delegates directs.
class Neo {
  Neo._();

  static bool _isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  // ── Backgrounds ──────────────────────────────────────────────────────
  static Color bgBase(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.bgBase : NeoTheme.bgBase;
  static Color bgSurface(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.bgSurface : NeoTheme.bgSurface;
  static Color bgElevated(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.bgElevated : NeoTheme.bgElevated;
  static Color bgOverlay(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.bgOverlay : NeoTheme.bgOverlay;
  static Color bgActive(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.bgActive : NeoTheme.bgActive;
  static Color bgHover(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.bgHover : NeoTheme.bgHover;
  static Color bgBorder(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.bgBorder : NeoTheme.bgBorder;
  static Color borderLight(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.borderLight : NeoTheme.bgBorder;

  // ── Brand ────────────────────────────────────────────────────────────
  // accentColor : couleur d'accentuation principale selon le thème actif.
  // En thème sombre : blanc (NeoTheme.primaryRed = 0xFFFFFF).
  // En thème clair  : rouge (NeoLightTheme.primaryRed = 0xFFE50914).
  // Toujours préférer accentColor(c) quand un BuildContext est disponible.
  static Color accentColor(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.primaryRed : NeoTheme.primaryRed;
  // Alias rétrocompatible (sans contexte). Ne pas utiliser en thème clair.
  static const Color primaryRed = NeoTheme.primaryRed;
  static const Color primaryRedHover = NeoTheme.primaryRedHover;
  static const Color primaryRedDark = NeoTheme.primaryRedDark;
  static const Color prestigeGold = NeoTheme.prestigeGold;
  static const Color goldDark = NeoTheme.goldDark;
  static const Color purpleAccent = NeoTheme.purpleAccent;
  static const Color infoCyan = NeoTheme.infoCyan;

  // ── Texte ────────────────────────────────────────────────────────────
  static Color textPrimary(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.textPrimary : NeoTheme.textPrimary;
  static Color textSecondary(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.textSecondary : NeoTheme.textSecondary;
  static Color textTertiary(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.textTertiary : NeoTheme.textTertiary;
  static Color textDisabled(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.textDisabled : NeoTheme.textDisabled;

  // ── Sémantique ───────────────────────────────────────────────────────
  static const Color successGreen = NeoTheme.successGreen;
  static const Color warningOrange = NeoTheme.warningOrange;
  static const Color errorRed = NeoTheme.errorRed;

  // ── Décorations (dépendent du thème) ─────────────────────────────────
  static BoxDecoration cardDecoration(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.cardDecoration() : NeoTheme.cardDecoration;
  static BoxDecoration cardFocusedDecoration(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.cardFocusedDecoration : NeoTheme.cardFocusedDecoration;
  static BoxDecoration glassDecoration(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.glassDecoration() : NeoTheme.glassDecoration;
  static BoxDecoration panelDecoration(BuildContext c, {Color? accent, bool elevated = false}) =>
      _isLight(c)
          ? NeoLightTheme.panelDecoration(accent: accent)
          : NeoTheme.panelDecoration(accent: accent, elevated: elevated);
  static BoxDecoration pillDecoration(BuildContext c, {Color? color, bool selected = false}) =>
      _isLight(c)
          ? NeoLightTheme.pillDecoration(color: color, selected: selected)
          : NeoTheme.pillDecoration(color: color, selected: selected);

  // ── Gradients ────────────────────────────────────────────────────────
  // heroGradient : blanc→gris en sombre, rouge en clair. Le contenu posé
  // dessus doit utiliser [onHeroGradient].
  static LinearGradient heroGradient(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.heroGradient : NeoTheme.heroGradient;
  static const LinearGradient premiumGradient = NeoTheme.premiumGradient;
  static LinearGradient surfaceGradient(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.surfaceGradient : NeoTheme.surfaceGradient;

  /// Couleur de texte/icône lisible sur [heroGradient] dans le thème actif
  /// (noir sur le dégradé blanc du thème sombre, blanc sur rouge en clair).
  static Color onHeroGradient(BuildContext c) =>
      _isLight(c) ? Colors.white : Colors.black;

  /// Couleur de texte lisible sur une couleur de fond donnée (luminance).
  /// Pattern de référence déjà utilisé dans hero_banner.dart.
  static Color readableOn(Color background) =>
      background.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  /// Couleur de texte lisible sur [ColorScheme.primary] du thème actif
  /// (ColorScheme.primary vaut blanc en sombre / rouge en clair).
  static Color readableOnPrimary(BuildContext c) =>
      readableOn(Theme.of(c).colorScheme.primary);

  static LinearGradient topPanelGradient(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.topPanelGradient : NeoTheme.topPanelGradient;
  static LinearGradient glassGradient(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.glassGradient : NeoTheme.glassGradient;
  static LinearGradient cardOverlayGradient(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.cardOverlayGradient : NeoTheme.cardOverlayGradient;
  static LinearGradient shimmerGradient(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.shimmerGradient : NeoTheme.shimmerGradient;

  // ── Shadows ──────────────────────────────────────────────────────────
  static List<BoxShadow> shadowLevel1(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.shadowSm : NeoTheme.shadowLevel1;
  static List<BoxShadow> shadowLevel2(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.shadowMd : NeoTheme.shadowLevel2;
  static List<BoxShadow> shadowLevel3(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.shadowLg : NeoTheme.shadowLevel3;
  static List<BoxShadow> shadowGlow(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.shadowGlow : NeoTheme.shadowGlow;
  static List<BoxShadow> shadowGoldGlow(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.shadowGoldGlow : NeoTheme.shadowGoldGlow;

  // ── Radii (identiques entre thèmes) ──────────────────────────────────
  static const double radiusXs = NeoTheme.radiusXs;
  static const double radiusSm = NeoTheme.radiusSm;
  static const double radiusMd = NeoTheme.radiusMd;
  static const double radiusLg = NeoTheme.radiusLg;
  static const double radiusXl = NeoTheme.radiusXl;
  static const double radius2xl = NeoTheme.radius2xl;
  static const double radiusFull = 999.0;

  // ── Spacing ──────────────────────────────────────────────────────────
  static const double spaceXs = NeoTheme.spaceXs;
  static const double spaceSm = NeoTheme.spaceSm;
  static const double spaceMd = NeoTheme.spaceMd;
  static const double spaceLg = NeoTheme.spaceLg;
  static const double spaceXl = NeoTheme.spaceXl;
  static const double space2xl = NeoTheme.space2xl;
  static const double space3xl = NeoTheme.space3xl;
  static const double space4xl = NeoTheme.space4xl;

  // ── Curves & Durations (identiques) ──────────────────────────────────
  static const Curve smoothOut = NeoTheme.smoothOut;
  static const Curve smoothIn = NeoTheme.smoothIn;
  static const Curve premium = NeoTheme.premium;
  static const Curve cinematic = NeoTheme.cinematic;
  static const Curve bounceOut = NeoTheme.bounceOut;
  static const Duration durationFast = NeoTheme.durationFast;
  static const Duration durationNormal = NeoTheme.durationNormal;
  static const Duration durationSlow = NeoTheme.durationSlow;
  static const Duration durationHero = NeoTheme.durationHero;
  static const Duration durationSplash = NeoTheme.durationSplash;
  static const Duration staggerDelay = NeoTheme.staggerDelay;

  // ── Helpers responsive (identiques entre thèmes) ─────────────────────
  static bool isTV(BuildContext c) => NeoTheme.isTV(c);
  static bool is4K(BuildContext c) => NeoTheme.is4K(c);
  static bool isTablet(BuildContext c) => NeoTheme.isTablet(c);
  static bool isMobile(BuildContext c) => NeoTheme.isMobile(c);
  static bool get isDesktopPlatform => NeoTheme.isDesktopPlatform;
  static bool needsFocusNavigation(BuildContext c) => NeoTheme.needsFocusNavigation(c);
  static double scaleFactor(BuildContext c) => NeoTheme.scaleFactor(c);
  static double tvRailWidth(BuildContext c) => NeoTheme.tvRailWidth(c);
  static double get tvRailWidthExpanded => NeoTheme.tvRailWidthExpanded;
  static double heroHeight(BuildContext c) => NeoTheme.heroHeight(c);
  static double cardWidth(BuildContext c) => NeoTheme.cardWidth(c);
  static double cardHeight(BuildContext c) => NeoTheme.cardHeight(c);
  static double horizontalCardHeight(BuildContext c) => NeoTheme.horizontalCardHeight(c);
  static double searchCardHeight(BuildContext c) => NeoTheme.searchCardHeight(c);
  static double sectionGap(BuildContext c) => NeoTheme.sectionGap(c);
  static EdgeInsets screenPadding(BuildContext c) => NeoTheme.screenPadding(c);
  static double gridSpacing(BuildContext c) => NeoTheme.gridSpacing(c);
  static EdgeInsets contentPadding(BuildContext c) => NeoTheme.contentPadding(c);
  static double iconSize(BuildContext c) => NeoTheme.iconSize(c);
  static double chipHeight(BuildContext c) => NeoTheme.chipHeight(c);
  static double avatarSize(BuildContext c) => NeoTheme.avatarSize(c);
  static Size posterSize(BuildContext c, {bool tall = false}) =>
      NeoTheme.posterSize(c, tall: tall);
  static int gridColumns(BuildContext c) => NeoTheme.gridColumns(c);
  static double focusBorderWidth(BuildContext c) => NeoTheme.focusBorderWidth(c);
  static double focusBorderRadius(BuildContext c) => NeoTheme.focusBorderRadius(c);
  static double focusedCardScale(BuildContext c) => NeoTheme.focusedCardScale(c);
  static double minTouchTarget(BuildContext c) => NeoTheme.minTouchTarget(c);
  static double badgeHeight(BuildContext c) => NeoTheme.badgeHeight(c);

  // ── Genre colors ─────────────────────────────────────────────────────
  static Color getGenreColor(String genre) => NeoTheme.getGenreColor(genre);
  static const Map<String, Color> genreColors = NeoTheme.genreColors;

  // ── Typographie (délègue au thème correspondant) ─────────────────────
  static TextStyle displayLarge(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.displayLarge(c) : NeoTheme.displayLarge(c);
  static TextStyle displayMedium(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.displayMedium(c) : NeoTheme.displayMedium(c);
  static TextStyle headlineLarge(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.headlineLarge(c) : NeoTheme.headlineLarge(c);
  static TextStyle headlineMedium(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.headlineMedium(c) : NeoTheme.headlineMedium(c);
  static TextStyle titleLarge(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.titleLarge(c) : NeoTheme.titleLarge(c);
  static TextStyle titleMedium(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.titleMedium(c) : NeoTheme.titleMedium(c);
  static TextStyle bodyLarge(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.bodyLarge(c) : NeoTheme.bodyLarge(c);
  static TextStyle bodyMedium(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.bodyMedium(c) : NeoTheme.bodyMedium(c);
  static TextStyle bodySmall(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.bodySmall(c) : NeoTheme.bodySmall(c);
  static TextStyle labelLarge(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.labelLarge(c) : NeoTheme.labelLarge(c);
  static TextStyle labelMedium(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.labelMedium(c) : NeoTheme.labelMedium(c);
  static TextStyle labelSmall(BuildContext c) =>
      _isLight(c) ? NeoLightTheme.labelSmall(c) : NeoTheme.labelSmall(c);
}
