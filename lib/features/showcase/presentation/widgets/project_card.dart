import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../domain/entities/project_entity.dart';

/// How many tech tags a card shows before folding the rest into a "+N" pill.
/// A project may carry up to [kProjectTechMaxCount]; six pills wrap into a
/// ragged second row on a 360dp phone, three plus a count stay on one line.
const int kProjectCardTechVisible = 3;

/// One project row in the showcase grid.
///
/// Two shapes from one entity. A **featured** project gets a hero: a
/// `yelb`-tinted band holding the FEATURED pill, the name on its own line and
/// a larger emoji tile, with the tagline, tech and footer below. Everything
/// else is the standard card — tile, name and tagline side by side, then tech,
/// then the footer. The footer is the same on both: author on the left; like
/// pill, view count and — when the backend resolved one — the upstream star
/// count on the right. Repo and live links stay on the detail screen: without
/// `url_launcher` a card button could only copy them, and the footer has no
/// room to spare at 320dp.
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

    final radius = BorderRadius.circular(AppRadii.xl);

    return Container(
      decoration: BoxDecoration(
        color: colors.surf,
        // The drop shadow is the static, shared token (ADR-012) — never an
        // animated glow, see `docs/GOTCHAS.md`.
        borderRadius: radius,
        boxShadow: AppShadows.card(context),
      ),
      // A featured project used to be marked by a yellow border; the tinted
      // band inside the hero layout now carries that, so the chrome is the
      // same hairline on every card. It lives in `foregroundDecoration`, not
      // `decoration`: Container paints `decoration` *behind* the child, and
      // the featured band fills the card edge-to-edge, so a border there was
      // covered along the top and sides of the band (the standard card only
      // got away with it because its 14px padding never reaches the edge).
      // Same fix as the photo frame in `post_card.dart`.
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: radius,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: project.isFeatured
            ? _buildFeatured(context)
            : _buildStandard(context),
      ),
    );
  }

  Widget _buildFeatured(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: colors.yelb,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FeaturedPill(),
                    const SizedBox(height: 8),
                    Text(
                      project.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleLg.copyWith(
                        color: colors.ink,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _EmojiTile(
                emoji: project.emoji,
                size: 56,
                radius: AppRadii.sm,
                color: colors.surf,
                borderColor: colors.line2,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project.tagline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMd.copyWith(color: colors.ink2),
              ),
              if (project.tech.isNotEmpty) ...[
                const SizedBox(height: 12),
                _TechPills(tech: project.tech),
              ],
              const SizedBox(height: 12),
              _Footer(project: project, busy: busy, onToggleLike: onToggleLike),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStandard(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EmojiTile(
                emoji: project.emoji,
                size: 44,
                radius: AppRadii.xs,
                color: colors.surf2,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleCard.copyWith(
                        color: colors.ink,
                      ),
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
            ],
          ),
          if (project.tech.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TechPills(tech: project.tech),
          ],
          const SizedBox(height: 12),
          _Footer(project: project, busy: busy, onToggleLike: onToggleLike),
        ],
      ),
    );
  }
}

class _EmojiTile extends StatelessWidget {
  const _EmojiTile({
    required this.emoji,
    required this.size,
    required this.radius,
    required this.color,
    this.borderColor,
  });

  final String emoji;
  final double size;
  final double radius;
  final Color color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 1),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size / 2)),
    );
  }
}

class _FeaturedPill extends StatelessWidget {
  const _FeaturedPill();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 8, 4),
      decoration: BoxDecoration(
        color: colors.yel,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 11, color: colors.onYel),
          const SizedBox(width: 3),
          Text(
            'FEATURED',
            style: AppTextStyles.metaMonoSm.copyWith(
              color: colors.onYel,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The first [kProjectCardTechVisible] tags as pills, then one "+N" pill for
/// whatever is left — the detail screen lists them all.
class _TechPills extends StatelessWidget {
  const _TechPills({required this.tech});

  final List<String> tech;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final visible = tech.take(kProjectCardTechVisible).toList();
    final hidden = tech.length - visible.length;
    final style = AppTextStyles.metaMonoSm.copyWith(color: colors.ink2);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final name in visible)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.surf2,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(name, style: style),
          ),
        if (hidden > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: colors.line, width: 1),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text('+$hidden', style: style),
          ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.project,
    required this.busy,
    required this.onToggleLike,
  });

  final ProjectEntity project;
  final bool busy;
  final VoidCallback onToggleLike;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Row(
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
        _LikeButton(
          likeCount: project.likeCount,
          isLiked: project.isLiked,
          busy: busy,
          onTap: onToggleLike,
        ),
        const SizedBox(width: 8),
        _Stat(
          icon: Icons.visibility_outlined,
          value: project.viewCount,
          semanticsLabel: 'views',
        ),
        if (project.starCount != null) ...[
          const SizedBox(width: 8),
          _Stat(
            icon: Icons.star_border_rounded,
            value: project.starCount!,
            semanticsLabel: 'stars',
          ),
        ],
      ],
    );
  }
}

/// An icon and a compact count — views, upstream stars.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.semanticsLabel,
  });

  final IconData icon;
  final int value;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      label: '${Formatters.compactCount(value)} $semanticsLabel',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.ink2),
          const SizedBox(width: 4),
          Text(
            Formatters.compactCount(value),
            style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
          ),
        ],
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 14,
                color: busy ? colors.ink3 : (isLiked ? colors.red : colors.ink),
              ),
              if (likeCount > 0) ...[
                const SizedBox(width: 5),
                Text(
                  Formatters.compactCount(likeCount),
                  style: AppTextStyles.metaMono.copyWith(
                    color: isLiked ? colors.yeld : colors.ink,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
