import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../domain/entities/story_entity.dart';
import '../bloc/story_viewers_cubit.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// "Seen by" for a story you own.
///
/// [viewCount] comes from the story itself and outlives the names: the
/// viewer *list* is deleted 48 h after posting while the count is kept, so
/// an older archived story legitimately shows "Seen by 23" with nothing
/// under it. That is the empty state here, not an error.
Future<void> showStoryViewersSheet(
  BuildContext context, {
  required String storyId,
  required int viewCount,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // Same reason as `showPostOptionsSheet`: this opens from a full-screen
    // page pushed on the root navigator, and a sheet on a nested one would
    // render behind the shell chrome.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.of(context).surf,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (_) => BlocProvider(
      create: (_) => sl<StoryViewersCubit>()..load(storyId),
      child: _StoryViewersSheet(viewCount: viewCount),
    ),
  );
}

class _StoryViewersSheet extends StatelessWidget {
  const _StoryViewersSheet({required this.viewCount});

  final int viewCount;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 80,
            height: 4,
            decoration: BoxDecoration(color: colors.line, borderRadius: BorderRadius.circular(AppRadii.pill)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: Row(
              children: [
                Icon(CupertinoIcons.eye, size: 18, color: colors.ink2),
                const SizedBox(width: 8),
                Text(
                  viewCount == 1 ? 'Seen by 1 person' : 'Seen by $viewCount people',
                  style: AppTextStyles.body.copyWith(color: colors.ink, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.line),
          Expanded(
            child: BlocBuilder<StoryViewersCubit, StoryViewersState>(
              builder: (context, state) => _body(context, state, scrollController),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, StoryViewersState state, ScrollController controller) {
    final colors = AppColors.of(context);
    final cubit = context.read<StoryViewersCubit>();

    if (state.status == StoryViewersStatus.loading) {
      return ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // ListTile's two-line shape: 72px tall, 16/24 side padding.
          for (final width in const [118.0, 92.0, 136.0, 104.0, 124.0])
            ShimmerListTile(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 24, 16),
              gap: 16,
              titleWidth: width,
              subtitleWidth: 70,
              subtitleHeight: 9,
              trailing: const ShimmerBox(width: 24, height: 9),
            ),
        ],
      );
    }
    if (state.status == StoryViewersStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.errorMessage ?? 'Could not load who has seen this.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: colors.ink2),
          ),
        ),
      );
    }
    if (state.viewers.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: viewCount > 0
            // The count survived; the names did not.
            ? const EmptyStateCard(
                title: 'NAMES EXPIRED',
                hint: 'The list of names is only kept for 48 hours after posting.',
              )
            : const EmptyStateCard(title: 'NO VIEWS YET', hint: 'No one has seen this yet.'),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 300) cubit.loadMore();
        return false;
      },
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: state.viewers.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.viewers.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _ViewerRow(viewer: state.viewers[index]);
        },
      ),
    );
  }
}

class _ViewerRow extends StatelessWidget {
  const _ViewerRow({required this.viewer});

  final StoryViewerEntity viewer;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final user = viewer.user;
    return ListTile(
      leading: AppAvatar(
        initials: user.displayName.initials,
        seed: avatarSeedForId(user.id),
        size: 40,
        imageUrl: user.avatarUrl,
      ),
      title: Text(user.displayName, style: AppTextStyles.body.copyWith(color: colors.ink)),
      subtitle: Text('@${user.username}', style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3)),
      trailing: Text(
        Formatters.relativeShort(viewer.viewedAt),
        style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3),
      ),
    );
  }
}
