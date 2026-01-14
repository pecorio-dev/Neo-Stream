import 'package:flutter/material.dart';

/// Widget de texte responsive qui s'adapte automatiquement à la taille de l'écran
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;
  final double? scaleFactor;
  final double? minFontSize;
  final double? maxFontSize;

  const ResponsiveText(
    this.text, {
    Key? key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
    this.scaleFactor,
    this.minFontSize,
    this.maxFontSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculer le facteur d'échelle basé sur la taille de l'écran
    double responsiveScale = _calculateScale(screenWidth, screenHeight);
    
    if (scaleFactor != null) {
      responsiveScale *= scaleFactor!;
    }
    
    // Appliquer les limites min/max si spécifiées
    if (style?.fontSize != null) {
      double newFontSize = (style!.fontSize! * responsiveScale);
      
      if (minFontSize != null && newFontSize < minFontSize!) {
        newFontSize = minFontSize!;
      }
      if (maxFontSize != null && newFontSize > maxFontSize!) {
        newFontSize = maxFontSize!;
      }
      
      return Text(
        text,
        style: style?.copyWith(fontSize: newFontSize),
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow ?? TextOverflow.ellipsis,
        softWrap: softWrap,
      );
    }
    
    return Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.ellipsis,
      softWrap: softWrap,
    );
  }
  
  double _calculateScale(double width, double height) {
    // Tailles de référence (design de base)
    const double baseWidth = 375.0; // iPhone X width
    const double baseHeight = 812.0; // iPhone X height
    
    // Calculer les ratios
    final double widthRatio = width / baseWidth;
    final double heightRatio = height / baseHeight;
    
    // Utiliser le plus petit ratio pour éviter que le texte devienne trop grand
    final double scale = (widthRatio + heightRatio) / 2;
    
    // Limiter l'échelle entre 0.8 et 1.3
    return scale.clamp(0.8, 1.3);
  }
}

/// Widget de texte adaptatif qui ajuste automatiquement sa taille pour s'adapter à l'espace disponible
class AdaptiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final double? minFontSize;
  final double? maxFontSize;
  final double stepGranularity;

  const AdaptiveText(
    this.text, {
    Key? key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.minFontSize = 10.0,
    this.maxFontSize,
    this.stepGranularity = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth,
            ),
            child: Text(
              text,
              style: style,
              textAlign: textAlign,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}

/// Extension pour faciliter l'utilisation des textes responsives
extension ResponsiveTextExtension on Text {
  Widget responsive({
    double? scaleFactor,
    double? minFontSize,
    double? maxFontSize,
  }) {
    return ResponsiveText(
      data ?? '',
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap ?? true,
      scaleFactor: scaleFactor,
      minFontSize: minFontSize,
      maxFontSize: maxFontSize,
    );
  }
  
  Widget adaptive({
    double? minFontSize,
    double? maxFontSize,
    double stepGranularity = 1.0,
  }) {
    return AdaptiveText(
      data ?? '',
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      minFontSize: minFontSize,
      maxFontSize: maxFontSize,
      stepGranularity: stepGranularity,
    );
  }
}

/// Classe utilitaire pour obtenir des tailles responsives
class ResponsiveSizes {
  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculer le facteur d'échelle
    const double baseWidth = 375.0;
    const double baseHeight = 812.0;
    
    final double widthRatio = screenWidth / baseWidth;
    final double heightRatio = screenHeight / baseHeight;
    final double scale = (widthRatio + heightRatio) / 2;
    
    return (baseFontSize * scale.clamp(0.8, 1.3));
  }
  
  static double getResponsivePadding(BuildContext context, double basePadding) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth < 360) {
      return basePadding * 0.8;
    } else if (screenWidth < 400) {
      return basePadding * 0.9;
    } else if (screenWidth > 600) {
      return basePadding * 1.2;
    }
    
    return basePadding;
  }
  
  static double getResponsiveIconSize(BuildContext context, double baseIconSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    if (screenWidth < 360 || screenHeight < 600) {
      return baseIconSize * 0.8;
    } else if (screenWidth > 600) {
      return baseIconSize * 1.2;
    }
    
    return baseIconSize;
  }
  
  static bool isSmallScreen(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.height < 600 || size.width < 360;
  }
  
  static bool isNarrowScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 400;
  }
  
  static bool isLargeScreen(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > 600 && size.height > 800;
  }
}