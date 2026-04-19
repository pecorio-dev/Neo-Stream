import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Widget pour afficher les posters sans déformation
/// Utilise BoxFit.cover avec ClipRRect pour éviter les étirements
class PosterImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const PosterImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius = 12.0,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        color: NeoTheme.bgElevated,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: fit,
          width: width,
          height: height,
          memCacheWidth: memCacheWidth,
          memCacheHeight: memCacheHeight,
          placeholder: (context, url) =>
              placeholder ??
              Container(
                color: NeoTheme.bgElevated,
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(NeoTheme.primaryRed),
                  ),
                ),
              ),
          errorWidget: (context, url, error) =>
              errorWidget ?? _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: NeoTheme.bgElevated,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const Center(
        child: Icon(
          Icons.movie_outlined,
          color: NeoTheme.textDisabled,
          size: 48,
        ),
      ),
    );
  }
}

/// Widget pour afficher les posters avec aspect ratio préservé
/// Garantit que l'image ne sera jamais étirée
class AspectRatioPoster extends StatelessWidget {
  final String imageUrl;
  final double aspectRatio;
  final double borderRadius;
  final BoxFit fit;

  const AspectRatioPoster({
    super.key,
    required this.imageUrl,
    this.aspectRatio = 2 / 3, // Ratio standard des posters (largeur/hauteur)
    this.borderRadius = 12.0,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: PosterImage(
        imageUrl: imageUrl,
        borderRadius: borderRadius,
        fit: fit,
      ),
    );
  }
}

/// Extension pour faciliter l'utilisation
extension PosterImageExtension on String {
  Widget toPosterImage({
    double? width,
    double? height,
    double borderRadius = 12.0,
    BoxFit fit = BoxFit.cover,
  }) {
    return PosterImage(
      imageUrl: this,
      width: width,
      height: height,
      borderRadius: borderRadius,
      fit: fit,
    );
  }

  Widget toAspectRatioPoster({
    double aspectRatio = 2 / 3,
    double borderRadius = 12.0,
  }) {
    return AspectRatioPoster(
      imageUrl: this,
      aspectRatio: aspectRatio,
      borderRadius: borderRadius,
    );
  }
}
