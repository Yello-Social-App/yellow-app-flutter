import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/post_entity.dart';
import '../bloc/feed_cubit.dart';
import '../bloc/post_detail_cubit.dart';
import '../widgets/post_image_carousel.dart';
import '../widgets/post_options_sheet.dart';
import '../widgets/reaction_breakdown_sheet.dart';
import '../widgets/reaction_picker_sheet.dart';

class PostDetailPage extends StatelessWidget {
  const PostDetailPage({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PostDetailCubit>(param1: postId)..load(),
      child: const _PostDetailView(),
    );
  }
}

class _PostDetailView extends StatefulWidget {
  const _PostDetailView();

  @override
  State<_PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<_PostDetailView> {
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();

  /// The top-level comment a reply-in-progress will nest under — always a
  /// top-level id even when replying to one of its replies (see
  /// `PostDetailCubit.submitComment`). Null means the compose bar is
  /// posting a plain top-level comment.
  CommentEntity? _replyParent;

  /// Who the "Replying to @…" strip names — the specific reply's author
  /// when replying to a reply, otherwise `_replyParent`'s own author.
  String? _replyToName;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  /// Starts composing a reply. [mentionUsername] is set only when replying
  /// to one of [topLevelParent]'s replies (not the top-level comment
  /// itself) — Facebook's flat 2-level model stands in a third nesting
  /// level with an `@mention` prefilled into the text instead.
  void _startReply(CommentEntity topLevelParent, {String? mentionUsername}) {
    setState(() {
      _replyParent = topLevelParent;
      _replyToName = mentionUsername ?? topLevelParent.authorUsername;
    });
    if (mentionUsername != null) {
      _commentController.text = '@$mentionUsername ';
      _commentController.selection = TextSelection.collapsed(
        offset: _commentController.text.length,
      );
    }
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyParent = null;
      _replyToName = null;
    });
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<PostDetailCubit>();

    return BlocListener<PostDetailCubit, PostDetailState>(
      listenWhen: (prev, curr) => curr.status == PostDetailStatus.deleted,
      listener: (context, state) {
        sl<FeedCubit>().removePost(cubit.postId);
        AppStatusSnackbar.showSuccess(context, message: 'Post deleted.');
        Navigator.of(context).maybePop();
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: BlocBuilder<PostDetailCubit, PostDetailState>(
            builder: (context, state) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                    child: Row(
                      children: [
                        AppIconButton(
                          icon: const Icon(Icons.arrow_back),
                          size: 38,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 11),
                        Text(
                          'POST',
                          style: AppTextStyles.eyebrow.copyWith(
                            color: colors.ink2,
                          ),
                        ),
                        const Spacer(),
                        if (state.status == PostDetailStatus.loaded)
                          AppIconButton(
                            icon: const Icon(Icons.more_horiz),
                            size: 38,
                            onPressed: () =>
                                _showPostMenu(context, cubit, state),
                          ),
                      ],
                    ),
                  ),
                  Container(height: 1.5, color: colors.line),
                  Expanded(
                    child: switch (state.status) {
                      PostDetailStatus.loading => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      PostDetailStatus.error => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: ErrorView(
                            message:
                                state.errorMessage ??
                                'Could not load this post.',
                            onRetry: cubit.load,
                          ),
                        ),
                      ),
                      PostDetailStatus.loaded => _Loaded(
                        state: state,
                        onStartReply: _startReply,
                      ),
                      PostDetailStatus.deleted => const SizedBox.shrink(),
                    },
                  ),
                  if (state.status == PostDetailStatus.loaded)
                    _CommentBar(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      cubit: cubit,
                      replyToId: _replyParent?.id,
                      replyToName: _replyToName,
                      onCancelReply: _cancelReply,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

void _showPostMenu(
  BuildContext context,
  PostDetailCubit cubit,
  PostDetailState state,
) {
  showPostOptionsSheet(
    context,
    isOwnPost: state.isOwnPost,
    onCopyLink: () => _shareLink(context, cubit),
    onViewReactions: () => showReactionBreakdownSheet(context, fetch: cubit.getReactionSummary),
    onEdit: () => _showEditSheet(context, cubit, state.post!),
    onDelete: () => _confirmDeletePost(context, cubit),
  );
}

Future<void> _shareLink(BuildContext context, PostDetailCubit cubit) async {
  final url = await cubit.getShareLink();
  if (!context.mounted) return;
  if (url == null) {
    AppStatusSnackbar.showError(context, message: 'Could not get a share link.');
    return;
  }
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  AppStatusSnackbar.showSuccess(context, message: 'Link copied to clipboard.');
}

Future<void> _confirmDeletePost(BuildContext context, PostDetailCubit cubit) async {
  if (await confirmDeletePost(context)) cubit.deletePost();
}

Future<void> _confirmDeleteComment(
  BuildContext context,
  PostDetailCubit cubit,
  String commentId,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete this comment?'),
      content: const Text("This can't be undone."),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  final ok = await cubit.deleteComment(commentId);
  if (!context.mounted || ok) return;
  AppStatusSnackbar.showError(context, message: 'Could not delete comment.');
}

Future<void> _showEditSheet(BuildContext context, PostDetailCubit cubit, PostEntity post) {
  return showEditPostSheet(
    context,
    post: post,
    onSave: ({content, visibility}) async {
      final ok = await cubit.updatePost(content: content, visibility: visibility);
      // Keeps the Feed tab's own singleton in sync — editing here doesn't
      // touch `FeedCubit`'s post list on its own (see `FeedCubit.replacePost`).
      if (ok) {
        final updated = cubit.state.post;
        if (updated != null) sl<FeedCubit>().replacePost(updated);
      }
      return ok;
    },
  );
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.state, required this.onStartReply});
  final PostDetailState state;

  /// `mentionUsername` is passed only when the tapped "Reply" belongs to a
  /// reply rather than a top-level comment — see `_PostDetailViewState._startReply`.
  final void Function(CommentEntity topLevelParent, {String? mentionUsername})
  onStartReply;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final post = state.post!;
    final cubit = context.read<PostDetailCubit>();

    // Facebook-style 2-level grouping: top-level comments in their existing
    // (newest-first) order, each with its own replies sorted oldest-first
    // underneath — reply *position* in `state.comments` doesn't matter here,
    // a freshly-posted reply is prepended to the flat list but still sorts
    // to the end of its parent's group by `createdAt`. A reply whose parent
    // isn't in this page's comments (only page 0 is ever fetched — see
    // memory) would otherwise vanish, so it falls back to rendering plain.
    final topLevelComments = state.comments.where((c) => !c.isReply).toList();
    final topLevelIds = topLevelComments.map((c) => c.id).toSet();
    List<CommentEntity> repliesTo(String parentId) =>
        state.comments.where((c) => c.parentCommentId == parentId).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final orphanReplies = state.comments
        .where((c) => c.isReply && !topLevelIds.contains(c.parentCommentId))
        .toList();

    // Pull-to-refresh is currently the only way to pick up a comment (or a
    // reaction count) someone else added after this page opened — there's
    // no live/polling update, same as the rest of the app.
    return RefreshIndicator(
      onRefresh: cubit.refresh,
      color: colors.ink,
      backgroundColor: colors.surf,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
        children: [
          Container(
            decoration: BoxDecoration(
              color: colors.surf,
              border: Border.all(color: colors.line, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadii.xxl),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
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
                          size: 44,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.authorUsername,
                                style: AppTextStyles.titleMd.copyWith(
                                  fontSize: 15,
                                  color: colors.ink,
                                ),
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
                if (post.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Text(
                      post.content,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 16,
                        color: colors.ink,
                      ),
                    ),
                  ),
                if (post.hasImages)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    // A single photo follows its own aspect ratio at the
                    // card's fixed width instead of a fixed box; two or more
                    // become a swipeable carousel with a page indicator.
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      child: PostImageCarousel(
                        imageUrls: post.imageUrls,
                        placeholderHeight: 300,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _LikeButton(
                        post: post,
                        onTap: cubit.toggleLike,
                        onLongPress: () async {
                          final picked = await showReactionPicker(
                            context,
                            current: post.viewerReactionType,
                          );
                          if (picked != null) cubit.react(picked);
                        },
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        icon: Icons.mode_comment_outlined,
                        label: '${state.comments.length}',
                      ),
                      const Spacer(),
                      AppIconButton(
                        icon: const Icon(Icons.repeat),
                        size: 40,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
            child: Text(
              'COMMENTS · ${state.comments.length}',
              style: AppTextStyles.eyebrow.copyWith(color: colors.ink2),
            ),
          ),
          for (final comment in topLevelComments) ...[
            _CommentRow(
              comment: comment,
              canDelete: state.canDeleteComment(comment),
              onDelete: () => _confirmDeleteComment(context, cubit, comment.id),
              onQuickLike: () =>
                  cubit.reactToComment(comment.id, ReactionType.like),
              onReact: (type) => cubit.reactToComment(comment.id, type),
              onReply: () => onStartReply(comment),
              onViewReactions: () => showReactionBreakdownSheet(
                context,
                fetch: () => cubit.getCommentReactionSummary(comment.id),
              ),
            ),
            for (final reply in repliesTo(comment.id))
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: _CommentRow(
                  comment: reply,
                  isReply: true,
                  canDelete: state.canDeleteComment(reply),
                  onDelete: () =>
                      _confirmDeleteComment(context, cubit, reply.id),
                  onQuickLike: () =>
                      cubit.reactToComment(reply.id, ReactionType.like),
                  onReact: (type) => cubit.reactToComment(reply.id, type),
                  onReply: () => onStartReply(
                    comment,
                    mentionUsername: reply.authorUsername,
                  ),
                  onViewReactions: () => showReactionBreakdownSheet(
                    context,
                    fetch: () => cubit.getCommentReactionSummary(reply.id),
                  ),
                ),
              ),
          ],
          for (final orphan in orphanReplies)
            _CommentRow(
              comment: orphan,
              canDelete: state.canDeleteComment(orphan),
              onDelete: () => _confirmDeleteComment(context, cubit, orphan.id),
              onQuickLike: () =>
                  cubit.reactToComment(orphan.id, ReactionType.like),
              onReact: (type) => cubit.reactToComment(orphan.id, type),
              onReply: () => onStartReply(orphan),
              onViewReactions: () => showReactionBreakdownSheet(
                context,
                fetch: () => cubit.getCommentReactionSummary(orphan.id),
              ),
            ),
          if (state.hasMoreComments)
            _LoadMoreComments(
              loading: state.isLoadingMoreComments,
              onTap: cubit.loadMoreComments,
            ),
        ],
      ),
    );
  }
}

class _LoadMoreComments extends StatelessWidget {
  const _LoadMoreComments({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: loading ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: colors.line, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.ink2,
                    ),
                  )
                : Text(
                    'Load more comments',
                    style: AppTextStyles.button.copyWith(color: colors.ink2),
                  ),
          ),
        ),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
    required this.onQuickLike,
    required this.onReact,
    required this.onReply,
    required this.onViewReactions,
    this.isReply = false,
  });
  final CommentEntity comment;
  final bool canDelete;
  final VoidCallback onDelete;

  /// Plain tap on the reaction row — toggles `LIKE` (see `onReact` for the
  /// long-press picker).
  final VoidCallback onQuickLike;
  final ValueChanged<ReactionType> onReact;
  final VoidCallback onReply;

  /// Tapping the reaction count opens the "who reacted" breakdown sheet —
  /// the same `GET .../summary` call the post's overflow menu uses, just
  /// against this comment instead (`targetType=COMMENT`).
  final VoidCallback onViewReactions;

  /// Renders with a smaller avatar — `_Loaded` already indents replies with
  /// a `Padding`; this is the second half of Facebook's "belongs to the
  /// comment above" visual cue.
  final bool isReply;

  Future<void> _pickReaction(BuildContext context) async {
    final picked = await showReactionPicker(
      context,
      current: comment.viewerReactionType,
    );
    if (picked != null) onReact(picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reacted = comment.viewerReactionType;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.pushNamed(
              RouteNames.userProfile,
              pathParameters: {'userId': comment.authorId},
            ),
            child: AppAvatar(
              initials: comment.authorUsername.initials,
              seed: avatarSeedForId(comment.authorId),
              imageUrl: comment.authorAvatarUrl,
              size: isReply ? 30 : 38,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surf,
                border: Border.all(color: colors.line, width: 1.5),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.pushNamed(
                            RouteNames.userProfile,
                            pathParameters: {'userId': comment.authorId},
                          ),
                          child: Text(
                            comment.authorUsername,
                            style: AppTextStyles.titleSm.copyWith(
                              fontSize: 12,
                              color: colors.ink,
                            ),
                          ),
                        ),
                      ),
                      if (canDelete)
                        InkWell(
                          onTap: onDelete,
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.close,
                              size: 15,
                              color: colors.ink2,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    comment.content,
                    style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      InkWell(
                        onTap: onQuickLike,
                        onLongPress: () => _pickReaction(context),
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 2,
                            horizontal: 2,
                          ),
                          child: reacted == null || reacted == ReactionType.like
                              ? Icon(
                                  reacted == null
                                      ? Icons.favorite_border
                                      : Icons.favorite,
                                  size: 14,
                                  color: reacted == null
                                      ? colors.ink3
                                      : colors.red,
                                )
                              : Text(
                                  reacted.emoji,
                                  style: const TextStyle(fontSize: 13),
                                ),
                        ),
                      ),
                      // A sibling tap target, not nested inside the quick-like
                      // `InkWell` above — two nested `GestureDetector`/`InkWell`
                      // widgets with independent `onTap`s share one gesture
                      // arena and can resolve ambiguously, so the count gets
                      // its own separate hit area instead (same pattern as
                      // the "Reply" `InkWell` below).
                      if (comment.reactionCount > 0)
                        InkWell(
                          onTap: onViewReactions,
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 2,
                              horizontal: 2,
                            ),
                            child: Text(
                              '${comment.reactionCount}',
                              style: AppTextStyles.metaMono.copyWith(
                                color: reacted != null
                                    ? colors.red
                                    : colors.ink3,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 14),
                      // Facebook's "Like · Reply" row — see `_Loaded` for how
                      // a tap here resolves to the right `parentCommentId`.
                      InkWell(
                        onTap: onReply,
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 2,
                            horizontal: 2,
                          ),
                          child: Text(
                            'Reply',
                            style: AppTextStyles.metaMono.copyWith(
                              color: colors.ink2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.post,
    required this.onTap,
    required this.onLongPress,
  });
  final PostEntity post;
  final VoidCallback onTap;

  /// Opens the reaction picker (see `reaction_picker_sheet.dart`).
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reacted = post.viewerReactionType;
    return Material(
      color: reacted != null ? colors.red : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        side: BorderSide(
          color: reacted != null ? colors.red : colors.line,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              reacted == null || reacted == ReactionType.like
                  ? Icon(
                      reacted == null ? Icons.favorite_border : Icons.favorite,
                      size: 16,
                      color: reacted == null ? colors.ink2 : Colors.white,
                    )
                  : Text(reacted.emoji, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Text(
                Formatters.compactCount(post.reactionTotal),
                style: AppTextStyles.button.copyWith(
                  color: reacted != null ? Colors.white : colors.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.ink2),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.button.copyWith(color: colors.ink2)),
        ],
      ),
    );
  }
}

class _CommentBar extends StatelessWidget {
  const _CommentBar({
    required this.controller,
    required this.focusNode,
    required this.cubit,
    required this.replyToId,
    required this.replyToName,
    required this.onCancelReply,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final PostDetailCubit cubit;

  /// The comment id to send as `parentCommentId` — null posts a plain
  /// top-level comment. See `_PostDetailViewState._startReply`.
  final String? replyToId;

  /// Who the "Replying to @…" strip names; shown whenever [replyToId] is set.
  final String? replyToName;
  final VoidCallback onCancelReply;

  void _submit() {
    final wasReply = replyToId != null;
    cubit.submitComment(controller.text, parentCommentId: replyToId);
    controller.clear();
    if (wasReply) onCancelReply();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(top: BorderSide(color: colors.line, width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyToId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Row(
                children: [
                  Icon(Icons.reply, size: 14, color: colors.ink2),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Replying to @$replyToName',
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.metaMono.copyWith(
                        color: colors.ink2,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onCancelReply,
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.close, size: 15, color: colors.ink2),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: colors.surf,
                    border: Border.all(color: colors.line, width: 1.5),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: AppTextStyles.hint.copyWith(color: colors.ink),
                    decoration: InputDecoration(
                      hintText: replyToId != null
                          ? 'Write a reply'
                          : 'Add a comment',
                      hintStyle: AppTextStyles.hint.copyWith(
                        color: colors.ink3,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              AppIconButton(
                icon: const Icon(Icons.arrow_upward),
                filled: true,
                borderColor: colors.ink,
                size: 46,
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
