import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/services/image_url_resolver.dart';

/// CachedNetworkImage with automatic proxy for cpasmieux.is images
class ProxiedCachedImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const ProxiedCachedImage(
    this.imageUrl, {
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final proxiedUrl = ImageUrlResolver.resolve(imageUrl);
    return CachedNetworkImage(
      imageUrl: proxiedUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}
