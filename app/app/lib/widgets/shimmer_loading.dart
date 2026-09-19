import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../config/theme.dart';
import '../config/neo.dart';
import '../config/tv_config.dart';

/// Grille skeleton élégante pour les écrans de recherche (phone + TV).
///
/// Remplace le spinner brut pendant le chargement initial : cartes
/// factices 2/3 avec titre + pills, dimensionnement stable identique à la
/// vraie grille pour éviter tout saut de layout.
class ShimmerSearchGrid extends StatelessWidget {
  final int crossAxisCount;
  final bool isTV;
  final int itemCount;
  final EdgeInsetsGeometry padding;
  final double childAspectRatio;

  const ShimmerSearchGrid({
    super.key,
    this.crossAxisCount = 2,
    this.isTV = false,
    this.itemCount = 12,
    this.padding = EdgeInsets.zero,
    this.childAspectRatio = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    final base = isTV ? TVTheme.cardColor : Neo.bgElevated(context);
    final highlight =
        isTV ? const Color(0xFF2A2A35) : Neo.bgBorder(context).withValues(alpha: 0.3);
    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        period: const Duration(milliseconds: 1400),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
          ),
          itemCount: itemCount,
          itemBuilder: (_, __) => RepaintBoundary(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: base,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: base,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ShimmerHomeLoading extends StatelessWidget {
  ShimmerHomeLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final heroHeight = NeoTheme.heroHeight(context);
    final horizontalPadding = NeoTheme.screenPadding(context).horizontal / 2;
    final scale = NeoTheme.scaleFactor(context);
    final iconBoxSize = (40 * scale).roundToDouble();

    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: Neo.bgElevated(context),
        highlightColor: Neo.bgActive(context),
        period: Duration(milliseconds: 1500), // Optimisé pour 60fps
        child: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RepaintBoundary(
              child: Container(
                height: heroHeight,
                margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
                decoration: BoxDecoration(
                  color: Neo.bgElevated(context),
                  borderRadius: BorderRadius.circular(NeoTheme.radius2xl),
                ),
              ),
            ),
            SizedBox(height: 28),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                children: List.generate(
                  3,
                  (i) => Expanded(
                    child: Container(
                      height: (80 * scale).roundToDouble(),
                      margin: EdgeInsets.only(right: i < 2 ? 12 : 0),
                      decoration: BoxDecoration(
                        color: Neo.bgElevated(context),
                        borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
            for (var section = 0; section < 4; section++) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Row(
                  children: [
                    Container(
                      width: iconBoxSize,
                      height: iconBoxSize,
                      decoration: BoxDecoration(
                        color: Neo.bgElevated(context),
                        borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                      ),
                    ),
                    SizedBox(width: NeoTheme.isTV(context) ? 18 : 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: (160 * scale).roundToDouble(),
                            height: (16 * scale).roundToDouble(),
                            decoration: BoxDecoration(
                              color: Neo.bgElevated(context),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          SizedBox(height: 6),
                          Container(
                            width: (100 * scale).roundToDouble(),
                            height: (10 * scale).roundToDouble(),
                            decoration: BoxDecoration(
                              color: Neo.bgElevated(context),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              RepaintBoundary(
                child: SizedBox(
                  height: NeoTheme.cardHeight(context),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      return RepaintBoundary(
                        child: Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Container(
                            width: NeoTheme.cardWidth(context),
                            decoration: BoxDecoration(
                              color: Neo.bgElevated(context),
                              borderRadius: BorderRadius.circular(NeoTheme.radiusLg),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: NeoTheme.sectionGap(context)),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
