import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/core/theme/app_colors.dart';
import 'package:yello_social_app/core/theme/app_style.dart';
import 'package:yello_social_app/shared/widgets/ink_outline.dart';

/// [AppColors] has no `==`, so compare its tokens as a list.
List<Color> _tokens(AppColors c) => [
  c.bg,
  c.surf,
  c.surf2,
  c.ink,
  c.ink2,
  c.ink3,
  c.line,
  c.line2,
  c.yel,
  c.yelb,
  c.yeld,
  c.onYel,
  c.red,
  c.grn,
  c.shell,
  c.slot,
];

void main() {
  group('AppThemeFlavor.ink', () {
    test('keeps the classic palette and only makes the line solid ink', () {
      for (final brightness in Brightness.values) {
        final classic = AppColors.resolve(AppThemeFlavor.classic, brightness);
        final ink = AppColors.resolve(AppThemeFlavor.ink, brightness);
        expect(ink.line, ink.ink);
        expect(_tokens(ink.copyWith(line: classic.line)), _tokens(classic));
      }
    });

    test('round-trips through its persisted name', () {
      expect(AppThemeFlavor.fromName(AppThemeFlavor.ink.name), AppThemeFlavor.ink);
    });

    test('is the only flavor drawn outlined', () {
      expect(AppStyle.resolve(AppThemeFlavor.ink).outlined, isTrue);
      expect(AppStyle.resolve(AppThemeFlavor.classic).outlined, isFalse);
      expect(AppStyle.resolve(AppThemeFlavor.quietRails).outlined, isFalse);
    });

    test('hard shadows never blur, and the soft look has none', () {
      final shadows = AppStyle.ink.hardShadow(AppColors.inkLight, AppStyle.cardOffset);
      expect(shadows, hasLength(1));
      expect(shadows.single.blurRadius, 0);
      expect(shadows.single.offset, const Offset(AppStyle.cardOffset, AppStyle.cardOffset));
      expect(AppStyle.soft.hardShadow(AppColors.light, AppStyle.cardOffset), isEmpty);
    });
  });

  group('InkOutline', () {
    Widget host(AppStyle style) => MaterialApp(
      theme: ThemeData(extensions: [AppColors.inkLight, style]),
      home: const Scaffold(
        body: Center(child: InkOutline(child: SizedBox.square(key: Key('child'), dimension: 40))),
      ),
    );

    testWidgets('adds no chrome in the soft look', (tester) async {
      await tester.pumpWidget(host(AppStyle.soft));
      expect(find.descendant(of: find.byType(InkOutline), matching: find.byType(DecoratedBox)), findsNothing);
    });

    testWidgets('draws an outline and a hard shadow when outlined', (tester) async {
      await tester.pumpWidget(host(AppStyle.ink));
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(InkOutline), matching: find.byType(DecoratedBox)).first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect(decoration.boxShadow!.single.blurRadius, 0);
      expect(find.byKey(const Key('child')), findsOneWidget);
    });
  });
}
