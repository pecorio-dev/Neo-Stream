import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design_system/color_system.dart';
import '../../core/design_system/animation_system.dart';
import '../../data/models/movie.dart';
import '../providers/favorites_provider.dart';
import '../screens/movie_details_screen.dart';
import 'tv_focusable_card.dart';

class ContentCard extends ConsumerStatefulWidget {
  final Movie content;
  final int index;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enableGlowEffect;
  final bool enableHoverAnimation;

  const ContentCard({
    super.key,
    required this.content,
    required this.index,
    this.onTap,
    this.focusNode,
    this.autofocus = false,
    this.enableGlowEffect = true,
    this.enableHoverAnimation = true,
  });

  @override
  ConsumerState<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends ConsumerState<ContentCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AnimationSystem.easeOutQuint,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AnimationSystem.neonPulse,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHoverEnter() {
    if (widget.enableHoverAnimation) {
      setState(() => _isHovered = true);
      _animationController.forward();
    }
  }

  void _onHoverExit() {
    if (widget.enableHoverAnimation) {
      setState(() => _isHovered = false);
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoritesProviderValue = ref.watch(favoritesProvider);
    final isFavorite = favoritesProviderValue.isFavoriteSync(widget.content.id);

    return MouseRegion(
      onEnter: (_) => _onHoverEnter(),
      onExit: (_) => _onHoverExit(),
      child: TVFocusableCard(
        onPressed: widget.onTap ?? () => _navigateToDetails(context),
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ColorSystem.backgroundTertiary,
                ColorSystem.backgroundSecondary,
              ],
            ),
                  border: Border.all(
                    color: ColorSystem.neonCyan.withOpacity(
                      0.3 + (0.4 * _glowAnimation.value),
                    ),
                    width: 1.5 + (0.5 * _glowAnimation.value),
                  ),
                  boxShadow: [
                    // Glow effect
                    if (widget.enableGlowEffect)
                      BoxShadow(
                        color: ColorSystem.neonCyan.withOpacity(
                          0.2 * _glowAnimation.value,
                        ),
                        blurRadius: 20 * _glowAnimation.value,
                        spreadRadius: 5 * _glowAnimation.value,
                      ),
                    // Base shadow
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Poster
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              ColorSystem.backgroundTertiary,
                              ColorSystem.backgroundSecondary,
                            ],
                          ),
                        ),
                child: Stack(
                  children: [
                    // Placeholder icon
                    Center(
                      child: Icon(
                        Icons.movie,
                        size: 48,
                        color: ColorSystem.textTertiary,
                      ),
                    ),
                    
                    // Rating badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getRatingColor(widget.content.numericRating).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 12,
                              color: ColorSystem.textPrimary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              widget.content.numericRating.toStringAsFixed(1),
                              style: TextStyle(
                                color: ColorSystem.backgroundPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Favorite button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _toggleFavorite(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: ColorSystem.backgroundPrimary.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: isFavorite ? ColorSystem.neonPink : ColorSystem.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    
                    // Play overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              ColorSystem.backgroundPrimary.withOpacity(0.3),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: ColorSystem.neonCyan.withOpacity(0.8),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: ColorSystem.neonCyan.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.play_arrow,
                              color: ColorSystem.backgroundPrimary,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Content info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.content.displayTitle,
                    style: TextStyle(
                      color: ColorSystem.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (widget.content.genres.isNotEmpty)
                    Text(
                      widget.content.genres.take(2).join(', '),
                      style: TextStyle(
                        color: ColorSystem.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.movie,
                        size: 12,
                        color: ColorSystem.neonCyan,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Film',
                        style: TextStyle(
                          color: ColorSystem.neonCyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
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

  Color _getRatingColor(double rating) {
    if (rating >= 8.0) {
      return ColorSystem.neonGreen;
    } else if (rating >= 7.0) {
      return ColorSystem.neonCyan;
    } else if (rating >= 6.0) {
      return ColorSystem.warningColor;
    } else if (rating >= 5.0) {
      return ColorSystem.warningColor;
    } else {
      return ColorSystem.errorColor;
    }
  }

  void _toggleFavorite(BuildContext context) {
    ref.read(favoritesProvider).toggleFavorite(widget.content);
  }

  void _navigateToDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MovieDetailsScreen(movie: widget.content),
      ),
    );
  }
}
