import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/tv_config.dart';

class TVFocusableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onFocus;
  final bool autoFocus;
  final double minWidth;
  final double maxWidth;
  final EdgeInsets padding;
  final BorderRadius? borderRadius;

  const TVFocusableCard({
    super.key,
    required this.child,
    this.onTap,
    this.onFocus,
    this.autoFocus = false,
    this.minWidth = TVConfig.cardMinWidth,
    this.maxWidth = TVConfig.cardMaxWidth,
    this.padding = TVConfig.cardPadding,
    this.borderRadius,
  });

  @override
  State<TVFocusableCard> createState() => _TVFocusableCardState();
}

class _TVFocusableCardState extends State<TVFocusableCard> {
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool focused) {
    if (_isFocused != focused) {
      setState(() => _isFocused = focused);
      if (focused) {
        widget.onFocus?.call();
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.space) {
      widget.onTap?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(16);

    return Focus(
      focusNode: _focusNode,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: AnimatedScale(
            duration: TVConfig.focusAnimationDuration,
            curve: Curves.easeOut,
            scale: _isFocused ? TVConfig.focusScale : TVConfig.unfocusScale,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: widget.minWidth,
                maxWidth: widget.maxWidth,
              ),
              child: AnimatedContainer(
                duration: TVConfig.focusAnimationDuration,
                curve: Curves.easeOut,
                decoration: _isFocused
                    ? TVTheme.focusedCardDecoration
                    : TVTheme.cardDecoration,
                child: ClipRRect(
                  borderRadius: radius,
                  child: Padding(
                    padding: widget.padding,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TVCardGrid extends StatelessWidget {
  final List<Widget> children;
  final int minCrossAxisCount;
  final int maxCrossAxisCount;
  final double childAspectRatio;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsets padding;

  const TVCardGrid({
    super.key,
    required this.children,
    this.minCrossAxisCount = 2,
    this.maxCrossAxisCount = 6,
    this.childAspectRatio = TVConfig.cardAspectRatio,
    this.mainAxisSpacing = TVConfig.gridSpacing,
    this.crossAxisSpacing = TVConfig.gridSpacing,
    this.padding = TVConfig.screenPadding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - padding.horizontal;
        final cardWidth = TVConfig.cardMaxWidth + crossAxisSpacing;
        final crossAxisCount = (availableWidth / cardWidth)
            .clamp(minCrossAxisCount.toDouble(), maxCrossAxisCount.toDouble())
            .round();

        return GridView.builder(
          padding: padding,
          physics: const TVScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            mainAxisSpacing: mainAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

class TVScrollPhysics extends ScrollPhysics {
  const TVScrollPhysics({super.parent});

  @override
  TVScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return TVScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 3.5;

  @override
  double frictionFactor(double overscrollFraction) => 0.52;

  @override
  double carriedMomentum(double existingVelocity) {
    return existingVelocity.sign *
        (existingVelocity.abs() * 0.3).clamp(0, 1000);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity.abs() < toleranceFor(position).velocity) ||
        (velocity > 0 && position.pixels >= position.maxScrollExtent) ||
        (velocity < 0 && position.pixels <= position.minScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      tolerance: toleranceFor(position),
    );
  }
}

class TVFocusableListTile extends StatefulWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onFocus;
  final bool autoFocus;
  final EdgeInsets? padding;

  const TVFocusableListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onFocus,
    this.autoFocus = false,
    this.padding,
  });

  @override
  State<TVFocusableListTile> createState() => _TVFocusableListTileState();
}

class _TVFocusableListTileState extends State<TVFocusableListTile> {
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.space) {
      widget.onTap?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (focused) {
        if (_isFocused != focused) {
          setState(() => _isFocused = focused);
          if (focused) widget.onFocus?.call();
        }
      },
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: TVConfig.focusAnimationDuration,
            decoration: BoxDecoration(
              color: _isFocused ? TVTheme.cardColor : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isFocused ? TVTheme.accentRed : Colors.transparent,
                width: 2,
              ),
            ),
            child: ListTile(
              contentPadding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: widget.leading,
              title: widget.title,
              subtitle: widget.subtitle,
              trailing: widget.trailing,
              onTap: widget.onTap,
            ),
          ),
        ),
      ),
    );
  }
}