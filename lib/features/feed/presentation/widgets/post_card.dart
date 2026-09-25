import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../domain/entities/post_entity.dart';
import 'post_image_carousel.dart';
import 'reaction_glyph.dart';
import 'reaction_picker.dart';

/// One feed card, matching the mockup's post article: text-only posts get
/// the mockup's bold "quote" typography, but as of 2026-09-09 with **no
/// background fill** — the plain text sits directly on the card, and only
/// `#hashtag` words inside it (there's no distinct tags field on the real
/// backend; a hashtag is just plain text a user typed/picked at compose
/// time, see `CreatePostCubit.pickedTags`) get an individual yellow
/// highlight behind just that word, via [_contentSpans]. Posts with
/// `images` get the mockup's photo-card treatment instead.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onOpen,
    required this.onLike,
    required this.onReact,
    required this.onSave,
    required this.onRepost,
    this.onMore,
  });

  final PostEntity post;
  final VoidCallback onOpen;
  final VoidCallback onLike;

  /// The "···" button's tap target. Optional — screens that haven't been
  /// wired up with their own overflow menu yet (Shared posts, Public
  /// profile, own Profile) fall back to [onOpen] so "···" still does
  /// *something* useful (opens the post) instead of nothing. The Feed
  /// screen is the only caller that passes a real one today, opening the
  /// post options sheet in place (copy link / view reactions / edit /
  /// delete) instead of navigating away — see `FeedPage`.
  final VoidCallback? onMore;

  /// Long-press-picker path — sets/switches/removes a specific
  /// [ReactionType] (see [onLike] for the plain single-tap quick-like).
  final ValueChanged<ReactionType> onReact;
  final VoidCallback onSave;

  /// A two-outcome toggle, same shape as [onLike]: reposts if
  /// `post.repostedByMe` is false, cancels (deletes) the viewer's own
  /// repost if it's true — see `FeedCubit.toggleRepost`'s doc for why it
  /// can't be more than a same-session toggle.
  final VoidCallback onRepost;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        // The page background is flat white, same as this card's own fill
        // (`colors.surf`) — without this the hairline border above would be
        // the *only* thing separating a card from the page. The shared
        // two-layer drop shadow is what makes the card read as floating on
        // the page rather than drawn on it; see [AppShadows.card].
        boxShadow: AppShadows.card(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(post: post, onOpen: onOpen, onMore: onMore),
          if (post.isRepost)
            _RepostedLabel(username: post.originalPost!.authorUsername),
          if (!post.hasImages)
            _TextBody(post: post)
          else
            _PhotoBody(post: post),
          if (post.isRepost) RepostedPostPreview(original: post.originalPost!),
          _Actions(
            post: post,
            onLike: onLike,
            onReact: onReact,
            onSave: onSave,
            onRepost: onRepost,
            onOpen: onOpen,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.post,
    required this.onOpen,
    required this.onMore,
  });
  final PostEntity post;
  final VoidCallback onOpen;

  /// See [PostCard.onMore] — null falls back to [onOpen].
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.md),
              onTap: () => context.pushNamed(
                RouteNames.userProfile,
                pathParameters: {'userId': post.authorId},
              ),
              child: Row(
                children: [
                  AppAvatar(
                    initials: post.authorUsername.initials,
                    seed: avatarSeedForId(post.authorId),
                    imageUrl: post.authorAvatarUrl,
                    size: 42,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorUsername,
                          style: AppTextStyles.titleMd.copyWith(
                            color: colors.ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${post.authorUsername} · ${Formatters.relativeShort(post.createdAt)}',
                          style: AppTextStyles.metaMono.copyWith(
                            color: colors.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onMore ?? onOpen,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(CupertinoIcons.ellipsis, color: colors.ink3, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepostedLabel extends StatelessWidget {
  const _RepostedLabel({required this.username});
  final String username;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(
        children: [
          Icon(CupertinoIcons.arrow_2_squarepath, size: 13, color: colors.ink2),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Reposted from @$username',
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Facebook-style "shared post" embed: the original post's author, content
/// and images inside a compact, tappable card nested inside the repost's
/// own card. A repost's own [PostEntity.content]/[PostEntity.hasImages] are
/// almost always empty — this app's repost action (`FeedCubit.toggleRepost`)
/// is a plain one-tap share with no quote/comment compose step — so without
/// this, [PostCard] rendered nothing below the "Reposted from" line for the
/// overwhelming majority of reposts: an empty [_TextBody] and no indication
/// of what was actually shared. Reused as-is by [PostDetailPage] so a
/// repost's detail view isn't missing the same content.
class RepostedPostPreview extends StatelessWidget {
  const RepostedPostPreview({super.key, required this.original});
  final PostEntity original;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Material(
        color: colors.surf,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.pushNamed(
            RouteNames.postDetail,
            pathParameters: {'postId': original.id},
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: colors.line2, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppAvatar(
                      initials: original.authorUsername.initials,
                      seed: avatarSeedForId(original.authorId),
                      imageUrl: original.authorAvatarUrl,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            original.authorUsername,
                            style: AppTextStyles.titleSm.copyWith(
                              color: colors.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            Formatters.relativeShort(original.createdAt),
                            style: AppTextStyles.metaMono.copyWith(
                              color: colors.ink2,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (original.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: _contentSpans(
                        original.content,
                        AppTextStyles.body.copyWith(color: colors.ink),
                        colors.yel,
                      ),
                    ),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (original.hasImages) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    child: PostImageCarousel(
                      imageUrls: original.imageUrls,
                      placeholderHeight: 180,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Matches a `#hashtag` run in post content — see [_contentSpans].
final RegExp _hashtagPattern = RegExp(r'#\w+');

/// Splits [text] on `#hashtag` runs: everything else keeps [style] as-is
/// (no background at all), each hashtag gets that same [style] plus
/// [tagBackground] painted behind just that word.
List<InlineSpan> _contentSpans(
  String text,
  TextStyle style,
  Color tagBackground,
) {
  final spans = <InlineSpan>[];
  var last = 0;
  for (final match in _hashtagPattern.allMatches(text)) {
    if (match.start > last) {
      spans.add(
        TextSpan(text: text.substring(last, match.start), style: style),
      );
    }
    spans.add(
      TextSpan(
        text: match.group(0),
        style: style.copyWith(backgroundColor: tagBackground),
      ),
    );
    last = match.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last), style: style));
  }
  return spans;
}

class _TextBody extends StatelessWidget {
  const _TextBody({required this.post});
  final PostEntity post;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Text.rich(
        TextSpan(
          children: _contentSpans(
            post.content,
            AppTextStyles.body.copyWith(color: colors.ink),
            colors.yel,
          ),
        ),
      ),
    );
  }
}

class _PhotoBody extends StatelessWidget {
  const _PhotoBody({required this.post});
  final PostEntity post;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text.rich(
              TextSpan(
                children: _contentSpans(
                  post.content,
                  AppTextStyles.body.copyWith(color: colors.ink),
                  colors.yel,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          // A single photo keeps the card's width and follows its own
          // aspect ratio (no fixed height); two or more become a swipeable
          // carousel with a page indicator — see [PostImageCarousel].
          //
          // Tapping the photo opens the full-screen zoomable viewer rather
          // than the post (the header, the body text and the comment chip
          // all still open the post) — the photo is cropped to the card
          // here, so "expand it" is the more useful thing for that tap to
          // mean, which is also what every other social app does with it.
          child: Container(
            // The border lives in `foregroundDecoration`, not `decoration`:
            // the photo (`Image.network(..., width: double.infinity)` for a
            // single image) fills this box edge-to-edge, and Container
            // paints `decoration` *behind* the child, so a border put there
            // was fully covered by the image — invisible even though it
            // was technically being drawn. `decoration` still supplies the
            // rounded-rect clip shape; `foregroundDecoration` paints the
            // same-radius border on top of the (clipped) image instead.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            foregroundDecoration: BoxDecoration(
              border: Border.all(color: colors.line, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            clipBehavior: Clip.antiAlias,
            child: PostImageCarousel(imageUrls: post.imageUrls),
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.post,
    required this.onLike,
    required this.onReact,
    required this.onSave,
    required this.onRepost,
    required this.onOpen,
  });

  final PostEntity post;
  final VoidCallback onLike;
  final ValueChanged<ReactionType> onReact;
  final VoidCallback onSave;
  final VoidCallback onRepost;
  final VoidCallback onOpen;

  /// [pillContext] is the like pill's own context, not this row's — the
  /// picker anchors its floating rail to that box (see [showReactionPicker]).
  Future<void> _pickReaction(BuildContext pillContext) async {
    final picked = await showReactionPicker(
      pillContext,
      current: post.viewerReactionType,
    );
    if (picked != null) onReact(picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reacted = post.viewerReactionType;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Wrapped so the long-press picker can anchor to the pill itself —
          // `context` out here is the whole action row, which would float the
          // rail above the comment and repost buttons too.
          Builder(
            builder: (pillContext) => _Pill(
              onTap: onLike,
              onLongPress: () => _pickReaction(pillContext),
              border: reacted != null ? colors.red : colors.line,
              background: reacted != null ? colors.red : Colors.transparent,
              foreground: reacted != null ? Colors.white : colors.ink2,
              label: Formatters.compactCount(post.reactionTotal),
              // Fixed-size slot — see [ReactionGlyph]: the glyph swaps
              // between an icon and an emoji, and sizing the pill to
              // whichever is current made it shrink/grow as it changed.
              iconBuilder: (fg) => ReactionGlyph(reaction: reacted, color: fg, size: 15, animate: true),
            ),
          ),
          const SizedBox(width: 7),
          _Pill(
            onTap: onOpen,
            border: colors.line,
            background: Colors.transparent,
            foreground: colors.ink2,
            label: Formatters.compactCount(post.commentCount),
            iconBuilder: (fg) =>
                Icon(CupertinoIcons.bubble_left, size: 14, color: fg),
          ),
          const SizedBox(width: 7),
          _Pill(
            onTap: onRepost,
            border: post.repostedByMe ? colors.grn : colors.line,
            background: post.repostedByMe ? colors.grn : Colors.transparent,
            foreground: post.repostedByMe ? Colors.white : colors.ink2,
            label: Formatters.compactCount(post.repostCount),
            iconBuilder: (fg) => Icon(CupertinoIcons.arrow_2_squarepath, size: 14, color: fg),
          ),
          const Spacer(),
          _Pill(
            onTap: onSave,
            border: post.savedByMe ? colors.ink : colors.line,
            background: post.savedByMe ? colors.yel : Colors.transparent,
            foreground: post.savedByMe ? colors.onYel : colors.ink2,
            label: post.savedByMe ? 'Saved' : 'Save',
            iconBuilder: (fg) => Icon(
              post.savedByMe ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
              size: 13,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.onTap,
    this.onLongPress,
    required this.border,
    required this.background,
    required this.foreground,
    required this.label,
    required this.iconBuilder,
  });

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color border;
  final Color background;
  final Color foreground;
  final String label;
  final Widget Function(Color) iconBuilder;

  /// Every pill's icon gets the same square slot regardless of the glyph it
  /// draws (icons here range 13–15px, and the like pill's can be an emoji),
  /// so the whole action row keeps one constant height instead of the pills
  /// disagreeing on it — see [ReactionGlyphSlot].
  static const double _iconSlot = 15;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        side: BorderSide(color: border, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReactionGlyphSlot(size: _iconSlot, child: iconBuilder(foreground)),
              const SizedBox(width: 7),
              Text(
                label,
                style: AppTextStyles.button.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
