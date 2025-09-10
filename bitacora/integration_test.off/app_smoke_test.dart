import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bitacora/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('smoke: la app arranca sin excepciones', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
