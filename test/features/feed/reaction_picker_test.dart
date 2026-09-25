import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/core/theme/app_colors.dart';
import 'package:yello_social_app/core/theme/app_theme.dart';
import 'package:yello_social_app/features/feed/domain/entities/post_entity.dart';
import 'package:yello_social_app/features/feed/presentation/widgets/reaction_picker.dart';

/// The picker is a rail floating against the button that opened it, not a
/// bottom sheet. Which side of the button it lands on, and that it stays on
/// screen when the button is near an edge, is the whole behaviour.
void main() {
  /// Pumps a single button at [buttonAlignment] and long-presses it.
  /// Returns the button's rect so the caller can compare the rail against it.
  Future<Rect> openPickerOn(WidgetTester tester, Alignment buttonAlignment) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(AppThemeFlavor.classic),
        home: Scaffold(
          body: Align(
            alignment: buttonAlignment,
            child: Builder(
              builder: (buttonContext) => GestureDetector(
                key: key,
                onLongPress: () => showReactionPicker(buttonContext, current: ReactionType.haha),
                child: const SizedBox(width: 90, height: 40, child: ColoredBox(color: Color(0xFFEEEEEE))),
              ),
            ),
          ),
        ),
      ),
    );
    final buttonRect = tester.getRect(find.byKey(key));
    await tester.longPress(find.byKey(key));
    await tester.pumpAndSettle();
    return buttonRect;
  }

  Rect railRect(WidgetTester tester) =>
      tester.getRect(find.ancestor(of: find.text('😆'), matching: find.byType(Material)).last);

  testWidgets('long-press floats the six reactions above the button, not in a bottom sheet', (tester) async {
    final button = await openPickerOn(tester, Alignment.center);

    for (final type in ReactionType.values) {
      expect(find.text(type.emoji), findsOneWidget, reason: '${type.wireValue} tile missing');
    }
    expect(find.byType(BottomSheet), findsNothing);

    final rail = railRect(tester);
    expect(rail.bottom, lessThanOrEqualTo(button.top), reason: 'rail $rail should sit above the button $button');
    // Roughly centred on the button rather than spanning the screen.
    expect((rail.center.dx - button.center.dx).abs(), lessThan(1));
    expect(rail.width, lessThan(tester.view.physicalSize.width / tester.view.devicePixelRatio));
  });

  testWidgets('a button too close to the top gets the rail underneath it instead', (tester) async {
    final button = await openPickerOn(tester, Alignment.topCenter);

    expect(railRect(tester).top, greaterThanOrEqualTo(button.bottom));
  });

  testWidgets('a button at the left edge keeps the whole rail on screen', (tester) async {
    await openPickerOn(tester, Alignment.centerLeft);

    expect(railRect(tester).left, greaterThanOrEqualTo(0));
  });

  testWidgets('tapping a tile returns that reaction, and the barrier dismisses with null', (tester) async {
    ReactionType? picked;
    var opened = 0;
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(AppThemeFlavor.classic),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (buttonContext) => GestureDetector(
                key: key,
                onLongPress: () async {
                  opened++;
                  picked = await showReactionPicker(buttonContext);
                },
                child: const SizedBox(width: 90, height: 40, child: ColoredBox(color: Color(0xFFEEEEEE))),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ReactionType.wow.emoji));
    await tester.pumpAndSettle();
    expect(picked, ReactionType.wow);

    await tester.longPress(find.byKey(key));
    await tester.pumpAndSettle();
    // Top-left corner: outside the rail wherever it landed.
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(opened, 2);
    expect(picked, isNull, reason: 'dismissing without choosing must not react');
  });

  testWidgets('the rail fits a 320dp screen without overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openPickerOn(tester, Alignment.center);

    expect(tester.takeException(), isNull);
    final rail = railRect(tester);
    expect(rail.left, greaterThanOrEqualTo(0));
    expect(rail.right, lessThanOrEqualTo(320));
  });

  test('the LOVE tile renders as 🖕 but still travels as LOVE on the wire', () {
    expect(ReactionType.love.emoji, '🖕');
    expect(ReactionType.love.wireValue, 'LOVE');
    // Nothing else borrowed the glyph, so the rail has no duplicate tiles.
    expect(ReactionType.values.map((t) => t.emoji).toSet(), hasLength(ReactionType.values.length));
  });
}
