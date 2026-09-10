import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/core/di/injection.dart';
import 'package:yello_social_app/features/chat/presentation/bloc/messages_cubit.dart';
import 'package:yello_social_app/features/feed/presentation/bloc/feed_cubit.dart';
import 'package:yello_social_app/features/notification/presentation/bloc/notifications_cubit.dart';
import 'package:yello_social_app/features/shell/presentation/widgets/bottom_nav_bar.dart';

class _MockMessagesCubit extends MockCubit<MessagesState> implements MessagesCubit {}

class _MockNotificationsCubit extends MockCubit<NotificationsState> implements NotificationsCubit {}

class _MockFeedCubit extends MockCubit<FeedState> implements FeedCubit {}

void main() {
  setUp(() {
    final messages = _MockMessagesCubit();
    whenListen(messages, const Stream<MessagesState>.empty(), initialState: const MessagesState());
    sl.registerSingleton<MessagesCubit>(messages);

    final notifications = _MockNotificationsCubit();
    whenListen(notifications, const Stream<NotificationsState>.empty(), initialState: const NotificationsState());
    sl.registerSingleton<NotificationsCubit>(notifications);

    // The Profile tab's avatar reads FeedCubit.state.me (see
    // BottomNavBar's doc comment) — registered here so its BlocBuilder
    // has something to resolve, even though no test exercises a real photo.
    final feed = _MockFeedCubit();
    whenListen(feed, const Stream<FeedState>.empty(), initialState: const FeedState());
    sl.registerSingleton<FeedCubit>(feed);
  });

  tearDown(() => sl.reset());

  // Regression test for a real bug: `Scaffold.bottomNavigationBar` gives its
  // child a loose height constraint that can be nearly the full body height,
  // and a plain `Row` stretches to fill it instead of shrinking to content
  // (fixed by wrapping the Row in `IntrinsicHeight`) — the floating pill nav
  // bar was rendering at full-screen height. Caught via live device testing,
  // not just code review.
  testWidgets('stays a compact pill and does not stretch to fill the Scaffold body height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBody: true,
          body: Container(color: Colors.blue),
          bottomNavigationBar: BottomNavBar(currentIndex: 0, onTabSelected: (_) {}, onCreate: () {}),
        ),
      ),
    );

    final size = tester.getSize(find.byType(BottomNavBar));
    expect(
      size.height,
      lessThan(150),
      reason: 'the floating pill nav bar must stay compact, not stretch to fill the screen',
    );
  });

  // Regression test for a real bug: on a narrow phone width, "Signals" and
  // "Profile" didn't fit their Expanded tab slice and wrapped onto a 2nd
  // line. Labels must shrink (via FittedBox) instead of wrapping.
  testWidgets('keeps every label on a single line even on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(300, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBody: true,
          body: Container(color: Colors.blue),
          bottomNavigationBar: BottomNavBar(currentIndex: 0, onTabSelected: (_) {}, onCreate: () {}),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    for (final label in ['Feed', 'Signals', 'Inbox', 'Profile']) {
      // A label wrapped onto a 2nd line would roughly double this height;
      // FittedBox instead keeps the Text's own layout pinned to one line
      // (it scales the *painted* result down, it doesn't let Text wrap).
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.size.height, lessThan(14), reason: '"$label" must stay on one line, not wrap to a 2nd line');
    }
  });

  // Regression test: on a gesture-nav device (nonzero MediaQuery.padding.bottom
  // — Android's gesture pill, iOS's home indicator), the floating pill nav
  // bar used to sit under/behind that system UI because its bottom margin
  // was a plain hardcoded 20, ignoring the device's own safe-area inset.
  testWidgets('grows its bottom margin by the device safe-area inset instead of ignoring it', (tester) async {
    const inset = 40.0;
    // FakeViewPadding is in physical pixels, converted to logical via
    // devicePixelRatio — pin it to 1.0 so `inset` compares directly against
    // logical-pixel widget geometry below (same convention the "narrow
    // screen" test above uses for physicalSize).
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(bottom: inset);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    Future<Size> pump() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            extendBody: true,
            body: Container(color: Colors.blue),
            bottomNavigationBar: BottomNavBar(currentIndex: 0, onTabSelected: (_) {}, onCreate: () {}),
          ),
        ),
      );
      return tester.getSize(find.byType(BottomNavBar));
    }

    final insetHeight = await pump();

    tester.view.resetPadding();
    final flatHeight = await pump();

    expect(tester.takeException(), isNull);
    // The bar's bounding box is its own SizedBox (fixed height) plus the
    // outer Padding's top+bottom — only the bottom side should grow, and by
    // exactly the simulated inset, so the pill still clears the gesture
    // area on that device instead of sitting flush under the original
    // hardcoded 20px margin.
    expect(insetHeight.height, closeTo(flatHeight.height + inset, 0.5));
  });
}
