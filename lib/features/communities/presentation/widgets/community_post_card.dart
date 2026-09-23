import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../feed/domain/entities/post_entity.dart' show ReactionType;
import '../../domain/entities/community_post_entity.dart';
import 'vote_arrow_icon.dart';

/// One thread row, used by both the cross-community timeline and a single
/// community's list.
///
/// The vote column is deliberately separate from the reaction pill: they are
/// two independent server-side signals (votes order `sort=hot|top`, reactions
/// are the same six-way set as a feed post), so collapsing them into one
/// control would silently drop one of them.
class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onVote,
    required this.onReact,
    this.busy = false,
    this.showCommunity = true,
    this.onCommunityTap,
  });

  final CommunityPostEntity post;
  final VoidCallback onTap;
  final void Function(CommunityVote vote) onVote;
  final void Function(ReactionType type) onReact;

  /// A vote or reaction is in flight — both controls go inert so a fast double
  /// tap can't fire two writes whose responses land out of order.
  final bool busy;

  /// Hidden on a community's own screen, where every row is from the same
  /// community and the chip would just repeat the header.
  final bool showCommunity;
  final VoidCallback? onCommunityTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(5, 12, 5, 12),
          child: Row(
            // Centred, not top-aligned: the vote column is about the whole
            // post, so it sits against the middle of the row rather than
            // hanging off the first line of the title.
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _VoteColumn(
                score: post.score,
                vote: post.viewerVote,
                busy: busy,
                onVote: onVote,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (showCommunity) ...[
                          Flexible(
                            child: GestureDetector(
                              onTap: onCommunityTap,
                              child: Text(
                                '${post.community.emoji} ${post.community.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.metaMono.copyWith(
                                  color: colors.ink2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (post.tag.isNotEmpty) _TagPill(tag: post.tag),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleCard.copyWith(
                        color: colors.ink,
                      ),
                    ),
                    if (post.hasBody) ...[
                      const SizedBox(height: 6),
                      Text(
                        post.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(color: colors.ink2),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        AppAvatar(
                          initials: post.authorDisplayName.initials,
                          seed: avatarSeedForId(post.authorId),
                          imageUrl: post.authorAvatarUrl,
                          size: 24,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            post.authorUsername.withAtSign,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.metaMono.copyWith(
                              color: colors.ink2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Formatters.relativeShort(post.createdAt),
                          style: AppTextStyles.metaMono.copyWith(
                            color: colors.ink3,
                          ),
                        ),
                        const Spacer(),
                        _MetaPill(
                          icon: Icons.mode_comment_outlined,
                          label: Formatters.compactCount(post.commentCount),
                        ),
                        const SizedBox(width: 6),
                        _ReactionPill(
                          total: post.reactionTotal,
                          viewerReaction: post.viewerReactionType,
                          busy: busy,
                          onReact: onReact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Up / score / down. Tapping the arrow already lit clears the vote, which is
/// why `CommunityVote.toggledFrom` exists — the endpoint takes an absolute
/// value, so "clear" is a real value (`0`) rather than a second write of the
/// same direction.
class _VoteColumn extends StatelessWidget {
  const _VoteColumn({
    required this.score,
    required this.vote,
    required this.busy,
    required this.onVote,
  });

  final int score;
  final CommunityVote vote;
  final bool busy;
  final void Function(CommunityVote vote) onVote;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      children: [
        _VoteArrow(
          up: true,
          active: vote == CommunityVote.up,
          busy: busy,
          onTap: () => onVote(CommunityVote.up),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            Formatters.compactCount(score),
            style: AppTextStyles.titleSm.copyWith(
              color: switch (vote) {
                CommunityVote.up => colors.yeld,
                CommunityVote.down => colors.red,
                CommunityVote.none => colors.ink2,
              },
            ),
          ),
        ),
        _VoteArrow(
          up: false,
          active: vote == CommunityVote.down,
          busy: busy,
          onTap: () => onVote(CommunityVote.down),
        ),
      ],
    );
  }
}

class _VoteArrow extends StatelessWidget {
  const _VoteArrow({
    required this.up,
    required this.active,
    required this.busy,
    required this.onTap,
  });

  final bool up;
  final bool active;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // No chip behind the arrow: the state is already legible from the artwork
    // itself, outline vs filled. `Material` stays only to give the tap ripple
    // a surface above the card's own background — hence transparent, and
    // never a blurred `BoxShadow`, which crashed this project's
    // Impeller/Android renderer when rebuilt from Cubit state (see CLAUDE.md).
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: busy ? null : onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 30,
          height: 26,
          child: Center(
            child: VoteArrowIcon(
              up: up,
              active: active,
              dimmed: busy,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.yelb,
        border: Border.all(color: colors.line, width: 1),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        tag.toUpperCase(),
        style: AppTextStyles.metaMonoSm.copyWith(color: colors.yeld),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: colors.ink3),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.metaMono.copyWith(color: colors.ink3)),
      ],
    );
  }
}

/// Tap to LIKE, long-press for the full six-type picker — the same gesture
/// split the feed's post card uses, so the reaction affordance is consistent
/// across both kinds of post.
class _ReactionPill extends StatelessWidget {
  const _ReactionPill({
    required this.total,
    required this.viewerReaction,
    required this.busy,
    required this.onReact,
  });

  final int total;
  final ReactionType? viewerReaction;
  final bool busy;
  final void Function(ReactionType type) onReact;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reacted = viewerReaction != null;

    return GestureDetector(
      onTap: busy ? null : () => onReact(viewerReaction ?? ReactionType.like),
      onLongPress: busy ? null : () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: reacted ? colors.yelb : Colors.transparent,
          border: Border.all(
            color: reacted ? colors.yel : colors.line,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          children: [
            Text(
              viewerReaction?.emoji ?? ReactionType.like.emoji,
              style: TextStyle(
                fontSize: 12,
                color: reacted ? null : colors.ink3,
              ),
            ),
            if (total > 0) ...[
              const SizedBox(width: 5),
              Text(
                Formatters.compactCount(total),
                style: AppTextStyles.metaMono.copyWith(
                  color: reacted ? colors.yeld : colors.ink3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    final colors = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surf,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xxl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final type in ReactionType.values)
                GestureDetector(
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onReact(type);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: viewerReaction == type
                          ? colors.yelb
                          : colors.surf2,
                      border: Border.all(
                        color: viewerReaction == type
                            ? colors.yel
                            : colors.line,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      type.emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
