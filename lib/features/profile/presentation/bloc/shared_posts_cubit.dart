import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../feed/domain/entities/post_entity.dart';
import '../../../feed/domain/usecases/delete_post_usecase.dart';
import '../../../feed/domain/usecases/like_post_usecase.dart';
import '../../../feed/domain/usecases/react_usecases.dart';
import '../../domain/usecases/profile_usecases.dart';

enum SharedPostsStatus { loading, loaded, error }

class SharedPostsState extends Equatable {
  const SharedPostsState({this.status = SharedPostsStatus.loading, this.posts = const [], this.errorMessage});

  final SharedPostsStatus status;
  final List<PostEntity> posts;
  final String? errorMessage;

  SharedPostsState copyWith({SharedPostsStatus? status, List<PostEntity>? posts, String? errorMessage}) {
    return SharedPostsState(status: status ?? this.status, posts: posts ?? this.posts, errorMessage: errorMessage);
  }

  @override
  List<Object?> get props => [status, posts, errorMessage];
}

/// Backs the dedicated "Shared" screen reachable by tapping the Profile
/// stats row's Shared tile (`profile_page.dart`'s `_StatTile` — the same
/// "tap a stat, push a full screen" pattern the Connections tile already
/// uses to reach Circle). Shows the same posts as Profile's in-page
/// "Shared" tab (`ProfileState.repostedPosts`), just as its own screen
/// rather than an in-page filter.
///
/// Deliberately its own small cubit rather than reusing `ProfileCubit`:
/// `ProfileCubit` is `registerFactory` (see DI) — a fresh, unloaded
/// instance every time it's resolved — so a pushed page resolving it would
/// start from empty state, not the list already showing on Profile.
/// Every other pushed page in this app (`PostDetailCubit`,
/// `PublicProfileCubit`) already owns a fresh, independently-loading cubit
/// rather than reaching back into a caller's, so this follows that same
/// convention instead of fighting it.
class SharedPostsCubit extends Cubit<SharedPostsState> {
  SharedPostsCubit({
    required GetMeUseCase getMe,
    required GetUserPostsUseCase getUserPosts,
    required LikePostUseCase likePost,
    required ReactToPostUseCase reactToPost,
    required ToggleSaveUseCase toggleSave,
    required RepostUseCase repost,
    required DeletePostUseCase deletePost,
  }) : _getMe = getMe,
       _getUserPosts = getUserPosts,
       _likePost = likePost,
       _reactToPost = reactToPost,
       _toggleSave = toggleSave,
       _repost = repost,
       _deletePost = deletePost,
       super(const SharedPostsState());

  final GetMeUseCase _getMe;
  final GetUserPostsUseCase _getUserPosts;
  final LikePostUseCase _likePost;
  final ReactToPostUseCase _reactToPost;
  final ToggleSaveUseCase _toggleSave;
  final RepostUseCase _repost;
  final DeletePostUseCase _deletePost;

  Future<void> load() async {
    emit(state.copyWith(status: SharedPostsStatus.loading));

    final meResult = await _getMe(const NoParams());
    // This screen is pushed/popped like `PostDetailCubit`/`PublicProfileCubit`
    // — a pop while this chain is in flight closes this factory cubit before
    // it resolves. Same guard `ReactorsCubit.load()` documents.
    if (isClosed) return;
    if (meResult.isLeft()) {
      emit(state.copyWith(status: SharedPostsStatus.error, errorMessage: meResult.fold((l) => l.message, (_) => null)));
      return;
    }
    final me = meResult.fold((_) => null, (r) => r)!;

    await _seedMyRepostIds(me.id);
    if (isClosed) return;

    final postsResult = await _getUserPosts(GetUserPostsParams(userId: me.id));
    if (isClosed) return;
    postsResult.fold(
      (failure) => emit(state.copyWith(status: SharedPostsStatus.error, errorMessage: failure.message)),
      (page) => emit(
        state.copyWith(
          status: SharedPostsStatus.loaded,
          posts: _withMyReposts(page.posts.where((p) => p.isRepost).toList()),
        ),
      ),
    );
  }

  Future<void> toggleLike(PostEntity post) async {
    final result = await _likePost(post);
    if (isClosed) return;
    result.fold((_) {}, (updated) => _replace(post.id, (_) => updated));
  }

  /// Sets/switches/removes [post]'s reaction to [type] — the long-press
  /// reaction-picker path (see [toggleLike] for the plain single-tap path).
  Future<void> react(PostEntity post, ReactionType type) async {
    final result = await _reactToPost(ReactToPostParams(post: post, type: type));
    if (isClosed) return;
    result.fold((_) {}, (updated) => _replace(post.id, (_) => updated));
  }

  Future<void> toggleSave(String postId) async {
    final result = await _toggleSave(PostIdParams(postId));
    if (isClosed) return;
    result.fold((_) {}, (saved) => _replace(postId, (p) => p.copyWith(savedByMe: saved)));
  }

  /// The viewer's own repost of a given original post id — see
  /// `FeedCubit._myRepostIds`'s identical doc.
  final Map<String, String> _myRepostIds = {};

  static const _maxRepostScanPages = 25;

  /// Recovers reposts made in an earlier session — see
  /// `FeedCubit._seedMyRepostIds`'s identical doc for the full reasoning.
  Future<void> _seedMyRepostIds(String myUserId) async {
    for (var page = 0; page < _maxRepostScanPages; page++) {
      final result = await _getUserPosts(GetUserPostsParams(userId: myUserId, page: page));
      var hasMore = false;
      final failed = result.isLeft();
      result.fold((_) {}, (data) {
        hasMore = data.hasMore;
        for (final p in data.posts) {
          if (p.isRepost) _myRepostIds[p.originalPost!.id] = p.id;
        }
      });
      if (failed || !hasMore) break;
    }
  }

  /// Same re-entrancy guard as `FeedCubit._pendingReposts` — see its doc.
  final Set<String> _pendingReposts = {};

  /// Toggles [post]'s repost state — two outcomes, same shape as
  /// [toggleLike]; see `FeedCubit.toggleRepost`'s doc for the full
  /// reasoning. Note every card on this screen is itself already a repost
  /// (see class doc) — tapping this reposts/cancels *that* repost post, not
  /// the original it quotes, same as everywhere else `PostCard` is used.
  Future<void> toggleRepost(PostEntity post) async {
    if (!_pendingReposts.add(post.id)) return;
    try {
      if (post.repostedByMe) {
        final myRepostId = _myRepostIds[post.id];
        if (myRepostId == null) return;
        final result = await _deletePost(myRepostId);
        if (isClosed) return;
        result.fold((_) {}, (_) {
          _myRepostIds.remove(post.id);
          _replace(post.id, (p) => p.copyWith(repostCount: p.repostCount - 1, repostedByMe: false));
        });
      } else {
        final result = await _repost(RepostParams(postId: post.id));
        if (isClosed) return;
        result.fold((_) {}, (newPost) {
          _myRepostIds[post.id] = newPost.id;
          _replace(post.id, (p) => p.copyWith(repostCount: p.repostCount + 1, repostedByMe: true));
        });
      }
    } finally {
      _pendingReposts.remove(post.id);
    }
  }

  /// Re-applies [_myRepostIds] onto freshly-fetched posts — see
  /// `FeedCubit._withMyReposts`'s identical doc for why this is needed.
  List<PostEntity> _withMyReposts(List<PostEntity> posts) =>
      posts.map((p) => _myRepostIds.containsKey(p.id) ? p.copyWith(repostedByMe: true) : p).toList();

  /// Applies a post that came back from its own detail screen — a reaction or
  /// a new comment made in there changes counts this list shows, and nothing
  /// re-fetches it on the way back (see ADR-032). No-ops on a post this list
  /// doesn't hold.
  ///
  /// [PostEntity.repostedByMe] is re-derived from [_myRepostIds] rather than
  /// taken from the incoming copy — see `FeedCubit.replacePost`'s identical
  /// doc for why that flag can never be trusted across screens.
  void applyUpdated(PostEntity post) =>
      _replace(post.id, (_) => post.copyWith(repostedByMe: _myRepostIds.containsKey(post.id)));

  void _replace(String id, PostEntity Function(PostEntity) update) {
    final index = state.posts.indexWhere((p) => p.id == id);
    if (index == -1) return;
    final next = [...state.posts];
    next[index] = update(next[index]);
    emit(state.copyWith(posts: next));
  }
}
