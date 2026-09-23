import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../feed/domain/entities/post_entity.dart';
import '../../../feed/domain/usecases/delete_post_usecase.dart';
import '../../../feed/domain/usecases/get_post_usecase.dart';
import '../../../feed/domain/usecases/get_saved_post_ids_usecase.dart';
import '../../../feed/domain/usecases/like_post_usecase.dart';
import '../../../feed/domain/usecases/react_usecases.dart';
import '../../../friends/domain/entities/friendship_entity.dart';
import '../../../friends/domain/usecases/friends_usecases.dart';
import '../../domain/usecases/profile_usecases.dart';

enum ProfileTab { posts, reposts, saved }

enum ProfileStatus { initial, loading, loaded, error }

class ProfileState extends Equatable {
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.user,
    this.connectionsCount = 0,
    this.connections = const [],
    this.myPosts = const [],
    this.savedPosts = const [],
    this.tab = ProfileTab.posts,
    this.errorMessage,
    this.hasMorePosts = false,
    this.loadingMorePosts = false,
    this.isUploadingAvatar = false,
  });

  final ProfileStatus status;
  final UserEntity? user;
  final int connectionsCount;

  /// First page of the viewer's friends, used only for the header's
  /// face-pile. [connectionsCount] stays the source of truth for the number —
  /// this list is a handful of avatars, not the whole circle.
  final List<FriendshipEntity> connections;
  final List<PostEntity> myPosts;
  final List<PostEntity> savedPosts;
  final ProfileTab tab;
  final String? errorMessage;
  final bool hasMorePosts;
  final bool loadingMorePosts;
  final bool isUploadingAvatar;

  List<PostEntity> get originalPosts =>
      myPosts.where((p) => !p.isRepost).toList();
  List<PostEntity> get repostedPosts =>
      myPosts.where((p) => p.isRepost).toList();

  List<PostEntity> get activeTabPosts => switch (tab) {
    ProfileTab.posts => originalPosts,
    ProfileTab.reposts => repostedPosts,
    ProfileTab.saved => savedPosts,
  };

  ProfileState copyWith({
    ProfileStatus? status,
    UserEntity? user,
    int? connectionsCount,
    List<FriendshipEntity>? connections,
    List<PostEntity>? myPosts,
    List<PostEntity>? savedPosts,
    ProfileTab? tab,
    String? errorMessage,
    bool? hasMorePosts,
    bool? loadingMorePosts,
    bool? isUploadingAvatar,
  }) {
    return ProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      connectionsCount: connectionsCount ?? this.connectionsCount,
      connections: connections ?? this.connections,
      myPosts: myPosts ?? this.myPosts,
      savedPosts: savedPosts ?? this.savedPosts,
      tab: tab ?? this.tab,
      errorMessage: errorMessage,
      hasMorePosts: hasMorePosts ?? this.hasMorePosts,
      loadingMorePosts: loadingMorePosts ?? this.loadingMorePosts,
      isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
    );
  }

  @override
  List<Object?> get props => [
    status,
    user,
    connectionsCount,
    connections,
    myPosts,
    savedPosts,
    tab,
    errorMessage,
    hasMorePosts,
    loadingMorePosts,
    isUploadingAvatar,
  ];
}

/// Owns the Profile tab: the signed-in user's own profile, their posts
/// (split into "posted" vs. "reposted" for the mockup's Post/Shared tabs),
/// and their locally-bookmarked posts for the Saved tab.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required GetMeUseCase getMe,
    required UpdateProfileUseCase updateProfile,
    required UpdateAvatarUseCase updateAvatar,
    required GetUserPostsUseCase getUserPosts,
    required GetSavedPostIdsUseCase getSavedPostIds,
    required GetPostUseCase getPost,
    required GetFriendsUseCase getFriends,
    required LikePostUseCase likePost,
    required ReactToPostUseCase reactToPost,
    required RepostUseCase repost,
    required DeletePostUseCase deletePost,
    required ToggleSaveUseCase toggleSave,
  }) : _getMe = getMe,
       _updateProfile = updateProfile,
       _updateAvatar = updateAvatar,
       _getUserPosts = getUserPosts,
       _getSavedPostIds = getSavedPostIds,
       _getPost = getPost,
       _getFriends = getFriends,
       _likePost = likePost,
       _reactToPost = reactToPost,
       _repost = repost,
       _deletePost = deletePost,
       _toggleSave = toggleSave,
       super(const ProfileState());

  final GetMeUseCase _getMe;
  final UpdateProfileUseCase _updateProfile;
  final UpdateAvatarUseCase _updateAvatar;
  final GetUserPostsUseCase _getUserPosts;
  final GetSavedPostIdsUseCase _getSavedPostIds;
  final GetPostUseCase _getPost;
  final GetFriendsUseCase _getFriends;
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
        state.status != ProfileStatus.loaded) {
      return;
    }
    final version = _loadVersion;
    emit(state.copyWith(loadingMorePosts: true));
    final result = await _getUserPosts(
      GetUserPostsParams(userId: state.user!.id, page: _postsPage + 1),
    );
    if (isClosed) return;
    if (version != _loadVersion) return;
    result.fold(
      (failure) => emit(
        state.copyWith(loadingMorePosts: false, errorMessage: failure.message),
      ),
      (page) {
        _postsPage++;
        final existingIds = state.myPosts.map((post) => post.id).toSet();
        emit(
          state.copyWith(
            loadingMorePosts: false,
            hasMorePosts: page.hasMore,
            myPosts: [
              ...state.myPosts,
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
    if (state.status == ProfileStatus.loaded) return;
    await refresh();
  }

  Future<void> refresh() async {
    if (state.loadingMorePosts || state.status == ProfileStatus.loading) return;
    _loadVersion++;
    emit(state.copyWith(status: ProfileStatus.loading));

    final meResult = await _getMe(const NoParams());
    // While Profile is normally kept alive across tab switches, this
    // factory cubit is still closed by a `BlocProvider` on genuine pop
    // (e.g. re-entering via a fresh push after sign-out) — a pop mid-chain
    // closes it before this resolves. Same guard `ReactorsCubit.load()`
    // documents.
    if (isClosed) return;
    if (meResult.isLeft()) {
      emit(
        state.copyWith(
          status: ProfileStatus.error,
          errorMessage: meResult.fold((l) => l.message, (_) => null),
        ),
      );
      return;
    }
    final user = meResult.fold((_) => null, (r) => r)!;

    _postsPage = 0;
    final postsResult = await _getUserPosts(
      GetUserPostsParams(userId: user.id),
    );
    if (isClosed) return;
    emit(
      state.copyWith(
        hasMorePosts: postsResult.fold((_) => false, (page) => page.hasMore),
      ),
    );
    final myPosts = postsResult.fold(
      (_) => <PostEntity>[],
      (page) => page.posts,
    );

    final savedPosts = await _loadSavedPosts();
    if (isClosed) return;

    await _seedMyRepostIds(user.id);
    if (isClosed) return;

    emit(
      state.copyWith(
        status: ProfileStatus.loaded,
        user: user,
        myPosts: _withMyReposts(myPosts),
        connectionsCount: user.friendsCount,
        savedPosts: _withMyReposts(savedPosts),
      ),
    );

    // Friend avatars for the header's face-pile. Deliberately after the
    // `loaded` emit above so the profile still paints at the same moment it
    // always has: the row shows the count alone until this lands, and stays
    // that way if the call fails.
    final friendsResult = await _getFriends(const PageParams());
    if (isClosed) return;
    friendsResult.fold((_) {}, (page) => emit(state.copyWith(connections: page.friendships)));
  }

  /// Re-applies [_myRepostIds] onto freshly-fetched posts — see
  /// `FeedCubit._withMyReposts`'s identical doc for why this is needed.
  List<PostEntity> _withMyReposts(List<PostEntity> posts) => posts
      .map(
        (p) =>
            _myRepostIds.containsKey(p.id) ? p.copyWith(repostedByMe: true) : p,
      )
      .toList();

  Future<List<PostEntity>> _loadSavedPosts() async {
    final idsResult = await _getSavedPostIds(const NoParams());
    final ids = idsResult.fold((_) => <String>[], (r) => r);
    final posts = <PostEntity>[];
    for (final id in ids) {
      final result = await _getPost(PostIdParams(id));
      result.fold((_) {}, posts.add);
    }
    return posts;
  }

  void selectTab(ProfileTab tab) => emit(state.copyWith(tab: tab));

  /// Returns success so the page can show a snackbar on either outcome,
  /// same convention as [uploadAvatar] below.
  Future<bool> updateProfile({
    String? username,
    String? fullName,
    String? bio,
    bool clearFullName = false,
    bool clearBio = false,
    File? avatar,
    File? cover,
    bool? removeAvatar,
    bool? removeCover,
  }) async {
    if (state.isUploadingAvatar) return false;
    emit(state.copyWith(isUploadingAvatar: true));
    final result = await _updateProfile(
      UpdateProfileParams(
        username: username,
        fullName: fullName,
        bio: bio,
        clearFullName: clearFullName,
        clearBio: clearBio,
        avatar: avatar,
        cover: cover,
        removeAvatar: removeAvatar,
        removeCover: removeCover,
      ),
    );
    if (isClosed) return false;
    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            isUploadingAvatar: false,
            errorMessage: failure.message,
          ),
        );
        return false;
      },
      (user) {
        emit(
          state.copyWith(
            isUploadingAvatar: false,
            user: user,
            errorMessage: null,
          ),
        );
        return true;
      },
    );
  }

  /// Uploads a new avatar (`POST /users/me`, multipart) and swaps it
  /// into `state.user` on success. [isUploadingAvatar] just gates the UI's
  /// own busy affordance. Returns success so the page can show a snackbar on
  /// failure, same convention as `PostDetailCubit.updatePost`/`deletePost`.
  Future<bool> uploadAvatar(File file) async {
    if (state.isUploadingAvatar) return false;
    emit(state.copyWith(isUploadingAvatar: true));
    final result = await _updateAvatar(file);
    if (isClosed) return false;
    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            isUploadingAvatar: false,
            errorMessage: failure.message,
          ),
        );
        return false;
      },
      (user) {
        emit(
          state.copyWith(
            isUploadingAvatar: false,
            user: user,
            errorMessage: null,
          ),
        );
        return true;
      },
    );
  }

  Future<void> toggleLike(PostEntity post) async {
    final result = await _likePost(post);
    if (isClosed) return;
    result.fold((_) {}, (updated) => _replacePost(post.id, (_) => updated));
  }

  /// Sets/switches/removes [post]'s reaction to [type] — the long-press
  /// reaction-picker path (see [toggleLike] for the plain single-tap path).
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
  /// reasoning (identical here, just applied to `myPosts` instead of a
  /// feed list).
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
          emit(
            state.copyWith(
              myPosts: state.myPosts.where((p) => p.id != myRepostId).toList(),
            ),
          );
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
          emit(state.copyWith(myPosts: [newPost, ...state.myPosts]));
        });
      }
    } finally {
      _pendingReposts.remove(post.id);
    }
  }

  /// Applies an update to a post wherever it appears — it may be listed
  /// under both "posted" and "saved" at once.
  void _replacePost(String id, PostEntity Function(PostEntity) update) {
    PostEntity applyTo(PostEntity p) => p.id == id ? update(p) : p;
    emit(
      state.copyWith(
        myPosts: state.myPosts.map(applyTo).toList(),
        savedPosts: state.savedPosts.map(applyTo).toList(),
      ),
    );
  }
}
