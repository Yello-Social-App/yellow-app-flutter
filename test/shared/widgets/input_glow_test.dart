import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/core/theme/app_colors.dart';
import 'package:yello_social_app/shared/widgets/glow_border.dart';
import 'package:yello_social_app/shared/widgets/input_glow.dart';
import 'package:yello_social_app/shared/widgets/send_icon.dart';

/// Every text field in the app lights its outline while the user is typing
/// into it: [InputGlow] for a field inside a shell, [GlowInputBorder] for one
/// outlined through its own `InputDecoration`. These pin the on/off contract;
/// what the halo looks like on the device's renderer needs a real phone.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: child))));

  GlowBorder outline(WidgetTester tester) => tester.widget<GlowBorder>(find.byType(GlowBorder));

  testWidgets('InputGlow lights up while its field has focus, and goes back at rest', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await pump(
      tester,
      InputGlow(
        borderRadius: BorderRadius.circular(12),
        child: TextField(focusNode: focus, decoration: const InputDecoration(border: InputBorder.none)),
      ),
    );

    expect(outline(tester).color, AppColors.light.line);
    expect(outline(tester).blur, 0);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(outline(tester).color, AppColors.light.yel);
    expect(outline(tester).blur, greaterThan(0));

    focus.unfocus();
    await tester.pump();
    expect(outline(tester).color, AppColors.light.line);
    expect(outline(tester).blur, 0);
  });

  testWidgets('InputGlow with a controller stays lit while a draft is held', (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await pump(
      tester,
      InputGlow(
        borderRadius: BorderRadius.circular(12),
        controller: controller,
        child: TextField(controller: controller, focusNode: focus),
      ),
    );

    await tester.enterText(find.byType(TextField), 'hello');
    focus.unfocus();
    await tester.pump();
    expect(outline(tester).color, AppColors.light.yel);

    controller.clear();
    await tester.pump();
    expect(outline(tester).color, AppColors.light.line);
  });

  test('GlowInputBorder keeps its glow through the decorator\'s tween and copyWith', () {
    const plain = OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFDDDDDD), width: 1.5));
    const lit = GlowInputBorder(borderSide: BorderSide(color: Color(0xFFFFCE2B), width: 1.5), glowOpacity: 0.5);

    final halfway = ShapeBorder.lerp(plain, lit, 0.5);
    expect(halfway, isA<GlowInputBorder>());
    expect((halfway! as GlowInputBorder).glowOpacity, closeTo(0.25, 1e-9));

    final copied = lit.copyWith(borderSide: const BorderSide(color: Color(0xFF000000)));
    expect(copied, isA<GlowInputBorder>());
    expect(copied.glowOpacity, 0.5);
  });

  testWidgets('SendIcon takes its size and colour from the ambient IconTheme', (tester) async {
    await pump(
      tester,
      const IconTheme(
        data: IconThemeData(size: 30, color: Color(0xFF123456)),
        child: SendIcon(semanticLabel: 'Send'),
      ),
    );
    expect(tester.getSize(find.byType(SendIcon)), const Size(30, 30));
    expect(find.bySemanticsLabel('Send'), findsOneWidget);
  });
}
