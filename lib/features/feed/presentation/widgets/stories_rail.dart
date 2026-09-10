import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../domain/entities/story_entity.dart';

/// The "STORIES" card at the top of the feed: an add-your-own tile followed
/// by each friend's story ring, matching the mockup's horizontal rail.
class StoriesRail extends StatelessWidget {
  const StoriesRail({super.key, required this.stories, required this.onAddStory, required this.onOpenStory});

  final List<StoryEntity> stories;
  final VoidCallback onAddStory;
  final void Function(int userIndex) onOpenStory;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text('STORIES', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
          ),
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _AddStoryTile(onTap: onAddStory),
                for (var i = 0; i < stories.length; i++) _StoryTile(story: stories[i], onTap: () => onOpenStory(i)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddStoryTile extends StatelessWidget {
  const _AddStoryTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surf2,
                border: Border.all(color: colors.line, width: 1.5, style: BorderStyle.solid),
              ),
              child: Icon(Icons.add, color: colors.ink3, size: 21),
            ),
            const SizedBox(height: 8),
            Text('YOU', style: AppTextStyles.metaMono.copyWith(color: colors.ink2)),
          ],
        ),
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({required this.story, required this.onTap});
  final StoryEntity story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              AppAvatar(
                initials: story.name.initials,
                seed: story.avatarSeed,
                size: 60,
                ringColor: story.seen ? colors.line : colors.yel,
              ),
              const SizedBox(height: 8),
              Text(
                story.firstName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
