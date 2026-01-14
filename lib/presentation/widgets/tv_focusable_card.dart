import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/services/platform_service.dart';
import '../../core/theme/app_theme.dart';

/// Widget card focalisable pour la navigation TV
class TVFocusableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final FocusNode? focusNode;
  final bool autofocus;
  final EdgeInsets? margin;
  final BorderRadius? borderRadius;

  const TVFocusableCard({
    Key? key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.focusNode,
    this.autofocus = false,
    this.margin,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<TVFocusableCard> createState() => _TVFocusableCardState();
}

class _TVFocusableCardState extends State<TVFocusableCard>
    with TickerProviderStateMixin {
  late FocusNode _focusNode;
  late AnimationController _focusAnimationController;
  late Animation<double> _focusAnimation;
  late Animation<double> _scaleAnimation;

  bool _isFocused = false;

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
    super.dispose();
  }

  void _setupAnimations() {
    _focusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _focusAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _focusAnimationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _focusAnimationController,
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
        // Feedback haptique léger pour la navigation TV
        HapticFeedback.selectionClick();
      } else {
        _focusAnimationController.reverse();
      }
    }
  }

  void _onPressed() {
    // Feedback haptique pour la sélection
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Toujours permettre la navigation avec focus pour la sélection de plateforme
    // et autres écrans où la télécommande doit fonctionner
    return AnimatedBuilder(
      animation: _focusAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: widget.margin,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
              border: _isFocused
                  ? Border.all(
                      color: AppTheme.accentNeon,
                      width: 3,
                    )
                  : null,
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: AppTheme.accentNeon.withOpacity(0.4),
                        blurRadius: 12 * _focusAnimation.value,
                        spreadRadius: 2 * _focusAnimation.value,
                      ),
                    ]
                  : null,
            ),
            child: Focus(
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              onKeyEvent: _handleKeyEvent,
              child: GestureDetector(
                onTap: widget.onPressed,
                onLongPress: widget.onLongPress,
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
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

/// Extension pour adapter facilement les widgets existants
extension TVFocusableExtension on Widget {
  Widget makeTVFocusable({
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
    FocusNode? focusNode,
    bool autofocus = false,
    EdgeInsets? margin,
    BorderRadius? borderRadius,
  }) {
    return TVFocusableCard(
      onPressed: onPressed,
      onLongPress: onLongPress,
      focusNode: focusNode,
      autofocus: autofocus,
      margin: margin,
      borderRadius: borderRadius,
      child: this,
    );
  }
}