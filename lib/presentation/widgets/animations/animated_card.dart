import 'package:flutter/material.dart';
import '../../../core/design_system/animation_system.dart';
import '../../../core/design_system/color_system.dart';

/// Carte animée avec effets de neon glow et transitions fluides
class AnimatedNeonCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double width;
  final double height;
  final bool showGlow;
  final Color glowColor;
  final Duration animationDuration;
  final EdgeInsets padding;

  const AnimatedNeonCard({
    Key? key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.width = double.infinity,
    this.height = 200,
    this.showGlow = true,
    this.glowColor = ColorSystem.neonCyan,
    this.animationDuration = const Duration(milliseconds: 300),
    this.padding = const EdgeInsets.all(0),
  }) : super(key: key);

  @override
  State<AnimatedNeonCard> createState() => _AnimatedNeonCardState();
}

class _AnimatedNeonCardState extends State<AnimatedNeonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: AnimationSystem.easeOutQuint),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AnimationSystem.neonPulse),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEnter() {
    setState(() => _isHovered = true);
    _controller.forward();
  }

  void _onExit() {
    setState(() => _isHovered = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: widget.width,
            height: widget.height,
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (widget.showGlow)
                  BoxShadow(
                    color: widget.glowColor.withOpacity(
                      0.3 * _glowAnimation.value,
                    ),
                    blurRadius: 20 * _glowAnimation.value,
                    spreadRadius: 5 * _glowAnimation.value,
                  ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: widget.glowColor.withOpacity(
                  0.3 + (0.2 * _glowAnimation.value),
                ),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ColorSystem.backgroundTertiary,
                  ColorSystem.backgroundTertiary.withOpacity(0.8),
                ],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Texte animé avec effet de typing ou fade-in
class AnimatedNeonText extends StatefulWidget {
  final String text;
  final TextStyle textStyle;
  final Duration duration;
  final bool showCursor;
  final Curve curve;

  const AnimatedNeonText(
    this.text, {
    Key? key,
    this.textStyle = const TextStyle(
      color: ColorSystem.neonCyan,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
    this.duration = const Duration(milliseconds: 800),
    this.showCursor = false,
    this.curve = AnimationSystem.easeOutQuint,
  }) : super(key: key);

  @override
  State<AnimatedNeonText> createState() => _AnimatedNeonTextState();
}

class _AnimatedNeonTextState extends State<AnimatedNeonText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [
            widget.textStyle.color ?? ColorSystem.neonCyan,
            (widget.textStyle.color ?? ColorSystem.neonCyan)
                .withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: Text(
          widget.text,
          style: widget.textStyle.copyWith(
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Bouton animé avec effet neon avancé
class AnimatedNeonButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final Color color;
  final Color hoverColor;
  final Color? secondaryColor;
  final Duration duration;
  final bool showGlow;
  final bool showRipple;
  final double borderRadius;
  final EdgeInsets padding;
  final Widget? icon;
  final bool fullWidth;

  const AnimatedNeonButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.color = ColorSystem.neonCyan,
    this.hoverColor = ColorSystem.neonPurple,
    this.secondaryColor,
    this.duration = const Duration(milliseconds: 300),
    this.showGlow = true,
    this.showRipple = true,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    this.icon,
    this.fullWidth = false,
  }) : super(key: key);

  @override
  State<AnimatedNeonButton> createState() => _AnimatedNeonButtonState();
}

class _AnimatedNeonButtonState extends State<AnimatedNeonButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<Color?> _colorAnimation;
  late Animation<double> _borderWidthAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: AnimationSystem.easeOutQuint),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AnimationSystem.neonPulse),
    );

    _colorAnimation = ColorTween(
      begin: widget.color,
      end: widget.hoverColor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _borderWidthAnimation = Tween<double>(begin: 1.5, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEnter() {
    setState(() => _isHovered = true);
    _controller.forward();
  }

  void _onExit() {
    setState(() => _isHovered = false);
    _controller.reverse();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _colorAnimation.value ?? widget.color;

    return MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value * (_isPressed ? 0.98 : 1.0),
              child: Container(
                width: widget.fullWidth ? double.infinity : null,
                padding: widget.padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: currentColor.withOpacity(0.8),
                    width: _borderWidthAnimation.value,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      currentColor.withOpacity(_isHovered ? 0.15 : 0.08),
                      currentColor.withOpacity(_isHovered ? 0.08 : 0.04),
                      if (widget.secondaryColor != null)
                        widget.secondaryColor!.withOpacity(_isHovered ? 0.1 : 0.05),
                    ],
                  ),
                  boxShadow: [
                    // Glow effect
                    if (widget.showGlow)
                      BoxShadow(
                        color: currentColor.withOpacity(0.4 * _glowAnimation.value),
                        blurRadius: 25 * _glowAnimation.value,
                        spreadRadius: 3 * _glowAnimation.value,
                      ),
                    // Inner glow
                    BoxShadow(
                      color: currentColor.withOpacity(0.1 * _glowAnimation.value),
                      blurRadius: 15,
                      spreadRadius: -2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      widget.icon!,
                      const SizedBox(width: 8),
                    ],
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          currentColor,
                          widget.secondaryColor ?? currentColor.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Indicateur de chargement animé avec style neon
class NeonLoadingIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const NeonLoadingIndicator({
    Key? key,
    this.color = ColorSystem.neonCyan,
    this.size = 50,
    this.duration = const Duration(seconds: 2),
  }) : super(key: key);

  @override
  State<NeonLoadingIndicator> createState() => _NeonLoadingIndicatorState();
}

class _NeonLoadingIndicatorState extends State<NeonLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotateAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();

    _rotateAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: AnimationSystem.neonPulse),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _rotateAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Liste animée avec stagger effect
class AnimatedStaggeredList extends StatefulWidget {
  final List<Widget> children;
  final Duration itemDelay;
  final Curve curve;

  const AnimatedStaggeredList({
    Key? key,
    required this.children,
    this.itemDelay = const Duration(milliseconds: 100),
    this.curve = AnimationSystem.easeOutQuint,
  }) : super(key: key);

  @override
  State<AnimatedStaggeredList> createState() => _AnimatedStaggeredListState();
}

class _AnimatedStaggeredListState extends State<AnimatedStaggeredList>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<Offset>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.children.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    _animations = _controllers
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: controller, curve: widget.curve),
          );
        })
        .toList();

    _animateItems();
  }

  void _animateItems() {
    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(widget.itemDelay * i, () {
        if (mounted) {
          _controllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        widget.children.length,
        (index) => SlideTransition(
          position: _animations[index],
          child: FadeTransition(
            opacity: _controllers[index],
            child: widget.children[index],
          ),
        ),
      ),
    );
  }
}
