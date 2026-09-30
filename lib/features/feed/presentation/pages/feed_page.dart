import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/asset_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_style.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../communities/domain/entities/community_post_entity.dart';
import '../../../communities/presentation/bloc/community_feed_cubit.dart';
import '../../../communities/presentation/widgets/community_post_card.dart';
import '../../../communities/presentation/widgets/shimmer_community_post_card.dart';
import '../../../notification/presentation/bloc/notifications_cubit.dart';
import '../../../safety/presentation/bloc/report_post_cubit.dart';
import '../../../safety/presentation/widgets/report_post_sheet.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/date_label.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../../shared/widgets/underline_tabs.dart';
import '../../../../shared/widgets/yello_wordmark.dart';
import '../../domain/entities/post_entity.dart';
import '../../domain/entities/story_entity.dart';
import '../bloc/feed_cubit.dart';
import '../widgets/create_post_prompt.dart';
import '../widgets/post_card.dart';
import '../widgets/post_options_sheet.dart';
import '../widgets/reaction_breakdown_sheet.dart';
import '../widgets/stories_rail.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<FeedCubit>()..load()),
        // The Community tab's timeline, scoped to joined communities. Lazy
        // (BlocProvider's default), so it is only created — and only fetches
        // — the first time the Community tab is opened; a factory rather
        // than `FeedCubit`'s singleton, but it lives as long as this page,
        // which the shell keeps alive, so it survives tab switches too.
        // `setScope` is the one fetch: it emits `loading` and refreshes.
        BlocProvider(
          create: (_) =>
              sl<CommunityFeedCubit>()..setScope(CommunityFeedScope.joined),
        ),
      ],
      child: const _FeedView(),
    );
  }
}

/// The two tabs under the stories row: your own feed, and threads from the
/// communities you've joined.
enum _FeedTab {
  feed('Feed'),
  community('Community');

  const _FeedTab(this.label);

  final String label;
}

class _FeedView extends StatefulWidget {
  const _FeedView();

  @override
  State<_FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<_FeedView> {
  // Drives the logo's tap behavior below: scroll-to-top needs to read/
  // animate this list's own offset, and the refresh needs to trigger
  // `RefreshIndicator`'s own spinner (via its `GlobalKey`) rather than just
  // silently calling the cubit, so a tap-to-refresh looks the same as a
  // pull-to-refresh.
  final _scrollController = ScrollController();
  final _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  _FeedTab _tab = _FeedTab.feed;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Logo tap: standard "tap the masthead" affordance. Scrolls back to the
  /// top first if the feed isn't already there; only once already at the
  /// top does a tap actually refresh — mirrors how Twitter/Instagram-style
  /// feeds treat their own top logo, and matches what was asked for here.
  void _onLogoTap() {
    if (!_scrollController.hasClients) return;
    // A small tolerance rather than requiring exactly 0 — overscroll bounce
    // can leave `offset` at a few stray negative/positive pixels even while
    // visually "at the top".
    if (_scrollController.offset > 4) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _refreshIndicatorKey.currentState?.show();
    }
  }

  void _selectTab(_FeedTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    if (tab != _FeedTab.community) return;
    // The first read creates the cubit, whose `setScope` is the initial
    // fetch. After that it is a long-lived list like the feed's, so a
    // community joined elsewhere would never show up here — re-entering the
    // tab brings it current (without blanking: `refresh` keeps the list).
    final community = context.read<CommunityFeedCubit>();
    if (community.state.status == CommunityFeedStatus.loaded) {
      unawaited(community.refresh());
    }
  }

  /// Pull-to-refresh and the logo's refresh act on whichever tab is showing.
  /// Only reads [CommunityFeedCubit] while its tab is open, so a refresh on
  /// the Feed tab never creates (and fetches) the community timeline.
  Future<void> _refresh() => switch (_tab) {
    _FeedTab.feed => context.read<FeedCubit>().refresh(),
    _FeedTab.community => context.read<CommunityFeedCubit>().refresh(),
  };

  void _loadMore() => switch (_tab) {
    _FeedTab.feed => context.read<FeedCubit>().loadMore(),
    _FeedTab.community => context.read<CommunityFeedCubit>().loadMore(),
  };

  /// Opens the composer and, on a successful post, drops the created story
  /// straight into "Your story" — `POST /stories` answers with the whole
  /// `Story`, so no follow-up `GET /stories/me` is needed.
  Future<void> _openComposer(BuildContext context, FeedCubit cubit) async {
    final story = await context.pushNamed<Object?>(RouteNames.storyCompose);
    if (story is StoryEntity) cubit.prependMyStory(story);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<FeedCubit>();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<FeedCubit, FeedState>(
          buildWhen: (previous, current) =>
              previous.status != current.status ||
              previous.posts != current.posts ||
              previous.rail != current.rail ||
              previous.errorMessage != current.errorMessage ||
              previous.me != current.me,
          builder: (context, state) {
            return NotificationListener<ScrollUpdateNotification>(
              onNotification: (n) {
                final metrics = n.metrics;
                if (metrics.pixels > metrics.maxScrollExtent - 600) {
                  _loadMore();
                }
                return false;
              },
              child: RefreshIndicator(
                key: _refreshIndicatorKey,
                onRefresh: _refresh,
                color: colors.ink,
                backgroundColor: colors.surf,
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Above the pinned bar, not inside it — see DateLabel's
                    // doc comment for the on-device bugs the inside version hit.
                    // The date, app bar, stories and tab row sit on `surf`
                    // (white in the light themes) as one header block; the
                    // list below stays on the page's `bg`.
                    SliverToBoxAdapter(
                      child: ColoredBox(
                        color: colors.surf,
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(18, 14, 14, 0),
                          child: DateLabel(),
                        ),
                      ),
                    ),
                    _FeedAppBar(onLogoTap: _onLogoTap),
                    SliverToBoxAdapter(
                      child: ColoredBox(
                        color: colors.surf,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 4),
                          child: StoriesRail(
                            rail: state.rail,
                            myAvatarUrl: state.me?.avatarUrl,
                            myInitials:
                                (state.me?.fullName ??
                                        state.me?.username ??
                                        'You')
                                    .initials,
                            mySeed: state.me == null
                                ? 0
                                : avatarSeedForId(state.me!.id),
                            onAddStory: () => _openComposer(context, cubit),
                            // Keyed by author id, not by rail index: the
                            // rail this tap came from may be seconds old,
                            // and an index would play the wrong ring if one
                            // expired in between.
                            onOpenRing: (authorId) => context
                                .pushNamed<void>(
                                  RouteNames.storyViewer,
                                  pathParameters: {'authorId': authorId},
                                )
                                .then((_) => cubit.reloadStories()),
                          ),
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: UnderlineTabsDelegate<_FeedTab>(
                        values: _FeedTab.values,
                        current: _tab,
                        labelOf: (tab) => tab.label,
                        onSelect: _selectTab,
                        colors: colors,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 14)),
                    if (_tab == _FeedTab.community)
                      const _CommunityTimeline()
                    else if (state.status == FeedStatus.loading &&
                        state.posts.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        sliver: SliverList.list(
                          children: const [
                            ShimmerPostCard(),
                            ShimmerPostCard(hasImage: false),
                          ],
                        ),
                      )
                    else if (state.status == FeedStatus.error &&
                        state.posts.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                            child: ErrorView(
                              message:
                                  state.errorMessage ??
                                  'Could not load your feed.',
                              onRetry: cubit.refresh,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                        sliver: SliverToBoxAdapter(
                          child: CreatePostPrompt(
                            myInitials: state.me == null
                                ? ''
                                : (state.me!.fullName ?? state.me!.username)
                                      .initials,
                            myAvatarUrl: state.me?.avatarUrl,
                            mySeed: state.me == null
                                ? 0
                                : avatarSeedForId(state.me!.id),
                            onTap: () =>
                                context.pushNamed(RouteNames.createPost),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        sliver: SliverList.separated(
                          itemCount: state.posts.length,
                          separatorBuilder: (_, _) => const SizedBox.shrink(),
                          itemBuilder: (context, index) => _FeedPostCard(
                            postId: state.posts[index].id,
                            cubit: cubit,
                          ),
                        ),
                      ),
                      const _PaginationFooter(),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The Community tab: `GET /community-posts?scope=joined`, as one sliver
/// group so it drops into the feed's own scroll view under the pinned tabs.
class _CommunityTimeline extends StatelessWidget {
  const _CommunityTimeline();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CommunityFeedCubit>();

    return BlocBuilder<CommunityFeedCubit, CommunityFeedState>(
      builder: (context, state) {
        final Widget body;
        if (state.posts.isEmpty &&
            (state.status == CommunityFeedStatus.initial ||
                state.status == CommunityFeedStatus.loading)) {
          body = SliverList.list(
            children: const [
              ShimmerCommunityPostCard(),
              SizedBox(height: 10),
              ShimmerCommunityPostCard(hasBody: false),
            ],
          );
        } else if (state.status == CommunityFeedStatus.error &&
            state.posts.isEmpty) {
          body = SliverToBoxAdapter(
            child: Center(
              child: ErrorView(
                message:
                    state.errorMessage ?? 'Could not load community posts.',
                onRetry: cubit.refresh,
              ),
            ),
          );
        } else if (state.posts.isEmpty) {
          body = const SliverToBoxAdapter(child: _NoJoinedCommunities());
        } else {
          body = SliverMainAxisGroup(
            slivers: [
              SliverList.separated(
                itemCount: state.posts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final post = state.posts[index];
                  return CommunityPostCard(
                    post: post,
                    busy: state.busyIds.contains(post.id),
                    onTap: () => _openCommunityThread(context, cubit, post),
                    onVote: (vote) => cubit.toggleVote(post, vote),
                    onReact: (type) => cubit.react(post, type),
                    onCommunityTap: () => context.pushNamed(
                      RouteNames.community,
                      pathParameters: {'slug': post.community.slug},
                    ),
                  );
                },
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: state.isLoadingMore
                      ? const ShimmerCommunityPostCard(hasBody: false)
                      : state.hasMore
                      ? const SizedBox.shrink()
                      : const EmptyStateCard(
                          title: 'CAUGHT UP',
                          hint: "That's everything from your communities.",
                        ),
                ),
              ),
            ],
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          sliver: body,
        );
      },
    );
  }
}

/// Empty Community tab: nothing joined yet (or nothing posted in what is).
/// Points at Explore, whose landing screen is the community directory.
class _NoJoinedCommunities extends StatelessWidget {
  const _NoJoinedCommunities();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const EmptyStateCard(
          title: 'NO COMMUNITY POSTS YET',
          hint: 'Posts from the communities you join show up here.',
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

/// Opens a community thread and applies whatever it pops back onto this
/// row — the same ADR-032 handoff the Communities screen does. The thread
/// route takes the entity through `extra` because the backend has no
/// `GET /community-posts/{id}` to rebuild it from an id alone.
Future<void> _openCommunityThread(
  BuildContext context,
  CommunityFeedCubit cubit,
  CommunityPostEntity post,
) async {
  final updated = await context.pushNamed<CommunityPostEntity>(
    RouteNames.communityPost,
    pathParameters: {'postId': post.id},
    extra: post,
  );
  if (updated != null) cubit.applyUpdated(updated);
}

/// Wraps one feed card in its own [BlocSelector], scoped to just this post
/// (by id) rather than [FeedState.posts] as a whole — the outer
/// `BlocBuilder<FeedCubit, FeedState>` above already rebuilds this sliver's
/// `itemBuilder` on *any* post's like/react/repost/save (`FeedCubit._replace`
/// creates a new `List` every time — see that builder's `buildWhen`), which
/// would otherwise rebuild every currently-visible [PostCard], not just the
/// one that changed. [PostEntity] is `Equatable`, so [BlocSelector] only
/// re-invokes [builder] — reconstructing the actual (heavier) [PostCard]
/// subtree — when *this* post's own fields actually differ from last time.
class _FeedPostCard extends StatelessWidget {
  const _FeedPostCard({required this.postId, required this.cubit});

  final String postId;
  final FeedCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<FeedCubit, FeedState, PostEntity?>(
      selector: (state) => _findPost(state.posts, postId),
      builder: (context, post) {
        // Only transiently null: between this post being removed from
        // `FeedState.posts` (delete/repost-cancel) and this item's own
        // slot disappearing from the list on the next build.
        if (post == null) return const SizedBox.shrink();
        return PostCard(
          post: post,
          onOpen: () => _openPost(context, cubit, post.id),
          onLike: () => cubit.toggleLike(post),
          onReact: (type) => cubit.react(post, type),
          onSave: () => cubit.toggleSave(post.id),
          onRepost: () => cubit.toggleRepost(post),
          // Reads `cubit.state` at tap time rather than closing over the
          // `FeedState` this widget was built with, so the menu's
          // `isOwnPost` check (via `state.me`) can't go stale relative to
          // this scoped-down widget's own narrower rebuild triggers.
          onMore: () => _showFeedPostMenu(context, cubit, cubit.state, post),
        );
      },
    );
  }
}

/// Opens the post's own screen and applies whatever it pops back onto this
/// row — a reaction or a comment made in there changes counts the card here
/// shows, and nothing re-fetches the feed on the way back (see ADR-032). The
/// detail screen hands back null when it has nothing to hand back, and
/// `replacePost` no-ops on a post this feed no longer lists.
Future<void> _openPost(
  BuildContext context,
  FeedCubit cubit,
  String postId,
) async {
  final updated = await context.pushNamed<PostEntity>(
    RouteNames.postDetail,
    pathParameters: {'postId': postId},
  );
  if (updated != null) cubit.replacePost(updated);
}

PostEntity? _findPost(List<PostEntity> posts, String id) {
  for (final p in posts) {
    if (p.id == id) return p;
  }
  return null;
}

/// Feed card's own "···" — opens the same options sheet the post detail
/// screen uses (see `post_options_sheet.dart`), in place, instead of
/// navigating away. Ownership (`FeedState.me`) gates edit/delete exactly
/// like `PostDetailState.isOwnPost` does on the detail screen.
void _showFeedPostMenu(
  BuildContext context,
  FeedCubit cubit,
  FeedState state,
  PostEntity post,
) {
  showPostOptionsSheet(
    context,
    isOwnPost: state.me != null && state.me!.id == post.authorId,
    onCopyLink: () => _copyFeedPostLink(context, cubit, post.id),
    onViewReactions: () => showReactionBreakdownSheet(
      context,
      fetch: () => cubit.getReactionSummary(post.id),
      targetType: 'POST',
      targetId: post.id,
    ),
    onEdit: () => showEditPostSheet(
      context,
      post: post,
      onSave: ({content, visibility}) =>
          cubit.updatePost(post.id, content: content, visibility: visibility),
    ),
    onDelete: () => _confirmDeleteFeedPost(context, cubit, post.id),
    onHide: () => _hideFeedPost(context, cubit, post.id),
    onReport: () => _reportFeedPost(context, post.id),
    onMute: () => _muteFeedPostAuthor(context, cubit, post),
    authorUsername: post.authorUsername,
  );
}

/// Hides one post — no confirmation, because it is reversible in spirit
/// (the author is unaffected, nothing is reported) and asking twice for a
/// "not this one" gesture makes the feed feel heavier than it is.
Future<void> _hideFeedPost(
  BuildContext context,
  FeedCubit cubit,
  String postId,
) async {
  final ok = await cubit.hidePost(postId);
  if (!context.mounted) return;
  if (ok) {
    AppStatusSnackbar.showSuccess(
      context,
      message: "Hidden. You won't see this post again.",
    );
  } else {
    AppStatusSnackbar.showError(context, message: 'Could not hide that post.');
  }
}

/// The sheet owns the request; this only says how it went. A report is
/// deliberately *not* followed by hiding the post — two different decisions,
/// and quietly doing the second would make "report" feel like it deleted
/// something.
Future<void> _reportFeedPost(BuildContext context, String postId) async {
  final outcome = await showReportPostSheet(context, postId: postId);
  if (!context.mounted || outcome == null) return;
  switch (outcome) {
    case ReportOutcome.sent:
      AppStatusSnackbar.showSuccess(
        context,
        message: 'Thanks — our team will take a look.',
      );
    case ReportOutcome.alreadyReported:
      AppStatusSnackbar.showSuccess(
        context,
        message: "You've already reported this post.",
      );
    case ReportOutcome.failed:
    case ReportOutcome.none:
      break;
  }
}

Future<void> _muteFeedPostAuthor(
  BuildContext context,
  FeedCubit cubit,
  PostEntity post,
) async {
  if (!await confirmMuteAuthor(context, post.authorUsername)) return;
  if (!context.mounted) return;
  final ok = await cubit.muteAuthor(post.authorId);
  if (!context.mounted) return;
  if (ok) {
    AppStatusSnackbar.showSuccess(
      context,
      message: '${post.authorUsername.withAtSign} is muted.',
    );
  } else {
    AppStatusSnackbar.showError(
      context,
      message: 'Could not mute that account.',
    );
  }
}

Future<void> _copyFeedPostLink(
  BuildContext context,
  FeedCubit cubit,
  String postId,
) async {
  final url = await cubit.getShareLink(postId);
  if (!context.mounted) return;
  if (url == null) {
    AppStatusSnackbar.showError(
      context,
      message: 'Could not get a share link.',
    );
    return;
  }
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  AppStatusSnackbar.showSuccess(context, message: 'Link copied to clipboard.');
}

Future<void> _confirmDeleteFeedPost(
  BuildContext context,
  FeedCubit cubit,
  String postId,
) async {
  if (!await confirmDeletePost(context)) return;
  final ok = await cubit.deletePost(postId);
  if (!context.mounted) return;
  if (ok) {
    AppStatusSnackbar.showSuccess(context, message: 'Post deleted.');
  } else {
    AppStatusSnackbar.showError(context, message: 'Could not delete post.');
  }
}

/// Feed's top bar — a real `SliverAppBar` so it can pin: `pinned: true`
/// keeps the logo + search + bell + circle bar stuck to the top as the list scrolls,
/// with the Feed / Community tabs pinning directly beneath it.
///
/// A single fixed-height toolbar — no `expandedHeight`/`flexibleSpace`. The
/// brand tile and wordmark are set directly as `title` so they're part of
/// the toolbar itself: always rendered, at one constant size/position, in
/// every scroll state.
///
/// Circle is back in the header, in the slot Inbox held (Inbox is still the
/// bottom bar's Chat slot). The [DateLabel] eyebrow is a separate sliver
/// above this bar and scrolls away while the bar stays.
///
/// [onLogoTap] — see `_FeedViewState._onLogoTap`: scroll-to-top-then-refresh,
/// the standard "tap the masthead" gesture. Plain `GestureDetector`, not an
/// `InkWell`/button — this is a brand mark reacting to a tap, not a control
/// that should visually read as one.
class _FeedAppBar extends StatelessWidget {
  const _FeedAppBar({required this.onLogoTap});

  final VoidCallback onLogoTap;

  static const _toolbarHeight = 60.0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: colors.surf,
      surfaceTintColor: Colors.transparent,
      // The app-wide `AppBarTheme` pins elevation to 0 everywhere (flat
      // chrome by design). Left flat here too now: the pinned tab row right
      // underneath draws the hairline, so a shadow on this bar would land on
      // the tabs rather than on the list.
      toolbarHeight: _toolbarHeight,
      titleSpacing: 16,
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onLogoTap,
        child: const RepaintBoundary(
          child: YelloWordmark(fontSize: AppTextStyles.displayXlFontSize),
        ),
      ),
      actions: [
        _HeaderButton(
          label: 'Search',
          icon: const Icon(CupertinoIcons.search, size: 20),
          onPressed: () => context.pushNamed(RouteNames.search),
        ),
        const SizedBox(width: 10),
        // Signals (notifications) and Circle, reached from here with
        // `goBranch` rather than a push — both are shell branches.
        const _SignalsAction(),
        const SizedBox(width: 10),
        // Circle (friends) — the brand-mark icon, not a user photo. Its
        // branch (index 1) has no bottom-nav slot, so this and Profile's
        // connections row are its entry points.
        _HeaderButton(
          label: 'Circle',
          icon: Image.asset(
            AssetConstants.circleIcon,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
          ),
          onPressed: () => StatefulNavigationShell.of(context).goBranch(1),
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}

/// A round, hairline-ringed header button with no badge — Search and
/// Circle. Same shape as Signals so the three read as one group.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => _HeaderBadgeButton(
    icon: icon,
    count: 0,
    label: label,
    onPressed: onPressed,
  );
}

/// A round, hairline-ringed header button with an unread count on its
/// shoulder — Signals, and (count 0) every other header button.
class _HeaderBadgeButton extends StatelessWidget {
  const _HeaderBadgeButton({
    required this.icon,
    required this.count,
    required this.label,
    required this.onPressed,
  });

  final Widget icon;
  final int count;
  final String label;
  final VoidCallback onPressed;

  static const _size = 42.0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = AppStyle.of(context);
    return Semantics(
      label: label,
      value: count > 0 ? '$count unread' : null,
      button: true,
      child: SizedBox.square(
        dimension: _size,
        // `Stack`/`Positioned` inside the button's own box, not overhanging
        // it: a badge painted outside its parent's bounds gets no hits.
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Filled only under ink outline, where the hard shadow needs
                // a solid face to sit under.
                color: style.outlined ? colors.surf : null,
                border: Border.all(color: colors.line, width: style.borderWidth),
                boxShadow: style.hardShadow(colors, AppStyle.buttonOffset),
              ),
              child: ClipOval(
                child: Material(
                  type: MaterialType.transparency,
                  child: AppIconButton(
                    size: _size,
                    icon: icon,
                    onPressed: onPressed,
                  ),
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                top: -3,
                right: -3,
                child: IgnorePointer(
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.red,
                      borderRadius: BorderRadius.circular(9),
                      // Ringed in the bar's own background so the badge
                      // reads as cut into the button rather than pasted on.
                      border: Border.all(color: colors.surf, width: 1.5),
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: AppTextStyles.metaMonoSm.copyWith(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The app bar's Signals button, scoped to its own `BlocBuilder` so a
/// notification arriving repaints a 42px button instead of the whole pinned
/// app bar.
class _SignalsAction extends StatelessWidget {
  const _SignalsAction();

  /// `MainShellPage.onTabSelected` silently re-fetches Signals whenever its
  /// tab is (re)selected — `NotificationsCubit` is a long-lived singleton
  /// behind a kept-alive branch, so without that it loads exactly once and
  /// then goes stale for the rest of the app's life. Reaching the branch
  /// straight from this button bypasses that callback, so the same refresh
  /// has to happen here.
  void _openSignals(BuildContext context) {
    unawaited(sl<NotificationsCubit>().refresh());
    StatefulNavigationShell.of(context).goBranch(3);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      bloc: sl<NotificationsCubit>(),
      buildWhen: (a, b) => a.unreadCount != b.unreadCount,
      builder: (context, state) => _HeaderBadgeButton(
        label: 'Signals',
        count: state.unreadCount,
        onPressed: () => _openSignals(context),
        // Only animates while there is something unread — otherwise it sits
        // on the static first frame, so it doesn't loop forever as chrome
        // noise.
        icon: Image.asset(
          Theme.of(context).brightness == Brightness.dark
              ? (state.unreadCount > 0
                    ? AssetConstants.notificationIconActiveDark
                    : AssetConstants.notificationIconDark)
              : (state.unreadCount > 0
                    ? AssetConstants.notificationIconActive
                    : AssetConstants.notificationIcon),
          width: 21,
          height: 21,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// Pagination footer sliver ("loading more" spinner / "caught up" card),
/// split out of the main `BlocBuilder<FeedCubit, FeedState>` above into its
/// own `BlocSelector` scoped to just `isLoadingMore`/`hasMore`. The
/// in-flight flag `FeedCubit.loadMore()` flips mid-scroll (fired off the
/// `NotificationListener<ScrollUpdateNotification>` above as the list nears
/// its bottom) now only rebuilds this small sliver instead of the whole
/// pinned app bar/stories rail/post-list tree above it — see the outer
/// `BlocBuilder`'s `buildWhen`, which deliberately excludes these two
/// fields since this widget owns them instead.
class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<FeedCubit, FeedState, (bool, bool)>(
      selector: (state) => (state.isLoadingMore, state.hasMore),
      builder: (context, s) {
        final (isLoadingMore, hasMore) = s;
        if (isLoadingMore) {
          // The next page's first card, not a spinner under the last one.
          return const SliverPadding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 16),
            sliver: SliverToBoxAdapter(child: ShimmerPostCard(hasImage: false)),
          );
        }
        if (!hasMore) {
          return const SliverPadding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 24),
            sliver: SliverToBoxAdapter(
              child: EmptyStateCard(
                title: 'CAUGHT UP',
                hint: "You've seen everything from today.",
              ),
            ),
          );
        }
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      },
    );
  }
}
