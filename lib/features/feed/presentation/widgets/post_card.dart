import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_style.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/linked_text.dart';
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
/// highlight behind just that word, via [LinkedText]. Posts with `images`
/// are photo-first instead: the photo fills the top of the card with the
/// header and caption laid over it ([_PhotoBody]).
///
/// Links in the body are tappable and open in the phone's browser, and each
/// one gets an Open Graph card under the text — [LinkPreviewList], ADR-039.
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
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        // The page background is flat white, same as this card's own fill
        // (`colors.surf`) — without this the hairline border below would be
        // the *only* thing separating a card from the page. The shared
        // two-layer drop shadow is what makes the card read as floating on
        // the page rather than drawn on it; see [AppShadows.card].
        boxShadow: AppShadows.card(context),
      ),
      // In the foreground: a photo post's photo runs to the card's top and
      // side edges, and a border in `decoration` would be painted under it
      // (docs/GOTCHAS.md, "A Container border disappears…").
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: colors.line, width: AppStyle.of(context).outlined ? 2 : 1),
        borderRadius: BorderRadius.circular(AppRadii.xxl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.hasImages)
            _PhotoBody(
              post: post,
              onOpen: onOpen,
              onMore: onMore,
              onLike: onLike,
            )
          else
            _Header(post: post, onOpen: onOpen, onMore: onMore),
          if (post.isRepost)
            _RepostedLabel(
              username: post.originalPost!.authorUsername,
              topPadding: post.hasImages ? 12 : 0,
            ),
          if (!post.hasImages) _TextBody(post: post),
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
    this.onPhoto = false,
  });
  final PostEntity post;
  final VoidCallback onOpen;

  /// See [PostCard.onMore] — null falls back to [onOpen].
  final VoidCallback? onMore;

  /// Laid over a photo (see [_PhotoBody]): white text and glyph over the
  /// photo's darkened top edge instead of the palette's ink.
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final nameColor = onPhoto ? Colors.white : colors.ink;
    final metaColor = onPhoto
        ? Colors.white.withValues(alpha: 0.8)
        : colors.ink2;
    final moreColor = onPhoto ? Colors.white : colors.ink3;
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
                            color: nameColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${post.authorUsername} · ${Formatters.relativeShort(post.createdAt)}',
                          style: AppTextStyles.metaMono.copyWith(
                            color: metaColor,
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
                child: Icon(
                  CupertinoIcons.ellipsis,
                  color: moreColor,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepostedLabel extends StatelessWidget {
  const _RepostedLabel({required this.username, this.topPadding = 0});
  final String username;

  /// Zero under the header, which brings its own bottom padding; a photo
  /// post's photo has none, so the label needs its own gap there.
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(14, topPadding, 14, 10),
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
                  // No link cards inside the embed — it is already a card
                  // inside a card, and the text is capped at six lines. The
                  // links themselves still open.
                  LinkedText(
                    text: original.content,
                    style: AppTextStyles.body.copyWith(color: colors.ink),
                    tagBackground: colors.yel,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    showLinkPreviews: false,
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

class _TextBody extends StatelessWidget {
  const _TextBody({required this.post});
  final PostEntity post;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: LinkedText(
            text: post.content,
            style: AppTextStyles.body.copyWith(color: colors.ink),
            tagBackground: colors.yel,
          ),
        ),
      ],
    );
  }
}

/// A photo post: the photo runs edge to edge across the top of the card, the
/// author header is laid over its top edge and the caption over its bottom
/// edge, each on a dark gradient so white text reads over any photo. Text-only
/// posts keep the plain [_Header] + [_TextBody] layout.
///
/// Tapping the photo opens the full-screen viewer ([PostImageCarousel]) and
/// double-tapping it likes the post; the header opens the author, and the
/// caption — capped at three lines here — opens the post, where it is shown
/// in full with its link cards.
class _PhotoBody extends StatefulWidget {
  const _PhotoBody({
    required this.post,
    required this.onOpen,
    required this.onMore,
    required this.onLike,
  });
  final PostEntity post;
  final VoidCallback onOpen;
  final VoidCallback? onMore;

  /// The action row's quick-like toggle — see [_PhotoBodyState._likeFromPhoto]
  /// for why a double-tap only ever calls it to like, never to unlike.
  final VoidCallback onLike;

  /// A single photo keeps its own aspect ratio between these bounds, cropped
  /// to fit outside them: tall enough that the header and a caption never
  /// meet over a short panorama, and no taller than 4:5 so one long
  /// screenshot doesn't fill the screen.
  static const double _minHeight = 240;
  static const double _maxHeightPerWidth = 1.25;

  /// Clears the header (14 + 42 avatar + 12) for the multi-photo count badge.
  static const double _belowHeader = 70;

  @override
  State<_PhotoBody> createState() => _PhotoBodyState();
}

class _PhotoBodyState extends State<_PhotoBody>
    with SingleTickerProviderStateMixin {
  /// Created on the first double-tap, not per card: most photo cards
  /// scrolling past are never double-tapped.
  AnimationController? _heart;

  @override
  void dispose() {
    _heart?.dispose();
    super.dispose();
  }

  /// Double-tap likes, the way every photo feed does it: it never takes a
  /// reaction away, and it never swaps one the viewer picked (a "haha" stays
  /// a "haha"). Only a post with no reaction yet goes through [onLike]; the
  /// heart plays either way, so the tap still reads as registered. A second
  /// double-tap while the first like is in flight sees the optimistic
  /// reaction and skips, and [FeedCubit.toggleLike]'s pending set guards the
  /// rest.
  void _likeFromPhoto() {
    if (widget.post.viewerReactionType == null) widget.onLike();
    final heart = _heart ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..addListener(() => setState(() {}));
    heart.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final heart = _heart;
    final multi = post.imageUrls.length > 1;
    final hasCaption = post.content.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints.tightFor(width: width).copyWith(
                minHeight: _PhotoBody._minHeight,
                maxHeight: width * _PhotoBody._maxHeightPerWidth,
              ),
              // Dark behind the photo so the white header still reads while
              // the image is loading.
              child: ColoredBox(
                color: Colors.black,
                child: PostImageCarousel(
                  imageUrls: post.imageUrls,
                  // Square carousel for two or more photos.
                  placeholderHeight: width,
                  chromePadding: const EdgeInsets.fromLTRB(
                    14,
                    _PhotoBody._belowHeader,
                    0,
                    12,
                  ),
                  onDoubleTap: _likeFromPhoto,
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.black.withValues(alpha: 0),
                        if (hasCaption) ...[
                          Colors.black.withValues(alpha: 0),
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ],
                      stops: hasCaption
                          ? const [0, 0.3, 0.5, 1]
                          : const [0, 0.3],
                    ),
                  ),
                ),
              ),
            ),
            if (heart != null && heart.isAnimating)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(child: _HeartBurst(progress: heart.value)),
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              // Transparency so the header's ink ripples paint over the
              // photo rather than on the card's Material underneath it.
              child: Material(
                type: MaterialType.transparency,
                child: _Header(
                  post: post,
                  onOpen: widget.onOpen,
                  onMore: widget.onMore,
                  onPhoto: true,
                ),
              ),
            ),
            if (hasCaption)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: widget.onOpen,
                  child: Padding(
                    // Lifted clear of the carousel's dot row on multi-photo
                    // posts.
                    padding: EdgeInsets.fromLTRB(14, 0, 14, multi ? 14 : 14),
                    // White links (the underline carries the affordance) and
                    // no hashtag highlight: the palette's yellows are picked
                    // for the card's own fill, not for a darkened photo.
                    child: LinkedText(
                      text: post.content,
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      linkColor: Colors.white,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      showLinkPreviews: false,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The heart that pops over a photo on double-tap: springs in past full
/// size, settles, holds, then shrinks and fades. Plain transforms and
/// opacity only — no blurred shadow for legibility, since it redraws every
/// frame of the animation (docs/GOTCHAS.md, the Impeller `BoxShadow` crash).
class _HeartBurst extends StatelessWidget {
  const _HeartBurst({required this.progress});

  /// 0..1 through the burst.
  final double progress;

  static final Animatable<double> _scale = TweenSequence([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.2,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.2,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 15,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 35),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.6,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 25,
    ),
  ]);

  static final Animatable<double> _opacity = TweenSequence([
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 75),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
  ]);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _opacity.transform(progress),
      child: Transform.scale(
        scale: _scale.transform(progress),
        child: const Icon(
          CupertinoIcons.heart_fill,
          color: Colors.white,
          size: 96,
        ),
      ),
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
              iconBuilder: (fg) => ReactionGlyph(
                reaction: reacted,
                color: fg,
                size: 15,
                animate: true,
              ),
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
            iconBuilder: (fg) =>
                Icon(CupertinoIcons.arrow_2_squarepath, size: 14, color: fg),
          ),
          const Spacer(),
          _Pill(
            onTap: onSave,
            border: post.savedByMe ? colors.ink : colors.line,
            background: post.savedByMe ? colors.yel : Colors.transparent,
            foreground: post.savedByMe ? colors.onYel : colors.ink2,
            label: post.savedByMe ? 'Saved' : 'Save',
            iconBuilder: (fg) => Icon(
              post.savedByMe
                  ? CupertinoIcons.bookmark_fill
                  : CupertinoIcons.bookmark,
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
    final colors = AppColors.of(context);
    final style = AppStyle.of(context);
    // Under ink outline every chip is drawn in ink, and a filled (active) one
    // — reacted, reposted, saved — lifts on a small hard shadow.
    final filled = background != Colors.transparent;
    final pill = Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        side: BorderSide(color: style.outlined ? colors.ink : border, width: style.borderWidth),
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
              ReactionGlyphSlot(
                size: _iconSlot,
                child: iconBuilder(foreground),
              ),
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
    if (!style.outlined || !filled) return pill;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: style.hardShadow(colors, AppStyle.chipOffset),
      ),
      child: pill,
    );
  }
}
