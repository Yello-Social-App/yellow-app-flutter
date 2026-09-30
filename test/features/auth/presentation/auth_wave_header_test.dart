import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/auth/presentation/widgets/auth_wave_header.dart';

void main() {
  // No `theme:` — `AppColors.of` falls back to the light palette, same as
  // the other widget tests in this repo.
  Widget host({required VoidCallback onTap, bool reduceMotion = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: AuthWaveHeader(
            title: 'Sign In',
            action: AuthHeaderAction(
              label: 'Sign Up',
              icon: CupertinoIcons.person_crop_circle,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the title and fires the action link', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(onTap: () => taps++));
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
    await tester.tap(find.text('Sign Up'));
    expect(taps, 1);
  });

  testWidgets('wave grows over time and then settles', (tester) async {
    await tester.pumpWidget(host(onTap: () {}));
    await tester.pump(const Duration(milliseconds: 400));
    // Still animating mid-way: pumpAndSettle has frames left to run.
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduce-motion draws the line without animating', (
    tester,
  ) async {
    await tester.pumpWidget(host(onTap: () {}, reduceMotion: true));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
