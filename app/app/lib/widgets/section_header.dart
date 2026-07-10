import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../config/neo.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onSeeAll;
  final EdgeInsets? padding;

  SectionHeader({
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
    final isTV = NeoTheme.isTV(context);

    return Padding(
      padding: resolvedPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 3,
                  height: isTV ? 26 : 20,
                  decoration: BoxDecoration(
                    gradient: NeoTheme.heroGradient,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: NeoTheme.primaryRed.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isTV ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Neo.titleLarge(context).copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.1,
                        ),
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Text(
                            subtitle!,
                            style: Neo.bodySmall(context).copyWith(
                              color: Neo.textDisabled(context),
                              height: 1.3,
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
          if (onSeeAll != null) ...[
            SizedBox(width: 12),
            Focus(
              canRequestFocus: isTV,
              onKeyEvent: isTV ? (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.enter ||
                     event.logicalKey == LogicalKeyboardKey.select)) {
                  onSeeAll!();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              } : null,
              child: Builder(
                builder: (ctx) {
                  final focused = isTV && Focus.of(ctx).hasFocus;
                  return GestureDetector(
                    onTap: onSeeAll,
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 150),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12 * scale,
                        vertical: 7 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: focused
                            ? NeoTheme.primaryRed.withValues(alpha: 0.15)
                            : Neo.bgElevated(context).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: focused
                              ? NeoTheme.primaryRed
                              : Neo.bgBorder(context).withValues(alpha: 0.18),
                          width: focused ? 2 : 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Tout voir',
                            style: Neo.labelSmall(context).copyWith(
                              color: focused ? NeoTheme.primaryRed : Neo.textTertiary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14 * scale,
                            color: focused ? NeoTheme.primaryRed : Neo.textDisabled(context),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
