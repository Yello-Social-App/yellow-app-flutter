import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../domain/entities/project_entity.dart';

/// One project row in the showcase grid.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.onTap,
    required this.onToggleLike,
    this.busy = false,
  });

  final ProjectEntity project;
  final VoidCallback onTap;
  final VoidCallback onToggleLike;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(
          // A featured project is marked by its border rather than a badge or a
          // glow — a blurred shadow on a Cubit-rebuilt widget crashed on this
          // project's Impeller/Android renderer (see CLAUDE.md).
          color: project.isFeatured ? colors.yel : colors.line,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.surf2,
                      border: Border.all(color: colors.ink, width: 1.5),
                      borderRadius: BorderRadius.circular(AppRadii.xs),
                    ),
                    child: Text(project.emoji, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                project.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.titleMd.copyWith(color: colors.ink, fontSize: 16),
                              ),
                            ),
                            if (project.isFeatured) ...[
                              const SizedBox(width: 6),
                              Text(
                                'FEATURED',
                                style: AppTextStyles.metaMono.copyWith(color: colors.yeld, fontSize: 9),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          project.tagline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _LikeButton(
                    likeCount: project.likeCount,
                    isLiked: project.isLiked,
                    busy: busy,
                    onTap: onToggleLike,
                  ),
                ],
              ),
              if (project.tech.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tech in project.tech)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.surf2,
                          border: Border.all(color: colors.line, width: 1),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          tech,
                          style: AppTextStyles.metaMono.copyWith(color: colors.ink2, fontSize: 9),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  AppAvatar(
                    initials: project.authorDisplayName.initials,
                    seed: avatarSeedForId(project.authorId),
                    imageUrl: project.authorAvatarUrl,
                    size: 22,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      project.authorUsername.withAtSign,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    [
                      if (project.starCount != null) '★ ${Formatters.compactCount(project.starCount!)}',
                      '${Formatters.compactCount(project.viewCount)} VIEWS',
                    ].join(' · '),
                    style: AppTextStyles.metaMono.copyWith(color: colors.ink3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.likeCount,
    required this.isLiked,
    required this.busy,
    required this.onTap,
  });

  final int likeCount;
  final bool isLiked;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: isLiked ? colors.yelb : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        side: BorderSide(color: isLiked ? colors.yel : colors.line, width: 1.5),
      ),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 14,
                color: busy ? colors.ink3 : (isLiked ? colors.red : colors.ink2),
              ),
              if (likeCount > 0) ...[
                const SizedBox(width: 5),
                Text(
                  Formatters.compactCount(likeCount),
                  style: AppTextStyles.metaMono.copyWith(color: isLiked ? colors.yeld : colors.ink2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
