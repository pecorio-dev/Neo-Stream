import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'core/initialization/app_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.backgroundPrimary,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  try {
    await initializeAppWithSync().timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint('⚠️ App initialization error: $e');
  }

  runApp(
    const ProviderScope(
      child: NeoStreamApp(),
    ),
  );
}

class NeoStreamApp extends ConsumerWidget {
  const NeoStreamApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'NeoStream',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      onGenerateRoute: AppRouter.generateRoute,
      builder: (context, child) {
        ErrorWidget.builder = (details) => Scaffold(
          body: Center(
            child: Text('Une erreur est survenue: ${details.exception}'),
          ),
        );
        return child!;
      },
    );
  }
}
