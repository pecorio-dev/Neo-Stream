import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final String? actionText;
  final bool showGlow;

  const SectionTitle({
    super.key,
    required this.title,
    this.icon,
    this.color,
    this.onTap,
    this.actionText,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.neonBlue;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: effectiveColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                boxShadow: showGlow ? [
                  BoxShadow(
                    color: effectiveColor.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ] : null,
              ),
              child: Icon(
                icon,
                color: effectiveColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          if (onTap != null && actionText != null)
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: effectiveColor.withOpacity(0.5),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionText!,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: effectiveColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: effectiveColor,
                      size: 12,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ).animate(
      effects: [
        const FadeEffect(
          duration: Duration(milliseconds: 400),
          begin: 0.0,
          end: 1.0,
        ),
        const SlideEffect(
          duration: Duration(milliseconds: 400),
          begin: Offset(-0.3, 0.0),
          end: Offset.zero,
        ),
      ],
    );
  }
}

class SectionTitleGlow extends StatefulWidget {
  final String title;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final String? actionText;

  const SectionTitleGlow({
    super.key,
    required this.title,
    this.icon,
    this.color,
    this.onTap,
    this.actionText,
  });

  @override
  State<SectionTitleGlow> createState() => _SectionTitleGlowState();
}

class _SectionTitleGlowState extends State<SectionTitleGlow>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? AppColors.neonBlue;
    
    return MouseRegion(
      onEnter: (_) => _glowController.forward(),
      onExit: (_) => _glowController.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_glowController, _pulseController]),
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    effectiveColor.withOpacity(0.1),
                    effectiveColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: effectiveColor.withOpacity(0.3 + (_glowController.value * 0.4)),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: effectiveColor.withOpacity(0.2 + (_glowController.value * 0.3)),
                    blurRadius: 10 + (_glowController.value * 10),
                    spreadRadius: _glowController.value * 2,
                  ),
                  BoxShadow(
                    color: effectiveColor.withOpacity(0.1 + (_pulseController.value * 0.1)),
                    blurRadius: 20 + (_pulseController.value * 10),
                    spreadRadius: _pulseController.value * 3,
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      color: effectiveColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                  ],
                  
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  if (widget.onTap != null && widget.actionText != null) ...[
                    Text(
                      widget.actionText!,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: effectiveColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: effectiveColor,
                      size: 12,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class SectionDivider extends StatelessWidget {
  final Color? color;
  final double height;
  final bool showGlow;

  const SectionDivider({
    super.key,
    this.color,
    this.height = 1,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.neonBlue;
    
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            effectiveColor.withOpacity(0.5),
            effectiveColor,
            effectiveColor.withOpacity(0.5),
            Colors.transparent,
          ],
        ),
        boxShadow: showGlow ? [
          BoxShadow(
            color: effectiveColor.withOpacity(0.3),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ] : null,
      ),
    ).animate(
      onPlay: (controller) => controller.repeat(),
      effects: [
        const ShimmerEffect(
          duration: Duration(seconds: 2),
          color: AppColors.neonBlue,
        ),
      ],
    );
  }
}