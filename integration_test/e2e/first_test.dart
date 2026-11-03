import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';

import 'support/notes_helpers.dart';

/// Smoke journey S1-S10 of the Notes app (see README.md).
/// The shared helpers and the app start/cleanup live in
/// support/notes_helpers.dart (notesTest).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ONE notesTest per file: the app can only start once per run.
  notesTest('Notes smoke journey S1-S10', (tester) async {
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
  });
}