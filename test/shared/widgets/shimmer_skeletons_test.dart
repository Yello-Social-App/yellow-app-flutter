import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/chat/presentation/widgets/shimmer_chat_thread.dart';
import 'package:yello_social_app/features/chat/presentation/widgets/shimmer_conversation_list.dart';
import 'package:yello_social_app/features/chat/presentation/widgets/shimmer_group_info.dart';
import 'package:yello_social_app/features/communities/presentation/widgets/shimmer_community_comment.dart';
import 'package:yello_social_app/features/communities/presentation/widgets/shimmer_community_card.dart';
import 'package:yello_social_app/features/communities/presentation/widgets/shimmer_community_post_card.dart';
import 'package:yello_social_app/features/feed/presentation/widgets/shimmer_archive_row.dart';
import 'package:yello_social_app/features/feed/presentation/widgets/shimmer_post_detail.dart';
import 'package:yello_social_app/features/friends/presentation/widgets/shimmer_friends_section.dart';
import 'package:yello_social_app/features/notification/presentation/widgets/shimmer_notification_row.dart';
import 'package:yello_social_app/features/notification/presentation/widgets/shimmer_preferences.dart';
import 'package:yello_social_app/features/profile/presentation/widgets/shimmer_own_profile_view.dart';
import 'package:yello_social_app/features/search/presentation/widgets/shimmer_search_result_row.dart';
import 'package:yello_social_app/features/showcase/presentation/widgets/shimmer_project_card.dart';
import 'package:yello_social_app/features/showcase/presentation/widgets/shimmer_project_detail.dart';
import 'package:yello_social_app/shared/widgets/paged_list_view.dart';
import 'package:yello_social_app/shared/widgets/shimmer_loading.dart';

/// The per-screen skeletons are built from fixed-width [ShimmerBox]es sized
/// to match their real card's text — which means a row of them can overflow
/// on a narrow phone in a way the real, `Expanded`/ellipsised text never
/// would. Pump each one at the narrowest width we ship to and make sure the
/// framework throws no "RenderFlex overflowed" from any of them.
void main() {
  const narrowPhone = Size(320, 640);

  Future<void> pumpAtNarrowWidth(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = narrowPhone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    // One extra frame so the shimmer's repeating controller has ticked once.
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('community post skeletons lay out without overflow', (tester) async {
    await pumpAtNarrowWidth(
      tester,
      ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
        children: const [ShimmerCommunityPostCard(), ShimmerCommunityPostCard(hasBody: false)],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(ShimmerCommunityPostCard), findsNWidgets(2));
  });

  testWidgets('community directory skeleton lays out without overflow', (tester) async {
    await pumpAtNarrowWidth(
      tester,
      ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 24), children: const [ShimmerCommunityCard()]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('project skeleton lays out without overflow', (tester) async {
    await pumpAtNarrowWidth(
      tester,
      ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 24), children: const [ShimmerProjectCard()]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('search result skeleton lays out without overflow', (tester) async {
    await pumpAtNarrowWidth(
      tester,
      ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 24), children: const [ShimmerSearchResultRow()]),
    );
    expect(tester.takeException(), isNull);
  });

  // Both profile screens share one layout, so they share this skeleton; the
  // public one only drops the email row from the details card (ADR-013).
  for (final rows in [4, 3]) {
    testWidgets('profile skeleton lays out without overflow ($rows detail rows)', (tester) async {
      await pumpAtNarrowWidth(tester, ShimmerOwnProfileView(detailRows: rows));
      expect(tester.takeException(), isNull);

      // Its header is taller than the viewport, so the post skeletons below it
      // are never built until the list scrolls — scroll down to cover the rest.
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(ShimmerPostCard), findsNWidgets(2));
    });
  }

  testWidgets('list-row skeletons lay out without overflow', (tester) async {
    await pumpAtNarrowWidth(
      tester,
      ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
        children: const [
          ShimmerConversationList(),
          ShimmerNotificationRow(),
          ShimmerNotificationRow(bodyLines: 0),
          ShimmerFriendsSection(),
          ShimmerArchiveRow(captionWidth: 400),
          ShimmerCommunityComment(handleWidth: 400),
          ShimmerCommentRow(nameWidth: 400),
          // The widest trailing any call site passes.
          ShimmerListTile(
            avatarSize: 46,
            titleWidth: 400,
            subtitleWidth: 400,
            trailing: ShimmerBox(width: 78, height: 34),
          ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('page-shaped skeletons lay out without overflow', (tester) async {
    await pumpAtNarrowWidth(tester, const ShimmerChatThread());
    expect(tester.takeException(), isNull);

    await pumpAtNarrowWidth(tester, const ShimmerPostDetail());
    expect(tester.takeException(), isNull);

    for (final page in const [ShimmerGroupInfo(), ShimmerProjectDetail(), ShimmerPreferences()]) {
      await pumpAtNarrowWidth(
        tester,
        SingleChildScrollView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 24), child: page),
      );
      expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
    }
  });

  testWidgets('a bone with no width collapses in an unbounded row instead of throwing', (tester) async {
    await pumpAtNarrowWidth(
      tester,
      const SingleChildScrollView(scrollDirection: Axis.horizontal, child: ShimmerBox(height: 12)),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ShimmerBox)), const Size(0, 12));
  });

  testWidgets('reduce-motion draws the bones flat and lets the frame settle', (tester) async {
    tester.view.physicalSize = narrowPhone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: narrowPhone, disableAnimations: true),
          child: Scaffold(body: ShimmerPostCard()),
        ),
      ),
    );
    // A running ticker would schedule frames forever and time this out.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('PagedListView shows the caller-supplied skeleton while loading, spaced like real rows',
      (tester) async {
    await pumpAtNarrowWidth(
      tester,
      PagedListView(
        isLoading: true,
        errorMessage: null,
        onRetry: () {},
        isEmpty: false,
        emptyTitle: '',
        emptyHint: '',
        itemCount: 0,
        isLoadingMore: false,
        onLoadMore: () {},
        itemBuilder: (context, index) => const SizedBox.shrink(),
        separatorHeight: 12,
        skeleton: const [ShimmerProjectCard(), ShimmerProjectCard()],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(ShimmerProjectCard), findsNWidgets(2));
    expect(find.byType(ShimmerListCard), findsNothing, reason: 'the generic card must not leak in beside a custom skeleton');

    final first = tester.getBottomLeft(find.byType(ShimmerProjectCard).first);
    final second = tester.getTopLeft(find.byType(ShimmerProjectCard).last);
    expect(second.dy - first.dy, 12, reason: 'skeletons use the same separatorHeight as the rows they stand in for');
  });

  testWidgets('PagedListView still falls back to the generic list card', (tester) async {
    await pumpAtNarrowWidth(
      tester,
      PagedListView(
        isLoading: true,
        errorMessage: null,
        onRetry: () {},
        isEmpty: false,
        emptyTitle: '',
        emptyHint: '',
        itemCount: 0,
        isLoadingMore: false,
        onLoadMore: () {},
        itemBuilder: (context, index) => const SizedBox.shrink(),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(ShimmerListCard), findsNWidgets(2));
  });
}
