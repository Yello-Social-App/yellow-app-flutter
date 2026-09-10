import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../profile/domain/usecases/profile_usecases.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/post_entity.dart';
import '../../domain/entities/reaction_breakdown.dart';
import '../../domain/usecases/add_comment_usecase.dart';
import '../../domain/usecases/delete_comment_usecase.dart';
import '../../domain/usecases/delete_post_usecase.dart';
import '../../domain/usecases/get_comments_usecase.dart';
import '../../domain/usecases/get_post_detail_usecase.dart';
import '../../domain/usecases/get_share_link_usecase.dart';
import '../../domain/usecases/like_post_usecase.dart';
import '../../domain/usecases/react_usecases.dart';
import '../../domain/usecases/update_post_usecase.dart';

enum PostDetailStatus { loading, loaded, error, deleted }

class PostDetailState extends Equatable {
  const PostDetailState({
    this.status = PostDetailStatus.loading,
    this.post,
    this.comments = const [],
    this.errorMessage,
    this.isSubmittingComment = false,
    this.currentUserId,
    this.commentsPage = 0,
    this.hasMoreComments = false,
    this.isLoadingMoreComments = false,
  });

  final PostDetailStatus status;
  final PostEntity? post;
  final List<CommentEntity> comments;
  final String? errorMessage;
  final bool isSubmittingComment;

  /// Fetched via `GET /users/me` so the "own post" check below is against
  /// a confirmed id rather than a guessed JWT claim shape.
  final String? currentUserId;

  /// The last comments page successfully loaded (0-based) — the backend
  /// paginates comments page-number style, not cursor style (see memory),
  /// so [loadMoreComments] just asks for `commentsPage + 1`.
  final int commentsPage;
  final bool hasMoreComments;
  final bool isLoadingMoreComments;

  bool get isOwnPost => currentUserId != null && post?.authorId == currentUserId;
  bool canDeleteComment(CommentEntity comment) =>
      currentUserId != null && (comment.authorId == currentUserId || isOwnPost);

  PostDetailState copyWith({
    PostDetailStatus? status,
    PostEntity? post,
    List<CommentEntity>? comments,
    String? errorMessage,
    bool? isSubmittingComment,
    String? currentUserId,
    int? commentsPage,
    bool? hasMoreComments,
    bool? isLoadingMoreComments,
  }) {
    return PostDetailState(
      status: status ?? this.status,
      post: post ?? this.post,
      comments: comments ?? this.comments,
      errorMessage: errorMessage,
      isSubmittingComment: isSubmittingComment ?? this.isSubmittingComment,
      currentUserId: currentUserId ?? this.currentUserId,
      commentsPage: commentsPage ?? this.commentsPage,
      hasMoreComments: hasMoreComments ?? this.hasMoreComments,
      isLoadingMoreComments: isLoadingMoreComments ?? this.isLoadingMoreComments,
    );
  }

  @override
  List<Object?> get props => [
        status,
        post,
        comments,
        errorMessage,
        isSubmittingComment,
        currentUserId,
        commentsPage,
        hasMoreComments,
        isLoadingMoreComments,
      ];
}

class PostDetailCubit extends Cubit<PostDetailState> {
  PostDetailCubit({
    required this.postId,
    required GetPostDetailUseCase getPostDetail,
    required GetCommentsUseCase getComments,
    required AddCommentUseCase addComment,
    required LikePostUseCase likePost,
    required ReactToPostUseCase reactToPost,
    required ReactToCommentUseCase reactToComment,
    required GetReactionSummaryUseCase getReactionSummary,
    required UpdatePostUseCase updatePost,
    required DeletePostUseCase deletePost,
    required DeleteCommentUseCase deleteComment,
    required GetShareLinkUseCase getShareLink,
    required GetMeUseCase getMe,
  }) : _getPostDetail = getPostDetail,
       _getComments = getComments,
       _addComment = addComment,
       _likePost = likePost,
       _reactToPost = reactToPost,
       _reactToComment = reactToComment,
       _getReactionSummary = getReactionSummary,
       _updatePost = updatePost,
       _deletePost = deletePost,
       _deleteComment = deleteComment,
       _getShareLink = getShareLink,
       _getMe = getMe,
       super(const PostDetailState());

  final String postId;
  final GetPostDetailUseCase _getPostDetail;
  final GetCommentsUseCase _getComments;
  final AddCommentUseCase _addComment;
  final LikePostUseCase _likePost;
  final ReactToPostUseCase _reactToPost;
  final ReactToCommentUseCase _reactToComment;
  final GetReactionSummaryUseCase _getReactionSummary;
  final UpdatePostUseCase _updatePost;
  final DeletePostUseCase _deletePost;
  final DeleteCommentUseCase _deleteComment;
  final GetShareLinkUseCase _getShareLink;
  final GetMeUseCase _getMe;

  Future<void> load() async {
    emit(state.copyWith(status: PostDetailStatus.loading));
    final result = await _getPostDetail(PostIdParams(postId));
    result.fold(
      (failure) => emit(state.copyWith(status: PostDetailStatus.error, errorMessage: failure.message)),
      (detail) => emit(PostDetailState(
        status: PostDetailStatus.loaded,
        post: detail.post,
        comments: detail.comments,
        hasMoreComments: detail.hasMoreComments,
      )),
    );
    // Best-effort — an own-post/own-comment check just stays hidden if this
    // fails, it doesn't block the rest of the page.
    (await _getMe(const NoParams())).fold((_) {}, (me) => emit(state.copyWith(currentUserId: me.id)));
  }

  /// Re-fetches the post + its first page of comments for pull-to-refresh —
  /// unlike [load], this never flips `status` to `loading`, so the page
  /// keeps showing what it already has (the `RefreshIndicator`'s own spinner
  /// is the only loading affordance) instead of blanking to a full-screen
  /// spinner mid-pull. This is currently the only way to see a comment
  /// someone else added after this page opened — there's no live/polling
  /// update. Silently keeps the stale list on failure, same convention as
  /// `FeedCubit.refresh` when posts are already loaded.
  Future<void> refresh() async {
    final result = await _getPostDetail(PostIdParams(postId));
    result.fold(
      (_) {},
      // Resets back to page 0 — a pull-to-refresh re-fetches only the first
      // page, same as `load()`, so any page 1+ previously loaded via
      // `loadMoreComments` is dropped rather than left stale.
      (detail) => emit(state.copyWith(
        post: detail.post,
        comments: detail.comments,
        commentsPage: 0,
        hasMoreComments: detail.hasMoreComments,
      )),
    );
  }

  /// Fetches the next page of top-level comments and appends them —
  /// id-deduped as a defensive backstop against the page-number pagination
  /// shifting underneath a concurrent new comment (see `commentsPage` doc).
  /// No-ops if a fetch is already in flight or the last page said there's
  /// nothing more.
  Future<void> loadMoreComments() async {
    if (state.isLoadingMoreComments || !state.hasMoreComments) return;
    emit(state.copyWith(isLoadingMoreComments: true));
    final nextPage = state.commentsPage + 1;
    final result = await _getComments(GetCommentsParams(postId: postId, page: nextPage));
    result.fold(
      (failure) => emit(state.copyWith(isLoadingMoreComments: false, errorMessage: failure.message)),
      (page) {
        final existingIds = state.comments.map((c) => c.id).toSet();
        final fresh = page.comments.where((c) => !existingIds.contains(c.id));
        emit(state.copyWith(
          isLoadingMoreComments: false,
          comments: [...state.comments, ...fresh],
          commentsPage: nextPage,
          hasMoreComments: page.hasMore,
        ));
      },
    );
  }

  /// Edits the post (only non-null fields change). Returns success so the
  /// UI can pop its edit sheet / show an error.
  Future<bool> updatePost({String? content, PostVisibility? visibility}) async {
    final result = await _updatePost(UpdatePostParams(postId: postId, content: content, visibility: visibility));
    return result.fold(
      (failure) {
        emit(state.copyWith(errorMessage: failure.message));
        return false;
      },
      (updated) {
        emit(state.copyWith(post: updated, errorMessage: null));
        return true;
      },
    );
  }

  Future<bool> deletePost() async {
    final result = await _deletePost(postId);
    return result.fold(
      (failure) {
        emit(state.copyWith(errorMessage: failure.message));
        return false;
      },
      (_) {
        emit(state.copyWith(status: PostDetailStatus.deleted));
        return true;
      },
    );
  }

  Future<bool> deleteComment(String commentId) async {
    final result = await _deleteComment(commentId);
    return result.fold(
      (failure) {
        emit(state.copyWith(errorMessage: failure.message));
        return false;
      },
      (_) {
        final post = state.post;
        emit(
          state.copyWith(
            comments: state.comments.where((c) => c.id != commentId).toList(),
            post: post?.copyWith(commentCount: post.commentCount > 0 ? post.commentCount - 1 : 0),
          ),
        );
        return true;
      },
    );
  }

  /// Returns the post's public share URL, or null on failure (the UI shows
  /// a snackbar either way).
  Future<String?> getShareLink() async {
    final result = await _getShareLink(postId);
    return result.fold((failure) {
      emit(state.copyWith(errorMessage: failure.message));
      return null;
    }, (url) => url);
  }

  /// Guards [toggleLike]/[react] against a fast double-tap firing a second
  /// request before the first response lands — see
  /// `FeedCubit._pendingReactions` for the full failure mode this closes
  /// (same one, just keyed by a single post since this cubit only ever
  /// holds the one being viewed).
  bool _postReactionPending = false;

  Future<void> toggleLike() async {
    final post = state.post;
    if (post == null || _postReactionPending) return;
    _postReactionPending = true;
    try {
      final result = await _likePost(post);
      result.fold((_) {}, (updated) => emit(state.copyWith(post: updated)));
    } finally {
      _postReactionPending = false;
    }
  }

  /// Sets/switches/removes the post's reaction to [type] — the long-press
  /// reaction-picker path (see [toggleLike] for the plain single-tap path).
  Future<void> react(ReactionType type) async {
    final post = state.post;
    if (post == null || _postReactionPending) return;
    _postReactionPending = true;
    try {
      final result = await _reactToPost(ReactToPostParams(post: post, type: type));
      result.fold((_) {}, (updated) => emit(state.copyWith(post: updated)));
    } finally {
      _postReactionPending = false;
    }
  }

  /// Comment ids with a reaction PUT/DELETE in flight — same double-tap
  /// guard as [_postReactionPending], keyed per comment since several
  /// comments can genuinely be reacted to concurrently (unlike the single
  /// post this cubit owns).
  final Set<String> _pendingCommentReactions = {};

  /// Same set/switch/remove semantics as [react], against one comment.
  Future<void> reactToComment(String commentId, ReactionType type) async {
    if (!_pendingCommentReactions.add(commentId)) return;
    try {
      final index = state.comments.indexWhere((c) => c.id == commentId);
      if (index == -1) return;
      final result = await _reactToComment(ReactToCommentParams(comment: state.comments[index], type: type));
      result.fold((_) {}, (updated) {
        final freshIndex = state.comments.indexWhere((c) => c.id == commentId);
        if (freshIndex == -1) return;
        final next = [...state.comments];
        next[freshIndex] = updated;
        emit(state.copyWith(comments: next));
      });
    } finally {
      _pendingCommentReactions.remove(commentId);
    }
  }

  /// On-demand reaction breakdown for this post (the overflow menu's "View
  /// reactions") — null on failure, same fold-to-null pattern as
  /// [getShareLink].
  Future<ReactionBreakdown?> getReactionSummary() async {
    final result = await _getReactionSummary(GetReactionSummaryParams(targetType: 'POST', targetId: postId));
    return result.fold((_) => null, (summary) => summary);
  }

  /// Same on-demand breakdown as [getReactionSummary], for one comment
  /// instead of the post itself (`targetType=COMMENT`) — the reaction count
  /// text on a comment/reply opens this.
  Future<ReactionBreakdown?> getCommentReactionSummary(String commentId) async {
    final result =
        await _getReactionSummary(GetReactionSummaryParams(targetType: 'COMMENT', targetId: commentId));
    return result.fold((_) => null, (summary) => summary);
  }

  /// [parentCommentId] nests this as a reply — always the *top-level*
  /// comment's id (never another reply's), matching the 2-level model
  /// `post_detail_page.dart` renders (see its `_Loaded`): replying to a
  /// reply still attaches to that reply's top-level parent, with an
  /// `@mention` in the text standing in for a third nesting level.
  Future<void> submitComment(String text, {String? parentCommentId}) async {
    if (text.trim().isEmpty || state.isSubmittingComment) return;
    emit(state.copyWith(isSubmittingComment: true));
    final result = await _addComment(AddCommentParams(postId: postId, text: text, parentCommentId: parentCommentId));
    result.fold((_) => emit(state.copyWith(isSubmittingComment: false)), (comment) {
      final post = state.post;
      emit(
        state.copyWith(
          isSubmittingComment: false,
          comments: [comment, ...state.comments],
          post: post?.copyWith(commentCount: post.commentCount + 1),
        ),
      );
    });
  }
}
