import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/tv_config.dart';
import '../../widgets/tv_wrapper.dart';
import '../../widgets/tv_focusable_card.dart';
import '../../widgets/tv_remote_navigator.dart';
import 'profile_selection_tv_screen.dart';
import 'tv_home_screen.dart';

class TVEntryScreen extends StatefulWidget {
  const TVEntryScreen({super.key});

  @override
  State<TVEntryScreen> createState() => _TVEntryScreenState();
}

class _TVEntryScreenState extends State<TVEntryScreen> {
  int _step = 0;
  int _platformIndex = 0;

  static const List<_PlatformOption> _platforms = [
    _PlatformOption(id: 'android_tv', name: 'Android TV', icon: Icons.tv),
    _PlatformOption(id: 'fire_tv', name: 'Fire TV', icon: Icons.local_fire_department),
    _PlatformOption(id: 'apple_tv', name: 'Apple TV', icon: Icons.play_circle),
    _PlatformOption(id: 'tv_box', name: 'Box TV', icon: Icons.devices),
    _PlatformOption(id: 'web_tv', name: 'Web TV', icon: Icons.language),
  ];

  void _selectPlatform(int index) {
    setState(() {
      _platformIndex = index;
      _step = 1;
    });
  }

  void _onProfileSelected() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const TVHomeScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 1) {
      return ProfileSelectionTVScreen(onProfileSelected: _onProfileSelected);
    }

    return Scaffold(
      backgroundColor: TVTheme.backgroundDark,
      body: Container(
        decoration: TVTheme.screenDecoration,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              Text(
                'NEO STREAM',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: TVTheme.accentRed,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'SELECTION DE LA PLATEFORME',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: TVTheme.textSecondary,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 60),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.1,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 20,
                      ),
                      itemCount: _platforms.length,
                      itemBuilder: (context, index) {
                        final platform = _platforms[index];
                        return TVFocusableCard(
                          onTap: () => _selectPlatform(index),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                platform.icon,
                                color: TVTheme.textSecondary,
                                size: 40,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                platform.name,
                                style: const TextStyle(
                                  color: TVTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Utilisez les touches directionnelles et Entree pour selectionner',
                  style: TextStyle(color: TVTheme.textDisabled, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformOption {
  final String id;
  final String name;
  final IconData icon;

  const _PlatformOption({
    required this.id,
    required this.name,
    required this.icon,
  });
}