import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/settings/domain/entities/app_update.dart';
import 'package:yello_social_app/features/settings/presentation/widgets/update_available_sheet.dart';

const _update = AppUpdate(
  version: '1.0.1',
  buildNumber: 12,
  apkUrl: 'https://example.test/yello-1.0.1.apk',
  notes: 'Calls ring even when Yello is closed. Group calls hold up to eight people. Fixed a crash on open.',
);

void main() {
  /// Opens the sheet from a button, the way the shell does, and hands back
  /// a reader for what it resolved to. `unset` until the sheet closes.
  Future<Object? Function()> openSheet(WidgetTester tester, {AppUpdate update = _update, Size? size}) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    Object? result = 'unset';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showUpdateAvailableSheet(context, update),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => result;
  }

  group('updateHighlights', () {
    test('a one-line note is split by sentence, capped at three', () {
      expect(updateHighlights('One. Two! Three? Four.'), ['One.', 'Two!', 'Three?']);
    });

    test('a note with one item per line is taken line by line, markers dropped', () {
      expect(updateHighlights('- Faster feed\n• Group calls\n\n* Fixes'), ['Faster feed', 'Group calls', 'Fixes']);
    });

    test('an empty note has no highlights', () => expect(updateHighlights('  '), isEmpty));
  });

  testWidgets('shows the published version and its notes as a checklist', (tester) async {
    await openSheet(tester);

    expect(find.text('NEW · v1.0.1'), findsOneWidget);
    expect(find.text('A fresh Yello is ready'), findsOneWidget);
    expect(find.text('Calls ring even when Yello is closed.'), findsOneWidget);
    expect(find.text('Group calls hold up to eight people.'), findsOneWidget);
    expect(find.text('Fixed a crash on open.'), findsOneWidget);
  });

  testWidgets('"Update now" closes the sheet with true', (tester) async {
    final result = await openSheet(tester);

    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();

    expect(result(), isTrue);
    expect(find.text('A fresh Yello is ready'), findsNothing);
  });

  testWidgets('"Maybe later" closes the sheet with false', (tester) async {
    final result = await openSheet(tester);

    await tester.tap(find.text('Maybe later'));
    await tester.pumpAndSettle();

    expect(result(), isFalse);
    expect(find.text('A fresh Yello is ready'), findsNothing);
  });

  // The 320dp entry in docs/GOTCHAS.md: a layout that fits at 360 can still
  // overflow on a small phone, or on a larger Display size setting.
  testWidgets('fits a 320dp phone with no release notes', (tester) async {
    await openSheet(
      tester,
      update: const AppUpdate(version: '10.20.30', buildNumber: 99, apkUrl: 'https://example.test/y.apk'),
      size: const Size(320, 640),
    );

    expect(find.text('NEW · v10.20.30'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
