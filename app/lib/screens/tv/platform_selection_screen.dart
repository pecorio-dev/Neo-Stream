import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/tv_config.dart';
import '../../widgets/tv_focusable_card.dart';
import '../../widgets/tv_remote_navigator.dart';
import '../../utils/tv_detector.dart';
import 'profile_selection_tv_screen.dart';

class PlatformSelectionScreen extends StatefulWidget {
  final VoidCallback onPlatformSelected;
  final void Function(bool isTVMode) onModeDetermined;

  const PlatformSelectionScreen({
    super.key,
    required this.onPlatformSelected,
    required this.onModeDetermined,
  });

  @override
  State<PlatformSelectionScreen> createState() => _PlatformSelectionScreenState();
}

class _PlatformSelectionScreenState extends State<PlatformSelectionScreen> {
  int _focusedIndex = 0;
  final FocusNode _screenFocusNode = FocusNode();

  static const List<_PlatformOption> _options = [
    _PlatformOption(
      id: 'android_tv',
      name: 'Android TV',
      icon: Icons.tv,
      description: 'Téléviseurs Android TV',
    ),
    _PlatformOption(
      id: 'fire_tv',
      name: 'Fire TV',
      icon: Icons.fireplace,
      description: 'Amazon Fire TV Stick / Cube',
    ),
    _PlatformOption(
      id: 'apple_tv',
      name: 'Apple TV',
      icon: Icons.play_circle,
      description: 'Apple TV HD / 4K',
    ),
    _PlatformOption(
      id: 'tv_box',
      name: 'Box TV',
      icon: Icons.device_unknown,
      description: 'Mi Box, Shield, Chromecast',
    ),
    _PlatformOption(
      id: 'web_tv',
      name: 'Web TV',
      icon: Icons.web,
      description: 'Navigateur web sur TV',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _screenFocusNode.requestFocus();
      _autoDetectPlatform();
    });
  }

  @override
  void dispose() {
    _screenFocusNode.dispose();
    super.dispose();
  }

  void _autoDetectPlatform() {
    String detectedId = 'android_tv';

    if (TVDetector.isTVMode) {
      if (Platform.isAndroid) {
        final brand = Platform.environment['BRAND'] ?? '';
        if (brand.toLowerCase().contains('amazon') ||
            brand.toLowerCase().contains('fire')) {
          detectedId = 'fire_tv';
        } else {
          detectedId = 'android_tv';
        }
      } else if (Platform.isMacOS) {
        detectedId = 'apple_tv';
      }
    }

    final index = _options.indexWhere((o) => o.id == detectedId);
    if (index != -1) {
      setState(() => _focusedIndex = index);
    }
  }

  void _handleDpad(TVDirection direction) {
    setState(() {
      switch (direction) {
        case TVDirection.up:
          if (_focusedIndex >= 3) {
            _focusedIndex -= 3;
          } else if (_focusedIndex > 0) {
            _focusedIndex = 0;
          }
          break;
        case TVDirection.down:
          if (_focusedIndex < 2) {
            _focusedIndex += 3;
          } else if (_focusedIndex < 4) {
            _focusedIndex = 4;
          }
          break;
        case TVDirection.left:
          if (_focusedIndex % 3 != 0) {
            _focusedIndex--;
          }
          break;
        case TVDirection.right:
          if (_focusedIndex % 3 != 2 && _focusedIndex < 4) {
            _focusedIndex++;
          }
          break;
        default:
          break;
      }
    });
  }

  void _handleSelect() {
    final option = _options[_focusedIndex];
    _savePlatformPreference(option.id);
    widget.onModeDetermined(true);
    widget.onPlatformSelected();
  }

  Future<void> _savePlatformPreference(String platformId) async {
  }

  @override
  Widget build(BuildContext context) {
    return TVRemoteNavigator(
      onDpad: _handleDpad,
      onSelect: _handleSelect,
      onBack: () => Navigator.of(context).maybePop(),
      child: Scaffold(
        backgroundColor: TVTheme.backgroundDark,
        body: Container(
          decoration: TVTheme.screenDecoration,
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                Text(
                  'SÉLECTION DE LA PLATEFORME',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: TVTheme.textPrimary,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choisissez votre type d\'appareil',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: TVTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 60),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.2,
                          mainAxisSpacing: 24,
                          crossAxisSpacing: 24,
                        ),
                        itemCount: _options.length,
                        itemBuilder: (context, index) {
                          final option = _options[index];
                          final isFocused = _focusedIndex == index;

                          return TVFocusableCard(
                            autoFocus: false,
                            onFocus: () => setState(() => _focusedIndex = index),
                            onTap: () {
                              setState(() => _focusedIndex = index);
                              _handleSelect();
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: isFocused
                                        ? TVTheme.accentRed.withValues(alpha: 0.2)
                                        : TVTheme.cardColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    option.icon,
                                    color: isFocused
                                        ? TVTheme.accentRed
                                        : TVTheme.textSecondary,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  option.name,
                                  style: TextStyle(
                                    color: isFocused
                                        ? TVTheme.accentRed
                                        : TVTheme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  option.description,
                                  style: const TextStyle(
                                    color: TVTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Utilisez les touches directionnelles pour naviguer',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: TVTheme.textDisabled,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
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
  final String description;

  const _PlatformOption({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
  });
}
