import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../feed/domain/entities/comment_entity.dart';
import '../../../feed/domain/entities/post_entity.dart' show ReactionType;
import '../../../feed/domain/usecases/delete_comment_usecase.dart';
import '../../../feed/domain/usecases/edit_comment_usecase.dart';
import '../../../profile/domain/usecases/profile_usecases.dart' show GetMeUseCase;
import '../../domain/entities/community_post_entity.dart';
import '../../domain/usecases/communities_usecases.dart';

enum CommunityPostStatus { initial, loading, loaded, error }

class CommunityPostState extends Equatable {
  const CommunityPostState({
    required this.post,
    this.status = CommunityPostStatus.initial,
    this.comments = const [],
    this.page = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.isVoting = false,
    this.isPosting = false,
    this.replyingTo,
    this.editingId,
    this.errorMessage,
    this.busyCommentIds = const {},
    this.viewerId,
  });

  /// The thread itself. Never null: there is no `GET /community-posts/{id}`
  /// route, so this screen is always opened *with* the post it shows and
  /// updates it in place from the vote/reaction responses.
  final CommunityPostEntity post;
  final CommunityPostStatus status;
  final List<CommentEntity> comments;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isVoting;
  final bool isPosting;

  /// Top-level comment being replied to, or null for a root comment. The
  /// backend only nests one level deep, so replying to a reply attaches to
  /// that reply's own parent — see [CommunityPostCubit.startReply].
  final CommentEntity? replyingTo;

  /// Comment currently open in the editor, or null when composing a new one.
  final String? editingId;
  final String? errorMessage;
  final Set<String> busyCommentIds;

  /// The signed-in user's id, once `/users/me` has answered.
  ///
  /// The `Comment` schema has no `isOwner` flag (unlike `Post` and
  /// `CommunityPost`), so "can I edit this?" has to be decided by comparing
  /// author ids — which means knowing who the viewer is. Null until that
  /// resolves, and while it is null no comment offers an edit control rather
  /// than offering one that would 403.
  final String? viewerId;

  /// True when [comment] was written by the signed-in user.
  bool isMine(CommentEntity comment) => viewerId != null && comment.authorId == viewerId;

  /// The commenter may edit; the commenter, the thread's author and moderators
  /// may delete. `isOwner` on the post covers the thread-author case; a
  /// moderator's extra power is only knowable server-side, so a moderator sees
  /// no delete control here and the endpoint stays the source of truth.
  bool canDelete(CommentEntity comment) => isMine(comment) || post.isOwner;

  /// Root comments, in wire order (newest first).
  List<CommentEntity> get roots => [
    for (final c in comments)
      if (!c.isReply) c,
  ];

  List<CommentEntity> repliesTo(String commentId) => [
    for (final c in comments)
      if (c.parentCommentId == commentId) c,
  ];

  CommunityPostState copyWith({
    CommunityPostEntity? post,
    CommunityPostStatus? status,
    List<CommentEntity>? comments,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isVoting,
    bool? isPosting,
    Object? replyingTo = _unset,
    Object? editingId = _unset,
    String? errorMessage,
    Set<String>? busyCommentIds,
    String? viewerId,
  }) {
    return CommunityPostState(
      post: post ?? this.post,
      status: status ?? this.status,
      comments: comments ?? this.comments,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isVoting: isVoting ?? this.isVoting,
      isPosting: isPosting ?? this.isPosting,
      // Sentinels: clearing a reply target / closing the editor both mean
      // setting these back to null, which a null-coalesce could not express.
      replyingTo: identical(replyingTo, _unset) ? this.replyingTo : replyingTo as CommentEntity?,
      editingId: identical(editingId, _unset) ? this.editingId : editingId as String?,
      errorMessage: errorMessage,
      busyCommentIds: busyCommentIds ?? this.busyCommentIds,
      viewerId: viewerId ?? this.viewerId,
    );
  }

  @override
  List<Object?> get props => [
    post,
    status,
    comments,
    page,
    hasMore,
    isLoadingMore,
    isVoting,
    isPosting,
    replyingTo,
    editingId,
    errorMessage,
    busyCommentIds,
    viewerId,
  ];
}

/// One community thread and its comments.
///
/// Created per push with the post it should show (`registerFactoryParam`),
/// because the backend exposes no single-community-post route — a thread is
/// only reachable from one of the two list endpoints. That also means a cold
/// deep link into a thread cannot be served; the route falls back to the
/// community's own screen instead (see `app_router.dart`).
class CommunityPostCubit extends Cubit<CommunityPostState> {
  CommunityPostCubit({
    required CommunityPostEntity post,
    required GetCommunityCommentsUseCase getComments,
    required AddCommunityCommentUseCase addComment,
    required VoteCommunityPostUseCase vote,
    required ReactToCommunityPostUseCase react,
    required EditCommentUseCase editComment,
    required DeleteCommentUseCase deleteComment,
    required GetMeUseCase getMe,
  })  : _getComments = getComments,
        _addComment = addComment,
        _vote = vote,
        _react = react,
        _editComment = editComment,
        _deleteComment = deleteComment,
        _getMe = getMe,
        super(CommunityPostState(post: post));

  final GetCommunityCommentsUseCase _getComments;
  final AddCommunityCommentUseCase _addComment;
  final VoteCommunityPostUseCase _vote;
  final ReactToCommunityPostUseCase _react;
  final EditCommentUseCase _editComment;
  final DeleteCommentUseCase _deleteComment;
  final GetMeUseCase _getMe;

  Future<void> load() async {
    if (state.status == CommunityPostStatus.loaded) return;
    // Who the viewer is only gates the edit/delete affordances, so it is
    // fetched alongside the comments and never blocks them: a failure here
    // costs those controls, not the thread.
    final identity = _getMe(const NoParams());
    await refresh();
    final me = await identity;
    if (isClosed) return;
    me.fold((_) {}, (user) => emit(state.copyWith(viewerId: user.id)));
  }

  Future<void> refresh() async {
    emit(state.copyWith(status: CommunityPostStatus.loading));
    final result = await _getComments(CommunityCommentsParams(postId: state.post.id));
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(status: CommunityPostStatus.error, errorMessage: failure.message)),
      (page) => emit(
        state.copyWith(
          status: CommunityPostStatus.loaded,
          comments: page.comments,
          page: 0,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      ),
    );
  }

  Future<void> loadMoreComments() async {
    if (state.status != CommunityPostStatus.loaded || !state.hasMore || state.isLoadingMore) return;

    final nextPage = state.page + 1;
    emit(state.copyWith(isLoadingMore: true));

    final result = await _getComments(
      CommunityCommentsParams(postId: state.post.id, page: nextPage),
    );
    if (isClosed) return;
    result.fold(
      (_) => emit(state.copyWith(isLoadingMore: false, hasMore: false)),
      (page) => emit(
        state.copyWith(
          comments: [...state.comments, ...page.comments],
          page: nextPage,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      ),
    );
  }

  /// Targets [comment]'s own parent when it is itself a reply: the backend
  /// nests exactly one level, and `parentCommentId` must name a *top-level*
  /// comment, so "reply to a reply" lands beside it rather than under it.
  void startReply(CommentEntity comment) {
    final rootId = comment.parentCommentId ?? comment.id;
    final root = state.comments.firstWhere((c) => c.id == rootId, orElse: () => comment);
    emit(state.copyWith(replyingTo: root, editingId: null));
  }

  void cancelReply() => emit(state.copyWith(replyingTo: null));

  void startEdit(CommentEntity comment) => emit(state.copyWith(editingId: comment.id, replyingTo: null));

  void cancelEdit() => emit(state.copyWith(editingId: null));

  /// Submits the composer. Edits the open comment when [CommunityPostState.editingId]
  /// is set, otherwise posts a new comment (as a reply when a target is set).
  Future<bool> submit(String text) async {
    if (state.isPosting) return false;
    emit(state.copyWith(isPosting: true));

    final editingId = state.editingId;
    if (editingId != null) {
      final result = await _editComment(EditCommentParams(commentId: editingId, text: text));
      if (isClosed) return false;
      return result.fold(
        (failure) {
          emit(state.copyWith(isPosting: false, errorMessage: failure.message));
          return false;
        },
        (updated) {
          emit(
            state.copyWith(
              comments: [
                for (final c in state.comments)
                  if (c.id == updated.id) updated else c,
              ],
              isPosting: false,
              editingId: null,
            ),
          );
          return true;
        },
      );
    }

    final parent = state.replyingTo;
    final result = await _addComment(
      AddCommunityCommentParams(postId: state.post.id, text: text, parentCommentId: parent?.id),
    );
    if (isClosed) return false;
    return result.fold(
      (failure) {
        emit(state.copyWith(isPosting: false, errorMessage: failure.message));
        return false;
      },
      (comment) {
        emit(
          state.copyWith(
            // A reply goes directly after the replies already under its root so
            // the flat list still renders as a group; a root comment goes on
            // top, matching the list's newest-first order.
            comments: parent == null ? [comment, ...state.comments] : _insertReply(comment, parent.id),
            post: state.post.copyWith(commentCount: state.post.commentCount + 1),
            isPosting: false,
            replyingTo: null,
          ),
        );
        return true;
      },
    );
  }

  List<CommentEntity> _insertReply(CommentEntity reply, String rootId) {
    final out = <CommentEntity>[];
    var inserted = false;
    for (var i = 0; i < state.comments.length; i++) {
      final current = state.comments[i];
      out.add(current);
      if (inserted) continue;
      final isEndOfGroup = current.id == rootId || current.parentCommentId == rootId;
      final next = i + 1 < state.comments.length ? state.comments[i + 1] : null;
      if (isEndOfGroup && (next == null || next.parentCommentId != rootId)) {
        out.add(reply);
        inserted = true;
      }
    }
    // The root was paged out from under us — fall back to appending rather
    // than dropping the reply the user just wrote.
    if (!inserted) out.add(reply);
    return out;
  }

  Future<void> toggleVote(CommunityVote tapped) async {
    if (state.isVoting) return;
    emit(state.copyWith(isVoting: true));

    final result = await _vote(
      VoteCommunityPostParams(post: state.post, vote: tapped.toggledFrom(state.post.viewerVote)),
    );
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(isVoting: false, errorMessage: failure.message)),
      (updated) => emit(state.copyWith(post: updated, isVoting: false)),
    );
  }

  Future<void> react(ReactionType type) async {
    if (state.isVoting) return;
    emit(state.copyWith(isVoting: true));

    final result = await _react(ReactToCommunityPostParams(post: state.post, type: type));
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(isVoting: false, errorMessage: failure.message)),
      (updated) => emit(state.copyWith(post: updated, isVoting: false)),
    );
  }

  /// Deletes a comment (and, server-side, its replies) — allowed for the
  /// commenter, the thread's author, or a moderator, so the caller decides
  /// whether to offer it rather than this cubit guessing.
  Future<void> deleteComment(CommentEntity comment) async {
    if (state.busyCommentIds.contains(comment.id)) return;
    emit(state.copyWith(busyCommentIds: {...state.busyCommentIds, comment.id}));

    final result = await _deleteComment(comment.id);
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          errorMessage: failure.message,
          busyCommentIds: {...state.busyCommentIds}..remove(comment.id),
        ),
      ),
      (_) {
        // Replies are deleted with their parent server-side, so drop them here
        // too instead of leaving orphans whose parent no longer exists.
        final removed = <String>{
          comment.id,
          for (final c in state.comments)
            if (c.parentCommentId == comment.id) c.id,
        };
        final remaining = state.post.commentCount - removed.length;
        emit(
          state.copyWith(
            comments: [
              for (final c in state.comments)
                if (!removed.contains(c.id)) c,
            ],
            // The count came from the server and the replies may have been
            // paged out, so a naive subtraction can go negative.
            post: state.post.copyWith(commentCount: remaining < 0 ? 0 : remaining),
            busyCommentIds: {...state.busyCommentIds}..remove(comment.id),
            editingId: state.editingId == comment.id ? null : state.editingId,
          ),
        );
      },
    );
  }
}

const Object _unset = Object();
