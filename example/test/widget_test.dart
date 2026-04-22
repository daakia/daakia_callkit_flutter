import 'package:callkit/main.dart';
import 'package:callkit/secret/secret_credential.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  testWidgets('renders sdk example shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(firebaseState: const FirebaseInitResult.notInitialized(), initialSdkConfig: ExampleSdkBootstrapConfig(baseUrl: SecretCredential.baseUrl, secret: SecretCredential.secretKey),),
    );

    expect(find.text('Daakia SDK Example'), findsOneWidget);
    expect(find.text('Setup Status'), findsOneWidget);
    expect(find.text('Base URL'), findsOneWidget);
  });
}
