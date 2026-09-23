import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/date_label.dart';
import '../../../../shared/widgets/explore_title_menu.dart';
import '../../../../shared/widgets/filter_chip_pill.dart';
import '../../../../shared/widgets/paged_list_view.dart';
import '../../../../shared/widgets/segmented_tabs.dart';
import '../../domain/entities/community_entity.dart';
import '../../domain/entities/community_post_entity.dart';
import '../bloc/communities_cubit.dart';
import '../bloc/community_feed_cubit.dart';
import '../widgets/community_post_card.dart';
import '../widgets/shimmer_community_card.dart';
import '../widgets/shimmer_community_post_card.dart';

/// Communities hub: the cross-community timeline (`GET /community-posts`) and
/// the community directory (`GET /communities`) as three tabs of one screen,
/// since they are views of the same thing and the bottom nav has no free slot
/// for a sixth tab.
///
/// The two directory tabs — Discover and Joined — are one list under two
/// membership filters, not two screens, so they share a single
/// [CommunitiesCubit] and switching between them is a filter change.
class CommunitiesPage extends StatelessWidget {
  const CommunitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<CommunityFeedCubit>()..load()),
        BlocProvider(create: (_) => sl<CommunitiesCubit>()),
      ],
      child: const _CommunitiesView(),
    );
  }
}

enum _Tab {
  latest('Latest posts'),
  discover('Discover'),
  joined('Joined');

  const _Tab(this.label);

  final String label;

  /// Whether this tab renders the directory rather than the timeline.
  bool get isDirectory => this != _Tab.latest;

  /// The `GET /communities` membership filter this tab stands for. Null is
  /// "no filter" — see [CommunityMembershipFilter], which is deliberately a
  /// two-value enum used as a nullable.
  CommunityMembershipFilter? get membership => this == _Tab.joined ? CommunityMembershipFilter.joined : null;
}

class _CommunitiesView extends StatefulWidget {
  const _CommunitiesView();

  @override
  State<_CommunitiesView> createState() => _CommunitiesViewState();
}

class _CommunitiesViewState extends State<_CommunitiesView> {
  _Tab _tab = _Tab.latest;

  void _select(_Tab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    if (!tab.isDirectory) return;

    // The directory is only fetched once the user actually asks for it, so
    // opening this screen costs one request rather than two. Exactly one of
    // these two branches issues a request: a changed filter refetches, and
    // `load()` is a no-op once the list is loaded.
    final cubit = context.read<CommunitiesCubit>();
    if (cubit.state.membership != tab.membership) {
      cubit.setMembership(tab.membership);
    } else {
      cubit.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tab chrome — no back arrow, this is the Explore tab's landing
            // screen inside the shell, so Back means "hop to Feed" like on
            // every other tab. The title is the same `YelloWordmark`
            // treatment the other tabs use, but here it is also the menu
            // that switches to Showcase — under the same date eyebrow Feed
            // wears, at Feed's own spacing.
            const Padding(padding: EdgeInsets.fromLTRB(18, 14, 14, 0), child: DateLabel()),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 14, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ExploreTitleMenu(current: ExploreDestination.communities),
              ),
            ),
            _TabBar(current: _tab, onSelect: _select),
            const SizedBox(height: 12),
            Expanded(
              child: switch (_tab) {
                _Tab.latest => const _ThreadsTab(),
                _Tab.discover => const _DirectoryTab(joinedOnly: false),
                _Tab.joined => const _DirectoryTab(joinedOnly: true),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Underlined tab row. Unlike [FilterChipPill], these are not filters sitting
/// in a scrolling row — they swap the whole body, so they get the full width
/// and a yellow rule under the active one.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.current, required this.onSelect});

  final _Tab current;
  final ValueChanged<_Tab> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line, width: 1.5)),
      ),
      child: Row(
        children: [
          for (final tab in _Tab.values)
            Expanded(
              child: _TabButton(label: tab.label, selected: tab == current, onTap: () => onSelect(tab)),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 46,
        child: Stack(
          children: [
            Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.buttonLg.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? colors.ink : colors.ink3,
                ),
              ),
            ),
            if (selected) Positioned(left: 0, right: 0, bottom: 0, child: Container(height: 3, color: colors.yel)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Latest posts — the cross-community timeline.
// ---------------------------------------------------------------------------

class _ThreadsTab extends StatelessWidget {
  const _ThreadsTab();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<CommunityFeedCubit>();

    return BlocBuilder<CommunityFeedCubit, CommunityFeedState>(
      builder: (context, state) {
        return Column(
          children: [
            // Sort only. The scope filter (Everywhere / My communities) was
            // removed from the UI, so `CommunityFeedCubit` keeps its default
            // `CommunityFeedScope.all` and `setScope` is left uncalled — the
            // Joined tab answers "what am I in?" for communities, though not
            // for this timeline.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: SegmentedTabs<CommunityPostSort>(
                values: CommunityPostSort.values,
                current: state.sort,
                labelOf: (sort) => sort.label,
                onSelect: cubit.setSort,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: cubit.refresh,
                color: colors.ink,
                backgroundColor: colors.surf,
                child: PagedListView(
                  isLoading: state.status == CommunityFeedStatus.loading && state.posts.isEmpty,
                  errorMessage:
                      state.status == CommunityFeedStatus.error && state.posts.isEmpty
                          ? (state.errorMessage ?? 'Could not load threads.')
                          : null,
                  onRetry: cubit.refresh,
                  isEmpty: state.status == CommunityFeedStatus.loaded && state.posts.isEmpty,
                  emptyTitle: 'NOTHING HERE YET',
                  emptyHint: 'No threads on this sort yet.',
                  skeleton: const [ShimmerCommunityPostCard(), ShimmerCommunityPostCard(hasBody: false)],
                  itemCount: state.posts.length,
                  isLoadingMore: state.isLoadingMore,
                  onLoadMore: cubit.loadMore,
                  itemBuilder: (context, index) {
                    final post = state.posts[index];
                    return CommunityPostCard(
                      post: post,
                      busy: state.busyIds.contains(post.id),
                      onTap: () => _openThread(context, post),
                      onVote: (vote) => cubit.toggleVote(post, vote),
                      onReact: (type) => cubit.react(post, type),
                      onCommunityTap: () =>
                          context.pushNamed(RouteNames.community, pathParameters: {'slug': post.community.slug}),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Discover / Joined — the community directory under two membership filters.
// ---------------------------------------------------------------------------

class _DirectoryTab extends StatefulWidget {
  const _DirectoryTab({required this.joinedOnly});

  /// Which tab is showing. The filter itself lives in [CommunitiesCubit] — set
  /// by `_CommunitiesViewState._select` — so this only picks the copy; the two
  /// tabs share one [State] (and therefore one search box) by design.
  final bool joinedOnly;

  @override
  State<_DirectoryTab> createState() => _DirectoryTabState();
}

class _DirectoryTabState extends State<_DirectoryTab> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<CommunitiesCubit>();

    return BlocBuilder<CommunitiesCubit, CommunitiesState>(
      builder: (context, state) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                padding: const EdgeInsets.only(left: 16, right: 12),
                decoration: BoxDecoration(
                  color: colors.surf,
                  border: Border.all(color: colors.line, width: 1.5),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: cubit.onQueryChanged,
                        textInputAction: TextInputAction.search,
                        style: AppTextStyles.hint.copyWith(color: colors.ink),
                        decoration: InputDecoration(
                          hintText: widget.joinedOnly ? 'Find in your rooms' : 'Find by Name or tag',
                          hintStyle: AppTextStyles.hint.copyWith(color: colors.ink3),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    Icon(Icons.search, size: 20, color: colors.ink3),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: SegmentedTabs<CommunitySort>(
                values: CommunitySort.values,
                current: state.sort,
                labelOf: (sort) => sort.label,
                onSelect: cubit.setSort,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: cubit.refresh,
                color: colors.ink,
                backgroundColor: colors.surf,
                child: PagedListView(
                  isLoading: state.status == CommunitiesStatus.loading && state.communities.isEmpty,
                  errorMessage:
                      state.status == CommunitiesStatus.error && state.communities.isEmpty
                          ? (state.errorMessage ?? 'Could not load communities.')
                          : null,
                  onRetry: cubit.refresh,
                  isEmpty: state.status == CommunitiesStatus.loaded && state.communities.isEmpty,
                  emptyTitle: widget.joinedOnly ? 'NO ROOMS YET' : 'NO COMMUNITIES',
                  emptyHint: switch ((widget.joinedOnly, state.query.isEmpty)) {
                    (true, true) => 'Join one from Discover and it shows up here.',
                    (true, false) => 'None of your rooms match "${state.query}".',
                    (false, true) => 'Nothing matches this filter yet.',
                    (false, false) => 'Nothing matching "${state.query}".',
                  },
                  separatorHeight: 12,
                  skeleton: const [ShimmerCommunityCard(), ShimmerCommunityCard()],
                  header: _DirectoryHeader(
                    joinedOnly: widget.joinedOnly,
                    query: state.query,
                    loaded: state.communities.length,
                    hasMore: state.hasMore,
                  ),
                  itemCount: state.communities.length,
                  isLoadingMore: state.isLoadingMore,
                  onLoadMore: cubit.loadMore,
                  itemBuilder: (context, index) {
                    final community = state.communities[index];
                    return _CommunityCard(
                      community: community,
                      busy: state.busySlugs.contains(community.slug),
                      onTap: () => context.pushNamed(RouteNames.community, pathParameters: {'slug': community.slug}),
                      onToggleMembership: () => cubit.toggleMembership(community),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The eyebrow above the cards. Lives inside the scrollable (PagedListView's
/// `header`) so it scrolls away with the list instead of eating the viewport.
class _DirectoryHeader extends StatelessWidget {
  const _DirectoryHeader({required this.joinedOnly, required this.query, required this.loaded, required this.hasMore});

  final bool joinedOnly;
  final String query;
  final int loaded;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // The count is what has been paged in so far, not a server total — the
    // list endpoint doesn't return one — hence the "+" while more remain.
    final label = switch ((joinedOnly, query.isEmpty)) {
      (true, _) => 'YOUR ROOMS · $loaded${hasMore ? '+' : ''}',
      (false, true) => 'BROWSE ALL',
      (false, false) => 'RESULTS · $loaded${hasMore ? '+' : ''}',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(label, style: AppTextStyles.eyebrow.copyWith(color: colors.ink3)),
    );
  }
}

/// A directory card: cover band, emoji avatar breaking out of it, then the
/// name, handle, tagline and the join control.
class _CommunityCard extends StatelessWidget {
  const _CommunityCard({
    required this.community,
    required this.busy,
    required this.onTap,
    required this.onToggleMembership,
  });

  final CommunityEntity community;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onToggleMembership;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final (coverFrom, coverTo) = _coverColorsForSlug(community.slug);
    final meta = [
      '${Formatters.compactCount(community.memberCount)} MEMBERS',
      if (community.onlineCount != null) '${Formatters.compactCount(community.onlineCount!)} ONLINE',
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.card(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(-1, -0.7),
                      end: const Alignment(1, 0.7),
                      colors: [coverFrom, coverTo],
                    ),
                  ),
                ),
                Padding(
                  // Top inset clears the avatar, which sits 28px into this
                  // block — see the Positioned below.
                  padding: const EdgeInsets.fromLTRB(14, 34, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        community.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleCard.copyWith(color: colors.ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'c/${community.slug}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
                      ),
                      if (community.tagline.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Text(
                          community.tagline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.people_outline, size: 15, color: colors.ink3),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.metaMono.copyWith(color: colors.ink3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppButton(
                            label: community.isMember ? 'Leave' : 'Join',
                            variant: community.isMember ? AppButtonVariant.outline : AppButtonVariant.primary,
                            dense: true,
                            onPressed: busy ? null : onToggleMembership,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 14,
              top: 40,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle, color: colors.surf),
                child: Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surf2,
                    border: Border.all(color: colors.ink, width: 1.5),
                  ),
                  child: Text(community.emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Communities have no cover image on the backend — only an emoji — so the
/// card's band is a deterministic two-tone wash keyed off the slug: the same
/// community gets the same band on every device, with no extra round trip.
const List<(Color, Color)> _kCoverPalette = [
  (Color(0xFF14120C), Color(0xFFF4C542)),
  (Color(0xFF2A2408), Color(0xFFE8B02E)),
  (Color(0xFF1C1A13), Color(0xFFF7D77A)),
  (Color(0xFF3E3106), Color(0xFFF4C542)),
];

(Color, Color) _coverColorsForSlug(String slug) => _kCoverPalette[slug.hashCode.abs() % _kCoverPalette.length];

void _openThread(BuildContext context, CommunityPostEntity post) {
  // The thread route takes the entity through `extra` because the backend has
  // no `GET /community-posts/{id}` to rebuild it from an id alone.
  context.pushNamed(RouteNames.communityPost, pathParameters: {'postId': post.id}, extra: post);
}
