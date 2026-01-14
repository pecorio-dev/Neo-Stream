import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/services/image_proxy_service.dart';

/// Widget d'image réseau amélioré avec optimisations de connectivité
class EnhancedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Map<String, String>? headers;
  final BorderRadius? borderRadius;
  final bool useOptimizedLoading;

  const EnhancedNetworkImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
    this.headers,
    this.borderRadius,
    this.useOptimizedLoading = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildErrorWidget();
    }

    // Use proxy for cpasmieux images (blocked by ISP)
    String displayUrl = ImageProxyService.getCdnUrl(imageUrl);
    
    if (displayUrl != imageUrl) {
      print('🖼️ Using proxy for image: $imageUrl → $displayUrl');
    }

    Widget imageWidget = CachedNetworkImage(
      imageUrl: displayUrl,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
      httpHeaders: headers,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: imageWidget,
    );
  }

  Widget _buildPlaceholder() {
    return placeholder ??
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: borderRadius ?? BorderRadius.circular(8),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
            ),
          ),
        );
  }

  Widget _buildErrorWidget() {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: borderRadius ?? BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 32,
            ),
          ),
        );
  }


}

/// Widget d'image avec avatar par défaut
class EnhancedAvatarImage extends StatelessWidget {
  final String imageUrl;
  final double radius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const EnhancedAvatarImage({
    Key? key,
    required this.imageUrl,
    this.radius = 20,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      child: ClipOval(
        child: EnhancedNetworkImage(
          imageUrl: imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: placeholder ??
              Icon(
                Icons.person,
                size: radius,
                color: Colors.grey[600],
              ),
          errorWidget: errorWidget ??
              Icon(
                Icons.person,
                size: radius,
                color: Colors.grey[600],
              ),
        ),
      ),
    );
  }
}

/// Widget d'image pour les posters de films/séries
class EnhancedPosterImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final bool showPlayButton;
  final VoidCallback? onTap;

  const EnhancedPosterImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.showPlayButton = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          EnhancedNetworkImage(
            imageUrl: imageUrl,
            width: width,
            height: height,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(8),
            placeholder: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(
                  Icons.movie,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
            ),
            errorWidget: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(
                  Icons.broken_image,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          if (showPlayButton)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Service utilitaire pour les images
class ImageUtils {
  /// Construit une image avec fallback automatique
  static Widget buildImageWithFallback({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit? fit,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
  }) {
    return EnhancedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder,
      errorWidget: errorWidget,
      borderRadius: borderRadius,
    );
  }

  /// Construit un avatar avec fallback
  static Widget buildAvatar({
    required String imageUrl,
    double radius = 20,
  }) {
    return EnhancedAvatarImage(
      imageUrl: imageUrl,
      radius: radius,
    );
  }

  /// Construit un poster avec overlay optionnel
  static Widget buildPoster({
    required String imageUrl,
    double? width,
    double? height,
    bool showPlayButton = false,
    VoidCallback? onTap,
  }) {
    return EnhancedPosterImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      showPlayButton: showPlayButton,
      onTap: onTap,
    );
  }
}

