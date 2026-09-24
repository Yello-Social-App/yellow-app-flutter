import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/app_warning_dialog.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/filter_chip_pill.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../domain/entities/story_entity.dart';
import '../bloc/story_archive_cubit.dart';
import '../widgets/story_background.dart';
import '../widgets/story_viewers_sheet.dart';

/// Account menu → Story archive.
///
/// Stories are not deleted when they expire — they stay here, readable by
/// nobody but you, until you delete them. Grouped by the day they were
/// posted, which the endpoint explicitly leaves to the client.
class StoryArchivePage extends StatelessWidget {
  const StoryArchivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<StoryArchiveCubit>()..load(),
      child: const _StoryArchiveView(),
    );
  }
}

class _StoryArchiveView extends StatelessWidget {
  const _StoryArchiveView();

  Future<void> _delete(BuildContext context, StoryEntity story) async {
    final cubit = context.read<StoryArchiveCubit>();
    final confirmed = await AppWarningDialog.show(
      context,
      title: 'Delete this story?',
      message: 'It leaves your archive for good. If it is still live, it disappears for everyone too.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline,
    );
    if (!confirmed || !context.mounted) return;
    final error = await cubit.delete(story.id);
    if (!context.mounted || error == null) return;
    AppStatusSnackbar.showError(context, message: error);
  }

  /// `from`/`to` are inclusive UTC **calendar days** server-side, so the
  /// picker's local dates go through as-is and the data source formats them
  /// — see `StoryRemoteDataSourceImpl._day`.
  Future<void> _pickDateRange(BuildContext context, StoryArchiveState state) async {
    final cubit = context.read<StoryArchiveCubit>();
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      // Yello has no stories older than the account, but there is no cheap
      // way to know that date here — a year back covers every real archive
      // and keeps the picker navigable.
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: state.hasDateRange ? DateTimeRange(start: state.from!, end: state.to!) : null,
    );
    if (range == null) return;
    await cubit.setDateRange(range.start, range.end);
  }

  static String _shortDate(DateTime date) => '${date.month}/${date.day}';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<StoryArchiveCubit>();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: BlocBuilder<StoryArchiveCubit, StoryArchiveState>(
          builder: (context, state) {
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 400) cubit.loadMore();
                return false;
              },
              child: RefreshIndicator(
                onRefresh: cubit.load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                  children: [
                    Row(
                      children: [
                        AppIconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 12),
                        Text('Story archive', style: AppTextStyles.titleLg.copyWith(color: colors.ink)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Every story you have posted, including the ones that have expired. Only you can see this.',
                      style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChipPill(
                            label: 'All',
                            selected: state.typeFilter == null,
                            onTap: () => cubit.setTypeFilter(null),
                          ),
                          const SizedBox(width: 8),
                          FilterChipPill(
                            label: 'Photos',
                            selected: state.typeFilter == StoryType.image,
                            onTap: () => cubit.setTypeFilter(StoryType.image),
                          ),
                          const SizedBox(width: 8),
                          FilterChipPill(
                            label: 'Text',
                            selected: state.typeFilter == StoryType.text,
                            onTap: () => cubit.setTypeFilter(StoryType.text),
                          ),
                          const SizedBox(width: 8),
                          FilterChipPill(
                            label: state.hasDateRange
                                ? '${_shortDate(state.from!)} – ${_shortDate(state.to!)}'
                                : 'Any date',
                            selected: state.hasDateRange,
                            onTap: () => _pickDateRange(context, state),
                          ),
                          if (state.hasDateRange) ...[
                            const SizedBox(width: 8),
                            FilterChipPill(
                              label: 'Clear',
                              selected: false,
                              onTap: () => cubit.setDateRange(null, null),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    ..._body(context, state),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, StoryArchiveState state) {
    final colors = AppColors.of(context);
    final cubit = context.read<StoryArchiveCubit>();

    if (state.status == StoryArchiveStatus.loading) {
      return const [ShimmerListCard(), SizedBox(height: 10), ShimmerListCard()];
    }
    if (state.status == StoryArchiveStatus.error) {
      return [
        ErrorView(message: state.errorMessage ?? 'Could not load your archive.', onRetry: cubit.load),
      ];
    }
    if (state.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              Icon(Icons.auto_stories_outlined, size: 40, color: colors.ink3),
              const SizedBox(height: 14),
              Text('Nothing here yet', style: AppTextStyles.body.copyWith(color: colors.ink)),
              const SizedBox(height: 6),
              Text(
                state.typeFilter == null && !state.hasDateRange
                    ? 'Stories you post show up here once they expire.'
                    : 'Nothing matches those filters.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      for (final day in state.days) ...[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(_dayLabel(day.day), style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
        ),
        for (final story in day.stories) ...[
          _ArchiveRow(
            story: story,
            onDelete: () => _delete(context, story),
            onViewers: () => showStoryViewersSheet(
              context,
              storyId: story.id,
              viewCount: story.viewCount ?? 0,
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
      ],
      if (state.isLoadingMore)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
    ];
  }

  static String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    final label = '${months[day.month - 1]} ${day.day}';
    return day.year == now.year ? label : '$label ${day.year}';
  }
}

class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow({required this.story, required this.onDelete, required this.onViewers});

  final StoryEntity story;
  final VoidCallback onDelete;
  final VoidCallback onViewers;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final count = story.viewCount ?? 0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          _Thumbnail(story: story),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  story.hasText ? story.text! : 'Photo story',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(color: colors.ink),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      Formatters.relativeShort(story.createdAt),
                      style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      story.visibility == StoryVisibility.public ? Icons.public : Icons.group_outlined,
                      size: 12,
                      color: colors.ink3,
                    ),
                    if (!story.isExpired) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.yelb,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text('LIVE', style: AppTextStyles.metaMonoSm.copyWith(color: colors.yeld)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onViewers,
            child: Text(
              // `viewCount` outlives the names it was counted from — the
              // viewer list is dropped 48 h after posting, so an older row
              // still shows a number with an empty sheet behind it.
              count == 0 ? 'No views' : Formatters.compactCount(count),
              style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2),
            ),
          ),
          AppIconButton(
            icon: Icon(Icons.delete_outline, color: colors.ink2, size: 18),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.story});

  final StoryEntity story;

  static const double _size = 52;

  @override
  Widget build(BuildContext context) {
    final image = story.image;
    final radius = BorderRadius.circular(AppRadii.md);

    if (story.isImage && image != null) {
      return ClipRRect(
        borderRadius: radius,
        child: CachedNetworkImage(
          imageUrl: image.url,
          cacheKey: image.cacheKey,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          // A 52pt tile decoded at the full 1080x1920 source costs ~8 MB of
          // memory each; cap the decode at the displayed size (x3 for the
          // densest screens this ships to).
          memCacheWidth: (_size * 3).round(),
          memCacheHeight: (_size * 3).round(),
          placeholder: (_, _) => const ShimmerBox(width: _size, height: _size),
          errorWidget: (_, _, _) => SizedBox(
            width: _size,
            height: _size,
            child: Icon(Icons.broken_image_outlined, size: 18, color: AppColors.of(context).ink3),
          ),
        ),
      );
    }

    return StoryCoverSwatch(
      background: story.background ?? StoryBackground.cover0,
      size: _size,
      borderRadius: radius,
      child: Icon(Icons.text_fields, size: 18, color: storyBackgroundForeground(story.background)),
    );
  }
}
