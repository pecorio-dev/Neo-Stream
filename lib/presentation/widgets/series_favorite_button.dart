import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/series.dart';
import '../providers/favorites_provider.dart';

class SeriesFavoriteButton extends ConsumerStatefulWidget {
  final Series series;
  final double size;
  final Color color;
  final bool filled;

  const SeriesFavoriteButton(
    this.series, {
    this.size = 24,
    this.color = Colors.white,
    this.filled = false,
    Key? key,
  }) : super(key: key);

  @override
  ConsumerState<SeriesFavoriteButton> createState() =>
      _SeriesFavoriteButtonState();
}

class _SeriesFavoriteButtonState extends ConsumerState<SeriesFavoriteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isFavorite = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _checkFavoriteStatus();
  }

  @override
  void didUpdateWidget(SeriesFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series.id != widget.series.id) {
      _checkFavoriteStatus();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkFavoriteStatus() async {
    final favProvider = ref.read(favoritesProvider);
    final isFav =
        favProvider.isFavoriteSync(widget.series.url.hashCode.toString());
    if (mounted) {
      setState(() => _isFavorite = isFav);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final favProvider = ref.read(favoritesProvider);
      final success =
          await favProvider.toggleSeriesFavorite(widget.series);

      if (success && mounted) {
        setState(() => _isFavorite = !_isFavorite);
        if (_isFavorite) {
          _animationController.forward(from: 0.0);
        }
      }
    } catch (e) {
      print('Error toggling favorite: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _toggleFavorite,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.2)
            .animate(CurvedAnimation(
              parent: _animationController,
              curve: Curves.elasticOut,
            )),
        child: Icon(
          _isFavorite ? Icons.favorite : Icons.favorite_border,
          size: widget.size,
          color: _isFavorite ? Colors.red : widget.color,
        ),
      ),
    );
  }
}
