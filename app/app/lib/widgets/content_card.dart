import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../config/theme.dart';
import '../config/neo.dart';
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
  final ValueChanged<bool>? onFocusChange;
  final bool autofocus;

  ContentCard({
    super.key,
    required this.content,
    this.variant = CardVariant.standard,
    this.index = 0,
    this.onTap,
    this.onFocusChange,
    this.autofocus = false,
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
      autofocus: widget.autofocus,
      onFocusChange: (focused) {
        if (_isFocused == focused) return;
        setState(() => _isFocused = focused);
        if (focused && useFocus) {
          Scrollable.ensureVisible(
            context,
            duration: NeoTheme.durationFast,
            curve: NeoTheme.smoothOut,
            alignment: 0.5,
          );
        }
        widget.onFocusChange?.call(focused);
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
        label: '${widget.content.typeLabel}: ${widget.content.displayTitle}',
        onTap: widget.onTap,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            canRequestFocus: false,
            autofocus: false,
            focusColor: useFocus
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
            splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            highlightColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
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
                          color: Theme.of(context).colorScheme.primary,
                          width: focusBorderWidth,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
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
          ? Neo.cardFocusedDecoration(context)
          : Neo.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildPoster(widget.content.fullPosterUrl),
          DecoratedBox(
            decoration:
                BoxDecoration(gradient: Neo.cardOverlayGradient(context)),
          ),

          // Top badges
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: NeoTheme.contentPadding(context).copyWith(bottom: 22 * NeoTheme.scaleFactor(context)),
              decoration: BoxDecoration(
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
                    SizedBox(width: 8),
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
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Neo.bgBase(context).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                border: Border.all(
                  color: Neo.bgBorder(context).withValues(alpha: 0.25),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.content.languageTag.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: _buildInfoPill(
                        context,
                        widget.content.languageTag,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  Text(
                    widget.content.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Neo.labelLarge(context).copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    _metaLine(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Neo.labelSmall(context)
                        .copyWith(color: Neo.textSecondary(context)),
                  ),
                  if (footerPills.isNotEmpty) ...[
                    SizedBox(height: 9),
                    Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: footerPills),
                  ],
                  if (!compact &&
                      widget.content.description != null &&
                      widget.content.description!.trim().isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      widget.content.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Neo.bodySmall(context).copyWith(
                        color: Neo.textTertiary(context),
                        height: 1.25,
                      ),
                    ),
                  ],
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.play_circle_fill_rounded,
                        size: 15,
                        color: _isFocused
                            ? Theme.of(context).colorScheme.primary
                            : Neo.textSecondary(context),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.content.isSerie
                              ? 'Ouvrir la fiche serie'
                              : 'Ouvrir la fiche film',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Neo.labelSmall(context).copyWith(
                            color: _isFocused
                                ? Theme.of(context).colorScheme.primary
                                : Neo.textSecondary(context),
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
                  color: Neo.bgActive(context).withValues(alpha: 0.15),
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
              style: Neo.displayLarge(context).copyWith(
                fontSize: 52,
                foreground: Paint()
                  ..shader = Neo.heroGradient(context).createShader(
                    const Rect.fromLTWH(0, 0, 56, 64),
                  ),
                shadows: [
                  Shadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: Offset(0, 2),
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
          ? Neo.cardFocusedDecoration(context)
          : Neo.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildPoster(widget.content.fullPosterUrl),
          DecoratedBox(
            decoration:
                BoxDecoration(gradient: Neo.cardOverlayGradient(context)),
          ),

          // Top area: match pill + rating
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: NeoTheme.contentPadding(context).copyWith(bottom: 22 * NeoTheme.scaleFactor(context)),
              decoration: BoxDecoration(
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
                          padding: EdgeInsets.symmetric(
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
                            style: Neo.labelSmall(context).copyWith(
                              color: NeoTheme.successGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Spacer(),
                  if (widget.content.rating > 0) ...[
                    SizedBox(width: 8),
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
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Neo.bgBase(context).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                border: Border.all(
                  color: Neo.bgBorder(context).withValues(alpha: 0.25),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: Offset(0, 8),
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
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(height: 8),
                  ],
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.content.displayTitle,
                      maxLines: 1,
                      style: Neo.labelLarge(context).copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    widget.content.typeLabel,
                    style: Neo.labelSmall(context)
                        .copyWith(color: Neo.textSecondary(context)),
                  ),
                  if (footerPills.isNotEmpty) ...[
                    SizedBox(height: 9),
                    Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: footerPills),
                  ],
                  if (widget.content.description != null &&
                      widget.content.description!.trim().isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      widget.content.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Neo.bodySmall(context)
                          .copyWith(color: Neo.textTertiary(context)),
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
    final isTV = NeoTheme.isTV(context);
    return Container(
      width: isTV ? 372 : 318,
      decoration: _isFocused
          ? Neo.cardFocusedDecoration(context)
          : Neo.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: NeoTheme.posterSize(context, tall: true).width,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildPoster(widget.content.fullPosterUrl),
                DecoratedBox(
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
              padding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: isTV ? 16 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.content.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Neo.titleMedium(context),
                      ),
                      SizedBox(height: 3),
                      Text(
                        widget.content.currentEpisodeId ??
                            (widget.content.isSerie
                                ? 'Série en cours'
                                : 'Film en cours'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Neo.bodySmall(context),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.content.progressPercent != null) ...[
                        _buildProgressBar(widget.content.progressPercent!),
                        SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          Icon(
                            Icons.play_circle_fill_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Reprendre',
                            style: Neo.labelMedium(context).copyWith(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
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
        color: Neo.bgSurface(context),
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(
          color: Neo.bgBorder(context).withValues(alpha: 0.22),
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
          SizedBox(width: 18),
          Expanded(
            child: Padding(
              padding:
                  EdgeInsets.symmetric(vertical: 14, horizontal: 8),
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
                          style: Neo.titleMedium(context)
                              .copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (widget.content.rating > 0) ...[
                        SizedBox(width: 10),
                        _buildRatingBadge(
                          widget.content.rating,
                          compact: false,
                          emphasized: true,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTypeBadge(),
                      if (widget.content.languageTag.isNotEmpty)
                        _buildInfoPill(
                          context,
                          widget.content.languageTag,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      if (widget.content.releaseDate != null)
                        _buildInfoPill(
                          context,
                          '${widget.content.releaseDate}',
                        ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    widget.content.genresText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Neo.bodySmall(context)
                        .copyWith(color: Neo.textSecondary(context)),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _buildFooterPills(context, limit: 2),
                  ),
                  SizedBox(height: 12),
                  if (showDescription &&
                      widget.content.description != null &&
                      widget.content.description!.trim().isNotEmpty)
                    Text(
                      widget.content.description!,
                      maxLines: NeoTheme.isTV(context) ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: Neo.bodySmall(context)
                          .copyWith(color: Neo.textSecondary(context)),
                    ),
                  if (showDescription &&
                      widget.content.description != null &&
                      widget.content.description!.trim().isNotEmpty)
                    SizedBox(height: 8),
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
      return _NoPoster();
    }

    // On ne contraint QUE la largeur du cache : la hauteur s'adapte
    // proportionnellement, ce qui préserve le ratio de l'affiche (sinon
    // forcer les deux dimensions déforme/étire l'image avant le BoxFit).
    final cacheWidth = (NeoTheme.cardWidth(context) * 2).toInt();

    return ClipRRect(
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: cacheWidth,
        alignment: Alignment.center,
        placeholder: (_1, _2) => Shimmer.fromColors(
          baseColor: Neo.bgElevated(context),
          highlightColor: Neo.bgOverlay(context),
          child: Container(color: Neo.bgElevated(context)),
        ),
        errorWidget: (_1, _2, _3) => _NoPoster(),
      ),
    );
  }

  Widget _buildTypeBadge() {
    final Color color;
    if (widget.content.isAnime) {
      color = NeoTheme.purpleAccent;
    } else if (widget.content.isSerie) {
      color = NeoTheme.infoCyan;
    } else {
      color = Theme.of(context).colorScheme.primary;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
        color: Neo.bgOverlay(context),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: Offset(0, 2),
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
    final accent = color ?? Neo.bgBorder(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color != null
            ? accent.withValues(alpha: 0.12)
            : Neo.bgSurface(context).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color != null
              ? accent.withValues(alpha: 0.25)
              : Neo.bgBorder(context).withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: Neo.labelSmall(context).copyWith(
          color: color ?? Neo.textPrimary(context),
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
                  color: Neo.bgBorder(context).withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              // Fill with glow
              Container(
                width: fillWidth,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.45),
                      blurRadius: 6,
                      offset: Offset(0, 1),
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
          color: Neo.textPrimary(context),
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
            color: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    }

    if ((widget.content.todayViews ?? 0) > 0) {
      pills.add(
        _buildInfoPill(
          context,
          '${widget.content.todayViews} vues',
          color: Neo.textPrimary(context),
        ),
      );
    }

    return pills.take(limit).toList();
  }
}

/// Affiche bundlée « Image non disponible » utilisée quand le poster
/// distant est absent ou ne charge pas.
class _NoPoster extends StatelessWidget {
  _NoPoster();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/no_poster.png',
      fit: BoxFit.cover,
      errorBuilder: (_1, _2, _3) => Container(
        color: Neo.bgActive(context),
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: Neo.textDisabled(context)),
        ),
      ),
    );
  }
}
