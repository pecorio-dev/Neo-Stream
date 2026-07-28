import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/neo.dart';
import '../config/tv_config.dart';
import '../providers/providers.dart';
import '../providers/update_provider.dart';
import '../utils/tv_detector.dart';
import '../widgets/update_dialog.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'profile_selection_screen.dart';
import 'tv/tv_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _lineController;
  late AnimationController _textController;
  late AnimationController _pulseController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _lineWidth;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 900),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: NeoTheme.cinematic),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: NeoTheme.smoothOut),
    );

    _lineController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 700),
    );
    _lineWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _lineController, curve: NeoTheme.cinematic),
    );

    _textController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: NeoTheme.smoothOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    _logoController.forward();
    await Future.delayed(Duration(milliseconds: 600));

    _lineController.forward();
    await Future.delayed(Duration(milliseconds: 500));

    _textController.forward();

    await Future.delayed(Duration(milliseconds: 400));
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.tryAutoLogin();

    if (!mounted) return;

    await Future.delayed(Duration(milliseconds: 500));
    if (!mounted) return;

    await NeoTheme.loadForceTVMode();
    await TVDetector.init();
    if (!mounted) return;
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isPC = TVConfig.shouldUsePCMode(context);
    var isTV = !isPC && (TVDetector.isTVMode || TVConfig.shouldUseTVMode(context));
    // Fallback robuste pour les TV 16:9 standard (Freebox mini 4K, etc.) :
    // la détection par ratio (>1.7) ou par MethodChannel peut échouer selon
    // le firmware ; on force le mode TV pour tout écran Android ≥ 1920×1080.
    if (!isTV && !kIsWeb && Platform.isAndroid && width >= 1920 && height >= 1080) {
      isTV = true;
    }

    Widget destination;
    if (!success && authProvider.hasStoredSession) {
      destination = isTV ? const TVShell() : HomeScreen();
    } else if (!success) {
      destination = LoginScreen();
    } else {
      final user = authProvider.user;
      if (user == null) {
        destination = LoginScreen();
      } else if (!user.isSubAccount) {
        destination = ProfileSelectionScreen(mainUser: user);
      } else if (isTV) {
        destination = TVShell();
      } else {
        destination = HomeScreen();
      }
    }

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_1, _2, _3) => destination,
        transitionDuration: NeoTheme.durationSplash,
        transitionsBuilder: (_1, animation, _2, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (route) => false,
    );

    // Vérification de mise à jour en arrière-plan (silencieuse).
    // Affiche le popup seulement si une mise à jour est disponible.
    if (success) {
      _checkForUpdates(isTV: isTV);
    }
  }

  Future<void> _checkForUpdates({required bool isTV}) async {
    final update = context.read<UpdateProvider>();
    await update.checkAuto();
    if (!mounted) return;

    if (update.hasUpdate &&
        update.lastResult?.release != null &&
        !update.lastResult!.release!.isPrerelease) {
      // Afficher le popup après un court délai (laisser l'écran se poser).
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      showUpdateDialog(context, isTV: isTV);
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _lineController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Neo.bgBase(context),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [Color(0xFF12122A), Color(0xFF08081A), Color(0xFF06060C)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) => Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          height: 80 * NeoTheme.scaleFactor(context),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                        SizedBox(height: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              'NEO',
                              style: Neo.displayLarge(context).copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 44 * NeoTheme.scaleFactor(context),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'STREAM',
                              style: Neo.displayLarge(context).copyWith(
                                color: Neo.textPrimary(context).withValues(alpha: 0.9),
                                fontSize: 44 * NeoTheme.scaleFactor(context),
                                fontWeight: FontWeight.w200,
                                letterSpacing: 8,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'CINEMA · REIMAGINED',
                          style: Neo.labelSmall(context).copyWith(
                            color: Neo.textTertiary(context).withValues(alpha: 0.6),
                            letterSpacing: 6,
                            fontSize: 9 * NeoTheme.scaleFactor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 20),

              AnimatedBuilder(
                animation: _lineController,
                builder: (context, child) => Container(
                  height: 2,
                  width: 220 * _lineWidth.value,
                  decoration: BoxDecoration(
                    gradient: NeoTheme.heroGradient,
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 40),

              AnimatedBuilder(
                animation: Listenable.merge([_textController, _pulseController]),
                builder: (context, child) => Opacity(
                  opacity: _textOpacity.value,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Theme.of(context).colorScheme.primary.withValues(
                            alpha: 0.4 + (_pulseController.value * 0.4),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Chargement',
                        style: Neo.bodySmall(context).copyWith(
                          color: Neo.textDisabled(context),
                          letterSpacing: 3,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
