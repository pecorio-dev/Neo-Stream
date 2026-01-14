import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
// import cpasmieux_image_loader removed

class DnsCachedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;

  const DnsCachedNetworkImage({
    Key? key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<DnsCachedNetworkImage> createState() => _DnsCachedNetworkImageState();
}

class _DnsCachedNetworkImageState extends State<DnsCachedNetworkImage> {
  late Future<String> _resolvedUrlFuture;

  @override
  void initState() {
    super.initState();
    _resolvedUrlFuture = _resolveImageUrl();
  }

  @override
  void didUpdateWidget(DnsCachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolvedUrlFuture = _resolveImageUrl();
    }
  }

  Future<String> _resolveImageUrl() async {
    return widget.imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _resolvedUrlFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildPlaceholder();
        }

        final resolvedUrl = snapshot.data!;

        if (widget.borderRadius != null) {
          return ClipRRect(
            borderRadius: widget.borderRadius!,
            child: _buildImage(resolvedUrl),
          );
        }

        return _buildImage(resolvedUrl);
      },
    );
  }

  Widget _buildImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      placeholder: widget.placeholder,
      errorWidget: widget.errorWidget ?? _defaultErrorWidget,
    );
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!(context, widget.imageUrl);
    }
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[900],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      ),
    );
  }

  Widget _defaultErrorWidget(BuildContext context, String url, dynamic error) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[900],
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          color: Colors.grey,
        ),
      ),
    );
  }
}

