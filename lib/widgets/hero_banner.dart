import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/content.dart';
import '../services/api_service.dart';

class HeroBanner extends StatefulWidget {
  final List<Content> items;
  final void Function(Content) onTap;

  const HeroBanner({super.key, required this.items, required this.onTap});

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  PageController? _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;
  bool _isFocused = false; // Added focus state for TV
  final FocusNode _bannerFocusNode = FocusNode();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pageController ??= PageController(
      viewportFraction: _viewportFraction(MediaQuery.of(context).size.width),
    );
    _restartAutoScroll();
  }

  @override
  void didUpdateWidget(covariant HeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentPage >= widget.items.length) {
      _currentPage = 0;
    }
    if (oldWidget.items.length != widget.items.length) {
      _restartAutoScroll();
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController?.dispose();
    _bannerFocusNode.dispose();
    super.dispose();
  }

  double _viewportFraction(double width) {
    if (width >= 1400) return 0.84;
    if (width >= 1100) return 0.86;
    if (width >= 700) return 0.9;
    return 0.94;
  }

  void _restartAutoScroll() {
    _autoScrollTimer?.cancel();
    if (widget.items.length <= 1 || _pageController == null) {
      return;
    }

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      final controller = _pageController;
      if (!mounted || controller == null || !controller.hasClients) {
        return;
      }

      final nextPage = (_currentPage + 1) % widget.items.length;
      controller.animateToPage(
        nextPage,
        duration: NeoTheme.durationHero,
        curve: NeoTheme.premium,
      );
    });
  }

  void _pauseAutoScroll() {
    _autoScrollTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty || _pageController == null) {
      return const SizedBox.shrink();
    }

    final currentIndex = _currentPage.clamp(0, widget.items.length - 1);
    final currentItem = widget.items[currentIndex];
    final padding = NeoTheme.screenPadding(context);
    final heroHeight = NeoTheme.heroHeight(context);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Focus(
      focusNode: _bannerFocusNode,
      onFocusChange: (focused) {
        if (_isFocused == focused) return;
        setState(() => _isFocused = focused);
        if (focused) {
          _pauseAutoScroll();
        } else {
          _restartAutoScroll();
        }
      },
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        
        // Navigation circulaire dans le carousel
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          if (widget.items.length > 1) {
            final nextPage = (_currentPage + 1) % widget.items.length;
            _pageController?.animateToPage(
              nextPage,
              duration: NeoTheme.durationNormal,
              curve: NeoTheme.smoothOut,
            );
            return KeyEventResult.handled;
          }
        }
        
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          if (widget.items.length > 1 && _currentPage > 0) {
            final prevPage = _currentPage - 1;
            _pageController?.animateToPage(
              prevPage,
              duration: NeoTheme.durationNormal,
              curve: NeoTheme.smoothOut,
            );
            return KeyEventResult.handled;
          }
          // Si on est au début, laisser le focus remonter au rail de navigation
          return KeyEventResult.ignored;
        }
        
        if (event.logicalKey == LogicalKeyboardKey.enter || 
            event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.space) {
          widget.onTap(currentItem);
          return KeyEventResult.handled;
        }
        
        return KeyEventResult.ignored;
      },
      child: Semantics(
        label: 'Carousel: ${currentItem.displayTitle}',
        hint: 'Utilisez les flèches gauche et droite pour naviguer',
        child: MouseRegion(
          onEnter: (_) => _pauseAutoScroll(),
          onExit: (_) => _restartAutoScroll(),
        child: GestureDetector(
            onPanDown: (_) => _pauseAutoScroll(),
            onPanCancel: () => _restartAutoScroll(),
            onPanEnd: (_) => _restartAutoScroll(),
            onTap: () => widget.onTap(currentItem),
            child: AnimatedContainer(
              duration: NeoTheme.durationFast,
              curve: NeoTheme.smoothOut,
              decoration: (_isFocused && NeoTheme.isTV(context))
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(NeoTheme.focusBorderRadius(context)),
                      border: Border.all(
                        color: NeoTheme.primaryRed, 
                        width: NeoTheme.focusBorderWidth(context),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: NeoTheme.primaryRed.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                  : null,
              child: SizedBox(
                height: heroHeight + (widget.items.length > 1 ? 30 : 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            padEnds: false,
                            itemCount: widget.items.length,
                            onPageChanged: (index) {
                              if (_currentPage == index) {
                                return;
                              }
                              setState(() => _currentPage = index);
                            },
                            itemBuilder: (context, index) {
                              final item = widget.items[index];
                              final isActive = index == currentIndex;
                              return AnimatedPadding(
                                duration: NeoTheme.durationNormal,
                                curve: NeoTheme.smoothOut,
                                padding: EdgeInsets.only(
                                  left: index == 0 ? padding.left : 8,
                                  right: index == widget.items.length - 1
                                      ? padding.right
                                      : 8,
                                  top: isActive ? 0 : 16,
                                  bottom: isActive ? 0 : 16,
                                ),
                                child: GestureDetector(
                                  onTap: () => widget.onTap(item),
                                  child: AnimatedContainer(
                                    duration: NeoTheme.durationNormal,
                                    curve: NeoTheme.smoothOut,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(NeoTheme.radius2xl),
                                      boxShadow: isActive
                                          ? [
                                              ...NeoTheme.shadowLevel3,
                                              BoxShadow(
                                                color: NeoTheme.primaryRed
                                                    .withValues(alpha: 0.12),
                                                blurRadius: 28,
                                                offset: const Offset(0, 16),
                                              ),
                                            ]
                                          : NeoTheme.shadowLevel2,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        AnimatedBuilder(
                                          animation: _pageController!,
                                          builder: (context, child) {
                                            double value = 1.0;
                                            if (_pageController!
                                                .position
                                                .haveDimensions) {
                                              value =
                                                  _pageController!.page! - index;
                                              value = (1 - (value.abs() * 0.3))
                                                  .clamp(0.0, 1.0);
                                            }
                                            return Transform.scale(
                                              scale:
                                                  1.0 +
                                                  (1 - value) *
                                                      0.1, // Zoom leger sur l'image non centree
                                              child: child,
                                            );
                                          },
                                          child: item.fullPosterUrl.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: item.fullPosterUrl,
                                                  fit: BoxFit.cover,
                                                  placeholder: (_, _) => Container(color: NeoTheme.bgElevated),
                                                  errorWidget: (_, _, _) =>
                                                      Container(
                                                        color: NeoTheme.bgElevated,
                                                        child: const Center(
                                                          child: Icon(Icons.movie_rounded, color: NeoTheme.textDisabled, size: 48),
                                                        ),
                                                      ),
                                                )
                                              : Container(
                                                  color: NeoTheme.bgElevated,
                                                ),
                                        ),
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                NeoTheme.bgBase.withValues(
                                                  alpha: 0.15,
                                                ),
                                                NeoTheme.bgBase.withValues(
                                                  alpha: 0.95,
                                                ),
                                              ],
                                              stops: const [0.0, 0.45, 1.0],
                                            ),
                                          ),
                                        ),
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                              colors: [
                                                NeoTheme.bgBase.withValues(
                                                  alpha: isActive ? 0.85 : 0.75,
                                                ),
                                                NeoTheme.bgBase.withValues(
                                                  alpha: 0.2,
                                                ),
                                                Colors.transparent,
                                              ],
                                              stops: const [0.0, 0.45, 0.88],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          Positioned(
                            left: padding.left + 14,
                            right: padding.right + 14,
                            bottom: 24,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isWide ? 560 : double.infinity,
                                    ),
                                    child: _buildOverlayCard(
                                      context,
                                      currentItem,
                                    ),
                                  ),
                                ),
                                if (isWide) ...[
                                  SizedBox(width: 14 * NeoTheme.scaleFactor(context)),
                                  _buildCounterCard(context),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.items.length > 1)
                      Padding(
                        padding: EdgeInsets.only(top: 12 * NeoTheme.scaleFactor(context)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(widget.items.length, (index) {
                            final isActive = index == currentIndex;
                            return AnimatedContainer(
                              duration: NeoTheme.durationNormal,
                              curve: NeoTheme.cinematic,
                              margin: EdgeInsets.symmetric(horizontal: 3 * NeoTheme.scaleFactor(context)),
                              width: isActive ? 28 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? NeoTheme.primaryRed
                                    : NeoTheme.textDisabled.withValues(
                                        alpha: 0.25,
                                      ),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: NeoTheme.primaryRed.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayCard(BuildContext context, Content item) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Container(
      padding: EdgeInsets.all(14 * NeoTheme.scaleFactor(context)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xE60C0C1C), Color(0xDD08081A)],
        ),
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(
          color: (item.isSerie ? NeoTheme.infoCyan : NeoTheme.primaryRed)
              .withValues(alpha: 0.2),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _heroChip(
                context,
                item.isSerie ? 'Serie' : 'Film',
                color: item.isSerie ? NeoTheme.infoCyan : NeoTheme.primaryRed,
              ),
              const SizedBox(width: 6),
              if (item.rating > 0)
                _metaPill(
                  context,
                  icon: Icons.star_rounded,
                  label: item.rating.toStringAsFixed(1),
                  color: NeoTheme.prestigeGold,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: NeoTheme.titleLarge(
              context,
            ).copyWith(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NeoTheme.primaryRed,
                    foregroundColor: Colors.white,
                    minimumSize: Size(0, 48 * NeoTheme.scaleFactor(context)),
                    padding: EdgeInsets.symmetric(horizontal: 16 * NeoTheme.scaleFactor(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                    ),
                    elevation: 4,
                    shadowColor: NeoTheme.primaryRed.withValues(alpha: 0.5),
                  ),
                  onPressed: () => widget.onTap(item),
                  icon: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 22 * NeoTheme.scaleFactor(context)),
                  label: Text(
                    isWide ? (item.isSerie ? 'Regarder la serie' : 'Regarder le film') : 'Regarder',
                    style: TextStyle(fontSize: 15 * NeoTheme.scaleFactor(context), fontWeight: FontWeight.bold, color: Colors.white),
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(48 * NeoTheme.scaleFactor(context), 48 * NeoTheme.scaleFactor(context)),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                  ),
                  side: BorderSide(color: NeoTheme.bgBorder.withValues(alpha: 0.8), width: 1.5),
                  backgroundColor: NeoTheme.bgBase.withValues(alpha: 0.4),
                ),
                onPressed: () async {
                  final api = ApiService();
                  try {
                    if (item.inLibrary) {
                      await api.removeFromLibrary(item.id);
                    } else {
                      await api.addToLibrary(item.id);
                    }
                    if (!mounted) return;
                    setState(() => item.inLibrary = !item.inLibrary);
                  } catch (_) {}
                },
                child: Icon(
                  item.inLibrary ? Icons.check_rounded : Icons.add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * NeoTheme.scaleFactor(context), vertical: 14 * NeoTheme.scaleFactor(context)),
      decoration: BoxDecoration(
        gradient: NeoTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
        border: Border.all(
          color: NeoTheme.bgBorder.withValues(alpha: 0.2),
          width: 0.5,
        ),
        boxShadow: NeoTheme.shadowLevel2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_currentPage + 1}',
            style: NeoTheme.titleLarge(context).copyWith(
              color: NeoTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '/ ${widget.items.length}',
            style: NeoTheme.bodySmall(
              context,
            ).copyWith(color: NeoTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _heroChip(BuildContext context, String label, {required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * NeoTheme.scaleFactor(context), vertical: 5 * NeoTheme.scaleFactor(context)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: NeoTheme.labelMedium(
          context,
        ).copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _metaPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * NeoTheme.scaleFactor(context), vertical: 5 * NeoTheme.scaleFactor(context)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14 * NeoTheme.scaleFactor(context), color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: NeoTheme.labelMedium(
              context,
            ).copyWith(color: NeoTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}
