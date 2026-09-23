import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/core/theme/app_colors.dart';
import 'package:yello_social_app/shared/widgets/date_label.dart';

/// [DateLabel] is the one line Feed, Explore and Inbox all open with, and on
/// Inbox it also carries the unread count behind the same `·` — which makes
/// it the widest thing in that header's title column, sharing the row with a
/// compose button.
///
/// These pin the joined shape and the one layout property worth guaranteeing
/// on a narrow phone: the label **wraps** rather than throwing a RenderFlex
/// overflow. Whether it actually needs to wrap is not testable here —
/// `flutter_test`'s default font gives every glyph a full em of width, so the
/// line measures far wider in a test than it does in Geist on a device.
void main() {
  const narrowPhone = Size(320, 640);

  // Wednesday is the longest weekday; every month abbreviates to three.
  final longestDay = DateTime(2026, 9, 23);

  Future<void> pump(WidgetTester tester, Widget child, {Size size = narrowPhone}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  String renderedText(WidgetTester tester) => tester.widget<Text>(find.byType(Text)).data!;

  testWidgets('renders the date uppercase, weekday first', (tester) async {
    await pump(tester, const DateLabel());
    final now = DateTime.now();
    expect(renderedText(tester), matches(RegExp(r'^[A-Z]+ · [A-Z]{3} \d{1,2}$')));
    expect(renderedText(tester), endsWith('${now.day}'));
  });

  testWidgets('a trailing fact joins behind the same separator, uppercased', (tester) async {
    await pump(tester, const DateLabel(trailing: '3 unread'));
    expect(renderedText(tester), endsWith(' · 3 UNREAD'));
    expect(' · '.allMatches(renderedText(tester)), hasLength(2));
  });

  testWidgets('the longest Inbox line wraps rather than overflowing at 320dp', (tester) async {
    // The Inbox slab's own geometry: 18pt gutters, the label in the flexible
    // slot, a 42pt compose button beside it — and the longest line the slab
    // can produce in it.
    await pump(
      tester,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            Expanded(
              child: DateLabel(color: AppColors.dark.ink2, trailing: 'All caught up', now: longestDay),
            ),
            const SizedBox(width: 42, height: 42),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(renderedText(tester), 'WEDNESDAY · SEP 23 · ALL CAUGHT UP');
    // Stays inside the slot it was given — the thing a `maxLines: 1` or an
    // unwrapped row would break. Its height is free to grow by whole lines.
    final slot = tester.getSize(find.byType(Expanded).first);
    expect(tester.getSize(find.byType(Text)).width, lessThanOrEqualTo(slot.width));
  });

  testWidgets('takes a colour override for surfaces that ignore the active theme', (tester) async {
    await pump(tester, DateLabel(color: AppColors.dark.ink2));
    expect(tester.widget<Text>(find.byType(Text)).style!.color, AppColors.dark.ink2);
  });
}
