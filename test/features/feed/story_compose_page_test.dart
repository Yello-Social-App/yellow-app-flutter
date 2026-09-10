import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/feed/presentation/pages/story_compose_page.dart';

void main() {
  // Regression coverage for a real safe-area gap: this is a full-bleed Stack
  // with hardcoded pixel offsets for its chrome (close button, tool rail,
  // caption field, "Share story" pill) and deliberately no SafeArea (it
  // would letterbox the background photo) — on a device with a taller
  // status bar/notch or a bottom gesture-nav/home-indicator inset, that
  // chrome used to sit the same fixed distance from the physical screen
  // edge regardless, risking overlap with system UI. Fixed by adding
  // MediaQuery's safe-area insets on top of each original offset.
  testWidgets('renders without overflow at zero safe-area insets (a 3-button-nav device)', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StoryComposePage()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renders without overflow, and pushes its chrome further from the edges, on a device with large safe-area '
    'insets (a notch + gesture nav)',
    (tester) async {
      addTearDown(tester.view.resetPadding);

      tester.view.padding = const FakeViewPadding(top: 0, bottom: 0);
      await tester.pumpWidget(const MaterialApp(home: StoryComposePage()));
      await tester.pump();
      final flatCloseRect = tester.getRect(find.byIcon(Icons.close));
      final flatShareRect = tester.getRect(find.text('Share story'));

      // top ~ a Dynamic-Island-class notch; bottom ~ an iOS home indicator /
      // Android gesture pill.
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      await tester.pumpWidget(const MaterialApp(home: StoryComposePage()));
      await tester.pump();
      expect(tester.takeException(), isNull);

      final insetCloseRect = tester.getRect(find.byIcon(Icons.close));
      final insetShareRect = tester.getRect(find.text('Share story'));

      // Top-anchored chrome must move further down (away from the notch);
      // bottom-anchored chrome must move further up (away from the home
      // indicator/gesture pill) — not stay pinned to the same offset from
      // the physical edge regardless of what the device reports.
      expect(insetCloseRect.top, greaterThan(flatCloseRect.top));
      expect(insetShareRect.top, lessThan(flatShareRect.top));
    },
  );
}
