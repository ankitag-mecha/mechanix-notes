import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';

import 'support/notes_helpers.dart';

/// Regression journey of the Notes app (see README.md).
///   R1  two notes with the same title are both kept
///   R2  each note is saved as a .md file with the typed text
/// Then two LOOK-ONLY steps (search history, menu of a pinned note) that
/// only print, so the next step can turn them into real checks (R5, R6).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ONE notesTest per file: the app can only start once per run.
  notesTest('Notes regression journey R1-R2', (tester) async {
    // Creates a note. The first line of [text] becomes the note title.
    Future<void> createNote(String text) async {
      await tester.tap(find.byIcon(Icons.add).first); // the add button
      await waitFor(tester, find.byType(LiveMarkdownEditor));
      await tester.tap(find.byType(LiveMarkdownEditor));
      await tester.pump(const Duration(seconds: 1));
      tester.testTextInput.enterText(text);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(imageAsset('assets/icons/back.png')); // saves the note
      await waitFor(tester, find.text('NOTES'));
      await tester.pump(const Duration(seconds: 2)); // let the animation finish
    }

    // ---- R1: two notes with the same title are both kept ----
    step('R1', 'two notes with the same title are both kept');
    await waitFor(tester, find.text('Write a note'));
    await createNote('Daily Journal\nFirst note.');
    await createNote('Daily Journal\nSecond note.');
    await printScreen(tester, 'HOME (two notes with the same title)');

    // Both notes are in the list (the title may or may not get a "(1)").
    expect(find.textContaining('Daily Journal'), findsNWidgets(2));
    expect(find.textContaining('First note.'), findsOneWidget);
    expect(find.textContaining('Second note.'), findsOneWidget);

    // On disk the second file gets "(1)" in its name.
    final files = await tester.runAsync(savedNoteFiles);
    debugPrint('SAVED FILES: $files');
    expect(files, containsAll(['Daily Journal.md', 'Daily Journal (1).md']));

    // ---- R2: each note is saved as a .md file with the typed text ----
    step('R2', 'each note is saved as a .md file with the typed text');
    final first = await tester
        .runAsync(() => File('$notesFolder/Daily Journal.md').readAsString());
    final second = await tester.runAsync(
        () => File('$notesFolder/Daily Journal (1).md').readAsString());
    debugPrint('FILE 1: $first');
    debugPrint('FILE 2: $second');
    expect(first, contains('First note.'));
    expect(second, contains('Second note.'));

    // ================== LOOK-ONLY (for R5 and R6) ==================
    // Nothing below is checked yet. It only prints what the app shows.

    // Search history: search, clear the text, and look at the screen.
    try {
      await tester.tap(imageAsset('assets/icons/search.png'));
      await waitFor(tester, find.byType(TextField));
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.byType(TextField), 'First');
      await tester.pump(const Duration(seconds: 2));
      await printScreen(tester, 'SEARCH (typed: First)');
      await tester.tap(imageAsset('assets/icons/close.png')); // clear / close
      await tester.pump(const Duration(seconds: 1));
      await printScreen(tester, 'SEARCH (after the X)');
      if (find.byType(TextField).evaluate().isNotEmpty) {
        await goBack(tester);
      }
      await waitFor(tester, find.text('NOTES'));
      await tester.pump(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('SEARCH HISTORY LOOK FAILED: $e');
    }

    // Menu of a pinned note: pin it, open the menu again, look at the texts.
    try {
      await tester.tap(find.textContaining('First note.').first);
      await waitFor(tester, imageAsset('assets/icons/back.png'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(imageAsset('assets/icons/more_vert.png'));
      await waitFor(tester, find.text('Pin note'));
      await tester.tap(find.text('Pin note'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(imageAsset('assets/icons/more_vert.png'));
      await tester.pump(const Duration(seconds: 1));
      await printScreen(tester, 'MENU (the note is pinned)');
    } catch (e) {
      debugPrint('UNPIN LOOK FAILED: $e');
    }
  });
}