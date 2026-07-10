import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../config/tv_config.dart';

/// Carte de contenu riche et stylisée pour l'interface TV.
///
/// Comporte :
/// - Poster avec gradient de fond dégradé
/// - Badge de type (Film / Série / Anime) avec couleur dédiée
/// - Note étoilée (optionnel)
/// - Indicateur de progression (optionnel)
/// - Label de métadonnée (ex. "2 saisons", "8 épisodes")
/// - Titre tronqué avec ombre subtile
/// - Animation d'entrée staggerée via [animate]
class TVContentCard extends StatelessWidget {
  final String posterUrl;
  final String title;
  final String? subtitle; // ex. "2 saisons", "8 épisodes"
  final String? typeLabel; // ex. "Film", "Série", "Anime"
  final double? rating;
  final double? progressPercent; // 0–100
  final int? badgeValue; // ex. nombre d'épisodes
  final IconData? badgeIcon;
  final IconData? typeIcon;
  final VoidCallback? onTap;
  final Color? accentColor; // surcharge couleur du badge

  const TVContentCard({
    super.key,
    required this.posterUrl,
    required this.title,
    this.subtitle,
    this.typeLabel,
    this.rating,
    this.progressPercent,
    this.badgeValue,
    this.badgeIcon,
    this.typeIcon,
    this.onTap,
    this.accentColor,
  });

  /// Couleur du badge selon le type de contenu.
  Color get _typeColor {
    if (accentColor != null) return accentColor!;
    switch (typeLabel) {
      case 'Film':
        return const Color(0xFFE50914);
      case 'Série' || 'Serie':
        return const Color(0xFF38BDF8);
      case 'Anime':
        return const Color(0xFF22D3EE);
      default:
        return TVTheme.accentRed;
    }
  }

  IconData get _typeIcon => typeIcon ?? Icons.play_arrow_rounded;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Poster ──
          Expanded(
            child: _PosterImage(
              posterUrl: posterUrl,
              typeLabel: typeLabel,
              typeIcon: _typeIcon,
              typeColor: _typeColor,
              rating: rating,
              progressPercent: progressPercent,
              badgeValue: badgeValue,
              badgeIcon: badgeIcon,
            ),
          ),
          // ── Text ──
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: TVTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: TVTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Enveloppe focusable + animation de scale au tap.
class _CardShell extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _CardShell({this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }
}

/// Poster avec overlay gradient + badges.
class _PosterImage extends StatelessWidget {
  final String posterUrl;
  final String? typeLabel;
  final IconData typeIcon;
  final Color typeColor;
  final double? rating;
  final double? progressPercent;
  final int? badgeValue;
  final IconData? badgeIcon;

  const _PosterImage({
    required this.posterUrl,
    this.typeLabel,
    required this.typeIcon,
    required this.typeColor,
    this.rating,
    this.progressPercent,
    this.badgeValue,
    this.badgeIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: TVTheme.cardColor,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Image ──
          posterUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: posterUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: TVTheme.cardColor,
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: TVTheme.accentRed,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => _buildPlaceholder(),
                )
              : _buildPlaceholder(),

          // ── Gradient overlay (bas → haut) ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.5],
                ),
              ),
            ),
          ),

          // ── Badge type (haut-gauche) ──
          if (typeLabel != null)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: typeColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(typeIcon, color: Colors.white, size: 10),
                    const SizedBox(width: 3),
                    Text(
                      typeLabel!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Rating (haut-droite) ──
          if (rating != null && rating! > 0)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: TVTheme.accentGold,
                      size: 11,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        color: TVTheme.accentGold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Badge valeur (bas-droite, ex. nombre épisodes) ──
          if (badgeValue != null)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badgeIcon != null)
                      Icon(badgeIcon, color: Colors.white70, size: 11),
                    if (badgeIcon != null) const SizedBox(width: 3),
                    Text(
                      '$badgeValue',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Progression (barre en bas) ──
          if (progressPercent != null && progressPercent! > 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: LinearProgressIndicator(
                  value: progressPercent! / 100,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(
                    TVTheme.accentRed.withValues(alpha: 0.9),
                  ),
                  minHeight: 4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: TVTheme.cardColor,
      child: const Center(
        child: Icon(Icons.movie_outlined, color: TVTheme.textDisabled, size: 36),
      ),
    );
  }
}

/// Extension pour animer une carte avec un stagger automatique.
extension TVContentCardAnimate on TVContentCard {
  Widget animateEntry({int index = 0, int staggerMs = 50}) {
    return animate()
        .fadeIn(
          duration: const Duration(milliseconds: 350),
          delay: Duration(milliseconds: index * staggerMs),
        )
        .scale(
          begin: const Offset(0.92, 0.92),
          end: const Offset(1.0, 1.0),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          delay: Duration(milliseconds: index * staggerMs),
        );
  }
}
