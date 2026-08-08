import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'config/light_theme.dart';
import 'config/theme.dart';
import 'providers/providers.dart';
import 'providers/theme_provider.dart';
import 'providers/update_provider.dart';
import 'screens/splash_screen.dart';
import 'services/download_service.dart';
import 'services/local_stream_proxy.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // Restaure la file de téléchargements (et relance ceux interrompus).
  // Non bloquant pour le démarrage.
  DownloadService.instance.init();
  // Proxy de streaming local (contournement des blocages DNS/FAI pour le
  // lecteur natif). Démarre en arrière-plan, non bloquant.
  LocalStreamProxy.instance.ensureRunning();

  // Les overflows RenderFlex sont ignorés silencieusement plutôt que de
  // planter l'app en debug — on garde le reste du comportement par défaut.
  FlutterError.onError = (details) {
    if (!details.exception.toString().contains('RenderFlex overflowed')) {
      FlutterError.presentError(details);
    }
  };
  ErrorWidget.builder = (details) {
    if (details.exception.toString().contains('RenderFlex overflowed')) {
      return const SizedBox.shrink();
    }
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
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ContentProvider()),
        ChangeNotifierProvider(create: (_) => UpdateProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Neo-Stream',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: NeoLightTheme.themeData,
            darkTheme: NeoTheme.themeData,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
