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
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/filter_chip_pill.dart';
import '../../../../shared/widgets/paged_list_view.dart';
import '../../domain/entities/community_entity.dart';
import '../../domain/entities/community_post_entity.dart';
import '../bloc/communities_cubit.dart';
import '../bloc/community_feed_cubit.dart';
import '../widgets/community_post_card.dart';

/// Communities hub: the cross-community timeline (`GET /community-posts`) and
/// the community directory (`GET /communities`) as two segments of one screen,
/// since they are two views of the same thing and the bottom nav has no free
/// slot for a sixth tab.
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

enum _Segment { threads, browse }

class _CommunitiesView extends StatefulWidget {
  const _CommunitiesView();

  @override
  State<_CommunitiesView> createState() => _CommunitiesViewState();
}

class _CommunitiesViewState extends State<_CommunitiesView> {
  _Segment _segment = _Segment.threads;

  void _select(_Segment segment) {
    if (_segment == segment) return;
    setState(() => _segment = segment);
    // The directory is only fetched once the user actually asks for it, so
    // opening this screen costs one request rather than two.
    if (segment == _Segment.browse) context.read<CommunitiesCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Row(
                children: [
                  AppIconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: AppTextStyles.displayXl.copyWith(color: colors.ink, fontSize: 28),
                        children: [
                          const TextSpan(text: 'Rooms'),
                          TextSpan(text: '.', style: TextStyle(color: colors.yel)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  _SegmentButton(
                    label: 'Threads',
                    selected: _segment == _Segment.threads,
                    onTap: () => _select(_Segment.threads),
                  ),
                  const SizedBox(width: 8),
                  _SegmentButton(
                    label: 'Communities',
                    selected: _segment == _Segment.browse,
                    onTap: () => _select(_Segment.browse),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (_segment) {
                _Segment.threads => const _ThreadsTab(),
                _Segment.browse => const _BrowseTab(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: selected ? colors.yel : colors.surf,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        side: BorderSide(color: selected ? colors.ink : colors.line, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            label,
            style: AppTextStyles.button.copyWith(color: selected ? colors.onYel : colors.ink2),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Threads — the cross-community timeline.
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
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final sort in CommunityPostSort.values) ...[
                            FilterChipPill(
                              label: sort.label,
                              selected: state.sort == sort,
                              onTap: () => cubit.setSort(sort),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Container(width: 1, height: 22, color: colors.line),
                          const SizedBox(width: 6),
                          for (final scope in CommunityFeedScope.values) ...[
                            FilterChipPill(
                              label: scope.label,
                              selected: state.scope == scope,
                              onTap: () => cubit.setScope(scope),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
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
                  emptyHint: state.scope == CommunityFeedScope.joined
                      ? 'Join a community and its threads show up here.'
                      : 'No threads on this sort yet.',
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
                      onCommunityTap: () => context.pushNamed(
                        RouteNames.community,
                        pathParameters: {'slug': post.community.slug},
                      ),
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
// Browse — the community directory.
// ---------------------------------------------------------------------------

class _BrowseTab extends StatefulWidget {
  const _BrowseTab();

  @override
  State<_BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends State<_BrowseTab> {
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colors.surf,
                  border: Border.all(color: colors.line, width: 1.5),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: TextField(
                  controller: _controller,
                  onChanged: cubit.onQueryChanged,
                  textInputAction: TextInputAction.search,
                  style: AppTextStyles.hint.copyWith(color: colors.ink),
                  decoration: InputDecoration(
                    hintText: 'Find a community',
                    hintStyle: AppTextStyles.hint.copyWith(color: colors.ink3),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final sort in CommunitySort.values) ...[
                      FilterChipPill(
                        label: sort.label,
                        selected: state.sort == sort,
                        onTap: () => cubit.setSort(sort),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Container(width: 1, height: 22, color: colors.line),
                    const SizedBox(width: 6),
                    for (final filter in CommunityMembershipFilter.values) ...[
                      FilterChipPill(
                        label: filter.label,
                        selected: state.membership == filter,
                        // Tapping the active filter clears it — null is
                        // "no filter", not a third enum value.
                        onTap: () => cubit.setMembership(state.membership == filter ? null : filter),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
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
                  emptyTitle: 'NO COMMUNITIES',
                  emptyHint: state.query.isEmpty
                      ? 'Nothing matches this filter yet.'
                      : 'Nothing matching "${state.query}".',
                  itemCount: state.communities.length,
                  isLoadingMore: state.isLoadingMore,
                  onLoadMore: cubit.loadMore,
                  itemBuilder: (context, index) {
                    final community = state.communities[index];
                    return _CommunityCard(
                      community: community,
                      busy: state.busySlugs.contains(community.slug),
                      onTap: () => context.pushNamed(
                        RouteNames.community,
                        pathParameters: {'slug': community.slug},
                      ),
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
    return Container(
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surf2,
                  border: Border.all(color: colors.ink, width: 1.5),
                ),
                child: Text(community.emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMd.copyWith(color: colors.ink, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      community.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        '${Formatters.compactCount(community.memberCount)} MEMBERS',
                        if (community.onlineCount != null)
                          '${Formatters.compactCount(community.onlineCount!)} ONLINE',
                      ].join(' · '),
                      style: AppTextStyles.metaMono.copyWith(color: colors.ink3),
                    ),
                  ],
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
        ),
      ),
    );
  }
}

void _openThread(BuildContext context, CommunityPostEntity post) {
  // The thread route takes the entity through `extra` because the backend has
  // no `GET /community-posts/{id}` to rebuild it from an id alone.
  context.pushNamed(
    RouteNames.communityPost,
    pathParameters: {'postId': post.id},
    extra: post,
  );
}
