import 'package:flutter/material.dart';

import '../config/theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onSeeAll;
  final EdgeInsets? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onSeeAll,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding ?? NeoTheme.screenPadding(context);
    final scale = NeoTheme.scaleFactor(context);
    final iconContainerSize = (40 * scale).roundToDouble();
    final iconSz = (18 * scale).roundToDouble();

    return Padding(
      padding: resolvedPadding,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: iconContainerSize,
                  height: iconContainerSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        (icon != null ? NeoTheme.primaryRed : NeoTheme.infoCyan)
                            .withValues(alpha: 0.2),
                        (icon != null ? NeoTheme.primaryRed : NeoTheme.infoCyan)
                            .withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(NeoTheme.radiusMd),
                    border: Border.all(
                      color: (icon != null ? NeoTheme.primaryRed : NeoTheme.infoCyan)
                          .withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Icon(
                    icon ?? Icons.auto_awesome_rounded,
                    size: iconSz,
                    color: icon != null
                        ? NeoTheme.primaryRed
                        : NeoTheme.infoCyan,
                  ),
                ),
                SizedBox(width: NeoTheme.isTV(context) ? 18 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: NeoTheme.titleLarge(context).copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: NeoTheme.bodySmall(context).copyWith(
                              color: NeoTheme.textDisabled,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: NeoTheme.textTertiary,
                padding: EdgeInsets.symmetric(
                  horizontal: 14 * scale,
                  vertical: 10 * scale,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color: NeoTheme.bgBorder.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                backgroundColor: NeoTheme.bgElevated.withValues(alpha: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Voir tout',
                    style: NeoTheme.labelMedium(context).copyWith(
                      color: NeoTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14 * scale,
                    color: NeoTheme.textTertiary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
