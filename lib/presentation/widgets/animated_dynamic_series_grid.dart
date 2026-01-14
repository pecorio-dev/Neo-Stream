import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../data/models/series.dart';
import 'dynamic_series_card.dart';

// Grille animée avec des cartes de séries dynamiques
class AnimatedDynamicSeriesGrid extends StatelessWidget {
  final List<Series> series;
  final Function(Series)? onSeriesTap;
  final Function(Series)? onSeriesLongPress;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsets? padding;
  final Duration animationDuration;
  final Duration delayBetweenItems;
  final DynamicSeriesCardType cardType;

  const AnimatedDynamicSeriesGrid({
    Key? key,
    required this.series,
    this.onSeriesTap,
    this.onSeriesLongPress,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.animationDuration = const Duration(milliseconds: 600),
    this.delayBetweenItems = const Duration(milliseconds: 80),
    this.cardType = DynamicSeriesCardType.standard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = _getDynamicCrossAxisCount(constraints.maxWidth);
          
          return GridView.builder(
            padding: padding ?? const EdgeInsets.all(16),
            physics: physics,
            shrinkWrap: shrinkWrap,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: _getDynamicAspectRatio(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: series.length,
            itemBuilder: (context, index) {
              return AnimationConfiguration.staggeredGrid(
                position: index,
                duration: animationDuration,
                delay: delayBetweenItems,
                columnCount: crossAxisCount,
                child: SlideAnimation(
                  verticalOffset: 30.0,
                  child: FadeInAnimation(
                    child: ScaleAnimation(
                      scale: 0.8,
                      child: DynamicSeriesCard(
                        series: series[index],
                        cardType: cardType,
                        index: index,
                        onTap: () => onSeriesTap?.call(series[index]),
                        onLongPress: () => onSeriesLongPress?.call(series[index]),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  int _getDynamicCrossAxisCount(double width) {
    switch (cardType) {
      case DynamicSeriesCardType.featured:
        return width > 800 ? 2 : 1;
      case DynamicSeriesCardType.standard:
        if (width > 1200) return 4;
        if (width > 800) return 3;
        return 2;
      case DynamicSeriesCardType.compact:
        if (width > 1200) return 5;
        if (width > 800) return 4;
        if (width > 600) return 3;
        return 2;
      case DynamicSeriesCardType.mini:
        if (width > 1200) return 6;
        if (width > 800) return 5;
        if (width > 600) return 4;
        return 3;
    }
  }

  double _getDynamicAspectRatio() {
    switch (cardType) {
      case DynamicSeriesCardType.featured:
        return 0.6;
      case DynamicSeriesCardType.standard:
        return 0.55;
      case DynamicSeriesCardType.compact:
        return 0.5;
      case DynamicSeriesCardType.mini:
        return 0.45;
    }
  }
}

// Grille mosaïque animée pour les séries avec différentes tailles
class AnimatedMosaicSeriesGrid extends StatelessWidget {
  final List<Series> series;
  final Function(Series)? onSeriesTap;
  final Function(Series)? onSeriesLongPress;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;
  final Duration animationDuration;
  final Duration delayBetweenItems;

  const AnimatedMosaicSeriesGrid({
    Key? key,
    required this.series,
    this.onSeriesTap,
    this.onSeriesLongPress,
    this.physics,
    this.padding,
    this.animationDuration = const Duration(milliseconds: 800),
    this.delayBetweenItems = const Duration(milliseconds: 120),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();

    return AnimationLimiter(
      child: SingleChildScrollView(
        physics: physics,
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          children: _buildAnimatedMosaicSections(),
        ),
      ),
    );
  }

  List<Widget> _buildAnimatedMosaicSections() {
    final sections = <Widget>[];
    int index = 0;
    int animationIndex = 0;

    while (index < series.length) {
      // Section avec une carte featured
      if (index < series.length) {
        sections.add(_buildAnimatedFeaturedSection(index, animationIndex));
        index++;
        animationIndex++;
      }

      // Section avec des cartes standard
      if (index < series.length) {
        final standardSeries = series.skip(index).take(4).toList();
        sections.add(_buildAnimatedStandardSection(standardSeries, index, animationIndex));
        index += standardSeries.length;
        animationIndex += standardSeries.length;
      }

      // Section avec des cartes compactes
      if (index < series.length) {
        final compactSeries = series.skip(index).take(6).toList();
        sections.add(_buildAnimatedCompactSection(compactSeries, index, animationIndex));
        index += compactSeries.length;
        animationIndex += compactSeries.length;
      }

      // Espacement entre les sections
      if (index < series.length) {
        sections.add(const SizedBox(height: 24));
      }
    }

    return sections;
  }

  Widget _buildAnimatedFeaturedSection(int seriesIndex, int animationIndex) {
    if (seriesIndex >= series.length) return const SizedBox.shrink();

    return AnimationConfiguration.staggeredList(
      position: animationIndex,
      duration: animationDuration,
      delay: delayBetweenItems,
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: ScaleAnimation(
            scale: 0.9,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Center(
                child: DynamicSeriesCard(
                  series: series[seriesIndex],
                  cardType: DynamicSeriesCardType.featured,
                  index: seriesIndex,
                  onTap: () => onSeriesTap?.call(series[seriesIndex]),
                  onLongPress: () => onSeriesLongPress?.call(series[seriesIndex]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedStandardSection(List<Series> sectionSeries, int startIndex, int animationStartIndex) {
    return AnimationConfiguration.staggeredList(
      position: animationStartIndex,
      duration: animationDuration,
      delay: delayBetweenItems,
      child: SlideAnimation(
        horizontalOffset: 30.0,
        child: FadeInAnimation(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;
                
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.55,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: sectionSeries.length,
                  itemBuilder: (context, index) {
                    final seriesItem = sectionSeries[index];
                    return DynamicSeriesCard(
                      series: seriesItem,
                      cardType: DynamicSeriesCardType.standard,
                      index: startIndex + index,
                      onTap: () => onSeriesTap?.call(seriesItem),
                      onLongPress: () => onSeriesLongPress?.call(seriesItem),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCompactSection(List<Series> sectionSeries, int startIndex, int animationStartIndex) {
    return AnimationConfiguration.staggeredList(
      position: animationStartIndex,
      duration: animationDuration,
      delay: delayBetweenItems,
      child: SlideAnimation(
        horizontalOffset: -30.0,
        child: FadeInAnimation(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount;
                if (constraints.maxWidth > 1200) {
                  crossAxisCount = 4;
                } else if (constraints.maxWidth > 800) {
                  crossAxisCount = 3;
                } else {
                  crossAxisCount = 2;
                }
                
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: sectionSeries.length,
                  itemBuilder: (context, index) {
                    final seriesItem = sectionSeries[index];
                    return DynamicSeriesCard(
                      series: seriesItem,
                      cardType: DynamicSeriesCardType.compact,
                      index: startIndex + index,
                      onTap: () => onSeriesTap?.call(seriesItem),
                      onLongPress: () => onSeriesLongPress?.call(seriesItem),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}