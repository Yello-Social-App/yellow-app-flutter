import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/di/injection.dart';
import 'package:yello_social_app/features/feed/domain/usecases/story_usecases.dart';
import 'package:yello_social_app/features/feed/presentation/bloc/story_compose_cubit.dart';
import 'package:yello_social_app/features/feed/presentation/pages/story_compose_page.dart';

class _MockCreateStory extends Mock implements CreateStoryUseCase {}

void main() {
  // The page resolves its cubit from the DI graph; nothing here posts, so a
  // never-called usecase behind it is enough.
  setUp(() => sl.registerFactory(() => StoryComposeCubit(_MockCreateStory())));

  tearDown(() => sl.reset());

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
      final flatCloseRect = tester.getRect(find.byIcon(CupertinoIcons.xmark));
      final flatShareRect = tester.getRect(find.text('Share with friends'));

      // top ~ a Dynamic-Island-class notch; bottom ~ an iOS home indicator /
      // Android gesture pill.
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      await tester.pumpWidget(const MaterialApp(home: StoryComposePage()));
      await tester.pump();
      expect(tester.takeException(), isNull);

      final insetCloseRect = tester.getRect(find.byIcon(CupertinoIcons.xmark));
      final insetShareRect = tester.getRect(find.text('Share with friends'));

      // Top-anchored chrome must move further down (away from the notch);
      // bottom-anchored chrome must move further up (away from the home
      // indicator/gesture pill) — not stay pinned to the same offset from
      // the physical edge regardless of what the device reports.
      expect(insetCloseRect.top, greaterThan(flatCloseRect.top));
      expect(insetShareRect.top, lessThan(flatShareRect.top));
    },
  );

  // Regression coverage for a caption typed blind: this Scaffold sets
  // `resizeToAvoidBottomInset: false` on purpose (letting it resize would
  // reframe the photo preview away from how the story actually plays back),
  // so nothing moves out from under the IME on its own — the bottom chrome
  // has to add the keyboard's own inset to its offset, or the caption field
  // sits behind the keyboard the whole time the user is typing into it.
  testWidgets('lifts the caption field and the Share button clear of the keyboard', (tester) async {
    addTearDown(tester.view.resetViewInsets);

    // Sync I/O only: `testWidgets` runs in a fake-async zone, so an awaited
    // real file future never completes and the test just hangs.
    final dir = Directory.systemTemp.createTempSync('yello_story_compose');
    addTearDown(() => dir.deleteSync(recursive: true));
    final photo = File('${dir.path}/photo.png')..writeAsBytesSync(_onePixelPng);

    // A singleton the test can hold, because the caption field only exists in
    // photo mode and the page builds its own cubit out of the DI graph.
    await sl.reset();
    final cubit = StoryComposeCubit(_MockCreateStory());
    sl.registerSingleton<StoryComposeCubit>(cubit);

    await tester.pumpWidget(const MaterialApp(home: StoryComposePage()));
    cubit.setImage(photo);
    await tester.pump();

    final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    const keyboardHeight = 300.0;
    final keyboardTop = screenHeight - keyboardHeight;

    // Resting: both sit low, in the band the keyboard is about to cover —
    // which is the whole reason the offsets have to react to it.
    expect(tester.getRect(find.text('Add a caption')).bottom, greaterThan(keyboardTop));

    // `viewInsets` is in physical pixels, unlike everything measured above.
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight * tester.view.devicePixelRatio);
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Fully above the keyboard, not merely nudged: a caption the user cannot
    // read while typing it is the bug, so clearing the IME is the assertion.
    expect(tester.getRect(find.text('Add a caption')).bottom, lessThan(keyboardTop));
    expect(tester.getRect(find.text('Share with friends')).bottom, lessThan(keyboardTop));
  });
}

/// A 1x1 PNG, so photo mode has a real file to point `Image.file` at.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);
