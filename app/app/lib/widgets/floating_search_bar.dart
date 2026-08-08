import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

import '../config/neo.dart';
import '../config/theme.dart';
import 'poster_image.dart';
import 'satisfying_animations.dart';

/// Barre de recherche flottante façon « glassmorphism ».
///
/// - Capsule de verre dépoli suspendue au-dessus du contenu.
/// - À la prise de focus : bordure colorée + halo lumineux animés, l'icône
///   « poppe » dans une pastille dégradée.
/// - À droite : indicateur de chargement ou bouton d'effacement animé en
///   rotation (avec retour haptique).
class FloatingSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final String hintText;
  final bool loading;

  const FloatingSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.hintText = 'Titre, genre, acteur...',
    this.loading = false,
  });

  /// Hauteur de la capsule (utile pour positionner un panneau en dessous).
  static const double barHeight = 56;

  @override
  State<FloatingSearchBar> createState() => _FloatingSearchBarState();
}

class _FloatingSearchBarState extends State<FloatingSearchBar> {
  bool _hasFocus = false;
  bool _hasText = false;
  double _clearSpin = 0;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.isNotEmpty;
    _hasFocus = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_sync);
    widget.controller.addListener(_sync);
  }

  void _sync() {
    if (!mounted) return;
    final focus = widget.focusNode.hasFocus;
    final text = widget.controller.text.isNotEmpty;
    if (focus != _hasFocus || text != _hasText) {
      setState(() {
        _hasFocus = focus;
        _hasText = text;
      });
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_sync);
    widget.controller.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: FloatingSearchBar.barHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isLight
                  ? [
                      Colors.white.withValues(alpha: 0.88),
                      Colors.white.withValues(alpha: 0.72),
                    ]
                  : [
                      Neo.bgSurface(context).withValues(alpha: 0.82),
                      Neo.bgBase(context).withValues(alpha: 0.86),
                    ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _hasFocus
                  ? primary.withValues(alpha: 0.75)
                  : (isLight
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.10)),
              width: _hasFocus ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              if (_hasFocus)
                BoxShadow(
                  color: primary.withValues(alpha: 0.28),
                  blurRadius: 26,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              // Pastille loupe animée.
              AnimatedScale(
                scale: _hasFocus ? 1.06 : 1.0,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: _hasFocus ? Neo.heroGradient(context) : null,
                    color: _hasFocus
                        ? null
                        : Neo.bgBorder(context).withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    boxShadow: _hasFocus
                        ? [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: _hasFocus
                        ? Neo.onHeroGradient(context)
                        : Neo.textTertiary(context),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  textInputAction: TextInputAction.search,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: Neo.bodyLarge(context).copyWith(
                    color: Neo.textPrimary(context),
                    fontSize: 15.5,
                  ),
                  cursorColor: primary,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: Neo.bodyMedium(context).copyWith(
                      color: Neo.textDisabled(context),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              // Zone d'action : chargement / effacement.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: widget.loading
                    ? Padding(
                        key: const ValueKey('loading'),
                        padding: const EdgeInsets.only(right: 16, left: 4),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(primary),
                          ),
                        ),
                      )
                    : _hasText
                        ? Padding(
                            key: const ValueKey('clear'),
                            padding: const EdgeInsets.only(right: 8, left: 4),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(() => _clearSpin += 1);
                                  widget.onClear?.call();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: AnimatedRotation(
                                    turns: _clearSpin,
                                    duration: const Duration(milliseconds: 380),
                                    curve: Curves.easeOutBack,
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 19,
                                      color: Neo.textTertiary(context),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox(key: ValueKey('empty'), width: 14),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 380.ms, delay: 100.ms, curve: Curves.easeOutCubic)
        .slideY(
          begin: -0.35,
          end: 0,
          duration: 480.ms,
          delay: 80.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Prévisualisation des résultats de recherche
// ─────────────────────────────────────────────────────────────────────────────

/// Données aplaties d'une ligne de prévisualisation (film, série ou anime).
class SearchPreviewItem {
  final int id;
  final String title;
  final String? posterUrl;
  final String typeLabel;
  final String? year;
  final double rating;
  final List<String> genres;
  final bool isAnime;

  /// Objet source (Content ou Anime) transmis au callback de navigation.
  final dynamic source;

  const SearchPreviewItem({
    required this.id,
    required this.title,
    required this.typeLabel,
    this.posterUrl,
    this.year,
    this.rating = 0,
    this.genres = const [],
    this.isAnime = false,
    this.source,
  });
}

/// Panneau flottant de prévisualisation des résultats, affiché sous la
/// [FloatingSearchBar] pendant la saisie.
///
/// Chaque ligne montre le poster, le titre, un badge de type coloré, les
/// genres/année et la note. Les lignes entrent en cascade ([staggeredFade]).
/// Un pied de panneau permet de déplier tous les résultats en grille.
class SearchPreviewPanel extends StatelessWidget {
  final String query;
  final List<SearchPreviewItem> items;
  final int totalCount;
  final bool loading;
  final ValueChanged<SearchPreviewItem> onTapItem;
  final VoidCallback? onViewAll;

  const SearchPreviewPanel({
    super.key,
    required this.query,
    required this.items,
    required this.totalCount,
    required this.loading,
    required this.onTapItem,
    this.onViewAll,
  });

  Color _typeColor(String typeLabel) {
    switch (typeLabel.toLowerCase()) {
      case 'film':
        return NeoTheme.infoCyan;
      case 'série':
      case 'serie':
        return NeoTheme.purpleAccent;
      case 'anime':
        return NeoTheme.warningOrange;
      default:
        return NeoTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final maxHeight = MediaQuery.of(context).size.height * 0.55;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Neo.radiusXl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isLight
                  ? [
                      Colors.white.withValues(alpha: 0.94),
                      Colors.white.withValues(alpha: 0.85),
                    ]
                  : [
                      Neo.bgElevated(context).withValues(alpha: 0.94),
                      Neo.bgSurface(context).withValues(alpha: 0.97),
                    ],
            ),
            borderRadius: BorderRadius.circular(Neo.radiusXl),
            border: Border.all(
              color: primary.withValues(alpha: isLight ? 0.25 : 0.30),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.12 : 0.5),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: primary.withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: loading
              ? _buildSkeleton(context)
              : items.isEmpty
                  ? _buildEmpty(context)
                  : _buildResults(context, primary, isLight),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 240.ms, curve: Curves.easeOutCubic)
        .slideY(begin: -0.05, end: 0, duration: 300.ms, curve: Curves.easeOutCubic)
        .scale(
          begin: const Offset(0.97, 0.97),
          end: const Offset(1, 1),
          duration: 300.ms,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
        );
  }

  Widget _buildHeader(BuildContext context, Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 15, color: primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Résultats pour « $query »',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Neo.labelMedium(context).copyWith(
                color: Neo.textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Container(
              key: ValueKey(totalCount),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: primary.withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Text(
                '$totalCount',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, Color primary, bool isLight) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context, primary),
        Divider(
          height: 1,
          thickness: 0.6,
          color: Neo.bgBorder(context).withValues(alpha: 0.25),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 6),
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 0.5,
              indent: 84,
              color: Neo.bgBorder(context).withValues(alpha: 0.18),
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildRow(context, item, primary)
                  .staggeredFade(index: index);
            },
          ),
        ),
        if (onViewAll != null) ...[
          Divider(
            height: 1,
            thickness: 0.6,
            color: Neo.bgBorder(context).withValues(alpha: 0.25),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onViewAll!();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Voir les $totalCount résultats',
                      style: Neo.labelLarge(context).copyWith(
                        color: primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRow(BuildContext context, SearchPreviewItem item, Color primary) {
    final typeColor = _typeColor(item.typeLabel);
    final subtitleParts = <String>[
      if (item.year != null && item.year!.isNotEmpty) item.year!,
      ...item.genres.take(2),
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTapItem(item);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              // Poster
              Hero(
                tag: 'preview_poster_${item.typeLabel}_${item.id}',
                child: PosterImage(
                  imageUrl: item.posterUrl ?? '',
                  width: 46,
                  height: 66,
                  borderRadius: 9,
                  memCacheWidth: 120,
                ),
              ),
              const SizedBox(width: 12),
              // Titre + métadonnées
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Neo.titleMedium(context).copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: typeColor.withValues(alpha: 0.4),
                              width: 0.7,
                            ),
                          ),
                          child: Text(
                            item.typeLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: typeColor,
                            ),
                          ),
                        ),
                        if (subtitleParts.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              subtitleParts.join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Neo.bodySmall(context).copyWith(
                                color: Neo.textTertiary(context),
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Note + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.rating > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: NeoTheme.prestigeGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: NeoTheme.prestigeGold,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            item.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: NeoTheme.prestigeGold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: Neo.textDisabled(context),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Shimmer.fromColors(
                baseColor: Neo.bgElevated(context),
                highlightColor: Neo.bgBorder(context).withValues(alpha: 0.30),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 66,
                      decoration: BoxDecoration(
                        color: Neo.bgElevated(context),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 13,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Neo.bgElevated(context),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 10,
                            width: 120,
                            decoration: BoxDecoration(
                              color: Neo.bgElevated(context),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 34,
            color: Neo.textDisabled(context),
          ),
          const SizedBox(height: 10),
          Text(
            'Aucun résultat pour « $query »',
            style: Neo.titleMedium(context).copyWith(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Essayez un autre titre ou autre orthographe.',
            style: Neo.bodySmall(context)
                .copyWith(color: Neo.textTertiary(context)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
