import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/core/theme/app_colors.dart';
import 'package:yello_social_app/core/theme/app_style.dart';
import 'package:yello_social_app/features/feed/presentation/widgets/pchum_ben_greeting_card.dart';
import 'package:yello_social_app/shared/widgets/active_tab_indicator_painter.dart';
import 'package:yello_social_app/shared/widgets/pchum_ben_ornaments.dart';

/// WCAG contrast ratio between two opaque colors.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('AppThemeFlavor.pchumBen', () {
    test('resolves to its own palette in each brightness', () {
      expect(AppColors.resolve(AppThemeFlavor.pchumBen, Brightness.light), same(AppColors.pchumBenLight));
      expect(AppColors.resolve(AppThemeFlavor.pchumBen, Brightness.dark), same(AppColors.pchumBenDark));
    });

    test('round-trips through its persisted name, and an unknown name is still classic', () {
      expect(AppThemeFlavor.fromName(AppThemeFlavor.pchumBen.name), AppThemeFlavor.pchumBen);
      // Leading the Theme screen must not make it the fallback: an install
      // with no stored flavor keeps the theme it already had (ADR-035).
      expect(AppThemeFlavor.fromName(null), AppThemeFlavor.classic);
      expect(AppThemeFlavor.fromName('no-such-flavor'), AppThemeFlavor.classic);
    });

    test('text inks hold their contrast floors on a card and on the page', () {
      for (final c in [AppColors.pchumBenLight, AppColors.pchumBenDark]) {
        for (final ground in [c.surf, c.bg]) {
          expect(_contrast(c.ink, ground), greaterThanOrEqualTo(4.5));
          expect(_contrast(c.ink2, ground), greaterThanOrEqualTo(4.5));
          // Placeholder and disabled text: the 3:1 floor.
          expect(_contrast(c.ink3, ground), greaterThanOrEqualTo(3));
        }
        // A label on the saffron fill, and the accent used as text.
        expect(_contrast(c.onYel, c.yel), greaterThanOrEqualTo(4.5));
        expect(_contrast(c.yeld, c.surf), greaterThanOrEqualTo(4.5));
        expect(_contrast(c.yeld, c.yelb), greaterThanOrEqualTo(4.5));
      }
    });

    test('the shell stays dark in both brightnesses', () {
      // ADR-009: everything drawn on it is light ink.
      expect(AppColors.pchumBenLight.shell.computeLuminance(), lessThan(0.05));
      expect(AppColors.pchumBenDark.shell.computeLuminance(), lessThan(0.05));
    });

    test('is the only flavor that draws the ornaments, and stays in the soft look', () {
      for (final flavor in AppThemeFlavor.values) {
        expect(AppStyle.resolve(flavor).pchumBen, flavor == AppThemeFlavor.pchumBen, reason: flavor.name);
      }
      expect(AppStyle.resolve(AppThemeFlavor.pchumBen).outlined, isFalse);
      expect(AppStyle.festive.hardShadow(AppColors.pchumBenLight, AppStyle.cardOffset), isEmpty);
    });
  });

  group('Pchum Ben ornaments', () {
    Widget host(Widget child, {double width = 320, AppColors colors = AppColors.pchumBenLight}) => MaterialApp(
      theme: ThemeData(
        brightness: colors == AppColors.pchumBenDark ? Brightness.dark : Brightness.light,
        extensions: [colors, AppStyle.festive],
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    );

    testWidgets('the frieze spans its width at a fixed height', (tester) async {
      await tester.pumpWidget(host(const PetalFrieze(fill: Colors.orange, vein: Colors.white)));
      expect(tester.getSize(find.byType(PetalFrieze)), const Size(320, PetalFriezePainter.height));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the pictures build in both brightnesses at their stated sizes', (tester) async {
      for (final colors in [AppColors.pchumBenLight, AppColors.pchumBenDark]) {
        await tester.pumpWidget(
          host(
            colors: colors,
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PchumBenSkyline(),
                PchumBenOfferingScene(width: 160),
                LotusMark(),
                LotusFlower(edge: Colors.black),
                SizedBox(height: 100, child: PchumBenCoverScene()),
                SizedBox(height: 100, child: PchumBenWaveScene()),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(PchumBenSkyline)), const Size(150, 30));
        expect(tester.getSize(find.byType(PchumBenOfferingScene)), const Size(160, 96));
        expect(tester.getSize(find.byType(LotusMark)), const Size(16, 16));
      }
    });

    testWidgets('the greeting card keeps its height and fits a 320dp phone', (tester) async {
      // 292 is the card's width on a 320dp screen, inside the feed's 14dp
      // gutters — the narrow case docs/GOTCHAS.md asks every new row to pass.
      for (final width in [292.0, 362.0]) {
        await tester.pumpWidget(host(width: width, const PchumBenGreetingCard()));
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(PchumBenGreetingCard)), Size(width, 120));
        expect(find.text('Happy Pchum Ben'), findsOneWidget);
      }
    });

    test('painters repaint only when what they draw changes', () {
      const a = PetalFriezePainter(fill: Colors.orange);
      expect(a.shouldRepaint(const PetalFriezePainter(fill: Colors.orange)), isFalse);
      expect(a.shouldRepaint(const PetalFriezePainter(fill: Colors.orange, pointUp: true)), isTrue);
      expect(const LotusRosettePainter().shouldRepaint(const LotusRosettePainter()), isFalse);

      const arrow = ActiveTabIndicatorPainter(selectedCenter: 50, slotWidth: 100, color: Colors.orange);
      const bud = ActiveTabIndicatorPainter(selectedCenter: 50, slotWidth: 100, color: Colors.orange, lotus: true);
      expect(arrow.shouldRepaint(bud), isTrue);
    });
  });
}
