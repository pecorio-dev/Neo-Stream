import 'package:flutter/material.dart';
import '../screens/settings/settings_screen.dart';
import '../../core/theme/app_theme.dart';

class SettingsButton extends StatelessWidget {
  final Color? color;
  final double? size;

  const SettingsButton({
    Key? key,
    this.color,
    this.size,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.settings,
        color: color ?? AppTheme.textPrimary,
        size: size ?? 24,
      ),
      onPressed: () => _navigateToSettings(context),
      tooltip: 'Paramètres',
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }
}

class FloatingSettingsButton extends StatelessWidget {
  const FloatingSettingsButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _navigateToSettings(context),
      backgroundColor: AppTheme.accentNeon,
      child: const Icon(
        Icons.settings,
        color: AppTheme.backgroundPrimary,
      ),
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }
}