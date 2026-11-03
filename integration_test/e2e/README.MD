# Notes app E2E tests

End-to-end smoke test for the Mechanix Notes app. It uses the app like a person:
opens it, taps, types, and checks what is on the screen.

## Run

From the project root:

```
flutter-elinux test integration_test/e2e/first_test.dart
```

The test deletes the app data itself (`~/Documents/notes` and
`~/.config/mechanix_apps/notes`) before and after the run, so no wrapper script
is needed.

**Warning:** this removes every note on the machine it runs on.

To keep a log:

```
flutter-elinux test integration_test/e2e/first_test.dart 2>&1 | tee run_$(date +%H%M).log
```

Lines like `>>> S8: pin a note from the three-dots menu` in the log show which
plan item is running. A failure belongs to the last `>>> S..` line above it.

## What is covered (smoke, S1 to S10)

| ID | What the test does | Expected result |
|---|---|---|
| S1 | Start the app | The title `NOTES` is shown |
| S2 | Look at a fresh app | `Write a note` is shown |
| S3 | Tap search | A search box with the hint `SEARCH NOTE` opens |
| S4 | Tap add, type a title and body, press back | The note is in the list, the empty message is gone |
| S5 | Open the note, type new text, press back | Same title, new body preview, old preview gone |
| S6 | Search for `Daily` | The note is in the results |
| S7 | Search for `zzzz` | `No note found` is shown |
| S8 | Open the note, three dots, `Pin note`, back | A `Pinned` section shows the note |
| S9 | Swipe the note, tap trash, tap `CANCEL` | The popup closes and the note stays |
| S10 | Swipe the note, tap trash, tap `DELETE` | The note is gone and `Write a note` is back |

## How it is built

- **One test, one app start.** The app can only start once per run (see Known
  limits), so S1 to S10 are steps of one journey in `first_test.dart`.
- **Helpers** at the top of the file: `resetAppData`, `imageAsset`, `waitFor`,
  `waitGone`, `step`, `printScreen`, `goBack`.
- **Typing in the editor:** the note body is drawn by the markdown editor, not a
  normal text field. The test taps `LiveMarkdownEditor` and types with
  `tester.testTextInput.enterText`. The first line becomes the note title.
- **Fake menu plugin:** the app calls `dismissMenu` on a plugin that does not
  exist on eLinux. The test answers that one call with OK. Any other call on that
  channel still fails on purpose.
- **Ignored noise:** only the Num Lock keyboard message from this device.
  Everything else is reported normally.

## Rules for adding a step

1. Check only what a user can see.
2. Wait with `waitFor` and `waitGone`. Short fixed pauses are only for screen
   animations.
3. Add a `// ---- Sn: ... ----` comment and a `step('Sn', '...')` line.
4. Run it twice in a row before committing.

## Known limits

- **One app start per file.** `multi_launch_check_test.dart` starts the app three
  times. The database now reopens, but the search index cannot start twice in one
  process (`Should not initialize flutter_rust_bridge twice`), and a late
  `Box is not initialized` error follows. Run that file again after the developers
  fix both. When it passes, split the journey into independent tests.
- **Editor text cannot be read from the screen.** S5 checks the preview in the
  list instead.
- **Runs on the dev machine** (eLinux, x64). The run on the Mecha Comet is not
  documented yet.

## Not done yet (regression)

- R1: two notes with the same title become `Title` and `Title (1)`
- R2: notes survive an app restart (the `.md` file exists)
- R3: markdown formatting (H1, H2, bold, italic, checklist, code block)
- R4: undo and redo
- R5: unpin
- R6: search history
- R7: many notes