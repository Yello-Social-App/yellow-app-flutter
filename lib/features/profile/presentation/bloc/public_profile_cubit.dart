import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../feed/domain/entities/post_entity.dart';
import '../../../feed/domain/usecases/delete_post_usecase.dart';
import '../../../feed/domain/usecases/like_post_usecase.dart';
import '../../../feed/domain/usecases/react_usecases.dart';
import '../../../friends/domain/entities/friendship_entity.dart';
import '../../../friends/domain/usecases/friends_usecases.dart';
import '../../domain/entities/public_user_entity.dart';
import '../../domain/usecases/profile_usecases.dart';

enum PublicProfileStatus { initial, loading, loaded, error }

/// The viewer's relationship, taken from the API's friendStatus.
enum FriendStatus { self, friends, incomingRequest, requestSent, none }

class PublicProfileState extends Equatable {
  const PublicProfileState({
    this.status = PublicProfileStatus.initial,
    this.user,
    this.posts = const [],
    this.friendStatus = FriendStatus.none,
    this.incomingRequestId,
    this.friendActionBusy = false,
    this.blockedByMe = false,
    this.errorMessage,
    this.hasMorePosts = false,
    this.loadingMorePosts = false,
  });

  final PublicProfileStatus status;
  final PublicUserEntity? user;
  final List<PostEntity> posts;
  final FriendStatus friendStatus;

  /// Set only when [friendStatus] is [FriendStatus.incomingRequest] — the id
  /// `AcceptFriendRequestUseCase`/`DeclineFriendRequestUseCase` need.
  ///
  /// That is the requesting user's own id, so it always equals [user]'s id:
  /// the API has no friendship-row id and addresses every request route by
  /// user (`POST /friends/requests/{user}/accept`). It stays a separate
  /// nullable field because its presence is also what says "there is an
  /// incoming request here to act on".
  final String? incomingRequestId;
  final bool friendActionBusy;
  final bool blockedByMe;
  final String? errorMessage;
  final bool hasMorePosts;
  final bool loadingMorePosts;

  PublicProfileState copyWith({
    PublicProfileStatus? status,
    PublicUserEntity? user,
    List<PostEntity>? posts,
    FriendStatus? friendStatus,
    Object? incomingRequestId = _unset,
    bool? friendActionBusy,
    bool? blockedByMe,
    String? errorMessage,
    bool? hasMorePosts,
    bool? loadingMorePosts,
  }) {
    return PublicProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      posts: posts ?? this.posts,
      friendStatus: friendStatus ?? this.friendStatus,
      incomingRequestId: identical(incomingRequestId, _unset)
          ? this.incomingRequestId
          : incomingRequestId as String?,
      friendActionBusy: friendActionBusy ?? this.friendActionBusy,
      blockedByMe: blockedByMe ?? this.blockedByMe,
      errorMessage: errorMessage,
      hasMorePosts: hasMorePosts ?? this.hasMorePosts,
      loadingMorePosts: loadingMorePosts ?? this.loadingMorePosts,
    );
  }

  @override
  List<Object?> get props => [
    status,
    user,
    posts,
    friendStatus,
    incomingRequestId,
    friendActionBusy,
    blockedByMe,
    errorMessage,
    hasMorePosts,
    loadingMorePosts,
  ];
}

const Object _unset = Object();

/// Read-only "someone else's profile" screen (`GET /users/{id}` +
/// `GET /users/{id}/posts`) — pushed from any avatar/username tap elsewhere
/// in the app (post author, comment author, a friends/notifications row).
/// Deliberately handles the "tapped my own avatar" case itself (via
/// [FriendStatus.self]) rather than making every tap site special-case it,
/// so `PublicProfilePage` is always safe to push regardless of who's shown.
class PublicProfileCubit extends Cubit<PublicProfileState> {
  PublicProfileCubit({
    required this.userId,
    BlockUserUseCase? blockUser,
    UnblockUserUseCase? unblockUser,
    required GetMeUseCase getMe,
    required GetUserUseCase getUser,
    required GetUserPostsUseCase getUserPosts,
    required GetFriendsUseCase getFriends,
    required GetFriendRequestsUseCase getFriendRequests,
    required SendFriendRequestUseCase sendFriendRequest,
    required AcceptFriendRequestUseCase acceptFriendRequest,
    required DeclineFriendRequestUseCase declineFriendRequest,
    required UnfriendUseCase unfriend,
    required LikePostUseCase likePost,
    required ReactToPostUseCase reactToPost,
    required RepostUseCase repost,
    required DeletePostUseCase deletePost,
    required ToggleSaveUseCase toggleSave,
  }) : _blockUser = blockUser,
       _unblockUser = unblockUser,
       _getMe = getMe,
       _getUser = getUser,
       _getUserPosts = getUserPosts,
       _getFriends = getFriends,
       _getFriendRequests = getFriendRequests,
       _sendFriendRequest = sendFriendRequest,
       _acceptFriendRequest = acceptFriendRequest,
       _declineFriendRequest = declineFriendRequest,
       _unfriend = unfriend,
       _likePost = likePost,
       _reactToPost = reactToPost,
       _repost = repost,
       _deletePost = deletePost,
       _toggleSave = toggleSave,
       super(const PublicProfileState());

  final BlockUserUseCase? _blockUser;
  final UnblockUserUseCase? _unblockUser;
  final String userId;
  final GetMeUseCase _getMe;
  final GetUserUseCase _getUser;
  final GetUserPostsUseCase _getUserPosts;
  final GetFriendsUseCase _getFriends;
  final GetFriendRequestsUseCase _getFriendRequests;
  final SendFriendRequestUseCase _sendFriendRequest;
  final AcceptFriendRequestUseCase _acceptFriendRequest;
  final DeclineFriendRequestUseCase _declineFriendRequest;
  final UnfriendUseCase _unfriend;
  final LikePostUseCase _likePost;
  final ReactToPostUseCase _reactToPost;
  final RepostUseCase _repost;
  final DeletePostUseCase _deletePost;
  final ToggleSaveUseCase _toggleSave;

  int _postsPage = 0;
  int _loadVersion = 0;

  Future<void> loadMorePosts() async {
    if (state.loadingMorePosts ||
        !state.hasMorePosts ||
        state.status != PublicProfileStatus.loaded) {
      return;
    }
    final version = _loadVersion;
    emit(state.copyWith(loadingMorePosts: true));
    final result = await _getUserPosts(
      GetUserPostsParams(userId: userId, page: _postsPage + 1),
    );
    if (isClosed) return;
    if (version != _loadVersion) return;
    result.fold(
      (failure) => emit(
        state.copyWith(loadingMorePosts: false, errorMessage: failure.message),
      ),
      (page) {
        _postsPage++;
        final existingIds = state.posts.map((post) => post.id).toSet();
        emit(
          state.copyWith(
            loadingMorePosts: false,
            hasMorePosts: page.hasMore,
            posts: [
              ...state.posts,
              ..._withMyReposts(
                page.posts
                    .where((post) => !existingIds.contains(post.id))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> load() async {
    if (state.loadingMorePosts || state.status == PublicProfileStatus.loading) {
      return;
    }
    _loadVersion++;
    emit(state.copyWith(status: PublicProfileStatus.loading));

    final meResult = await _getMe(const NoParams());
    // `PublicProfilePage` is pushed on every avatar/username tap and popped
    // freely — a pop while this multi-step chain is in flight closes this
    // factory cubit before it resolves. Same guard `ReactorsCubit.load()`
    // documents.
    if (isClosed) return;
    final myId = meResult.fold((_) => null, (me) => me.id);

    final userResult = await _getUser(userId);
    if (isClosed) return;
    if (userResult.isLeft()) {
      emit(
        state.copyWith(
          status: PublicProfileStatus.error,
          errorMessage: userResult.fold((l) => l.message, (_) => null),
        ),
      );
      return;
    }
    final user = userResult.fold((_) => null, (r) => r)!;

    _postsPage = 0;
    final postsResult = await _getUserPosts(GetUserPostsParams(userId: userId));
    if (isClosed) return;
    emit(
      state.copyWith(
        hasMorePosts: postsResult.fold((_) => false, (page) => page.hasMore),
      ),
    );
    if (postsResult.isLeft()) {
      emit(
        state.copyWith(
          status: PublicProfileStatus.error,
          posts: const [],
          errorMessage: postsResult.fold(
            (failure) => failure.message,
            (_) => null,
          ),
        ),
      );
      return;
    }
    if (myId != null) await _seedMyRepostIds(myId);
    if (isClosed) return;
    final posts = _withMyReposts(
      postsResult.fold((_) => <PostEntity>[], (page) => page.posts),
    );

    if (myId != null && myId == userId) {
      emit(
        state.copyWith(
          status: PublicProfileStatus.loaded,
          user: user,
          posts: posts,
          friendStatus: FriendStatus.self,
        ),
      );
      return;
    }

    final friendStatus = switch (user.friendStatus) {
      'SELF' => (FriendStatus.self, null),
      'FRIENDS' => (FriendStatus.friends, null),
      'REQUEST_SENT' => (FriendStatus.requestSent, null),
      'REQUEST_RECEIVED' => (FriendStatus.incomingRequest, userId),
      'NONE' => (FriendStatus.none, null),
      _ => await _resolveFriendStatus(),
    };
    if (isClosed) return;
    emit(
      state.copyWith(
        status: PublicProfileStatus.loaded,
        user: user,
        posts: posts,
        friendStatus: friendStatus.$1,
        incomingRequestId: friendStatus.$2,
      ),
    );
  }

  /// Cross-references `GET /friends` and `GET /friends/requests` (both page
  /// 0 only — the same single-page convention `NotificationsCubit` already
  /// uses for this kind of lookup, see memory) to classify [userId] relative
  /// to the viewer. Returns `(status, incomingRequestId)`.
  Future<(FriendStatus, String?)> _resolveFriendStatus() async {
    final friendsResult = await _getFriends(const PageParams());
    final isFriend = friendsResult.fold(
      (_) => false,
      (page) => page.friendships.any((f) => f.userId == userId),
    );
    if (isFriend) return (FriendStatus.friends, null);

    final requestsResult = await _getFriendRequests(const PageParams());
    final incomingMatches = requestsResult.fold(
      (_) => const <FriendshipEntity>[],
      (page) => page.friendships.where((f) => f.userId == userId).toList(),
    );
    if (incomingMatches.isNotEmpty) {
      return (FriendStatus.incomingRequest, incomingMatches.first.id);
    }

    return (FriendStatus.none, null);
  }

  Future<bool> setBlocked(bool blocked) async {
    if (state.friendActionBusy || state.loadingMorePosts) return false;
    _loadVersion++;
    final action = blocked ? _blockUser?.call : _unblockUser?.call;
    if (action == null) return false;
    emit(state.copyWith(friendActionBusy: true));
    final result = await action(UserIdParams(userId));
    if (isClosed) return false;
    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            friendActionBusy: false,
            errorMessage: failure.message,
          ),
        );
        return false;
      },
      (_) {
        emit(
          state.copyWith(
            friendActionBusy: false,
            blockedByMe: blocked,
            hasMorePosts: false,
            loadingMorePosts: false,
            posts: const [],
            friendStatus: FriendStatus.none,
            incomingRequestId: null,
          ),
        );
        return true;
      },
    );
  }

  Future<void> sendFriendRequest() async {
    emit(state.copyWith(friendActionBusy: true));
    final result = await _sendFriendRequest(UserIdParams(userId));
    // Same closed-page race as `load()`.
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(friendActionBusy: false, errorMessage: failure.message),
      ),
      (_) => emit(
        state.copyWith(
          friendActionBusy: false,
          friendStatus: FriendStatus.requestSent,
        ),
      ),
    );
  }

  Future<bool> acceptIncomingRequest() async {
    final requestId = state.incomingRequestId;
    if (requestId == null) return false;
    emit(state.copyWith(friendActionBusy: true));
    final result = await _acceptFriendRequest(RequestIdParams(requestId));
    // Same closed-page race as `load()`.
    if (isClosed) return false;
    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            friendActionBusy: false,
            errorMessage: failure.message,
          ),
        );
        return false;
      },
      (_) {
        emit(
          state.copyWith(
            friendActionBusy: false,
            friendStatus: FriendStatus.friends,
            incomingRequestId: null,
          ),
        );
        return true;
      },
    );
  }

  Future<bool> declineIncomingRequest() async {
    final requestId = state.incomingRequestId;
    if (requestId == null) return false;
    emit(state.copyWith(friendActionBusy: true));
    final result = await _declineFriendRequest(RequestIdParams(requestId));
    // Same closed-page race as `load()`.
    if (isClosed) return false;
    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            friendActionBusy: false,
            errorMessage: failure.message,
          ),
        );
        return false;
      },
      (_) {
        emit(
          state.copyWith(
            friendActionBusy: false,
            friendStatus: FriendStatus.none,
            incomingRequestId: null,
          ),
        );
        return true;
      },
    );
  }

  Future<void> unfriend() async {
    emit(state.copyWith(friendActionBusy: true));
    final result = await _unfriend(UserIdParams(userId));
    // Same closed-page race as `load()`.
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(friendActionBusy: false, errorMessage: failure.message),
      ),
      (_) => emit(
        state.copyWith(
          friendActionBusy: false,
          friendStatus: FriendStatus.none,
        ),
      ),
    );
  }

  Future<void> toggleLike(PostEntity post) async {
    final result = await _likePost(post);
    if (isClosed) return;
    result.fold((_) {}, (updated) => _replacePost(post.id, (_) => updated));
  }

  Future<void> react(PostEntity post, ReactionType type) async {
    final result = await _reactToPost(
      ReactToPostParams(post: post, type: type),
    );
    if (isClosed) return;
    result.fold((_) {}, (updated) => _replacePost(post.id, (_) => updated));
  }

  Future<void> toggleSave(String postId) async {
    final result = await _toggleSave(PostIdParams(postId));
    if (isClosed) return;
    result.fold(
      (_) {},
      (saved) => _replacePost(postId, (p) => p.copyWith(savedByMe: saved)),
    );
  }

  /// The viewer's own repost of a given original post id — see
  /// `FeedCubit._myRepostIds`'s identical doc.
  final Map<String, String> _myRepostIds = {};

  static const _maxRepostScanPages = 25;

  /// Recovers reposts made in an earlier session — see
  /// `FeedCubit._seedMyRepostIds`'s identical doc for the full reasoning.
  /// [myUserId] is the *viewer's* id (this cubit's own [userId] field is
  /// whoever's profile is being looked at, which may be someone else).
  Future<void> _seedMyRepostIds(String myUserId) async {
    for (var page = 0; page < _maxRepostScanPages; page++) {
      final result = await _getUserPosts(
        GetUserPostsParams(userId: myUserId, page: page),
      );
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
  /// reasoning. This screen never listed the viewer's own reposts inline
  /// (only [user]'s posts, cross-referenced against [_myRepostIds]), so
  /// unlike `FeedCubit`/`ProfileCubit` there's no card to prepend or remove
  /// here — just the toggled count/flag on [post] itself.
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
          _replacePost(
            post.id,
            (p) =>
                p.copyWith(repostCount: p.repostCount - 1, repostedByMe: false),
          );
        });
      } else {
        final result = await _repost(RepostParams(postId: post.id));
        if (isClosed) return;
        result.fold((_) {}, (newPost) {
          _myRepostIds[post.id] = newPost.id;
          _replacePost(
            post.id,
            (p) =>
                p.copyWith(repostCount: p.repostCount + 1, repostedByMe: true),
          );
        });
      }
    } finally {
      _pendingReposts.remove(post.id);
    }
  }

  /// Re-applies [_myRepostIds] onto freshly-fetched posts — see
  /// `FeedCubit._withMyReposts`'s identical doc for why this is needed.
  List<PostEntity> _withMyReposts(List<PostEntity> posts) => posts
      .map(
        (p) =>
            _myRepostIds.containsKey(p.id) ? p.copyWith(repostedByMe: true) : p,
      )
      .toList();

  /// Applies a post that came back from its own detail screen — a reaction or
  /// a new comment made in there changes counts this list shows, and nothing
  /// re-fetches it on the way back (see ADR-032). No-ops on a post this list
  /// doesn't hold.
  ///
  /// [PostEntity.repostedByMe] is re-derived from [_myRepostIds] rather than
  /// taken from the incoming copy — see `FeedCubit.replacePost`'s identical
  /// doc for why that flag can never be trusted across screens.
  void applyUpdated(PostEntity post) =>
      _replacePost(post.id, (_) => post.copyWith(repostedByMe: _myRepostIds.containsKey(post.id)));

  void _replacePost(String id, PostEntity Function(PostEntity) update) {
    emit(
      state.copyWith(
        posts: state.posts.map((p) => p.id == id ? update(p) : p).toList(),
      ),
    );
  }
}
