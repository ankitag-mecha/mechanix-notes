import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/main.dart' as app;

// ---------------------------------------------------------------
// Shared helpers for the Notes e2e tests.
// Every test file imports this file, so nothing is copied around.
// ---------------------------------------------------------------

/// Folder where the app saves each note as a .md file.
String get notesFolder => '${Platform.environment['HOME']}/Documents/notes';

/// Deletes all saved notes and the search index, so the app starts "fresh".
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

/// Names of the .md files the app saved, sorted (e.g. 'Daily Journal.md').
Future<List<String>> savedNoteFiles() async {
  final dir = Directory(notesFolder);
  if (!await dir.exists()) return [];
  final names = <String>[];
  for (final f in dir.listSync()) {
    if (f is File && f.path.endsWith('.md')) {
      names.add(f.path.split('/').last);
    }
  }
  names.sort();
  return names;
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

/// Prints a marker so the log shows which plan item (S1.., R1..) is running.
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

int _launches = 0;

/// One Notes e2e test. It: fakes the missing menu plugin, ignores the Num Lock
/// noise, clears the app data, starts the app, runs [body], then cleans up.
///
/// IMPORTANT: the app can only start once per test file (the search index
/// cannot start twice in one process). So use exactly ONE notesTest per file.
void notesTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    _launches++;
    if (_launches > 1) {
      throw StateError(
          'The app can only start once per test file. Put all steps in ONE '
          'notesTest per file.');
    }

    // The app calls a menu plugin that does not exist on eLinux
    // (error: MissingPluginException ... dismissMenu). We give it a fake
    // "OK, done" answer. Any OTHER call on this channel is not faked on
    // purpose, so we notice if the app starts using it.
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

      await body(tester);
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