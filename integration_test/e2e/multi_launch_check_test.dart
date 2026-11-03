import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechanix_notes/main.dart' as app;

/// EXPERIMENT: can the app start twice in one file?
/// Pass  = the developers' ObjectBox fix is in the code, so we can write
///         many small independent tests.
/// Fail  = look for 'Cannot create multiple Store instances' in the log.

/// Gives the missing eLinux menu plugin a fake "OK" answer.
void fakeMenuPlugin(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('native_adaptive_toolbox/menu'),
    (MethodCall call) async => null,
  );
}

Future<void> startApp(WidgetTester tester) async {
  fakeMenuPlugin(tester);
  app.main(<String>[]);
  await tester.pump(const Duration(seconds: 3));
}

/// Removes the app from the screen, so it can shut down cleanly.
Future<void> closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('launch 1: title is shown', (tester) async {
    await startApp(tester);
    expect(find.text('NOTES'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('launch 2: title is shown again', (tester) async {
    await startApp(tester);
    expect(find.text('NOTES'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('launch 3: title is shown a third time', (tester) async {
    await startApp(tester);
    expect(find.text('NOTES'), findsOneWidget);
    await closeApp(tester);
  });
}