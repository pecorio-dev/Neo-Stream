// Tests de démarrage de base de l'application Neo-Stream.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:neo_stream/main.dart';
import 'package:neo_stream/screens/downloads_screen.dart';

void main() {
  test('NeoStreamApp peut être instanciée', () {
    const app = NeoStreamApp();
    expect(app, isA<Widget>());
  });

  testWidgets('DownloadsScreen affiche son état vide sans crash',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: DownloadsScreen()));
    await tester.pump();
    expect(find.text('Téléchargements'), findsWidgets);
    expect(find.text('Aucun téléchargement'), findsOneWidget);
  });
}
