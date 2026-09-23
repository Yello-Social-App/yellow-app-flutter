import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/communities/presentation/widgets/shimmer_community_card.dart';
import 'package:yello_social_app/features/communities/presentation/widgets/shimmer_community_post_card.dart';
import 'package:yello_social_app/features/profile/presentation/widgets/shimmer_own_profile_view.dart';
import 'package:yello_social_app/features/profile/presentation/widgets/shimmer_profile_view.dart';
import 'package:yello_social_app/features/search/presentation/widgets/shimmer_search_result_row.dart';
import 'package:yello_social_app/features/showcase/presentation/widgets/shimmer_project_card.dart';
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

  testWidgets('public profile skeleton lays out without overflow, for both card shapes', (tester) async {
    await pumpAtNarrowWidth(tester, const ShimmerProfileView());
    expect(tester.takeException(), isNull);
    // The feed's post skeleton stands in for the tab's PostCards.
    expect(find.byType(ShimmerPostCard), findsNWidgets(2));

    await pumpAtNarrowWidth(tester, const ShimmerProfileView(cardOverlap: 20, tabCount: 2));
    expect(tester.takeException(), isNull);
  });

  // The Profile tab's layout diverged from the public profile's card shape,
  // so it carries its own skeleton (ADR-013).
  testWidgets('own profile skeleton lays out without overflow', (tester) async {
    await pumpAtNarrowWidth(tester, const ShimmerOwnProfileView());
    expect(tester.takeException(), isNull);

    // Its header is taller than the viewport, so the post skeletons below it
    // are never built until the list scrolls — scroll down to cover the rest.
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(ShimmerPostCard), findsNWidgets(2));
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
