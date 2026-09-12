import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/asset_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../../shared/widgets/yello_wordmark.dart';
import '../../domain/entities/post_entity.dart';
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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<FeedCubit>();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<FeedCubit, FeedState>(
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
                      sliver: SliverToBoxAdapter(child: _DateLabel()),
                    ),
                    _FeedAppBar(onLogoTap: _onLogoTap),
                    if (state.status == FeedStatus.loading && state.posts.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        sliver: SliverList.list(children: const [ShimmerPostCard(), ShimmerPostCard()]),
                      )
                    else if (state.status == FeedStatus.error && state.posts.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        sliver: SliverToBoxAdapter(
                          child: ErrorView(
                            message: state.errorMessage ?? 'Could not load your feed.',
                            onRetry: cubit.refresh,
                          ),
                        ),
                      )
                    else ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        sliver: SliverToBoxAdapter(
                          child: StoriesRail(
                            stories: state.stories,
                            onAddStory: () => context.pushNamed(RouteNames.storyCompose),
                            onOpenStory: (i) => context
                                .pushNamed<void>(RouteNames.storyViewer, pathParameters: {'userIndex': '$i'})
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
                          itemBuilder: (context, index) {
                            final post = state.posts[index];
                            return PostCard(
                              post: post,
                              onOpen: () =>
                                  context.pushNamed(RouteNames.postDetail, pathParameters: {'postId': post.id}),
                              onLike: () => cubit.toggleLike(post),
                              onReact: (type) => cubit.react(post, type),
                              onSave: () => cubit.toggleSave(post.id),
                              onRepost: () => cubit.toggleRepost(post),
                              onMore: () => _showFeedPostMenu(context, cubit, state, post),
                            );
                          },
                        ),
                      ),
                      if (state.isLoadingMore)
                        const SliverPadding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          sliver: SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                        )
                      else if (!state.hasMore)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                          sliver: const SliverToBoxAdapter(
                            child: EmptyStateCard(title: 'CAUGHT UP', hint: "You've seen everything from today."),
                          ),
                        ),
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
  );
}

Future<void> _copyFeedPostLink(BuildContext context, FeedCubit cubit, String postId) async {
  final url = await cubit.getShareLink(postId);
  if (!context.mounted) return;
  if (url == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not get a share link.')));
    return;
  }
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard.')));
}

Future<void> _confirmDeleteFeedPost(BuildContext context, FeedCubit cubit, String postId) async {
  if (!await confirmDeletePost(context)) return;
  final ok = await cubit.deletePost(postId);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Post deleted.' : 'Could not delete post.')));
}

/// Plain, ordinary (non-sticky) date row sitting directly above
/// `_FeedAppBar` in the sliver list — scrolls away normally with the rest
/// of the feed content instead of living inside the `SliverAppBar` itself.
///
/// Pulled all the way out to its own sliver after three separate on-device
/// bugs came from trying to keep both the date label and the wordmark
/// inside one `SliverAppBar` (wordmark-in-title-with-date-below it
/// overlapping; date-and-wordmark-together-in-`flexibleSpace` making the
/// wordmark disappear on scroll instead of acting like a persistent app-bar
/// identity; a parallax drift/jitter chase on top of that) — a
/// `SliverAppBar`'s toolbar is always the one truly fixed, always-visible
/// part of the widget, so the wordmark (the thing that should behave like
/// an actual app-bar logo) belongs there and nowhere else, which leaves no
/// good place left *inside* the app bar for the date. Living as its own
/// separate sliver sidesteps that fight entirely: it's just normal
/// scrolling content, no toolbar/`flexibleSpace` interaction to get backwards.
class _DateLabel extends StatelessWidget {
  const _DateLabel();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final now = DateTime.now();
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec', //
    ];
    final dateLabel = '${weekdays[now.weekday - 1]} · ${months[now.month - 1]} ${now.day}';
    return Text(dateLabel.toUpperCase(), style: AppTextStyles.metaMono.copyWith(color: colors.ink2));
  }
}

/// Feed's top bar — a real `SliverAppBar` (was a plain `SliverToBoxAdapter`
/// row) so it can pin: `pinned: true` keeps this wordmark+icons bar
/// permanently stuck to the top as the list scrolls down (rather than
/// scrolling fully away like an ordinary sliver, the way `_DateLabel`
/// above it still does).
///
/// A single fixed-height toolbar — no `expandedHeight`/`flexibleSpace` at
/// all, unlike earlier attempts here. The wordmark is set directly as
/// `title` so it's part of the toolbar itself: always rendered, at one
/// constant size/position, in every scroll state, which is what makes it
/// read as a real persistent app-bar identity rather than decorative
/// content that happens to be visible sometimes. See `_DateLabel`'s doc
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
        AppIconButton(icon: const Icon(Icons.search), onPressed: () => context.pushNamed(RouteNames.search)),
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
