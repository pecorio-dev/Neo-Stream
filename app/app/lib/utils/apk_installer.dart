import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Lance l'installation de l'APK via un Intent système (Android).
///
/// Sur les autres plateformes, ne fait rien et retourne `false`.
Future<bool> installApk(String filePath) async {
  if (kIsWeb || !Platform.isAndroid) return false;

  try {
    await const MethodChannel('eu.neostream.neo_stream/update')
        .invokeMethod('installApk', {'filePath': filePath});
    return true;
  } on PlatformException catch (e) {
    throw Exception('Installation échouée : ${e.message}');
  }
}
