import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_kenya_ekyc/main.dart'; // Imports your new Engine

void main() {
  testWidgets('Engine App loads successfully', (WidgetTester tester) async {
    // Build  engine app and trigger a frame.
    await tester.pumpWidget(const KenyaIdentityEngineApp());

    // Verify that the Engine App widget is mounted on the screen
    expect(find.byType(KenyaIdentityEngineApp), findsOneWidget);
  });
}