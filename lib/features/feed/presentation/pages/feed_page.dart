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
import '../../../../core/theme/app_text_styles.dart';
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
    return BlocProvider.value(value: sl<FeedCubit>()..load(), child: const _FeedView());
  }
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
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    } else {
      _refreshIndicatorKey.currentState?.show();
    }
  }

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
                  cubit.loadMore();
                }
                return false;
              },
              child: RefreshIndicator(
                key: _refreshIndicatorKey,
                onRefresh: cubit.refresh,
                color: colors.ink,
                backgroundColor: colors.surf,
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(18, 14, 14, 0),
                      sliver: SliverToBoxAdapter(child: DateLabel()),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 8)),

                    _FeedAppBar(onLogoTap: _onLogoTap),
                    if (state.status == FeedStatus.loading &&
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
                              message: state.errorMessage ?? 'Could not load your feed.',
                              onRetry: cubit.refresh,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        sliver: SliverToBoxAdapter(
                          child: StoriesRail(
                            rail: state.rail,
                            myAvatarUrl: state.me?.avatarUrl,
                            myInitials: (state.me?.fullName ?? state.me?.username ?? 'You').initials,
                            onAddStory: () => _openComposer(context, cubit),
                            // Keyed by author id, not by rail index: the
                            // rail this tap came from may be seconds old,
                            // and an index would play the wrong ring if one
                            // expired in between.
                            onOpenRing: (authorId) => context
                                .pushNamed<void>(RouteNames.storyViewer, pathParameters: {'authorId': authorId})
                                .then((_) => cubit.reloadStories()),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                        sliver: SliverToBoxAdapter(
                          child: CreatePostPrompt(
                            myInitials: state.me == null ? '' : (state.me!.fullName ?? state.me!.username).initials,
                            myAvatarUrl: state.me?.avatarUrl,
                            mySeed: state.me == null ? 0 : avatarSeedForId(state.me!.id),
                            onTap: () => context.pushNamed(RouteNames.createPost),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        sliver: SliverList.separated(
                          itemCount: state.posts.length,
                          separatorBuilder: (_, _) => const SizedBox.shrink(),
                          itemBuilder: (context, index) => _FeedPostCard(postId: state.posts[index].id, cubit: cubit),
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
Future<void> _openPost(BuildContext context, FeedCubit cubit, String postId) async {
  final updated = await context.pushNamed<PostEntity>(RouteNames.postDetail, pathParameters: {'postId': postId});
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
void _showFeedPostMenu(BuildContext context, FeedCubit cubit, FeedState state, PostEntity post) {
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
      onSave: ({content, visibility}) => cubit.updatePost(post.id, content: content, visibility: visibility),
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
Future<void> _hideFeedPost(BuildContext context, FeedCubit cubit, String postId) async {
  final ok = await cubit.hidePost(postId);
  if (!context.mounted) return;
  if (ok) {
    AppStatusSnackbar.showSuccess(context, message: "Hidden. You won't see this post again.");
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
      AppStatusSnackbar.showSuccess(context, message: 'Thanks — our team will take a look.');
    case ReportOutcome.alreadyReported:
      AppStatusSnackbar.showSuccess(context, message: "You've already reported this post.");
    case ReportOutcome.failed:
    case ReportOutcome.none:
      break;
  }
}

Future<void> _muteFeedPostAuthor(BuildContext context, FeedCubit cubit, PostEntity post) async {
  if (!await confirmMuteAuthor(context, post.authorUsername)) return;
  if (!context.mounted) return;
  final ok = await cubit.muteAuthor(post.authorId);
  if (!context.mounted) return;
  if (ok) {
    AppStatusSnackbar.showSuccess(context, message: '${post.authorUsername.withAtSign} is muted.');
  } else {
    AppStatusSnackbar.showError(context, message: 'Could not mute that account.');
  }
}

Future<void> _copyFeedPostLink(BuildContext context, FeedCubit cubit, String postId) async {
  final url = await cubit.getShareLink(postId);
  if (!context.mounted) return;
  if (url == null) {
    AppStatusSnackbar.showError(context, message: 'Could not get a share link.');
    return;
  }
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  AppStatusSnackbar.showSuccess(context, message: 'Link copied to clipboard.');
}

Future<void> _confirmDeleteFeedPost(BuildContext context, FeedCubit cubit, String postId) async {
  if (!await confirmDeletePost(context)) return;
  final ok = await cubit.deletePost(postId);
  if (!context.mounted) return;
  if (ok) {
    AppStatusSnackbar.showSuccess(context, message: 'Post deleted.');
  } else {
    AppStatusSnackbar.showError(context, message: 'Could not delete post.');
  }
}

/// Feed's top bar — a real `SliverAppBar` (was a plain `SliverToBoxAdapter`
/// row) so it can pin: `pinned: true` keeps this wordmark+icons bar
/// permanently stuck to the top as the list scrolls down (rather than
/// scrolling fully away like an ordinary sliver, the way [DateLabel]
/// above it still does).
///
/// A single fixed-height toolbar — no `expandedHeight`/`flexibleSpace` at
/// all, unlike earlier attempts here. The wordmark is set directly as
/// `title` so it's part of the toolbar itself: always rendered, at one
/// constant size/position, in every scroll state, which is what makes it
/// read as a real persistent app-bar identity rather than decorative
/// content that happens to be visible sometimes. See [DateLabel]'s doc
/// comment for why the date isn't in here too.
///
/// `RepaintBoundary` around the wordmark is left over from an earlier
/// version of this bar that still had a `flexibleSpace` collapse animation
/// to desync from — harmless and cheap to keep even now that there's no
/// scroll-driven animation left to jitter against.
///
/// [onLogoTap] — see `_FeedViewState._onLogoTap`: scroll-to-top-then-refresh,
/// the standard "tap the masthead" gesture. Plain `GestureDetector`, not an
/// `InkWell`/button — this is a brand mark reacting to a tap, not a control
/// that should visually read as one.
class _FeedAppBar extends StatelessWidget {
  const _FeedAppBar({required this.onLogoTap});

  final VoidCallback onLogoTap;

  static const _toolbarHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: colors.bg,
      surfaceTintColor: Colors.transparent,
      // The app-wide `AppBarTheme` pins elevation to 0 everywhere (flat
      // chrome by design) — overridden here so a hairline shadow fades in
      // only once the feed has actually scrolled underneath the bar
      // (Flutter ties a `SliverAppBar`'s elevation to `shrinkOffset > 0`),
      // giving the pinned bar a "resting on top of the list" depth cue it
      // wouldn't otherwise have while still flat before any scroll.
      elevation: 3,
      shadowColor: colors.ink.withValues(alpha: 0.15),
      toolbarHeight: _toolbarHeight,
      // titleSpacing: 18,
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onLogoTap,
        child: const RepaintBoundary(child: YelloWordmark(fontSize: AppTextStyles.displayXlFontSize)),
      ),
      actions: [
        // Signals (notifications) sits here rather than in the bottom bar —
        // it swapped places with the Explore sheet, which moved down to the
        // nav slot it vacated (see `BottomNavBar`). Branch 3 still exists in
        // the router, so this is a `goBranch` like Circle below, not a push;
        // the bar's active-tab indicator simply never lands on it any more.
        const _SignalsAction(),
        const SizedBox(width: 8),
        AppIconButton(icon: const Icon(CupertinoIcons.search), onPressed: () => context.pushNamed(RouteNames.search)),
        const SizedBox(width: 8),
        // Circle (friends) button — the brand-mark icon, not a user photo
        // (contrast `BottomNavBar`'s Profile-tab avatar, a different
        // button entirely). Circle's branch (index 1) has no bottom-nav
        // slot of its own — see `BottomNavBar`'s doc comment — so this is
        // currently the only nav entry point into it besides deep-linking.
        AppIconButton(
          icon: Image.asset(AssetConstants.circleIcon, width: 20, height: 20, fit: BoxFit.contain),
          onPressed: () => StatefulNavigationShell.of(context).goBranch(1),
        ),
        const SizedBox(width: 14),
      ],
    );
  }
}

/// The app bar's Signals button: the same unread dot `BottomNavBar` used to
/// paint on this tab, scoped to its own `BlocBuilder` so a notification
/// arriving repaints a 42px button instead of the whole pinned app bar.
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
    final colors = AppColors.of(context);
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      bloc: sl<NotificationsCubit>(),
      buildWhen: (a, b) => (a.unreadCount > 0) != (b.unreadCount > 0),
      builder: (context, state) => Semantics(
        label: 'Signals',
        value: state.unreadCount > 0 ? 'Unread notifications' : null,
        button: true,
        child: AppIconButton(
          // The dot lives inside the icon slot (anchored to the gif's own
          // bounds via this inner Stack) rather than around the outer
          // AppIconButton circle, so it reads as sitting on the glyph
          // itself instead of pasted onto the button's edge.
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              // Only animates while there is something unread — otherwise it
              // sits on the static first frame, so it doesn't loop forever
              // as chrome noise.
              Image.asset(
                state.unreadCount > 0 ? AssetConstants.notificationIconActive : AssetConstants.notificationIcon,
                width: 22,
                height: 22,
                fit: BoxFit.contain,
              ),
              if (state.unreadCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.red,
                      // Ringed in the bar's own background so the dot reads as
                      // cut into the icon rather than pasted on top.
                      border: Border.all(color: colors.bg, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () => _openSignals(context),
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
          return const SliverPadding(
            padding: EdgeInsets.symmetric(vertical: 16),
            sliver: SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
          );
        }
        if (!hasMore) {
          return const SliverPadding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 24),
            sliver: SliverToBoxAdapter(
              child: EmptyStateCard(title: 'CAUGHT UP', hint: "You've seen everything from today."),
            ),
          );
        }
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      },
    );
  }
}
