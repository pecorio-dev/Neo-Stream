import 'package:flutter/material.dart';
import 'theme.dart';

/// TV-specific theme constants and utilities
class TVTheme {
  TVTheme._();

  // ─── TV Navigation ────────────────────────────────────────────
  static const double railWidth = 80;
  static const double railIconSize = 28;
  static const double railLabelSize = 10;

  // ─── Focus Animation ──────────────────────────────────────────
  static const Duration focusAnimationDuration = Duration(milliseconds: 150);
  static const double focusedCardScale = 1.08;
  static const double focusBorderWidthTV = 3.0;
  static const double focusBorderWidthMobile = 2.0;

  // ─── Focus Shadow (TV) ────────────────────────────────────────
  static const List<BoxShadow> focusShadowTV = [
    BoxShadow(
      color: Color(0x66E50914), // primaryRed @ 40%
      blurRadius: 24,
      spreadRadius: 3,
      offset: Offset(0, 0),
    ),
    BoxShadow(
      color: Color(0x33E50914), // primaryRed @ 20%
      blurRadius: 48,
      spreadRadius: 8,
      offset: Offset(0, 0),
    ),
  ];

  // ─── TV Padding ───────────────────────────────────────────────
  static const double screenPaddingTV = 24;
  static const double sectionGapTV = 32;
  static const double cardGapTV = 16;

  // ─── Grid ─────────────────────────────────────────────────────
  static const double gridSpacingTV = 12;
  static const double gridAspectRatioPostersTV = 0.62; // 9:14.5
  static const double gridAspectRatioLandscapeTV = 0.56; // 16:9

  // ─── TV Breakpoints ───────────────────────────────────────────
  static const double breakpointTV = 1024;
  static const double breakpointLargeTV = 1400;
  static const double breakpointSmallScreen = 600;
}

/// Helper methods for TV navigation
extension TVNavigationHelper on BuildContext {
  /// Check if device needs focus-based navigation (TV/large screens)
  bool get isTVDevice => NeoTheme.isTV(this);

  /// Get focus traversal policy for TV
  FocusTraversalPolicy getFocusPolicy() => const OrderedTraversalPolicy();
}
