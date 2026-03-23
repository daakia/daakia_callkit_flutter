import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('renders sdk example shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MyApp(firebaseState: FirebaseInitResult.notInitialized()),
    );

    expect(find.text('Daakia SDK Example'), findsOneWidget);
    expect(find.text('Setup Status'), findsOneWidget);
    expect(find.text('Base URL'), findsOneWidget);
  });
}
