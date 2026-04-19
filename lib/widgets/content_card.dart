import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../config/theme.dart';
import '../models/content.dart';

enum CardVariant {
  standard,
  dailyTop,
  recommendation,
  continueWatching,
  search,
}

class ContentCard extends StatefulWidget {
  final Content content;
  final CardVariant variant;
  final int index;
  final VoidCallback? onTap;

  const ContentCard({
    super.key,
    required this.content,
    this.variant = CardVariant.standard,
    this.index = 0,
    this.onTap,
  });

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final useFocus = NeoTheme.needsFocusNavigation(context);
    final focusBorderWidth = NeoTheme.focusBorderWidth(context);
    final focusedScale = NeoTheme.focusedCardScale(context);

    return RepaintBoundary(
      child: Focus(
      // Problem #47: Focus change callback para atualizar visual
      onFocusChange: (focused) {
        if (_isFocused == focused) return;
        setState(() => _isFocused = focused);
      },
      onKeyEvent: useFocus
          ? (node, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.enter ||
                   event.logicalKey == LogicalKeyboardKey.select ||
                   event.logicalKey == LogicalKeyboardKey.space)) {
                widget.onTap?.call();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            }
          : null,
      child: Semantics(
        button: true,
        enabled: true,
        label:
            '${widget.content.isSerie ? 'Série' : 'Film'}: ${widget.content.displayTitle}',
        onTap: widget.onTap,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            canRequestFocus: useFocus,
            autofocus: false,
            focusColor: useFocus
                ? NeoTheme.primaryRed.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
            splashColor: NeoTheme.primaryRed.withValues(alpha: 0.1),
            highlightColor: NeoTheme.primaryRed.withValues(alpha: 0.05),
            child: AnimatedScale(
              scale: (_isFocused && useFocus) ? focusedScale : 1,
              duration: NeoTheme.durationFast,
              curve: NeoTheme.smoothOut,
              child: AnimatedContainer(
                duration: NeoTheme.durationFast,
                curve: NeoTheme.smoothOut,
                decoration: _isFocused && useFocus
                    ? BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(NeoTheme.radiusLg),
                        border: Border.all(
                          color: NeoTheme.primaryRed,
                          width: focusBorderWidth,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                NeoTheme.primaryRed.withValues(alpha: 0.6),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      )
                    : null,
                child: _buildVariant(context),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildVariant(BuildContext context) {
    switch (widget.variant) {
      case CardVariant.dailyTop:
        return _buildDailyTopCard(context);
      case CardVariant.recommendation:
        return _buildRecommendationCard(context);
      case CardVariant.continueWatching:
        return _buildContinueWatchingCard(context);
      case CardVariant.search:
        return _buildSearchCard(context);
      case CardVariant.standard:
        return _buildStandardCard(context);
    }
  }

  // ─── Standard Card ───────────────────────────────────────────────

  Widget _buildStandardCard(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;
    final footerPills = _buildFooterPills(context, limit: compact ? 2 : 3);

    return Container(
      width: NeoTheme.cardWidth(context),
      decoration: _isFocused
          ? NeoTheme.cardFocusedDecoration
          : NeoTheme.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildPoster(widget.content.fullPosterUrl),
          const DecoratedBox(
            decoration:
                BoxDecoration(gradient: NeoTheme.cardOverlayGradient),
          ),

          // Top badges
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: NeoTheme.contentPadding(context).copyWith(bottom: 22 * NeoTheme.scaleFactor(context)),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xBB06060C),
                    Color(0x6606060C),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildTypeBadge(),
                        if (widget.content.isPremiumContent)
                          _buildInfoPill(
                            context,
                            'Premium',
                            color: NeoTheme.prestigeGold,
                          ),
                      ],
                    ),
                  ),
                  if (widget.content.rating > 0) ...[
                    const SizedBox(width: 8),
                    _buildRatingBadge(
                      widget.content.rating,
                      compact: true,
                      emphasized: true,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Progress bar
          if (widget.content.progressPercent != null &&
              widget.content.progressPercent! > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildProgressBar(widget.content.progressPercent!),
            ),

          // Info footer
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NeoTheme.bgBase.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                border: Border.all(
                  color: NeoTheme.bgBorder.withValues(alpha: 0.25),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.content.languageTag.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildInfoPill(
                        context,
                        widget.content.languageTag,
                        color: NeoTheme.primaryRed,
                      ),
                    ),
                  // Problem #69: Title ellipsis instead of overflow
                  Text(
                    widget.content.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: NeoTheme.labelLarge(context).copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _metaLine(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NeoTheme.labelSmall(context)
                        .copyWith(color: NeoTheme.textSecondary),
                  ),
                  if (footerPills.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: footerPills),
                  ],
                  if (!compact &&
                      widget.content.description != null &&
                      widget.content.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.content.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NeoTheme.bodySmall(context).copyWith(
                        color: NeoTheme.textTertiary,
                        height: 1.25,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.play_circle_fill_rounded,
                        size: 15,
                        color: _isFocused
                            ? NeoTheme.primaryRed
                            : NeoTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.content.isSerie
                              ? 'Ouvrir la fiche serie'
                              : 'Ouvrir la fiche film',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NeoTheme.labelSmall(context).copyWith(
                            color: _isFocused
                                ? NeoTheme.primaryRed
                                : NeoTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Subtle hover overlay
          if (_isFocused)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: NeoTheme.bgActive.withValues(alpha: 0.15),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Daily Top Card ──────────────────────────────────────────────

  Widget _buildDailyTopCard(BuildContext context) {
    return SizedBox(
      width: NeoTheme.cardWidth(context) + 42,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 46,
            child: Text(
              '${widget.content.rank ?? (widget.index + 1)}',
              style: NeoTheme.displayLarge(context).copyWith(
                fontSize: 52,
                foreground: Paint()
                  ..shader = NeoTheme.heroGradient.createShader(
                    const Rect.fromLTWH(0, 0, 56, 64),
                  ),
                shadows: [
                  Shadow(
                    color: NeoTheme.primaryRed.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildStandardCard(context)),
        ],
      ),
    );
  }

  // ─── Recommendation Card ─────────────────────────────────────────

  Widget _buildRecommendationCard(BuildContext context) {
    final footerPills = _buildFooterPills(context, limit: 2);

    return Container(
      width: NeoTheme.cardWidth(context),
      decoration: _isFocused
          ? NeoTheme.cardFocusedDecoration
          : NeoTheme.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildPoster(widget.content.fullPosterUrl),
          const DecoratedBox(
            decoration:
                BoxDecoration(gradient: NeoTheme.cardOverlayGradient),
          ),

          // Top area: match pill + rating
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: NeoTheme.contentPadding(context).copyWith(bottom: 22 * NeoTheme.scaleFactor(context)),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xBB06060C),
                    Color(0x6606060C),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.content.matchPercent != null)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: NeoTheme.successGreen
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: NeoTheme.successGreen
                                  .withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '${widget.content.matchPercent}% pour vous',
                            style: NeoTheme.labelSmall(context).copyWith(
                              color: NeoTheme.successGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (widget.content.rating > 0) ...[
                    const SizedBox(width: 8),
                    _buildRatingBadge(
                        widget.content.rating, emphasized: true),
                  ],
                ],
              ),
            ),
          ),

          // Info footer
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: NeoTheme.bgBase.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                border: Border.all(
                  color: NeoTheme.bgBorder.withValues(alpha: 0.25),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.content.languageTag.isNotEmpty) ...[
                    _buildInfoPill(
                      context,
                      widget.content.languageTag,
                      color: NeoTheme.primaryRed,
                    ),
                    const SizedBox(height: 8),
                  ],
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.content.displayTitle,
                      maxLines: 1,
                      style: NeoTheme.labelLarge(context).copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.content.typeLabel,
                    style: NeoTheme.labelSmall(context)
                        .copyWith(color: NeoTheme.textSecondary),
                  ),
                  if (footerPills.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: footerPills),
                  ],
                  if (widget.content.description != null &&
                      widget.content.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.content.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NeoTheme.bodySmall(context)
                          .copyWith(color: NeoTheme.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Continue Watching Card ──────────────────────────────────────

  Widget _buildContinueWatchingCard(BuildContext context) {
    return Container(
      width: NeoTheme.isTV(context) ? 372 : 318,
      decoration: _isFocused
          ? NeoTheme.cardFocusedDecoration
          : NeoTheme.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: NeoTheme.posterSize(context, tall: true).width,
            height: NeoTheme.posterSize(context, tall: true).height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildPoster(widget.content.fullPosterUrl),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xC006060C)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    widget.content.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: NeoTheme.titleMedium(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.content.currentEpisodeId ??
                        (widget.content.isSerie
                            ? 'Serie en cours'
                            : 'Film en cours'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NeoTheme.bodySmall(context),
                  ),
                  const SizedBox(height: 10),
                  if (widget.content.progressPercent != null)
                    _buildProgressBar(widget.content.progressPercent!),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _buildFooterPills(context, limit: 3),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.play_circle_fill_rounded,
                        size: 18,
                        color: NeoTheme.primaryRed.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Reprendre maintenant',
                        style: NeoTheme.labelMedium(context).copyWith(
                          color: NeoTheme.primaryRed.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Search Card ─────────────────────────────────────────────────

  Widget _buildSearchCard(BuildContext context) {
    final showDescription = MediaQuery.of(context).size.width >= 900;

    return Container(
      decoration: BoxDecoration(
        color: NeoTheme.bgSurface,
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(
          color: NeoTheme.bgBorder.withValues(alpha: 0.22),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: NeoTheme.posterSize(context).width,
            height: NeoTheme.posterSize(context).height,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(NeoTheme.radiusLg),
                bottomLeft: Radius.circular(NeoTheme.radiusLg),
              ),
              child: _buildPoster(widget.content.fullPosterUrl),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.content.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: NeoTheme.titleMedium(context)
                              .copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (widget.content.rating > 0) ...[
                        const SizedBox(width: 10),
                        _buildRatingBadge(
                          widget.content.rating,
                          compact: false,
                          emphasized: true,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTypeBadge(),
                      if (widget.content.languageTag.isNotEmpty)
                        _buildInfoPill(
                          context,
                          widget.content.languageTag,
                          color: NeoTheme.primaryRed,
                        ),
                      if (widget.content.releaseDate != null)
                        _buildInfoPill(
                          context,
                          '${widget.content.releaseDate}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.content.genresText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NeoTheme.bodySmall(context)
                        .copyWith(color: NeoTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _buildFooterPills(context, limit: 2),
                  ),
                  const SizedBox(height: 12),
                  if (showDescription &&
                      widget.content.description != null &&
                      widget.content.description!.trim().isNotEmpty)
                    Text(
                      widget.content.description!,
                      maxLines: NeoTheme.isTV(context) ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: NeoTheme.bodySmall(context)
                          .copyWith(color: NeoTheme.textSecondary),
                    ),
                  if (showDescription &&
                      widget.content.description != null &&
                      widget.content.description!.trim().isNotEmpty)
                    const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared Builders ─────────────────────────────────────────────

  Widget _buildPoster(String url) {
    if (url.isEmpty) {
      return Container(
        color: NeoTheme.bgActive,
        child: const Center(
          child: Icon(
            Icons.movie_creation_outlined,
            color: NeoTheme.textDisabled,
          ),
        ),
      );
    }

    // Optimisation mémoire TV: limiter la taille du cache
    final cacheHeight = (NeoTheme.cardHeight(context) * 2).toInt();
    final cacheWidth = (NeoTheme.cardWidth(context) * 2).toInt();

    return ClipRRect(
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheHeight: cacheHeight,
        memCacheWidth: cacheWidth,
        alignment: Alignment.center,
        placeholder: (_, _) => Shimmer.fromColors(
          baseColor: NeoTheme.bgElevated,
          highlightColor: NeoTheme.bgOverlay,
          child: Container(color: NeoTheme.bgElevated),
        ),
        errorWidget: (_, _, _) => Container(
          color: NeoTheme.bgActive,
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: NeoTheme.textDisabled,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge() {
    final color =
        widget.content.isSerie ? NeoTheme.infoCyan : NeoTheme.primaryRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        widget.content.typeLabel,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildRatingBadge(
    double rating, {
    bool compact = false,
    bool emphasized = false,
  }) {
    final size = compact ? 32.0 : 38.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: NeoTheme.bgOverlay,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: rating / 10.0,
              strokeWidth: compact ? 2.0 : 2.5,
              backgroundColor:
                  NeoTheme.prestigeGold.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                NeoTheme.prestigeGold,
              ),
            ),
          ),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: NeoTheme.prestigeGold,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill(BuildContext context, String label, {Color? color}) {
    final accent = color ?? NeoTheme.bgBorder;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color != null
            ? accent.withValues(alpha: 0.12)
            : NeoTheme.bgSurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color != null
              ? accent.withValues(alpha: 0.25)
              : NeoTheme.bgBorder.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: NeoTheme.labelSmall(context).copyWith(
          color: color ?? NeoTheme.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildProgressBar(double percent) {
    final clampedValue = (percent / 100).clamp(0.0, 1.0);
    return SizedBox(
      height: 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fillWidth = constraints.maxWidth * clampedValue;
          return Stack(
            children: [
              // Track
              Container(
                decoration: BoxDecoration(
                  color: NeoTheme.bgBorder.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              // Fill with glow
              Container(
                width: fillWidth,
                decoration: BoxDecoration(
                  color: NeoTheme.primaryRed,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: NeoTheme.primaryRed.withValues(alpha: 0.45),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _metaLine() {
    final parts = <String>[];
    if (widget.content.releaseDate != null) {
      parts.add('${widget.content.releaseDate}');
    }
    if (parts.isEmpty) {
      parts.add(widget.content.typeLabel);
    }
    return parts.join(' / ');
  }

  List<Widget> _buildFooterPills(BuildContext context, {int limit = 3}) {
    final pills = <Widget>[];

    if (widget.content.isSerie && widget.content.seasonCount > 0) {
      pills.add(
        _buildInfoPill(
          context,
          widget.content.seasonCount > 1
              ? '${widget.content.seasonCount} saisons'
              : '1 saison',
        ),
      );
    }

    if (widget.content.episodeCount > 0) {
      pills.add(
          _buildInfoPill(context, '${widget.content.episodeCount} ep'));
    }

    if (widget.content.mainGenre.isNotEmpty) {
      pills.add(
        _buildInfoPill(
          context,
          widget.content.mainGenre,
          color: NeoTheme.textPrimary,
        ),
      );
    }

    if (widget.content.matchPercent != null) {
      final showMatchInFooter =
          widget.variant != CardVariant.recommendation;
      if (showMatchInFooter) {
        pills.add(
          _buildInfoPill(
            context,
            '${widget.content.matchPercent}% match',
            color: NeoTheme.primaryRed,
          ),
        );
      }
    }

    if ((widget.content.todayViews ?? 0) > 0) {
      pills.add(
        _buildInfoPill(
          context,
          '${widget.content.todayViews} vues',
          color: NeoTheme.textPrimary,
        ),
      );
    }

    return pills.take(limit).toList();
  }
}
