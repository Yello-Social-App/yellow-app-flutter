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
import '../../../safety/presentation/bloc/report_post_cubit.dart';
import '../../../safety/presentation/widgets/report_post_sheet.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/yello_wordmark.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/post_entity.dart';
import '../bloc/feed_cubit.dart';
import '../bloc/post_detail_cubit.dart';
import '../widgets/post_card.dart';
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
                        // Same brand wordmark treatment the tab-level
                        // headers use (Circle / Inbox / Signals), but at the
                        // inline `titleLg` step this back-arrow row is built
                        // around rather than the 34px page-level one.
                        const YelloWordmark(
                          fontSize: AppTextStyles.displayXlFontSize,
                          text: 'Post',
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
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
    onViewReactions: () => showReactionBreakdownSheet(
      context,
      fetch: cubit.getReactionSummary,
      targetType: 'POST',
      targetId: state.post!.id,
    ),
    onEdit: () => _showEditSheet(context, cubit, state.post!),
    onDelete: () => _confirmDeletePost(context, cubit),
    onHide: () => _hidePost(context, cubit),
    onReport: () => _reportPost(context, cubit),
    onMute: () => _mutePostAuthor(context, cubit, state.post!),
    authorUsername: state.post!.authorUsername,
  );
}

/// Hiding from the detail screen leaves nothing to look at, so the screen
/// closes — and the feed behind it drops the card too, the same way
/// deleting does (see the `PostDetailStatus.deleted` listener above). This
/// one is not a status on the state because, unlike a delete, nothing about
/// the post itself changed: it is still there, just not for this viewer.
Future<void> _hidePost(BuildContext context, PostDetailCubit cubit) async {
  final ok = await cubit.hidePost();
  if (!context.mounted) return;
  if (!ok) {
    AppStatusSnackbar.showError(
      context,
      message: cubit.state.errorMessage ?? 'Could not hide that post.',
    );
    return;
  }
  sl<FeedCubit>().removePost(cubit.postId);
  AppStatusSnackbar.showSuccess(
    context,
    message: "Hidden. You won't see this post again.",
  );
  Navigator.of(context).maybePop();
}

/// Reporting leaves the post on screen: it is a message to moderation, not
/// a "get this away from me" — that is what Hide is for, one row up.
Future<void> _reportPost(BuildContext context, PostDetailCubit cubit) async {
  final outcome = await showReportPostSheet(context, postId: cubit.postId);
  if (!context.mounted || outcome == null) return;
  switch (outcome) {
    case ReportOutcome.sent:
      AppStatusSnackbar.showSuccess(
        context,
        message: 'Thanks — our team will take a look.',
      );
    case ReportOutcome.alreadyReported:
      AppStatusSnackbar.showSuccess(
        context,
        message: "You've already reported this post.",
      );
    case ReportOutcome.failed:
    case ReportOutcome.none:
      break;
  }
}

Future<void> _mutePostAuthor(
  BuildContext context,
  PostDetailCubit cubit,
  PostEntity post,
) async {
  if (!await confirmMuteAuthor(context, post.authorUsername)) return;
  if (!context.mounted) return;
  final ok = await cubit.muteAuthor();
  if (!context.mounted) return;
  if (!ok) {
    AppStatusSnackbar.showError(
      context,
      message: cubit.state.errorMessage ?? 'Could not mute that account.',
    );
    return;
  }
  // The feed keeps its own copy of every post; a mute has to reach it
  // directly, since nothing re-fetches the feed on the way back here.
  sl<FeedCubit>().removePost(cubit.postId);
  AppStatusSnackbar.showSuccess(
    context,
    message: '${post.authorUsername.withAtSign} is muted.',
  );
  Navigator.of(context).maybePop();
}

Future<void> _shareLink(BuildContext context, PostDetailCubit cubit) async {
  final url = await cubit.getShareLink();
  if (!context.mounted) return;
  if (url == null) {
    AppStatusSnackbar.showError(
      context,
      message: 'Could not get a share link.',
    );
    return;
  }
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  AppStatusSnackbar.showSuccess(context, message: 'Link copied to clipboard.');
}

Future<void> _confirmDeletePost(
  BuildContext context,
  PostDetailCubit cubit,
) async {
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

Future<void> _showEditSheet(
  BuildContext context,
  PostDetailCubit cubit,
  PostEntity post,
) {
  return showEditPostSheet(
    context,
    post: post,
    onSave: ({content, visibility}) async {
      final ok = await cubit.updatePost(
        content: content,
        visibility: visibility,
      );
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
    // Lazily built (`ListView.builder`, not a fully materialized `children:`
    // list) so a post with a long comment thread only pays to build/layout/
    // paint the comments actually on screen (plus Flutter's small cache
    // extent) instead of every comment and reply up front. This matters
    // because there's no scoped `buildWhen`/selector above this widget —
    // liking/replying to/deleting *any* comment re-emits `PostDetailState`
    // and rebuilds this whole `_Loaded` tree, so without laziness here every
    // one of those actions would also rebuild every off-screen comment.
    const headerItemCount = 2; // index 0: the post itself, 1: "COMMENTS · N"
    final itemCount =
        headerItemCount +
        topLevelComments.length +
        orphanReplies.length +
        (state.hasMoreComments ? 1 : 0);

    return RefreshIndicator(
      onRefresh: cubit.refresh,
      color: colors.ink,
      backgroundColor: colors.surf,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) return _PostHeaderCard(post: post, cubit: cubit);
          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
              child: Text(
                'COMMENTS · ${post.commentCount}',
                style: AppTextStyles.eyebrow.copyWith(color: colors.ink2),
              ),
            );
          }
          final commentIndex = index - headerItemCount;
          if (commentIndex < topLevelComments.length) {
            final comment = topLevelComments[commentIndex];
            return _CommentThread(
              comment: comment,
              replies: repliesTo(comment.id),
              state: state,
              cubit: cubit,
              onStartReply: onStartReply,
            );
          }
          final orphanIndex = commentIndex - topLevelComments.length;
          if (orphanIndex < orphanReplies.length) {
            final orphan = orphanReplies[orphanIndex];
            return _CommentRow(
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
                targetType: 'COMMENT',
                targetId: orphan.id,
              ),
            );
          }
          return _LoadMoreComments(
            loading: state.isLoadingMoreComments,
            onTap: cubit.loadMoreComments,
          );
        },
      ),
    );
  }
}

/// The post itself — item 0 of `_Loaded`'s comments `ListView.builder`,
/// pulled out to its own widget so that builder's `itemBuilder` stays
/// readable instead of a large inline block for just one of its item types.
class _PostHeaderCard extends StatelessWidget {
  const _PostHeaderCard({required this.post, required this.cubit});

  final PostEntity post;
  final PostDetailCubit cubit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        boxShadow: AppShadows.card(context),
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
                          style: AppTextStyles.titleRow.copyWith(
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
                style: AppTextStyles.body.copyWith(color: colors.ink),
              ),
            ),
          if (post.hasImages)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              // A single photo follows its own aspect ratio at the card's
              // fixed width instead of a fixed box; two or more become a
              // swipeable carousel with a page indicator.
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                child: PostImageCarousel(
                  imageUrls: post.imageUrls,
                  placeholderHeight: 300,
                ),
              ),
            ),
          // Facebook-style "shared post" embed — see `RepostedPostPreview`'s
          // doc for why this can't be skipped: a repost's own content/images
          // are almost always empty.
          if (post.isRepost)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: RepostedPostPreview(original: post.originalPost!),
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
                  label: '${post.commentCount}',
                ),
                const Spacer(),
                _RepostButton(post: post, onTap: cubit.toggleRepost),
              ],
            ),
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
                    mainAxisAlignment: MainAxisAlignment.end,
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

/// One top-level comment's reply block, each reply linked to the one above
/// it by a thread line — see `_ReplyThreadPainter`. Pulled out of `_Loaded`
/// so the line-drawing has index access (first/last-of-group) without an
/// awkward local variable inside `_Loaded.build`'s list literal.
/// Parent comment plus its reply group, threaded together: draws the
/// lead-in segment from the parent's own avatar down into the reply group
/// (see `_ThreadLeadInPainter`) so the connector reads as one continuous
/// line from the original comment rather than starting partway down.
/// Renders the parent alone, with no line, when it has no replies.
class _CommentThread extends StatelessWidget {
  const _CommentThread({
    required this.comment,
    required this.replies,
    required this.state,
    required this.cubit,
    required this.onStartReply,
  });

  final CommentEntity comment;
  final List<CommentEntity> replies;
  final PostDetailState state;
  final PostDetailCubit cubit;
  final void Function(CommentEntity topLevelParent, {String? mentionUsername})
  onStartReply;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final parentRow = _CommentRow(
      comment: comment,
      canDelete: state.canDeleteComment(comment),
      onDelete: () => _confirmDeleteComment(context, cubit, comment.id),
      onQuickLike: () => cubit.reactToComment(comment.id, ReactionType.like),
      onReact: (type) => cubit.reactToComment(comment.id, type),
      onReply: () => onStartReply(comment),
      onViewReactions: () => showReactionBreakdownSheet(
        context,
        fetch: () => cubit.getCommentReactionSummary(comment.id),
        targetType: 'COMMENT',
        targetId: comment.id,
      ),
    );
    if (replies.isEmpty) return parentRow;

    return Column(
      children: [
        Stack(
          children: [
            // The avatar is top-aligned in the parent's Row, so its bottom
            // edge sits at a fixed y no matter how tall the card grows below
            // it (wrapped comment text, reactions) — safe to draw through
            // since that column is otherwise blank space beside the bubble.
            Positioned.fill(
              child: CustomPaint(
                painter: _ThreadLeadInPainter(color: colors.line),
              ),
            ),
            parentRow,
          ],
        ),
        _ReplyGroup(
          replies: replies,
          topLevelParent: comment,
          state: state,
          cubit: cubit,
          onStartReply: onStartReply,
        ),
      ],
    );
  }
}

/// The straight lead-in segment of the thread line: from the parent
/// comment's avatar bottom down through the rest of its card to where
/// `_ReplyThreadPainter` picks up and curls into the first reply's avatar.
class _ThreadLeadInPainter extends CustomPainter {
  const _ThreadLeadInPainter({required this.color});

  final Color color;

  static const double _trunkX = 19;
  static const double _avatarBottom = 38;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      const Offset(_trunkX, _avatarBottom),
      Offset(_trunkX, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ThreadLeadInPainter oldPainter) =>
      oldPainter.color != color;
}

class _ReplyGroup extends StatelessWidget {
  const _ReplyGroup({
    required this.replies,
    required this.topLevelParent,
    required this.state,
    required this.cubit,
    required this.onStartReply,
  });

  final List<CommentEntity> replies;
  final CommentEntity topLevelParent;
  final PostDetailState state;
  final PostDetailCubit cubit;
  final void Function(CommentEntity topLevelParent, {String? mentionUsername})
  onStartReply;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      children: [
        for (var i = 0; i < replies.length; i++)
          Stack(
            children: [
              // Painted behind the row; purely decorative so it never
              // intercepts the row's own taps (Like/Reply/avatar).
              Positioned.fill(
                child: CustomPaint(
                  painter: _ReplyThreadPainter(
                    color: colors.line,
                    continuesBelow: i < replies.length - 1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: _CommentRow(
                  comment: replies[i],
                  isReply: true,
                  canDelete: state.canDeleteComment(replies[i]),
                  onDelete: () =>
                      _confirmDeleteComment(context, cubit, replies[i].id),
                  onQuickLike: () =>
                      cubit.reactToComment(replies[i].id, ReactionType.like),
                  onReact: (type) => cubit.reactToComment(replies[i].id, type),
                  onReply: () => onStartReply(
                    topLevelParent,
                    mentionUsername: replies[i].authorUsername,
                  ),
                  onViewReactions: () => showReactionBreakdownSheet(
                    context,
                    fetch: () => cubit.getCommentReactionSummary(replies[i].id),
                    targetType: 'COMMENT',
                    targetId: replies[i].id,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Draws one reply's thread connector: a vertical trunk aligned under the
/// parent comment's 38px avatar (center x = 19), branching right into this
/// reply's own 30px avatar (top-aligned with the row, so center y = 15).
/// [continuesBelow] extends the trunk past the branch so it reaches the next
/// reply's painter and the whole group reads as one unbroken line; the last
/// reply in a group passes `false` so the line stops at its own avatar
/// instead of trailing past it.
class _ReplyThreadPainter extends CustomPainter {
  const _ReplyThreadPainter({
    required this.color,
    required this.continuesBelow,
  });

  final Color color;
  final bool continuesBelow;

  static const double _trunkX = 19;
  static const double _branchY = 15;
  static const double _gutterWidth = 32;
  static const double _cornerRadius = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Vertical trunk down to just above the branch, then a rounded curl
    // into this reply's avatar instead of a sharp elbow.
    final branch = Path()
      ..moveTo(_trunkX, 0)
      ..lineTo(_trunkX, _branchY - _cornerRadius)
      ..quadraticBezierTo(_trunkX, _branchY, _trunkX + _cornerRadius, _branchY)
      ..lineTo(_gutterWidth, _branchY);
    canvas.drawPath(branch, paint);

    if (continuesBelow) {
      canvas.drawLine(
        Offset(_trunkX, _branchY),
        Offset(_trunkX, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReplyThreadPainter oldPainter) =>
      oldPainter.color != color || oldPainter.continuesBelow != continuesBelow;
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

/// Mirrors the feed card's repost pill (`post_card.dart`'s `_Pill` with
/// `Icons.repeat`) — same green active state and count, wired to
/// `PostDetailCubit.toggleRepost` instead of `FeedCubit.toggleRepost`.
class _RepostButton extends StatelessWidget {
  const _RepostButton({required this.post, required this.onTap});
  final PostEntity post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reposted = post.repostedByMe;
    return Material(
      color: reposted ? colors.grn : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        side: BorderSide(
          color: reposted ? colors.grn : colors.line,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.repeat,
                size: 16,
                color: reposted ? Colors.white : colors.ink2,
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.compactCount(post.repostCount),
                style: AppTextStyles.button.copyWith(
                  color: reposted ? Colors.white : colors.ink2,
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
