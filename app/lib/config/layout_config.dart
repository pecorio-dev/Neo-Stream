import 'package:flutter/material.dart';

/// Configuration globale pour éviter les overflows dans toute l'application
class LayoutConfig {
  LayoutConfig._();

  /// Espacement standard réduit pour éviter les overflows
  static const double spacingXs = 2.0;
  static const double spacingS = 4.0;
  static const double spacingM = 6.0;
  static const double spacingL = 8.0;
  static const double spacingXl = 12.0;
  static const double spacingXxl = 16.0;

  /// Padding standard pour les écrans
  static EdgeInsets screenPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    if (width > 600) return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
  }

  /// Padding pour les contenus
  static EdgeInsets contentPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return const EdgeInsets.all(20);
    if (width > 600) return const EdgeInsets.all(16);
    return const EdgeInsets.all(12);
  }

  /// Wrapper pour Column qui prévient les overflows
  static Widget safeColumn({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
    MainAxisSize mainAxisSize = MainAxisSize.min,
  }) {
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children,
    );
  }

  /// Wrapper pour Row qui prévient les overflows
  static Widget safeRow({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    MainAxisSize mainAxisSize = MainAxisSize.min,
  }) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children,
    );
  }

  /// Wrapper pour les écrans avec Column qui scroll automatiquement si nécessaire
  static Widget flexibleScreen({
    required BuildContext context,
    required List<Widget> children,
    EdgeInsetsGeometry? padding,
    bool safeArea = true,
  }) {
    Widget content = SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    if (padding != null) {
      content = Padding(padding: padding, child: content);
    }

    if (safeArea) {
      content = SafeArea(child: content);
    }

    return content;
  }

  /// SizedBox avec hauteur sécurisée
  static Widget verticalSpace(double height) {
    return SizedBox(height: height.clamp(0, 100));
  }

  /// SizedBox avec largeur sécurisée
  static Widget horizontalSpace(double width) {
    return SizedBox(width: width.clamp(0, 100));
  }

  /// Contraintes maximales pour éviter les débordements
  static BoxConstraints maxConstraints(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return BoxConstraints(
      maxWidth: size.width,
      maxHeight: size.height,
    );
  }

  /// Contraintes pour les dialogues
  static BoxConstraints dialogConstraints(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return BoxConstraints(
      maxWidth: (size.width * 0.9).clamp(300, 600),
      maxHeight: size.height * 0.8,
    );
  }
}

/// Extension pour faciliter l'utilisation
extension LayoutExtensions on BuildContext {
  EdgeInsets get screenPadding => LayoutConfig.screenPadding(this);
  EdgeInsets get contentPadding => LayoutConfig.contentPadding(this);
  BoxConstraints get maxConstraints => LayoutConfig.maxConstraints(this);
  BoxConstraints get dialogConstraints => LayoutConfig.dialogConstraints(this);
}
