import 'package:flutter/cupertino.dart' show CupertinoIcons;
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
import '../bloc/community_detail_cubit.dart';
import '../widgets/community_post_card.dart';
import '../widgets/shimmer_community_post_card.dart';

/// One community: its about/rules header and its threads.
class CommunityDetailPage extends StatelessWidget {
  const CommunityDetailPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Keyed by slug so navigating from one community to another gets its own
      // cubit rather than reusing the first one's posts.
      create: (_) => sl<CommunityDetailCubit>(param1: slug)..load(),
      child: const _CommunityDetailView(),
    );
  }
}

class _CommunityDetailView extends StatelessWidget {
  const _CommunityDetailView();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<CommunityDetailCubit>();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<CommunityDetailCubit, CommunityDetailState>(
          builder: (context, state) {
            final community = state.community;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: Row(
                    children: [
                      AppIconButton(
                        icon: const Icon(CupertinoIcons.back),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          community == null ? 'Community' : '${community.emoji}  ${community.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleLg.copyWith(color: colors.ink),
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
                      isLoading: state.status == CommunityDetailStatus.loading && community == null,
                      errorMessage: state.status == CommunityDetailStatus.error
                          ? (state.errorMessage ?? 'Could not load this community.')
                          : null,
                      onRetry: cubit.refresh,
                      isEmpty: state.status == CommunityDetailStatus.loaded && state.posts.isEmpty,
                      emptyTitle: 'NO THREADS YET',
                      emptyHint: state.canPost
                          ? 'Start the first one.'
                          : 'Join this community to start a thread.',
                      skeleton: const [
                        ShimmerCommunityPostCard(showCommunity: false),
                        ShimmerCommunityPostCard(showCommunity: false, hasBody: false),
                      ],
                      header: community == null
                          ? null
                          : _Header(
                              community: community,
                              sort: state.sort,
                              membershipBusy: state.membershipBusy,
                              onToggleMembership: cubit.toggleMembership,
                              onSort: cubit.setSort,
                              onCompose: () => _compose(context, community),
                            ),
                      itemCount: state.posts.length,
                      isLoadingMore: state.isLoadingMore,
                      onLoadMore: cubit.loadMore,
                      itemBuilder: (context, index) {
                        final post = state.posts[index];
                        return CommunityPostCard(
                          post: post,
                          busy: state.busyIds.contains(post.id),
                          // Every row is from this community, so the chip would
                          // just repeat the header above it.
                          showCommunity: false,
                          onTap: () => _openThread(context, cubit, post),
                          onVote: (vote) => cubit.toggleVote(post, vote),
                          onReact: (type) => cubit.react(post, type),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openThread(
    BuildContext context,
    CommunityDetailCubit cubit,
    CommunityPostEntity post,
  ) async {
    final updated = await context.pushNamed<CommunityPostEntity>(
      RouteNames.communityPost,
      pathParameters: {'postId': post.id},
      extra: post,
    );
    // The thread screen pops with whatever it ended up holding, so a vote,
    // reaction or new comment made in there lands back on this row instead of
    // leaving a stale score behind.
    if (updated != null) cubit.applyUpdated(updated);
  }

  Future<void> _compose(BuildContext context, CommunityEntity community) async {
    final cubit = context.read<CommunityDetailCubit>();
    final created = await context.pushNamed<CommunityPostEntity>(
      RouteNames.createCommunityPost,
      pathParameters: {'slug': community.slug},
      extra: community,
    );
    if (created != null) cubit.prepend(created);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.community,
    required this.sort,
    required this.membershipBusy,
    required this.onToggleMembership,
    required this.onSort,
    required this.onCompose,
  });

  final CommunityEntity community;
  final CommunityPostSort sort;
  final bool membershipBusy;
  final VoidCallback onToggleMembership;
  final void Function(CommunityPostSort sort) onSort;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surf,
            border: Border.all(color: colors.line, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            boxShadow: AppShadows.card(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      community.tagline,
                      style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    label: community.isMember ? 'Leave' : 'Join',
                    variant: community.isMember ? AppButtonVariant.outline : AppButtonVariant.primary,
                    dense: true,
                    onPressed: membershipBusy ? null : onToggleMembership,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                [
                  '${Formatters.compactCount(community.memberCount)} MEMBERS',
                  if (community.onlineCount != null)
                    '${Formatters.compactCount(community.onlineCount!)} ONLINE',
                  'SINCE ${community.createdAt.year}',
                ].join(' · '),
                style: AppTextStyles.metaMono.copyWith(color: colors.ink3),
              ),
              if (community.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  community.description,
                  style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                ),
              ],
              if (community.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in community.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.surf2,
                          border: Border.all(color: colors.line, width: 1),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          tag.toUpperCase(),
                          style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2),
                        ),
                      ),
                  ],
                ),
              ],
              if (community.rules.isNotEmpty) ...[
                const SizedBox(height: 4),
                Theme(
                  // The default ExpansionTile draws its own dividers and
                  // indents, which fight this card's flat hand-drawn styling.
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 4),
                    title: Text(
                      'HOUSE RULES · ${community.rules.length}',
                      style: AppTextStyles.eyebrow.copyWith(color: colors.ink2),
                    ),
                    iconColor: colors.ink2,
                    collapsedIconColor: colors.ink2,
                    children: [
                      for (var i = 0; i < community.rules.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${i + 1}.',
                                style: AppTextStyles.metaMono.copyWith(color: colors.ink3),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  community.rules[i],
                                  style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final value in CommunityPostSort.values) ...[
              FilterChipPill(
                label: value.label,
                selected: sort == value,
                onTap: () => onSort(value),
              ),
              const SizedBox(width: 6),
            ],
            const Spacer(),
            // Posting is gated on membership server-side
            // (`403 COMMUNITY_MEMBERSHIP_REQUIRED`), so the entry point is
            // hidden for a non-member rather than shown and then rejected.
            if (community.isMember)
              AppButton(
                label: 'New thread',
                dense: true,
                icon: const Icon(CupertinoIcons.add, size: 14),
                onPressed: onCompose,
              ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}
