import 'package:flutter/material.dart';

/// Widget qui adapte automatiquement le layout en fonction de la taille de l'écran
class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool enableScrolling;
  final bool safeArea;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;

  const ResponsiveLayout({
    Key? key,
    required this.child,
    this.padding,
    this.enableScrolling = true,
    this.safeArea = true,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 600;
    final isNarrowScreen = screenSize.width < 400;
    
    // Calculer le padding responsive
    EdgeInsets responsivePadding = padding ?? EdgeInsets.all(
      isSmallScreen ? 16.0 : (isNarrowScreen ? 20.0 : 24.0)
    );

    Widget content = child;

    if (enableScrolling) {
      content = LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: crossAxisAlignment,
                  mainAxisAlignment: mainAxisAlignment,
                  children: [child],
                ),
              ),
            ),
          );
        },
      );
    }

    content = Padding(
      padding: responsivePadding,
      child: content,
    );

    if (safeArea) {
      content = SafeArea(child: content);
    }

    return content;
  }
}

/// Widget pour créer des colonnes responsives
class ResponsiveColumn extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final double? spacing;

  const ResponsiveColumn({
    Key? key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.spacing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 600;
    
    final double responsiveSpacing = spacing ?? (isSmallScreen ? 12.0 : 16.0);
    
    List<Widget> spacedChildren = [];
    for (int i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);
      if (i < children.length - 1) {
        spacedChildren.add(SizedBox(height: responsiveSpacing));
      }
    }

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: spacedChildren,
    );
  }
}

/// Widget pour créer des lignes responsives
class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final double? spacing;

  const ResponsiveRow({
    Key? key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.spacing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isNarrowScreen = screenSize.width < 400;
    
    final double responsiveSpacing = spacing ?? (isNarrowScreen ? 8.0 : 12.0);
    
    List<Widget> spacedChildren = [];
    for (int i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);
      if (i < children.length - 1) {
        spacedChildren.add(SizedBox(width: responsiveSpacing));
      }
    }

    return Row(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: spacedChildren,
    );
  }
}

/// Widget pour créer des cartes responsives
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final double? elevation;
  final BorderRadius? borderRadius;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;

  const ResponsiveCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.elevation,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.gradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 600;
    final isNarrowScreen = screenSize.width < 400;
    
    // Padding responsive
    final EdgeInsets responsivePadding = padding ?? EdgeInsets.all(
      isSmallScreen ? 12.0 : (isNarrowScreen ? 16.0 : 20.0)
    );
    
    // Margin responsive
    final EdgeInsets responsiveMargin = margin ?? EdgeInsets.all(
      isSmallScreen ? 8.0 : (isNarrowScreen ? 12.0 : 16.0)
    );
    
    // Border radius responsive
    final BorderRadius responsiveBorderRadius = borderRadius ?? BorderRadius.circular(
      isSmallScreen ? 12.0 : 16.0
    );

    return Container(
      margin: responsiveMargin,
      padding: responsivePadding,
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: responsiveBorderRadius,
        border: border,
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }
}

/// Widget pour créer des boutons responsives
class ResponsiveButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsets? padding;
  final double? minWidth;
  final double? height;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final BorderRadius? borderRadius;
  final double? elevation;

  const ResponsiveButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.padding,
    this.minWidth,
    this.height,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius,
    this.elevation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 600;
    final isNarrowScreen = screenSize.width < 400;
    
    // Padding responsive
    final EdgeInsets responsivePadding = padding ?? EdgeInsets.symmetric(
      horizontal: isNarrowScreen ? 16.0 : 24.0,
      vertical: isSmallScreen ? 12.0 : 16.0,
    );
    
    // Hauteur responsive
    final double responsiveHeight = height ?? (isSmallScreen ? 44.0 : 48.0);

    return SizedBox(
      width: minWidth ?? double.infinity,
      height: responsiveHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: responsivePadding,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(12),
          ),
          elevation: elevation,
        ),
        child: child,
      ),
    );
  }
}

/// Mixin pour ajouter des fonctionnalités responsives aux widgets
mixin ResponsiveMixin {
  bool isSmallScreen(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.height < 600 || size.width < 360;
  }
  
  bool isNarrowScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 400;
  }
  
  bool isLargeScreen(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > 600 && size.height > 800;
  }
  
  double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    const double baseWidth = 375.0;
    const double baseHeight = 812.0;
    
    final double widthRatio = screenWidth / baseWidth;
    final double heightRatio = screenHeight / baseHeight;
    final double scale = (widthRatio + heightRatio) / 2;
    
    return (baseFontSize * scale.clamp(0.8, 1.3));
  }
  
  EdgeInsets getResponsivePadding(BuildContext context, {
    double? horizontal,
    double? vertical,
    double? all,
  }) {
    final isSmall = isSmallScreen(context);
    final isNarrow = isNarrowScreen(context);
    
    if (all != null) {
      final responsiveAll = isSmall ? all * 0.8 : (isNarrow ? all * 0.9 : all);
      return EdgeInsets.all(responsiveAll);
    }
    
    final responsiveHorizontal = horizontal != null 
        ? (isNarrow ? horizontal * 0.8 : horizontal)
        : (isNarrow ? 16.0 : 24.0);
        
    final responsiveVertical = vertical != null
        ? (isSmall ? vertical * 0.8 : vertical)
        : (isSmall ? 12.0 : 16.0);
    
    return EdgeInsets.symmetric(
      horizontal: responsiveHorizontal,
      vertical: responsiveVertical,
    );
  }
}