import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/platform_service.dart';

class FocusSelectorWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool autofocus;
  final FocusNode? focusNode;
  final BorderRadius? borderRadius;
  final Color? focusColor;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsets? padding;
  final bool showFocusIndicator;
  final String? semanticLabel;

  const FocusSelectorWrapper({
    Key? key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.autofocus = false,
    this.focusNode,
    this.borderRadius,
    this.focusColor,
    this.borderColor,
    this.borderWidth = 2.0,
    this.padding,
    this.showFocusIndicator = true,
    this.semanticLabel,
  }) : super(key: key);

  @override
  State<FocusSelectorWrapper> createState() => _FocusSelectorWrapperState();
}

class _FocusSelectorWrapperState extends State<FocusSelectorWrapper>
    with TickerProviderStateMixin {

  late AnimationController _scaleController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  bool _isPressed = false;
  bool _hasFocus = false;
  late FocusNode _internalFocusNode;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    // Use the provided focus node or create an internal one
    _internalFocusNode = widget.focusNode ?? FocusNode();
    _internalFocusNode.addListener(_handleFocusListener);
  }

  @override
  void dispose() {
    // Remove listener before disposing the focus node
    _internalFocusNode.removeListener(_handleFocusListener);
    if (widget.focusNode == null) {
      // Only dispose if we created the focus node internally
      _internalFocusNode.dispose();
    }
    _scaleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _handleFocusListener() {
    // Update the internal focus state when the focus changes
    if (_hasFocus != _internalFocusNode.hasFocus) {
      setState(() {
        _hasFocus = _internalFocusNode.hasFocus;
      });
    }
  }

  void _handlePress() {
    if (widget.onPressed != null) {
      setState(() => _isPressed = true);
      _scaleController.forward();

      HapticFeedback.lightImpact();
      widget.onPressed!();

      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          _scaleController.reverse();
          setState(() => _isPressed = false);
        }
      });
    }
  }

  void _handleLongPress() {
    if (widget.onLongPress != null) {
      HapticFeedback.mediumImpact();
      widget.onLongPress!();
    }
  }

  void _handleFocusChange(bool hasFocus) {
    if (hasFocus) {
      _glowController.forward();
    } else {
      _glowController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Toujours permettre la navigation avec focus, même avant la sélection de plateforme
    return Focus(
      focusNode: _internalFocusNode,
      autofocus: widget.autofocus,
      onFocusChange: (hasFocus) {
        _handleFocusChange(hasFocus);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            _handlePress();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        label: widget.semanticLabel,
        button: widget.onPressed != null,
        child: GestureDetector(
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress,
          child: AnimatedBuilder(
            animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  padding: widget.padding,
                  decoration: BoxDecoration(
                    borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
                    border: widget.showFocusIndicator && _hasFocus
                        ? Border.all(
                            color: widget.borderColor ?? AppTheme.accentNeon,
                            width: widget.borderWidth,
                          )
                        : null,
                    boxShadow: widget.showFocusIndicator && _hasFocus
                        ? [
                            BoxShadow(
                              color: (widget.focusColor ?? AppTheme.accentNeon)
                                  .withOpacity(0.3 * _glowAnimation.value),
                              blurRadius: 12 * _glowAnimation.value,
                              spreadRadius: 2 * _glowAnimation.value,
                            ),
                          ]
                        : null,
                  ),
                  child: widget.child,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Extension pour faciliter l'utilisation
extension FocusableWidget on Widget {
  Widget makeFocusable({
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
    bool autofocus = false,
    FocusNode? focusNode,
    BorderRadius? borderRadius,
    Color? focusColor,
    Color? borderColor,
    double borderWidth = 2.0,
    EdgeInsets? padding,
    bool showFocusIndicator = true,
    String? semanticLabel,
  }) {
    return FocusSelectorWrapper(
      onPressed: onPressed,
      onLongPress: onLongPress,
      autofocus: autofocus,
      focusNode: focusNode,
      borderRadius: borderRadius,
      focusColor: focusColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      padding: padding,
      showFocusIndicator: showFocusIndicator,
      semanticLabel: semanticLabel,
      child: this,
    );
  }
}

// Widget pour afficher la position actuelle dans une liste
class FocusPositionIndicator extends StatelessWidget {
  final int currentIndex;
  final int totalItems;
  final String? label;
  final bool showOnlyWhenFocused;

  const FocusPositionIndicator({
    Key? key,
    required this.currentIndex,
    required this.totalItems,
    this.label,
    this.showOnlyWhenFocused = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!PlatformService.isTVMode) return const SizedBox.shrink();
    
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.backgroundPrimary.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.accentNeon.withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != null) ...[
              Text(
                label!,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              '${currentIndex + 1}/$totalItems',
              style: const TextStyle(
                color: AppTheme.accentNeon,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget pour les instructions de navigation TV
class TVNavigationHelp extends StatelessWidget {
  final List<String> instructions;
  final bool showAlways;

  const TVNavigationHelp({
    Key? key,
    required this.instructions,
    this.showAlways = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!PlatformService.isTVMode && !showAlways) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.backgroundPrimary.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.accentNeon.withOpacity(0.3),
          ),
        ),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: instructions.map((instruction) {
            final parts = instruction.split(':');
            if (parts.length == 2) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentNeon.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      parts[0].trim(),
                      style: const TextStyle(
                        color: AppTheme.accentNeon,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    parts[1].trim(),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              );
            }
            return Text(
              instruction,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}