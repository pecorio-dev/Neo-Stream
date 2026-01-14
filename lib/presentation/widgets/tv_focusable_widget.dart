import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/tv/tv_navigation_service.dart';
import '../../core/theme/app_theme.dart';

/// Widget focalisable pour la navigation TV
class TVFocusableWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final Color? focusColor;
  final double? focusWidth;
  final bool enabled;
  final bool showFocusHighlight;

  const TVFocusableWidget({
    Key? key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.padding,
    this.borderRadius,
    this.focusColor,
    this.focusWidth,
    this.enabled = true,
    this.showFocusHighlight = true,
  }) : super(key: key);

  @override
  State<TVFocusableWidget> createState() => _TVFocusableWidgetState();
}

class _TVFocusableWidgetState extends State<TVFocusableWidget>
    with TickerProviderStateMixin {
  late FocusNode _focusNode;
  late AnimationController _focusAnimationController;
  late AnimationController _pressAnimationController;
  late Animation<double> _focusAnimation;
  late Animation<double> _pressAnimation;
  late Animation<double> _scaleAnimation;

  bool _isFocused = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _setupAnimations();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _focusAnimationController.dispose();
    _pressAnimationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _focusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _pressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _focusAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _focusAnimationController,
      curve: Curves.easeInOut,
    ));

    _pressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pressAnimationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _pressAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _onFocusChanged() {
    final isFocused = _focusNode.hasFocus;
    if (_isFocused != isFocused) {
      setState(() {
        _isFocused = isFocused;
      });

      if (isFocused) {
        _focusAnimationController.forward();
        TVNavigationService.setCurrentFocus(_focusNode);
        // Feedback haptique léger pour la navigation TV
        HapticFeedback.selectionClick();
      } else {
        _focusAnimationController.reverse();
      }
    }
  }

  void _onPressed() {
    if (!widget.enabled) return;
    
    _pressAnimationController.forward().then((_) {
      _pressAnimationController.reverse();
    });
    
    // Feedback haptique pour la sélection
    HapticFeedback.lightImpact();
    
    widget.onPressed?.call();
  }

  void _onLongPressed() {
    if (!widget.enabled) return;
    
    // Feedback haptique pour l'appui long
    HapticFeedback.mediumImpact();
    
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Si pas en mode TV, retourner le widget simple
    if (!TVNavigationService.isTVMode) {
      return GestureDetector(
        onTap: widget.onPressed,
        onLongPress: widget.onLongPress,
        child: widget.child,
      );
    }

    return Semantics(
      label: widget.semanticLabel,
      button: true,
      enabled: widget.enabled,
      child: AnimatedBuilder(
        animation: Listenable.merge([_focusAnimation, _pressAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Focus(
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              onKeyEvent: _handleKeyEvent,
              child: Container(
                padding: widget.padding,
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
                  border: widget.showFocusHighlight && _isFocused
                      ? Border.all(
                          color: widget.focusColor ?? AppTheme.accentNeon,
                          width: widget.focusWidth ?? 3,
                        )
                      : null,
                  boxShadow: widget.showFocusHighlight && _isFocused
                      ? [
                          BoxShadow(
                            color: (widget.focusColor ?? AppTheme.accentNeon)
                                .withOpacity(0.4),
                            blurRadius: 12 * _focusAnimation.value,
                            spreadRadius: 2 * _focusAnimation.value,
                          ),
                        ]
                      : null,
                ),
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        _onPressed();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }
}

/// Widget de grille focalisable pour TV
class TVFocusableGrid extends StatefulWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsets? padding;
  final ScrollController? scrollController;

  const TVFocusableGrid({
    Key? key,
    required this.children,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 16,
    this.crossAxisSpacing = 16,
    this.padding,
    this.scrollController,
  }) : super(key: key);

  @override
  State<TVFocusableGrid> createState() => _TVFocusableGridState();
}

class _TVFocusableGridState extends State<TVFocusableGrid> {
  late ScrollController _scrollController;
  final List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _createFocusNodes();
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _createFocusNodes() {
    _focusNodes.clear();
    for (int i = 0; i < widget.children.length; i++) {
      final focusNode = FocusNode();
      focusNode.addListener(() => _onFocusChanged(i, focusNode));
      _focusNodes.add(focusNode);
    }
  }

  void _onFocusChanged(int index, FocusNode focusNode) {
    if (focusNode.hasFocus) {
      _ensureVisible(index);
    }
  }

  void _ensureVisible(int index) {
    if (!_scrollController.hasClients) return;

    final row = index ~/ widget.crossAxisCount;
    final itemHeight = 200.0; // Estimation de la hauteur d'un élément
    final targetOffset = row * (itemHeight + widget.mainAxisSpacing);
    
    final viewportHeight = _scrollController.position.viewportDimension;
    final currentOffset = _scrollController.offset;
    
    if (targetOffset < currentOffset) {
      // Scroll vers le haut
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (targetOffset + itemHeight > currentOffset + viewportHeight) {
      // Scroll vers le bas
      _scrollController.animateTo(
        targetOffset + itemHeight - viewportHeight,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.length != _focusNodes.length) {
      _createFocusNodes();
    }

    return GridView.builder(
      controller: _scrollController,
      padding: widget.padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        mainAxisSpacing: widget.mainAxisSpacing,
        crossAxisSpacing: widget.crossAxisSpacing,
        childAspectRatio: 0.7,
      ),
      itemCount: widget.children.length,
      itemBuilder: (context, index) {
        return TVFocusableWidget(
          focusNode: _focusNodes[index],
          autofocus: index == 0,
          child: widget.children[index],
        );
      },
    );
  }
}