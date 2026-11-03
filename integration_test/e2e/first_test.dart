import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';
import 'package:mechanix_notes/main.dart' as app;

// ---------------------------------------------------------------
// Small helpers (we keep them in this file until we need to share)
// ---------------------------------------------------------------

/// Deletes all saved notes and the search index, so the app starts "fresh".
/// Used BEFORE the test (required) and AFTER the test (best effort).
/// WARNING: this removes every note on the device it runs on.
Future<void> resetAppData() async {
  final home = Platform.environment['HOME'];
  if (home == null) return;
  for (final p in [
    '$home/Documents/notes',
    '$home/.config/mechanix_apps/notes',
  ]) {
    final d = Directory(p);
    if (await d.exists()) await d.delete(recursive: true);
  }
}

/// Finds an Image button by its asset name, e.g. imageAsset('assets/icons/back.png')
Finder imageAsset(String asset) => find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == asset,
    );

/// Waits (up to 15 s) until [finder] shows something. No fixed sleeping.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      throw TestFailure('Timed out after $timeout waiting for: $finder');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Waits (up to 15 s) until [finder] shows nothing anymore.
Future<void> waitGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(end)) {
      throw TestFailure('Timed out after $timeout; still showing: $finder');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Prints a marker so the log shows which plan item (S1..S10) is running.
void step(String id, String what) => debugPrint('>>> $id: $what');

/// Prints what is on the current screen so we can learn real names.
Future<void> printScreen(WidgetTester tester, String label) async {
  debugPrint('===== SCREEN: $label =====');
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    debugPrint('TEXT: ${t.data ?? t.textSpan?.toPlainText()}');
  }
  for (final f in tester.widgetList<TextField>(find.byType(TextField))) {
    debugPrint('TEXTFIELD hint: ${f.decoration?.hintText}');
  }
  for (final i in tester.widgetList<Icon>(find.byType(Icon))) {
    debugPrint('ICON: ${i.icon}');
  }
  for (final i in tester.widgetList<Image>(find.byType(Image))) {
    final p = i.image;
    debugPrint('IMAGE: ${p is AssetImage ? p.assetName : p.runtimeType}');
  }
}

/// Goes back one screen (same as the system back).
Future<void> goBack(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ONE test = ONE app start (the app cannot be started twice in a run yet).
  testWidgets('Notes smoke journey S1-S10', (tester) async {
    // The app calls a menu plugin that does not exist on eLinux
    // (error: MissingPluginException ... dismissMenu). We give it a fake
    // "OK, done" answer, so the error never happens. Any OTHER call on this
    // channel is not faked on purpose, so we notice if the app starts using it.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('native_adaptive_toolbox/menu'),
      (MethodCall call) async {
        if (call.method == 'dismissMenu') return null;
        throw MissingPluginException('Not faked in test: ${call.method}');
      },
    );

    // A Num Lock keyboard message from this device can fail a test.
    // We ignore ONLY that one message. Everything else is reported normally.
    final originalHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final text = details.exceptionAsString();
      if (text.contains('RawKeyboard reported')) {
        debugPrint('IGNORED KNOWN NOISE: ${text.split('\n').first}');
        return;
      }
      originalHandler?.call(details);
    };

    try {
      // Start from a fresh app, even if an earlier run left notes behind.
      await tester.runAsync(resetAppData);

      app.main(<String>[]); // start the app
      await tester.pump(const Duration(seconds: 3)); // let it load

      // ---- S1: the app opens and shows the title ----
      step('S1', 'the app opens and shows the title');
      expect(find.text('NOTES'), findsOneWidget);

      // ---- S2: on a fresh app the empty-list message is shown ----
      step('S2', 'on a fresh app the empty-list message is shown');
      await waitFor(tester, find.text('Write a note'));
      expect(find.text('Write a note'), findsOneWidget);

      // ---- S3: tapping search opens the search screen ----
      step('S3', 'tapping search opens the search screen');
      await tester.tap(find.byType(IconButton)); // the only icon button here
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(TextField), findsOneWidget); // the search box
      expect(find.text('SEARCH NOTE'), findsWidgets); // its hint text

      await goBack(tester);
      expect(find.text('NOTES'), findsOneWidget); // back on home

      // ---- S4: create a note, it appears in the list ----
      step('S4', 'create a note, it appears in the list');
      // Let the "back" animation finish first. A tap during the animation is
      // ignored by the app (this was the "would not hit test" warning).
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byIcon(Icons.add).first); // the add button
      await waitFor(tester, find.byType(LiveMarkdownEditor));

      // The editor is not a TextField: tap it, then type through the
      // test keyboard. The first line becomes the note title.
      await tester.tap(find.byType(LiveMarkdownEditor));
      await tester.pump(const Duration(seconds: 1));
      tester.testTextInput
          .enterText('Daily Journal\nToday I explored the notes app.');
      await tester.pump(const Duration(seconds: 1));

      // Back button of the app saves the note and returns to the list.
      await tester.tap(imageAsset('assets/icons/back.png'));
      await waitFor(tester, find.text('NOTES')); // wait for the list
      await tester.pump(const Duration(seconds: 1)); // let animation finish

      await printScreen(tester, 'HOME (after creating a note)');
      expect(find.text('Daily Journal'), findsOneWidget); // the new note
      expect(find.text('Write a note'), findsNothing); // list not empty now

      // ---- S5: open the note again and change it ----
      step('S5', 'open the note again and change it');
      await tester.tap(find.text('Daily Journal')); // open it from the list
      await waitFor(tester, imageAsset('assets/icons/back.png'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byType(LiveMarkdownEditor));
      await tester.pump(const Duration(seconds: 1));
      tester.testTextInput
          .enterText('Daily Journal\nSecond version of the body.');
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(imageAsset('assets/icons/back.png'));
      await waitFor(tester, find.text('NOTES'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Daily Journal'), findsOneWidget); // same title
      expect(find.text('Second version of the body.'), findsOneWidget); // new
      expect(find.text('Today I explored the notes app.'), findsNothing); // old

      // ---- S6: search finds the note ----
      step('S6', 'search finds the note');
      await tester.tap(imageAsset('assets/icons/search.png'));
      await waitFor(tester, find.byType(TextField));
      await tester.pump(const Duration(seconds: 1)); // let the screen finish opening
      await tester.enterText(find.byType(TextField), 'Daily');
      await tester.pump(const Duration(seconds: 2)); // give the search time to run
      expect(find.text('Daily Journal'), findsOneWidget);

      // ---- S7: search with no match shows the empty message ----
      step('S7', 'search with no match shows the empty message');
      await tester.enterText(find.byType(TextField), 'zzzz');
      await waitFor(tester, find.text('No note found'));
      expect(find.text('No note found'), findsOneWidget);

      // ---- S8: pin a note from the three-dots menu ----
      step('S8', 'pin a note from the three-dots menu');
      // first go back from the search screen to the list
      await goBack(tester);
      await waitFor(tester, find.text('NOTES'));
      await tester.pump(const Duration(seconds: 2)); // let the animation finish

      await tester.tap(find.text('Daily Journal')); // open the note
      await waitFor(tester, imageAsset('assets/icons/back.png'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(imageAsset('assets/icons/more_vert.png')); // three dots
      await waitFor(tester, find.text('Pin note'));
      await tester.tap(find.text('Pin note'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(imageAsset('assets/icons/back.png'));
      await waitFor(tester, find.text('NOTES'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Pinned'), findsOneWidget); // the Pinned section
      expect(find.text('Daily Journal'), findsOneWidget); // the note is in it

      // ---- S9: delete, then Cancel on the popup keeps the note ----
      step('S9', 'delete, then Cancel on the popup keeps the note');
      await tester.drag(find.text('Daily Journal'), const Offset(-300, 0));
      await waitFor(tester, imageAsset('assets/icons/trash.png')); // swipe action
      await tester.tap(imageAsset('assets/icons/trash.png'));
      await waitFor(tester, find.text('Do you want to delete this note?'));
      await tester.tap(find.text('CANCEL'));
      await waitGone(tester, find.text('Do you want to delete this note?'));
      expect(find.text('Daily Journal'), findsOneWidget); // still in the list

      // ---- S10: delete, then DELETE on the popup removes the note ----
      step('S10', 'delete, then DELETE on the popup removes the note');
      if (imageAsset('assets/icons/trash.png').evaluate().isEmpty) {
        await tester.drag(find.text('Daily Journal'), const Offset(-300, 0));
        await waitFor(tester, imageAsset('assets/icons/trash.png'));
      }
      await tester.tap(imageAsset('assets/icons/trash.png'));
      await waitFor(tester, find.text('Do you want to delete this note?'));
      await tester.tap(find.text('DELETE'));
      await waitGone(tester, find.text('Daily Journal'));
      await waitFor(tester, find.text('Write a note'));
      expect(find.text('Daily Journal'), findsNothing); // the note is gone
      expect(find.text('Write a note'), findsOneWidget); // empty list again

      debugPrint('===== END =====');
    } finally {
      // Remove the app from the screen while the settings above are still
      // on, then restore the normal error handler.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      FlutterError.onError = originalHandler;

      // Best-effort cleanup: a failure here must never fail the test.
      try {
        await tester.runAsync(resetAppData);
      } catch (e) {
        debugPrint('CLEANUP FAILED (ignored): $e');
      }
    }
  });
}