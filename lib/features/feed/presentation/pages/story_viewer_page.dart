import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/app_warning_dialog.dart';
import '../../domain/entities/story_entity.dart';
import '../bloc/story_cubit.dart';
import '../widgets/story_background.dart';
import '../widgets/story_viewers_sheet.dart';

/// The full-screen story viewer.
///
/// [authorId] names whose ring to open rather than its index in the rail:
/// the rail the tap came from may be seconds old, and a ring that expired
/// in between would otherwise play somebody else's story.
class StoryViewerPage extends StatelessWidget {
  const StoryViewerPage({super.key, required this.authorId, this.onlyThisAuthor = false});

  final String authorId;

  /// Play just this one author's ring (`GET /users/{id}/stories`) instead of
  /// continuing through the whole rail — how a ring opened from outside the
  /// Home tab behaves.
  final bool onlyThisAuthor;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = sl<StoryCubit>();
        if (onlyThisAuthor) {
          cubit.startForUser(authorId);
        } else {
          cubit.start(authorId);
        }
        return cubit;
      },
      child: const _StoryView(),
    );
  }
}

class _StoryView extends StatefulWidget {
  const _StoryView();

  @override
  State<_StoryView> createState() => _StoryViewState();
}

class _StoryViewState extends State<_StoryView> {
  final _replyController = TextEditingController();
  final _replyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Typing a reply holds the slide — losing the story you are replying to
    // mid-sentence is the single worst bug a story viewer can have.
    _replyFocus.addListener(() {
      final cubit = context.read<StoryCubit>();
      _replyFocus.hasFocus ? cubit.pause() : cubit.resume();
    });
  }

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final cubit = context.read<StoryCubit>();
    final error = await cubit.sendReply(text);
    if (!mounted) return;
    if (error != null) {
      AppStatusSnackbar.showError(context, message: error);
      return;
    }
    _replyController.clear();
    _replyFocus.unfocus();
    // A 202 is "accepted", not "delivered" — the message itself lands in
    // the conversation over the chat socket a moment later, so the viewer
    // confirms and moves on rather than waiting for it.
    AppStatusSnackbar.showSuccess(context, title: 'Sent', message: 'Your reply is on its way.');
  }

  Future<void> _confirmDelete() async {
    final cubit = context.read<StoryCubit>();
    cubit.pause();
    final confirmed = await AppWarningDialog.show(
      context,
      title: 'Delete this story?',
      message: 'It disappears for everyone straight away, and leaves your archive.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline,
    );
    if (!mounted) return;
    if (!confirmed) {
      cubit.resume();
      return;
    }
    final error = await cubit.deleteCurrent();
    if (!mounted) return;
    if (error != null) AppStatusSnackbar.showError(context, message: error);
  }

  Future<void> _openViewers(StoryEntity story) async {
    final cubit = context.read<StoryCubit>();
    cubit.pause();
    await showStoryViewersSheet(context, storyId: story.id, viewCount: story.viewCount ?? 0);
    if (mounted) cubit.resume();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StoryCubit, StoryState>(
      listenWhen: (prev, curr) => curr.status == StoryStatus.finished,
      listener: (context, state) => Navigator.of(context).maybePop(),
      // Progress ticks ~16x a second. Without this the whole tree —
      // including the decoded photo — would rebuild on every tick; the bars
      // read it on their own through a `BlocSelector` instead.
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.ringIndex != curr.ringIndex ||
          prev.slideIndex != curr.slideIndex ||
          prev.rings != curr.rings ||
          prev.paused != curr.paused ||
          prev.replying != curr.replying,
      builder: (context, state) {
        final cubit = context.read<StoryCubit>();

        if (state.status == StoryStatus.error) {
          return _ErrorScreen(message: state.errorMessage ?? 'Could not open this story.');
        }

        final ring = state.currentRing;
        final story = state.currentStory;
        if (state.status != StoryStatus.playing || ring == null || story == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0B0A07),
            body: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          );
        }

        // This is a full-bleed Stack (the frame fills the entire screen,
        // deliberately not wrapped in SafeArea so it doesn't letterbox) —
        // every piece of chrome instead adds the safe-area inset itself on
        // top of its original hand-tuned offset, so it clears the status
        // bar/notch/home-indicator/gesture-pill on any device instead of
        // just whatever the design was eyeballed against.
        final topInset = MediaQuery.paddingOf(context).top;
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

        return Scaffold(
          backgroundColor: const Color(0xFF0B0A07),
          // The reply field rides above the keyboard by hand (see the
          // bottom `Positioned`), so the Scaffold must not also resize.
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Positioned.fill(child: _StoryFrame(story: story)),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.72),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.88),
                      ],
                      stops: const [0, 0.34, 0.6, 1],
                    ),
                  ),
                ),
              ),

              // Tap zones sit under the chrome so the close button, the
              // reply field and the viewers button all win the hit test.
              Positioned(
                left: 0,
                right: 0,
                top: 120 + topInset,
                bottom: 120 + bottomInset,
                child: Row(
                  children: [
                    Expanded(
                      flex: 32,
                      child: GestureDetector(
                        onTap: cubit.previous,
                        onLongPressStart: (_) => cubit.pause(),
                        onLongPressEnd: (_) => cubit.resume(),
                        behavior: HitTestBehavior.opaque,
                      ),
                    ),
                    Expanded(
                      flex: 52,
                      child: GestureDetector(
                        onTap: cubit.next,
                        onLongPressStart: (_) => cubit.pause(),
                        onLongPressEnd: (_) => cubit.resume(),
                        behavior: HitTestBehavior.opaque,
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                top: 52 + topInset,
                left: 14,
                right: 14,
                child: _ProgressBars(slideCount: ring.stories.length),
              ),

              Positioned(
                top: 72 + topInset,
                left: 14,
                right: 14,
                child: _Header(
                  story: story,
                  onClose: cubit.dismiss,
                  onDelete: story.isOwner ? _confirmDelete : null,
                ),
              ),

              if (story.hasText)
                Positioned(
                  left: 16,
                  right: 16,
                  // A text story owns the middle of the frame; a caption on
                  // a photo sits just above the footer.
                  top: story.isImage ? null : 140 + topInset,
                  bottom: story.isImage ? 104 + bottomInset : 140 + bottomInset,
                  child: IgnorePointer(child: _StoryText(story: story)),
                ),

              Positioned(
                left: 14,
                right: 14,
                bottom: 30 + bottomInset + keyboardInset,
                child: story.isOwner
                    ? _OwnerFooter(story: story, onTap: () => _openViewers(story))
                    : _ReplyBar(
                        controller: _replyController,
                        focusNode: _replyFocus,
                        sending: state.replying,
                        authorName: story.author.firstName,
                        onSend: _send,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The slide itself — a photo, or the text story's gradient cover.
class _StoryFrame extends StatelessWidget {
  const _StoryFrame({required this.story});

  final StoryEntity story;

  @override
  Widget build(BuildContext context) {
    final image = story.image;
    if (!story.isImage || image == null) {
      return DecoratedBox(decoration: BoxDecoration(gradient: storyBackgroundGradient(story.background)));
    }
    return CachedNetworkImage(
      imageUrl: image.url,
      // The signed URL is re-signed on every read, so the raw URL is a
      // cache miss every time — key by the object's own address instead.
      // See `presignedObjectKey` and ADR-015.
      cacheKey: image.cacheKey,
      // `contain`, not `cover`: the whole photo has to be visible, whatever
      // shape it is. The server caps a stored story at 1080x1920, which is
      // never taller in aspect than a phone screen, so in practice this
      // always comes out as "width fills the screen, letterboxed above and
      // below" — the same result `fitWidth` would give, minus `fitWidth`'s
      // failure mode of cropping the top and bottom off an unusually tall
      // photo (or any photo, on a squatter tablet screen).
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, _) => const ColoredBox(
        color: Color(0xFF0B0A07),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)),
      ),
      errorWidget: (_, _, _) => const ColoredBox(
        color: Color(0xFF0B0A07),
        child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 40)),
      ),
    );
  }
}

class _StoryText extends StatelessWidget {
  const _StoryText({required this.story});

  final StoryEntity story;

  @override
  Widget build(BuildContext context) {
    // A text story is the whole frame, so it gets the display size and its
    // cover's own foreground; a caption on a photo is secondary copy over
    // the scrim, always white.
    final isCaption = story.isImage;
    final text = Text(
      story.text!,
      style: TextStyle(
        color: isCaption ? Colors.white : storyBackgroundForeground(story.background),
        fontSize: isCaption ? 17 : 29,
        fontWeight: isCaption ? FontWeight.w600 : FontWeight.w800,
        letterSpacing: isCaption ? 0 : -1,
        height: isCaption ? 1.3 : 1.08,
      ),
    );
    // The caption's `Positioned` pins only its bottom edge, which leaves the
    // height unbounded — an `Align` there would try to fill infinity and
    // fail layout. The full-frame case pins top *and* bottom, so it has a
    // real box to centre in.
    return isCaption ? text : Align(alignment: Alignment.centerLeft, child: text);
  }
}

/// Reads the ticking progress on its own so the rest of the viewer — and
/// the decoded photo behind it — is not rebuilt 16 times a second.
class _ProgressBars extends StatelessWidget {
  const _ProgressBars({required this.slideCount});

  final int slideCount;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<StoryCubit, StoryState, (int, double)>(
      selector: (state) => (state.slideIndex, state.progress),
      builder: (context, value) {
        final (slideIndex, progress) = value;
        return Row(
          children: [
            for (var i = 0; i < slideCount; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    value: i < slideIndex
                        ? 1
                        : i == slideIndex
                            ? progress.clamp(0.0, 1.0)
                            : 0,
                    backgroundColor: Colors.white.withValues(alpha: 0.32),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.story, required this.onClose, this.onDelete});

  final StoryEntity story;
  final VoidCallback onClose;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final author = story.author;
    return Row(
      children: [
        AppAvatar(
          initials: author.displayName.initials,
          seed: avatarSeedForId(author.id),
          size: 38,
          imageUrl: author.avatarUrl,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                story.isOwner ? 'Your story' : author.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Text(
                    Formatters.relativeShort(story.createdAt),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 10.5),
                  ),
                  if (story.visibility == StoryVisibility.public) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.public, size: 11, color: Colors.white.withValues(alpha: 0.62)),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (onDelete != null)
          IconButton(
            onPressed: onDelete,
            tooltip: 'Delete story',
            icon: const Icon(Icons.delete_outline, color: Colors.white),
          ),
        IconButton(onPressed: onClose, tooltip: 'Close', icon: const Icon(Icons.close, color: Colors.white)),
      ],
    );
  }
}

/// Your own slide: how many people have seen it, tapping through to who.
class _OwnerFooter extends StatelessWidget {
  const _OwnerFooter({required this.story, required this.onTap});

  final StoryEntity story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = story.viewCount ?? 0;
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.visibility_outlined, color: Colors.white, size: 17),
              const SizedBox(width: 8),
              Text(
                count == 0 ? 'No views yet' : 'Seen by ${Formatters.compactCount(count)}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Someone else's slide: a DM back to them.
///
/// The heart sends "❤️" as an ordinary reply rather than reacting — the
/// backend has no story reactions (its reference lists them as not built),
/// so a local-only heart would be a button that does nothing off-device.
class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.authorName,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final String authorName;
  final Future<void> Function(String text) onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(999),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !sending,
              maxLength: AppConstants.storyReplyMaxChars,
              textInputAction: TextInputAction.send,
              onSubmitted: onSend,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Reply to $authorName…',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        _CircleAction(
          busy: sending,
          icon: Icons.favorite_border,
          onTap: () => onSend('❤️'),
        ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.busy, required this.onTap});

  final IconData icon;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.3),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
        ),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0A07),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_stories_outlined, color: Colors.white38, size: 42),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 22),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Close', style: TextStyle(color: Color(0xFFF4C542))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
