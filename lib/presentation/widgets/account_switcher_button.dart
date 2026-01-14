import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/platform_service.dart';
import 'tv_focusable_card.dart';

class AccountSwitcherButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isCompact;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? textColor;

  const AccountSwitcherButton({
    Key? key,
    this.onPressed,
    this.isCompact = false,
    this.backgroundColor,
    this.iconColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppTheme.surface.withOpacity(0.8);
    final iColor = iconColor ?? AppTheme.accentNeon;
    final tColor = textColor ?? AppTheme.textPrimary;

    Widget button = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
        border: Border.all(
          color: AppTheme.accentNeon.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_circle,
            size: isCompact ? 16 : 20,
            color: iColor,
          ),
          if (!isCompact) ...[
            const SizedBox(width: 6),
            Text(
              'Changer',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: tColor,
              ),
            ),
          ],
        ],
      ),
    );

    // Wrapper TV focalisable si en mode TV
    if (PlatformService.isTVMode) {
      button = TVFocusableCard(
        onPressed: onPressed ?? () => _showAccountSwitcher(context),
        borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
        child: button,
      );
    } else {
      button = GestureDetector(
        onTap: onPressed ?? () => _showAccountSwitcher(context),
        child: button,
      );
    }

    return button;
  }

  void _showAccountSwitcher(BuildContext context) {
    Navigator.pushNamed(context, '/profile-selection');
  }
}

class AccountSwitcherFAB extends StatelessWidget {
  final VoidCallback? onPressed;

  const AccountSwitcherFAB({
    Key? key,
    this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget fab = FloatingActionButton(
      mini: true,
      backgroundColor: AppTheme.accentNeon,
      foregroundColor: AppTheme.backgroundPrimary,
      onPressed: onPressed ?? () => _showAccountSwitcher(context),
      child: const Icon(Icons.account_circle),
    );

    // Wrapper TV focalisable si en mode TV
    if (PlatformService.isTVMode) {
      fab = TVFocusableCard(
        onPressed: onPressed ?? () => _showAccountSwitcher(context),
        borderRadius: BorderRadius.circular(28),
        child: fab,
      );
    }

    return fab;
  }

  void _showAccountSwitcher(BuildContext context) {
    Navigator.pushNamed(context, '/profile-selection');
  }
}