import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
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
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../feed/domain/entities/comment_entity.dart';
import '../../../feed/domain/entities/post_entity.dart' show ReactionType;
import '../../domain/entities/community_post_entity.dart';
import '../bloc/community_post_cubit.dart';
import '../widgets/vote_arrow_icon.dart';

/// One community thread: the post, its comments, and a composer.
///
/// Receives the [post] rather than an id because the backend has no
/// `GET /community-posts/{id}` route — a thread is only reachable from one of
/// the two list endpoints. See [CommunityPostRouteFallback] for what a cold
/// deep link gets instead.
class CommunityPostPage extends StatelessWidget {
  const CommunityPostPage({super.key, required this.post});

  final CommunityPostEntity post;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CommunityPostCubit>(param1: post)..load(),
      child: const _CommunityPostView(),
    );
  }
}

/// Shown when the thread route is entered without the post it needs — a cold
/// deep link, or a restored route after the app was killed.
///
/// This is a backend gap, not a client shortcut: there is no endpoint that
/// returns one community post by id, so the thread genuinely cannot be
/// rebuilt from the URL alone. The community's own screen is the nearest
/// honest destination.
class CommunityPostRouteFallback extends StatelessWidget {
  const CommunityPostRouteFallback({super.key, this.communitySlug});

  final String? communitySlug;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  AppIconButton(
                    icon: const Icon(CupertinoIcons.back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const Spacer(),
              const EmptyStateCard(
                title: 'THREAD UNAVAILABLE',
                hint: 'Open this thread from its community to read it.',
              ),
              const SizedBox(height: 14),
              if (communitySlug != null && communitySlug!.isNotEmpty)
                AppButton(
                  label: 'Go to community',
                  onPressed: () => context.pushReplacementNamed(
                    RouteNames.community,
                    pathParameters: {'slug': communitySlug!},
                  ),
                )
              else
                AppButton(
                  label: 'Browse communities',
                  // The hub is a shell tab now, so `go` — pushing a branch
                  // route over the shell is not a thing.
                  onPressed: () => context.goNamed(RouteNames.communities),
                ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityPostView extends StatefulWidget {
  const _CommunityPostView();

  @override
  State<_CommunityPostView> createState() => _CommunityPostViewState();
}

class _CommunityPostViewState extends State<_CommunityPostView> {
  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
  final _scrollController = ScrollController();

  /// The id whose text is currently loaded into the composer, so switching
  /// from "reply" to "edit" (or between two edits) replaces the draft instead
  /// of appending to it.
  String? _loadedEditId;

  @override
  void dispose() {
    _composer.dispose();
    _composerFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification) return false;
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) return false;
    if (metrics.pixels >= metrics.maxScrollExtent - 300) {
      context.read<CommunityPostCubit>().loadMoreComments();
    }
    return false;
  }

  Future<void> _submit() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    final cubit = context.read<CommunityPostCubit>();
    final ok = await cubit.submit(text);
    if (!mounted) return;
    if (ok) {
      _composer.clear();
      _loadedEditId = null;
      _composerFocus.unfocus();
    } else {
      AppStatusSnackbar.showError(
        context,
        message: cubit.state.errorMessage ?? 'Could not post that.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<CommunityPostCubit>();

    return BlocConsumer<CommunityPostCubit, CommunityPostState>(
      listenWhen: (previous, current) => previous.editingId != current.editingId,
      listener: (context, state) {
        final editingId = state.editingId;
        if (editingId == null) {
          if (_loadedEditId != null) {
            _composer.clear();
            _loadedEditId = null;
          }
          return;
        }
        if (_loadedEditId == editingId) return;
        // A `firstWhere` with an `orElse` reaching for `.first` would throw on
        // an empty list; if the comment being edited is somehow gone, leave the
        // composer alone rather than crashing the screen.
        CommentEntity? target;
        for (final c in state.comments) {
          if (c.id == editingId) {
            target = c;
            break;
          }
        }
        if (target == null) return;
        _composer.text = target.content;
        _loadedEditId = editingId;
        _composerFocus.requestFocus();
      },
      builder: (context, state) {
        // `canPop: false` plus an explicit pop is the only way to hand a result
        // back on a *system* back gesture as well as the button — without it,
        // swiping back would drop the vote/reaction/comment changes made here
        // and the list underneath would keep showing stale counts.
        return PopScope<CommunityPostEntity>(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            context.pop(cubit.state.post);
          },
          child: Scaffold(
            backgroundColor: colors.bg,
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    child: Row(
                      children: [
                        AppIconButton(
                          icon: const Icon(CupertinoIcons.back),
                          onPressed: () => context.pop(cubit.state.post),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.pushNamed(
                              RouteNames.community,
                              pathParameters: {'slug': state.post.community.slug},
                            ),
                            child: Text(
                              '${state.post.community.emoji}  ${state.post.community.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.titleMd.copyWith(color: colors.ink),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _onScroll,
                      child: RefreshIndicator(
                        onRefresh: cubit.refresh,
                        color: colors.ink,
                        backgroundColor: colors.surf,
                        child: ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                          children: [
                            _ThreadHeader(
                              post: state.post,
                              busy: state.isVoting,
                              onVote: cubit.toggleVote,
                              onReact: cubit.react,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'COMMENTS · ${Formatters.compactCount(state.post.commentCount)}',
                              style: AppTextStyles.eyebrow.copyWith(color: colors.ink2),
                            ),
                            const SizedBox(height: 10),
                            if (state.status == CommunityPostStatus.loading && state.comments.isEmpty)
                              const ShimmerListCard()
                            else if (state.status == CommunityPostStatus.error && state.comments.isEmpty)
                              ErrorView(
                                message: state.errorMessage ?? 'Could not load comments.',
                                onRetry: cubit.refresh,
                              )
                            else if (state.comments.isEmpty)
                              const EmptyStateCard(
                                title: 'NO COMMENTS',
                                hint: 'Be the first to say something.',
                              )
                            else
                              for (final root in state.roots) ...[
                                _CommentTile(
                                  comment: root,
                                  state: state,
                                  onReply: () => cubit.startReply(root),
                                  onEdit: () => cubit.startEdit(root),
                                  onDelete: () => _confirmDelete(context, cubit, root),
                                ),
                                for (final reply in state.repliesTo(root.id))
                                  Padding(
                                    padding: const EdgeInsets.only(left: 30),
                                    child: _CommentTile(
                                      comment: reply,
                                      state: state,
                                      onReply: () => cubit.startReply(reply),
                                      onEdit: () => cubit.startEdit(reply),
                                      onDelete: () => _confirmDelete(context, cubit, reply),
                                    ),
                                  ),
                                const SizedBox(height: 10),
                              ],
                            if (state.isLoadingMore)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 18),
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _Composer(
                    controller: _composer,
                    focusNode: _composerFocus,
                    state: state,
                    onSubmit: _submit,
                    onCancelReply: cubit.cancelReply,
                    onCancelEdit: cubit.cancelEdit,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CommunityPostCubit cubit,
    CommentEntity comment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('Its replies go with it. This cannot be undone.'),
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
    await cubit.deleteComment(comment);
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.post,
    required this.busy,
    required this.onVote,
    required this.onReact,
  });

  final CommunityPostEntity post;
  final bool busy;
  final void Function(CommunityVote vote) onVote;
  final void Function(ReactionType type) onReact;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                initials: post.authorDisplayName.initials,
                seed: avatarSeedForId(post.authorId),
                imageUrl: post.authorAvatarUrl,
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMd.copyWith(color: colors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${post.authorUsername.withAtSign} · ${Formatters.relativeShort(post.createdAt)}',
                      style: AppTextStyles.metaMono.copyWith(color: colors.ink3),
                    ),
                  ],
                ),
              ),
              if (post.tag.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.yelb,
                    border: Border.all(color: colors.line, width: 1),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    post.tag.toUpperCase(),
                    style: AppTextStyles.metaMonoSm.copyWith(color: colors.yeld),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(post.title, style: AppTextStyles.quote.copyWith(color: colors.ink, fontSize: 20)),
          if (post.hasBody) ...[
            const SizedBox(height: 10),
            Text(post.body, style: AppTextStyles.body.copyWith(color: colors.ink2)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _VotePill(score: post.score, vote: post.viewerVote, busy: busy, onVote: onVote),
              const SizedBox(width: 10),
              // `Expanded` has to be a direct child of the `Row`, so it lives
              // here rather than inside `_ReactionRow`'s own build.
              Expanded(
                child: _ReactionRow(
                  counts: post.reactionCounts,
                  viewerReaction: post.viewerReactionType,
                  busy: busy,
                  onReact: onReact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontal up / score / down, sized for the thread header rather than the
/// card's vertical column.
class _VotePill extends StatelessWidget {
  const _VotePill({required this.score, required this.vote, required this.busy, required this.onVote});

  final int score;
  final CommunityVote vote;
  final bool busy;
  final void Function(CommunityVote vote) onVote;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surf2,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          _ArrowButton(
            up: true,
            active: vote == CommunityVote.up,
            busy: busy,
            onTap: () => onVote(CommunityVote.up),
          ),
          Text(
            Formatters.compactCount(score),
            style: AppTextStyles.titleSm.copyWith(
              color: switch (vote) {
                CommunityVote.up => colors.yeld,
                CommunityVote.down => colors.red,
                CommunityVote.none => colors.ink,
              },
            ),
          ),
          _ArrowButton(
            up: false,
            active: vote == CommunityVote.down,
            busy: busy,
            onTap: () => onVote(CommunityVote.down),
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.up, required this.active, required this.busy, required this.onTap});

  final bool up;
  final bool active;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      child: SizedBox(
        width: 38,
        height: 34,
        child: Center(
          child: VoteArrowIcon(up: up, active: active, dimmed: busy, size: 20),
        ),
      ),
    );
  }
}

/// The full six-type reaction row, laid out inline — there is room here,
/// unlike on a list card where the same choice hides behind a long-press.
class _ReactionRow extends StatelessWidget {
  const _ReactionRow({
    required this.counts,
    required this.viewerReaction,
    required this.busy,
    required this.onReact,
  });

  final Map<String, int> counts;
  final ReactionType? viewerReaction;
  final bool busy;
  final void Function(ReactionType type) onReact;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final type in ReactionType.values) ...[
            GestureDetector(
              onTap: busy ? null : () => onReact(type),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: viewerReaction == type ? colors.yelb : Colors.transparent,
                  border: Border.all(
                    color: viewerReaction == type ? colors.yel : colors.line,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Row(
                  children: [
                    Text(type.emoji, style: const TextStyle(fontSize: 13)),
                    if ((counts[type.wireValue] ?? 0) > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        Formatters.compactCount(counts[type.wireValue] ?? 0),
                        style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.state,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
  });

  final CommentEntity comment;
  final CommunityPostState state;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final busy = state.busyCommentIds.contains(comment.id);
    final isEditing = state.editingId == comment.id;

    return Opacity(
      opacity: busy ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: isEditing ? colors.yelb : colors.surf,
          border: Border.all(color: isEditing ? colors.yel : colors.line2, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(
              initials: comment.authorUsername.initials,
              seed: avatarSeedForId(comment.authorId),
              imageUrl: comment.authorAvatarUrl,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          comment.authorUsername.withAtSign,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleSm.copyWith(color: colors.ink),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Formatters.relativeShort(comment.createdAt),
                        style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(comment.content, style: AppTextStyles.bodySm.copyWith(color: colors.ink)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _TextAction(label: 'Reply', onTap: busy ? null : onReply),
                      if (state.isMine(comment)) ...[
                        const SizedBox(width: 14),
                        _TextAction(label: 'Edit', onTap: busy ? null : onEdit),
                      ],
                      if (state.canDelete(comment)) ...[
                        const SizedBox(width: 14),
                        _TextAction(label: 'Delete', onTap: busy ? null : onDelete, danger: true),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap, this.danger = false});

  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.metaMonoSm.copyWith(
          color: onTap == null ? colors.ink3 : (danger ? colors.red : colors.ink2),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.state,
    required this.onSubmit,
    required this.onCancelReply,
    required this.onCancelEdit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final CommunityPostState state;
  final Future<void> Function() onSubmit;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelEdit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final replyingTo = state.replyingTo;
    final isEditing = state.editingId != null;

    return Container(
      padding: EdgeInsets.fromLTRB(14, 8, 14, 8 + MediaQuery.viewInsetsOf(context).bottom),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(top: BorderSide(color: colors.line, width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEditing || replyingTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'EDITING YOUR COMMENT'
                          : 'REPLYING TO ${replyingTo!.authorUsername.withAtSign.toUpperCase()}',
                      style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
                    ),
                  ),
                  GestureDetector(
                    onTap: isEditing ? onCancelEdit : onCancelReply,
                    child: Icon(CupertinoIcons.xmark, size: 16, color: colors.ink3),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: colors.surf,
                    border: Border.all(color: colors.line, width: 1.5),
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    style: AppTextStyles.bodySm.copyWith(color: colors.ink),
                    decoration: InputDecoration(
                      hintText: isEditing ? 'Update your comment' : 'Add a comment',
                      hintStyle: AppTextStyles.hint.copyWith(color: colors.ink3),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                label: isEditing ? 'Save' : 'Post',
                dense: true,
                onPressed: state.isPosting ? null : () => onSubmit(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
