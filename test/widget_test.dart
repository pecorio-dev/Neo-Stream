import 'package:flutter_test/flutter_test.dart';
import 'package:neo_stream/main.dart';

void main() {
  testWidgets('Neo-Stream app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NeoStreamApp());
    // Just verify the app renders without crashing
    expect(find.text('NEO'), findsAny);
  });
}
