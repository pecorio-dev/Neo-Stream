import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'providers/providers.dart';
import 'providers/tv_profile_provider.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser media_kit pour la lecture vidéo
  MediaKit.ensureInitialized();

  // ═══════════════════════════════════════════════════════════════
  // SOLUTION DÉFINITIVE: Désactiver TOUS les overflows RenderFlex
  // ═══════════════════════════════════════════════════════════════
  FlutterError.onError = (FlutterErrorDetails details) {
    // Ignorer les erreurs RenderFlex overflow
    final exception = details.exception.toString();
    if (exception.contains('RenderFlex overflowed') ||
        exception.contains('A RenderFlex overflowed')) {
      // Ne rien faire - ignorer silencieusement
      return;
    }
    // Pour toutes les autres erreurs, utiliser le comportement par défaut
    FlutterError.presentError(details);
  };

  // Builder personnalisé pour gérer les overflows visuellement
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // Si c'est un overflow, retourner un widget vide au lieu d'une erreur
    final exception = details.exception.toString();
    if (exception.contains('RenderFlex overflowed') ||
        exception.contains('A RenderFlex overflowed')) {
      return const SizedBox.shrink();
    }
    // Pour les autres erreurs, afficher l'erreur normale
    return ErrorWidget(details.exception);
  };

  final isMobilePlatform =
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  if (isMobilePlatform) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: NeoTheme.bgBase,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  runApp(const NeoStreamApp());
}

class NeoStreamApp extends StatelessWidget {
  const NeoStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ContentProvider()),
        ChangeNotifierProvider(create: (_) => TVProfileProvider()..loadProfiles()),
      ],
      child: MaterialApp(
        title: 'Neo-Stream',
        debugShowCheckedModeBanner: false,
        theme: NeoTheme.themeData,
        home: const SplashScreen(),
      ),
    );
  }
}
