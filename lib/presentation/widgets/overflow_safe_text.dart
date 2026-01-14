import 'package:flutter/material.dart';

/// A text widget that automatically handles overflow by adjusting font size
/// and ensuring text fits within available space
class OverflowSafeText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;
  final double? minFontSize;
  final double? maxFontSize;
  final bool autoSize;
  final TextOverflow overflow;
  final double stepGranularity;

  const OverflowSafeText(
    this.text, {
    Key? key,
    this.style,
    this.maxLines,
    this.textAlign,
    this.minFontSize,
    this.maxFontSize,
    this.autoSize = true,
    this.overflow = TextOverflow.ellipsis,
    this.stepGranularity = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!autoSize) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        textAlign: textAlign,
        overflow: overflow,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return _AutoSizeText(
          text: text,
          style: style,
          maxLines: maxLines,
          textAlign: textAlign,
          minFontSize: minFontSize,
          maxFontSize: maxFontSize,
          overflow: overflow,
          stepGranularity: stepGranularity,
          constraints: constraints,
        );
      },
    );
  }
}

class _AutoSizeText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;
  final double? minFontSize;
  final double? maxFontSize;
  final TextOverflow overflow;
  final double stepGranularity;
  final BoxConstraints constraints;

  const _AutoSizeText({
    required this.text,
    this.style,
    this.maxLines,
    this.textAlign,
    this.minFontSize,
    this.maxFontSize,
    required this.overflow,
    required this.stepGranularity,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = style ?? defaultStyle;
    
    final originalFontSize = effectiveStyle.fontSize ?? 14.0;
    final minSize = minFontSize ?? originalFontSize * 0.7;
    final maxSize = maxFontSize ?? originalFontSize;
    
    double fontSize = maxSize;
    
    // Binary search for optimal font size
    while (fontSize >= minSize) {
      final testStyle = effectiveStyle.copyWith(fontSize: fontSize);
      
      if (_textFits(text, testStyle, constraints, maxLines)) {
        break;
      }
      
      fontSize -= stepGranularity;
    }
    
    // Ensure we don't go below minimum
    fontSize = fontSize.clamp(minSize, maxSize);
    
    return Text(
      text,
      style: effectiveStyle.copyWith(fontSize: fontSize),
      maxLines: maxLines,
      textAlign: textAlign,
      overflow: overflow,
    );
  }

  bool _textFits(
    String text,
    TextStyle style,
    BoxConstraints constraints,
    int? maxLines,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    );
    
    textPainter.layout(maxWidth: constraints.maxWidth);
    
    return textPainter.didExceedMaxLines == false &&
           textPainter.size.height <= constraints.maxHeight;
  }
}

/// A container that prevents overflow by providing safe constraints
class OverflowSafeContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Decoration? decoration;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  const OverflowSafeContainer({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.decoration,
    this.width,
    this.height,
    this.alignment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      decoration: decoration,
      alignment: alignment,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth,
              maxHeight: constraints.maxHeight,
            ),
            child: child,
          );
        },
      ),
    );
  }
}

/// A row that automatically wraps to prevent overflow
class OverflowSafeRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final double spacing;
  final double runSpacing;

  const OverflowSafeRow({
    Key? key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.spacing = 0.0,
    this.runSpacing = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Try to fit in a single row first
        return IntrinsicHeight(
          child: Wrap(
            direction: Axis.horizontal,
            alignment: _wrapAlignmentFromMainAxis(mainAxisAlignment),
            crossAxisAlignment: _wrapCrossAlignmentFromCrossAxis(crossAxisAlignment),
            spacing: spacing,
            runSpacing: runSpacing,
            children: children,
          ),
        );
      },
    );
  }

  WrapAlignment _wrapAlignmentFromMainAxis(MainAxisAlignment alignment) {
    switch (alignment) {
      case MainAxisAlignment.start:
        return WrapAlignment.start;
      case MainAxisAlignment.end:
        return WrapAlignment.end;
      case MainAxisAlignment.center:
        return WrapAlignment.center;
      case MainAxisAlignment.spaceBetween:
        return WrapAlignment.spaceBetween;
      case MainAxisAlignment.spaceAround:
        return WrapAlignment.spaceAround;
      case MainAxisAlignment.spaceEvenly:
        return WrapAlignment.spaceEvenly;
    }
  }

  WrapCrossAlignment _wrapCrossAlignmentFromCrossAxis(CrossAxisAlignment alignment) {
    switch (alignment) {
      case CrossAxisAlignment.start:
        return WrapCrossAlignment.start;
      case CrossAxisAlignment.end:
        return WrapCrossAlignment.end;
      case CrossAxisAlignment.center:
        return WrapCrossAlignment.center;
      case CrossAxisAlignment.stretch:
        return WrapCrossAlignment.start; // Wrap doesn't support stretch
      case CrossAxisAlignment.baseline:
        return WrapCrossAlignment.start; // Wrap doesn't support baseline
    }
  }
}

/// A column that automatically adjusts spacing to prevent overflow
class OverflowSafeColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final double spacing;

  const OverflowSafeColumn({
    Key? key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.spacing = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: mainAxisAlignment,
                crossAxisAlignment: crossAxisAlignment,
                mainAxisSize: mainAxisSize,
                children: _addSpacing(children, spacing),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _addSpacing(List<Widget> children, double spacing) {
    if (spacing == 0.0 || children.length <= 1) {
      return children;
    }

    final spacedChildren = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);
      if (i < children.length - 1) {
        spacedChildren.add(SizedBox(height: spacing));
      }
    }
    return spacedChildren;
  }
}

/// A flexible text widget that adapts to available space
class AdaptiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;
  final bool wrapWords;

  const AdaptiveText(
    this.text, {
    Key? key,
    this.style,
    this.maxLines,
    this.textAlign,
    this.wrapWords = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (wrapWords && constraints.maxWidth < double.infinity) {
          // Use flexible text that wraps
          return OverflowSafeText(
            text,
            style: style,
            maxLines: maxLines,
            textAlign: textAlign,
            autoSize: true,
          );
        } else {
          // Use ellipsis for single line or constrained text
          return Text(
            text,
            style: style,
            maxLines: maxLines ?? 1,
            textAlign: textAlign,
            overflow: TextOverflow.ellipsis,
          );
        }
      },
    );
  }
}