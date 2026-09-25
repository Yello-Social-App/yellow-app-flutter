import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../feed/domain/entities/story_entity.dart';
import '../../../feed/presentation/bloc/story_preview_cubit.dart';
import '../../../feed/presentation/widgets/story_background.dart';
import '../../domain/entities/message_entity.dart';

/// The "Replied to your story" block above a story reply's text.
///
/// Chat stores only a reference, so this fetches the story itself
/// (`GET /v1/stories/{id}`) through the shared [StoryPreviewCubit] cache.
/// Three outcomes, per the contract:
///
///  * the story loads → a thumbnail (photo) or its cover (text);
///  * it is expired and the viewer is not its author → the placeholder,
///    with no request spent;
///  * the fetch 404s → the same placeholder, and never asked again.
class StoryReplyPreview extends StatefulWidget {
  const StoryReplyPreview({
    super.key,
    required this.storyReply,
    required this.fromMe,
    required this.viewerId,
    required this.onYellow,
  });

  final StoryReplyEntity storyReply;

  /// The viewer sent this reply — "Replied to their story" rather than
  /// "Replied to your story".
  final bool fromMe;

  /// The signed-in user's id, for deciding whether an expired story can
  /// still be loaded (its author reads it from their archive).
  final String? viewerId;

  /// This sits inside the viewer's own yellow bubble, which needs ink copy
  /// instead of the surface's.
  final bool onYellow;

  @override
  State<StoryReplyPreview> createState() => _StoryReplyPreviewState();
}

class _StoryReplyPreviewState extends State<StoryReplyPreview> {
  late final StoryPreviewCubit _cache = sl<StoryPreviewCubit>();

  @override
  void initState() {
    super.initState();
    _cache.load(widget.storyReply.storyId, canLoad: widget.storyReply.canStillLoad(widget.viewerId));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final foreground = widget.onYellow ? colors.onYel : colors.ink;
    final muted = widget.onYellow ? colors.onYel.withValues(alpha: 0.7) : colors.ink2;

    return BlocBuilder<StoryPreviewCubit, StoryPreviewState>(
      // Explicit `bloc:` rather than a provider — this is a shared
      // singleton cache, not conversation-scoped state, and nothing above
      // the bubble should have to know about it.
      bloc: _cache,
      buildWhen: (prev, curr) {
        final id = widget.storyReply.storyId;
        return prev.stories[id] != curr.stories[id] ||
            prev.unavailable.contains(id) != curr.unavailable.contains(id);
      },
      builder: (context, state) {
        final story = state.stories[widget.storyReply.storyId];
        final missing = story == null && state.unavailable.contains(widget.storyReply.storyId);

        return Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: widget.onYellow ? colors.onYel.withValues(alpha: 0.10) : colors.surf2,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Thumb(story: story, storyReply: widget.storyReply, missing: missing),
              const SizedBox(width: 9),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.fromMe ? 'Replied to their story' : 'Replied to your story',
                      style: AppTextStyles.metaMonoSm.copyWith(color: muted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      missing
                          ? 'Story unavailable'
                          : story == null
                              ? '…'
                              : (story.hasText ? story.text! : 'Photo'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySm.copyWith(
                        color: missing ? muted : foreground,
                        fontStyle: missing ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.story, required this.storyReply, required this.missing});

  final StoryEntity? story;
  final StoryReplyEntity storyReply;
  final bool missing;

  static const double _size = 34;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(AppRadii.xs);
    final image = story?.image;

    if (image != null) {
      return ClipRRect(
        borderRadius: radius,
        child: CachedNetworkImage(
          imageUrl: image.url,
          // Signed URLs are re-signed on every read — key by the object's
          // own address or every bubble re-downloads the same picture.
          cacheKey: image.cacheKey,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          // A 34pt tile has no business decoding a 1080x1920 source at full
          // size; x3 covers the densest screens this ships to.
          memCacheWidth: (_size * 3).round(),
          memCacheHeight: (_size * 3).round(),
          errorWidget: (_, _, _) => _Placeholder(icon: CupertinoIcons.exclamationmark_triangle, color: colors.ink3),
        ),
      );
    }

    if (story != null) {
      return StoryCoverSwatch(
        background: story!.background ?? StoryBackground.cover0,
        size: _size,
        borderRadius: radius,
        child: Icon(CupertinoIcons.textformat, size: 14, color: storyBackgroundForeground(story!.background)),
      );
    }

    return _Placeholder(
      icon: missing
          ? CupertinoIcons.eye_slash
          : (storyReply.storyIsImage ? CupertinoIcons.photo : CupertinoIcons.textformat),
      color: colors.ink3,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _Thumb._size,
      height: _Thumb._size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.of(context).surf2,
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Icon(icon, size: 15, color: color),
    );
  }
}
