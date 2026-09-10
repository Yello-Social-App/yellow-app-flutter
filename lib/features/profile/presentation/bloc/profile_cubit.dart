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
import '../../../friends/domain/usecases/friends_usecases.dart';
import '../../domain/usecases/profile_usecases.dart';

enum ProfileTab { posts, reposts, saved }

enum ProfileStatus { initial, loading, loaded, error }

class ProfileState extends Equatable {
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.user,
    this.connectionsCount = 0,
    this.myPosts = const [],
    this.savedPosts = const [],
    this.tab = ProfileTab.posts,
    this.errorMessage,
    this.isUploadingAvatar = false,
  });

  final ProfileStatus status;
  final UserEntity? user;
  final int connectionsCount;
  final List<PostEntity> myPosts;
  final List<PostEntity> savedPosts;
  final ProfileTab tab;
  final String? errorMessage;
  final bool isUploadingAvatar;

  List<PostEntity> get originalPosts => myPosts.where((p) => !p.isRepost).toList();
  List<PostEntity> get repostedPosts => myPosts.where((p) => p.isRepost).toList();

  List<PostEntity> get activeTabPosts => switch (tab) {
    ProfileTab.posts => originalPosts,
    ProfileTab.reposts => repostedPosts,
    ProfileTab.saved => savedPosts,
  };

  ProfileState copyWith({
    ProfileStatus? status,
    UserEntity? user,
    int? connectionsCount,
    List<PostEntity>? myPosts,
    List<PostEntity>? savedPosts,
    ProfileTab? tab,
    String? errorMessage,
    bool? isUploadingAvatar,
  }) {
    return ProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      connectionsCount: connectionsCount ?? this.connectionsCount,
      myPosts: myPosts ?? this.myPosts,
      savedPosts: savedPosts ?? this.savedPosts,
      tab: tab ?? this.tab,
      errorMessage: errorMessage,
      isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
    );
  }

  @override
  List<Object?> get props => [
    status,
    user,
    connectionsCount,
    myPosts,
    savedPosts,
    tab,
    errorMessage,
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

  Future<void> load() async {
    if (state.status == ProfileStatus.loaded) return;
    await refresh();
  }

  Future<void> refresh() async {
    emit(state.copyWith(status: ProfileStatus.loading));

    final meResult = await _getMe(const NoParams());
    if (meResult.isLeft()) {
      emit(state.copyWith(status: ProfileStatus.error, errorMessage: meResult.fold((l) => l.message, (_) => null)));
      return;
    }
    final user = meResult.fold((_) => null, (r) => r)!;

    final postsResult = await _getUserPosts(GetUserPostsParams(userId: user.id));
    final myPosts = postsResult.fold((_) => <PostEntity>[], (page) => page.posts);

    final friendsResult = await _getFriends(const PageParams());
    final connections = friendsResult.fold((_) => 0, (page) => page.friendships.length);

    final savedPosts = await _loadSavedPosts();

    await _seedMyRepostIds(user.id);

    emit(
      state.copyWith(
        status: ProfileStatus.loaded,
        user: user,
        myPosts: _withMyReposts(myPosts),
        connectionsCount: connections,
        savedPosts: _withMyReposts(savedPosts),
      ),
    );
  }

  /// Re-applies [_myRepostIds] onto freshly-fetched posts — see
  /// `FeedCubit._withMyReposts`'s identical doc for why this is needed.
  List<PostEntity> _withMyReposts(List<PostEntity> posts) =>
      posts.map((p) => _myRepostIds.containsKey(p.id) ? p.copyWith(repostedByMe: true) : p).toList();

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
  Future<bool> updateProfile({String? username, String? fullName, String? bio}) async {
    final result = await _updateProfile(UpdateProfileParams(username: username, fullName: fullName, bio: bio));
    return result.fold(
      (failure) {
        emit(state.copyWith(errorMessage: failure.message));
        return false;
      },
      (user) {
        emit(state.copyWith(user: user, errorMessage: null));
        return true;
      },
    );
  }

  /// Uploads a new avatar (`PUT /users/me/avatar`, multipart) and swaps it
  /// into `state.user` on success. [isUploadingAvatar] just gates the UI's
  /// own busy affordance. Returns success so the page can show a snackbar on
  /// failure, same convention as `PostDetailCubit.updatePost`/`deletePost`.
  Future<bool> uploadAvatar(File file) async {
    emit(state.copyWith(isUploadingAvatar: true));
    final result = await _updateAvatar(file);
    return result.fold(
      (failure) {
        emit(state.copyWith(isUploadingAvatar: false, errorMessage: failure.message));
        return false;
      },
      (user) {
        emit(state.copyWith(isUploadingAvatar: false, user: user, errorMessage: null));
        return true;
      },
    );
  }

  Future<void> toggleLike(PostEntity post) async {
    final result = await _likePost(post);
    result.fold((_) {}, (updated) => _replacePost(post.id, (_) => updated));
  }

  /// Sets/switches/removes [post]'s reaction to [type] — the long-press
  /// reaction-picker path (see [toggleLike] for the plain single-tap path).
  Future<void> react(PostEntity post, ReactionType type) async {
    final result = await _reactToPost(ReactToPostParams(post: post, type: type));
    result.fold((_) {}, (updated) => _replacePost(post.id, (_) => updated));
  }

  Future<void> toggleSave(String postId) async {
    final result = await _toggleSave(PostIdParams(postId));
    result.fold((_) {}, (saved) => _replacePost(postId, (p) => p.copyWith(savedByMe: saved)));
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
  /// reasoning (identical here, just applied to `myPosts` instead of a
  /// feed list).
  Future<void> toggleRepost(PostEntity post) async {
    if (!_pendingReposts.add(post.id)) return;
    try {
      if (post.repostedByMe) {
        final myRepostId = _myRepostIds[post.id];
        if (myRepostId == null) return;
        final result = await _deletePost(myRepostId);
        result.fold((_) {}, (_) {
          _myRepostIds.remove(post.id);
          emit(state.copyWith(myPosts: state.myPosts.where((p) => p.id != myRepostId).toList()));
          _replacePost(post.id, (p) => p.copyWith(repostCount: p.repostCount - 1, repostedByMe: false));
        });
      } else {
        final result = await _repost(RepostParams(postId: post.id));
        result.fold((_) {}, (newPost) {
          _myRepostIds[post.id] = newPost.id;
          _replacePost(post.id, (p) => p.copyWith(repostCount: p.repostCount + 1, repostedByMe: true));
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
      state.copyWith(myPosts: state.myPosts.map(applyTo).toList(), savedPosts: state.savedPosts.map(applyTo).toList()),
    );
  }
}
