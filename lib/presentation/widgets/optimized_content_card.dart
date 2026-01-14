import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'app_image.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/content.dart';
import '../../data/models/series_compact.dart';
import '../screens/series_details_screen.dart';
// import cpasmieux_image_loader removed

/// Widget de carte de contenu ultra-optimisé pour les appareils lents
/// Utilise des animations CSS-like et une gestion mémoire intelligente
class OptimizedContentCard extends StatefulWidget {
  final Content content;
  final int index;
  final VoidCallback? onTap;
  final bool enableAnimations;

  const OptimizedContentCard({
    super.key,
    required this.content,
    required this.index,
    this.onTap,
    this.enableAnimations = true,
  });

  @override
  State<OptimizedContentCard> createState() => _OptimizedContentCardState();
}

class _OptimizedContentCardState extends State<OptimizedContentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isHovered = false;
  bool _isImageLoaded = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startEntryAnimation();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Animation d'entrée fluide
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _startEntryAnimation() {
    if (widget.enableAnimations) {
      // Délai progressif basé sur l'index pour un effet cascade
      Future.delayed(Duration(milliseconds: widget.index * 100), () {
        if (mounted) {
          _animationController.forward();
        }
      });
    } else {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: SlideTransition(
            position: _slideAnimation,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: _buildCard(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard() {
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..scale(_isHovered ? 1.05 : 1.0)
            ..rotateZ(_isHovered ? 0.01 : 0.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.cyberDark.withOpacity(0.9),
                AppColors.cyberBlack.withOpacity(0.95),
              ],
            ),
            border: Border.all(
              color: _isHovered 
                  ? AppColors.neonBlue.withOpacity(0.8)
                  : AppColors.neonBlue.withOpacity(0.3),
              width: _isHovered ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered 
                    ? AppColors.neonBlue.withOpacity(0.4)
                    : AppColors.neonBlue.withOpacity(0.1),
                blurRadius: _isHovered ? 20 : 8,
                spreadRadius: _isHovered ? 2 : 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageSection(),
                _buildInfoSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Expanded(
      flex: 7,
      child: Stack(
        children: [
          // Image principale avec optimisation mémoire
          Positioned.fill(
            child: _buildOptimizedImage(),
          ),
          
          // Gradient overlay stylisé
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),
          
          // Badges informatifs
          _buildBadges(),
          
          // Play button avec animation
          _buildPlayButton(),
        ],
      ),
    );
  }

  Widget _buildOptimizedImage() {
    if (widget.content.posterPath.isEmpty) {
      return _buildPlaceholder();
    }

    final imageWidget = AppImage(
      widget.content.posterPath,
      fit: BoxFit.cover,
      placeholder: _buildLoadingPlaceholder(),
      errorWidget: _buildPlaceholder(),
    );
    
    // Track when image loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isImageLoaded = true;
    });
    
    return imageWidget;
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: AppColors.cyberGray.withOpacity(0.3),
      child: Stack(
        children: [
          // Shimmer effect optimisé
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 1500),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.cyberGray.withOpacity(0.1),
                    AppColors.neonBlue.withOpacity(0.1),
                    AppColors.cyberGray.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image,
                  color: AppColors.neonBlue.withOpacity(0.5),
                  size: 32,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.neonBlue.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.cyberGray.withOpacity(0.3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.content.isMovie ? Icons.movie : Icons.tv,
            color: AppColors.textSecondary,
            size: 48,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.content.title,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadges() {
    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.content.isMovie 
                  ? AppColors.neonBlue.withOpacity(0.9)
                  : AppColors.neonPurple.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (widget.content.isMovie ? AppColors.neonBlue : AppColors.neonPurple)
                      .withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Text(
              widget.content.isMovie ? 'FILM' : 'SÉRIE',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Rating badge
          if (widget.content.voteAverage > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getRatingColor(widget.content.voteAverage).withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _getRatingColor(widget.content.voteAverage).withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    widget.content.voteAverage.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    return Positioned.fill(
      child: Center(
        child: AnimatedScale(
          scale: _isHovered ? 1.2 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withOpacity(_isHovered ? 0.9 : 0.7),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonBlue.withOpacity(0.4),
                  blurRadius: _isHovered ? 20 : 10,
                  spreadRadius: _isHovered ? 2 : 0,
                ),
              ],
            ),
            child: Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Expanded(
      flex: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre avec animation
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: _isHovered ? AppColors.neonBlue : AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              child: Text(
                widget.content.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            const SizedBox(height: 4),
            
            // Genres
            if (widget.content.genres.isNotEmpty)
              Text(
                widget.content.genres.take(2).join(' • '),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            
            const Spacer(),
            
            // Indicateur de qualité
            Row(
              children: [
                Icon(
                  widget.content.isMovie ? Icons.movie : Icons.tv,
                  size: 12,
                  color: AppColors.neonBlue.withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.content.isMovie ? 'Film' : 'Série',
                  style: TextStyle(
                    color: AppColors.neonBlue.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (widget.content.voteAverage > 7.0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.neonGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'TOP',
                      style: TextStyle(
                        color: AppColors.neonGreen,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _setHovered(bool hovered) {
    if (mounted) {
      setState(() {
        _isHovered = hovered;
      });
    }
  }

  Color _getRatingColor(double rating) {
    if (rating >= 8.0) return AppColors.neonGreen;
    if (rating >= 7.0) return AppColors.neonYellow;
    if (rating >= 6.0) return AppColors.neonOrange;
    return AppColors.laserRed;
  }
}


