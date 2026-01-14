import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../data/services/image_url_resolver.dart';

/// NetworkImage with automatic proxy support for cpasmieux.is images
class NetworkImageWithProxy extends ImageProvider<NetworkImageWithProxy> {
  final String imageUrl;
  final Map<String, String>? headers;

  NetworkImageWithProxy(
    this.imageUrl, {
    this.headers,
  });

  @override
  ImageStreamCompleter loadImage(NetworkImageWithProxy key, ImageDecoderCallback decode) {
    final resolvedUrl = ImageUrlResolver.resolve(imageUrl);
    final networkImage = NetworkImage(resolvedUrl, headers: headers);
    return networkImage.loadImage(networkImage, decode);
  }

  @override
  Future<NetworkImageWithProxy> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<NetworkImageWithProxy>(this);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkImageWithProxy &&
        other.imageUrl == imageUrl &&
        other.headers == headers;
  }

  @override
  int get hashCode => Object.hash(imageUrl, headers);

  @override
  String toString() => 'NetworkImageWithProxy(url: $imageUrl)';
}
