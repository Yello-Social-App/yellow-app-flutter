import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../feed/domain/entities/post_entity.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../bloc/shared_posts_cubit.dart';

/// Full-screen list of the signed-in user's shared (reposted) posts —
/// pushed from Profile's stats row (see `profile_page.dart`'s Shared
/// `_StatTile`), the same "tap a stat, get a whole screen" pattern the
/// Connections tile already uses for Circle. Same content as Profile's
/// in-page "Shared" tab, just as its own screen rather than an in-page
/// filter.
class SharedPostsPage extends StatelessWidget {
  const SharedPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => sl<SharedPostsCubit>()..load(), child: const _SharedPostsView());
  }
}

class _SharedPostsView extends StatelessWidget {
  const _SharedPostsView();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<SharedPostsCubit>();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              child: Row(
                children: [
                  AppIconButton(
                    icon: const Icon(CupertinoIcons.back),
                    size: 38,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 11),
                  Text('SHARED', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                ],
              ),
            ),
            Container(height: 1.5, color: colors.line),
            Expanded(
              child: BlocBuilder<SharedPostsCubit, SharedPostsState>(
                builder: (context, state) {
                  return switch (state.status) {
                    SharedPostsStatus.loading => const Center(child: CircularProgressIndicator()),
                    SharedPostsStatus.error => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: ErrorView(
                          message: state.errorMessage ?? 'Could not load your shared posts.',
                          onRetry: cubit.load,
                        ),
                      ),
                    ),
                    SharedPostsStatus.loaded when state.posts.isEmpty => Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.line, width: 1.5),
                            borderRadius: BorderRadius.circular(AppRadii.xl),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('NOTHING SHARED YET', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                              const SizedBox(height: 8),
                              Text(
                                'Repost something from your feed and it lands here.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SharedPostsStatus.loaded => RefreshIndicator(
                      onRefresh: cubit.load,
                      color: colors.ink,
                      backgroundColor: colors.surf,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                        children: [
                          for (final post in state.posts)
                            PostCard(
                              post: post,
                              onOpen: () => _openPost(context, cubit, post.id),
                              onLike: () => cubit.toggleLike(post),
                              onReact: (type) => cubit.react(post, type),
                              onSave: () => cubit.toggleSave(post.id),
                              onRepost: () => cubit.toggleRepost(post),
                            ),
                        ],
                      ),
                    ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the post's own screen and applies whatever it pops back onto this
/// row — a reaction or a comment made in there changes counts the card here
/// shows, and nothing re-fetches this list on the way back. See ADR-032.
Future<void> _openPost(BuildContext context, SharedPostsCubit cubit, String postId) async {
  final updated = await context.pushNamed<PostEntity>(RouteNames.postDetail, pathParameters: {'postId': postId});
  if (updated != null) cubit.applyUpdated(updated);
}
