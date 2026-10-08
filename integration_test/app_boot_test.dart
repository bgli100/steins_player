import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:steins_player/main.dart' as app;

/// Boot smoke test for a real device or simulator (`flutter test
/// integration_test/app_boot_test.dart -d device-id`).
///
/// It covers what the unit tests cannot: `MediaKit.ensureInitialized()`,
/// creating a `VideoController` (a platform texture), playing a bundled asset
/// through libmpv, and receiving its completion event. The splash screen only
/// hands over to the home page once the introduction clip has played to its
/// end, so reaching the home page proves all of that worked.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plays the introduction and reaches the home page', (
    tester,
  ) async {
    app.main();

    var reached = false;
    // The clip is about nine seconds long; the window leaves room for a slow
    // first start (decoder setup, asset extraction).
    for (var i = 0; i < 120 && !reached; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      reached = find.byType(app.HomePage).evaluate().isNotEmpty;
    }

    expect(
      reached,
      isTrue,
      reason: 'the splash never handed over to the home page',
    );
    expect(tester.takeException(), isNull);
  });
}
