import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../providers/watch_progress_provider.dart';

import '../../data/services/watch_progress_service.dart';

import '../widgets/disclaimer_dialog.dart';
import '../../utils/logo_generator.dart';
import '../../data/services/platform_service.dart';
import 'dart:io';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoAnimationController;
  late AnimationController _textAnimationController;
  late AnimationController _glowAnimationController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimationSequence();
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _textAnimationController.dispose();
    _glowAnimationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    // Logo animations
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoScaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.elasticOut,
    ));

    _logoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    // Text animations
    _textAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: Curves.easeOut,
    ));

    // Glow animation
    _glowAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimationSequence() async {
    // Démarrer l'animation du logo
    _logoAnimationController.forward();

    // Démarrer l'animation de glow en boucle
    _glowAnimationController.repeat(reverse: true);

    // Attendre un peu puis démarrer l'animation du texte
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      _textAnimationController.forward();
    }

    // Attendre la fin des animations puis naviguer
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      _navigateToMain();
    }
  }

  void _navigateToMain() async {
    // Wait for the widget to be mounted before accessing providers
    await Future.delayed(Duration.zero);

    if (!mounted) return;

    // Initialiser les providers
    final progressProvider = ref.read(watchProgressProvider);

    // Initialiser le provider de progression de lecture
    await progressProvider.initialize();

    // Vérifier d'abord si le disclaimer a été accepté
    final disclaimerAccepted = await DisclaimerDialog.hasBeenAccepted();
    final isAcceptanceValid = await DisclaimerDialog.isAcceptanceValid();

    if (!disclaimerAccepted || !isAcceptanceValid) {
      // Check if still mounted before showing dialog
      if (!mounted) return;

      // Afficher le disclaimer
      final accepted = await DisclaimerDialog.show(context);

      if (accepted != true) {
        // L'utilisateur a refusé, fermer l'application
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showExitConfirmation();
            }
          });
        }
        return;
      }
    }


    // Check if still mounted before final navigation
    if (mounted) {
      final isPlatformSetupCompleted =
          await PlatformService.isPlatformSetupCompleted();

      if (!isPlatformSetupCompleted) {
        // Première utilisation - aller à la sélection de plateforme
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/platform-selection');
        }
      } else {
        // Aller directement à l'écran principal
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/main');
        }
      }
    }
  }

  void _showExitConfirmation() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Fermeture de l\'application',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Vous devez accepter les conditions pour utiliser l\'application.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Use a callback to avoid context issues
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _navigateToMain();
                }
              });
            },
            child: const Text('Réessayer'),
          ),
          ElevatedButton(
            onPressed: () => exit(0),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Glow
          Center(
            child: FadeTransition(
              opacity: _glowAnimation,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentNeon.withOpacity(0.2),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo
                ScaleTransition(
                  scale: _logoScaleAnimation,
                  child: FadeTransition(
                    opacity: _logoFadeAnimation,
                    child: Hero(
                      tag: 'app_logo',
                      child: LogoGenerator.createNeoStreamLogo(
                        size: 150,
                        showDecorations: true,
                        glowIntensity: 1.0,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),

                // App Name with neon effect
                FadeTransition(
                  opacity: _textFadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        'NEO STREAM',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: AppTheme.accentNeon,
                              blurRadius: 10,
                            ),
                            Shadow(
                              color: AppTheme.accentNeon,
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'L\'expérience streaming ultime',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Version Footer
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _textFadeAnimation,
              child: const Center(
                child: Text(
                  'v1.0.0',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),

          // Loading bar at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _textFadeAnimation,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.accentNeon.withOpacity(0.5),
                ),
                minHeight: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
