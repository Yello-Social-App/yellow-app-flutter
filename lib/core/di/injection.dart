import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/password_reset_usecases.dart';
import '../../features/auth/domain/usecases/register_usecase.dart';
import '../../features/auth/domain/usecases/verify_otp_usecase.dart';
import '../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../features/chat/data/datasources/chat_local_datasource.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/domain/usecases/chat_usecases.dart';
import '../../features/chat/presentation/bloc/chat_cubit.dart';
import '../../features/chat/presentation/bloc/messages_cubit.dart';
import '../../features/feed/data/datasources/bookmarks_local_datasource.dart';
import '../../features/feed/data/datasources/feed_remote_datasource.dart';
import '../../features/feed/data/datasources/story_local_datasource.dart';
import '../../features/feed/data/repositories/feed_repository_impl.dart';
import '../../features/feed/domain/entities/post_entity.dart';
import '../../features/feed/domain/repositories/feed_repository.dart';
import '../../features/feed/domain/usecases/add_comment_usecase.dart';
import '../../features/feed/domain/usecases/create_post_usecase.dart';
import '../../features/feed/domain/usecases/delete_comment_usecase.dart';
import '../../features/feed/domain/usecases/delete_post_usecase.dart';
import '../../features/feed/domain/usecases/get_comments_usecase.dart';
import '../../features/feed/domain/usecases/get_feed_usecase.dart';
import '../../features/feed/domain/usecases/get_post_detail_usecase.dart';
import '../../features/feed/domain/usecases/get_post_usecase.dart';
import '../../features/feed/domain/usecases/get_saved_post_ids_usecase.dart';
import '../../features/feed/domain/usecases/get_share_link_usecase.dart';
import '../../features/feed/domain/usecases/get_stories_usecase.dart';
import '../../features/feed/domain/usecases/like_post_usecase.dart';
import '../../features/feed/domain/usecases/mark_story_seen_usecase.dart';
import '../../features/feed/domain/usecases/react_usecases.dart';
import '../../features/feed/domain/usecases/update_post_usecase.dart';
import '../../features/feed/presentation/bloc/create_post_cubit.dart';
import '../../features/feed/presentation/bloc/feed_cubit.dart';
import '../../features/feed/presentation/bloc/post_detail_cubit.dart';
import '../../features/feed/presentation/bloc/reactors_cubit.dart';
import '../../features/feed/presentation/bloc/story_cubit.dart';
import '../../features/friends/data/datasources/friends_remote_datasource.dart';
import '../../features/friends/data/repositories/friends_repository_impl.dart';
import '../../features/friends/domain/repositories/friends_repository.dart';
import '../../features/friends/domain/usecases/friends_usecases.dart';
import '../../features/friends/presentation/bloc/friends_cubit.dart';
import '../../features/notification/data/datasources/notification_remote_datasource.dart';
import '../../features/notification/data/repositories/notification_repository_impl.dart';
import '../../features/notification/domain/repositories/notification_repository.dart';
import '../../features/notification/domain/usecases/notification_usecases.dart';
import '../../features/notification/presentation/bloc/notifications_cubit.dart';
import '../../features/profile/data/datasources/profile_remote_datasource.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/domain/usecases/profile_usecases.dart';
import '../../features/profile/presentation/bloc/profile_cubit.dart';
import '../../features/profile/presentation/bloc/public_profile_cubit.dart';
import '../../features/profile/presentation/bloc/shared_posts_cubit.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';
import '../network/token_refresh_service.dart';
import '../router/app_router.dart';
import '../router/route_guards.dart';
import '../security/biometric_auth_service.dart';
import '../security/jwt_manager.dart';
import '../security/root_jailbreak_detector.dart';
import '../security/secure_storage_service.dart';
import '../security/session_manager.dart';
import '../theme/theme_cubit.dart';

/// The app's single [GetIt] instance. Everything — data sources,
/// repositories, use cases, Cubits, the router — is resolved through `sl`
/// (service locator) rather than constructed ad hoc, so a widget's
/// dependencies are swappable in tests via `sl.registerSingleton(fake)`.
final GetIt sl = GetIt.instance;

/// Wires the full dependency graph. Called once from `bootstrap()` (in turn
/// called from `main.dart`), after `AppConfig.init(...)` (several
/// registrations — [ApiClient] in particular — read `AppConfig` statics at
/// construction time).
Future<void> configureDependencies() async {
  _registerCore();
  _registerAuth();
  _registerFeed();
  _registerFriends();
  _registerNotifications();
  _registerProfile();
  _registerChat();
}

void _registerCore() {
  sl.registerLazySingleton(() => Connectivity());
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  sl.registerLazySingleton<SecureStorageService>(() => SecureStorageServiceImpl());
  sl.registerLazySingleton<JwtManager>(() => JwtManagerImpl());
  sl.registerLazySingleton<TokenRefreshService>(() => TokenRefreshServiceImpl(sl()));
  sl.registerLazySingleton<SessionManager>(() => SessionManagerImpl(sl(), sl(), sl()));
  sl.registerLazySingleton<RootJailbreakDetector>(() => RootJailbreakDetectorImpl());
  sl.registerLazySingleton<BiometricAuthService>(() => BiometricAuthServiceImpl());

  sl.registerLazySingleton(
    () => ApiClient(
      secureStorage: sl(),
      jwtManager: sl(),
      sessionManager: sl(),
      networkInfo: sl(),
      tokenRefreshService: sl(),
    ),
  );

  sl.registerLazySingleton(() => RouteGuards(sl()));
  sl.registerLazySingleton(() => AppRouter(sl(), sl()));
  sl.registerLazySingleton(() => ThemeCubit());
}

void _registerAuth() {
  sl.registerLazySingleton<AuthRemoteDataSource>(() => AuthRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<AuthLocalDataSource>(() => AuthLocalDataSourceImpl());
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl(), sl(), sl(), sl()));

  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUseCase(sl()));
  sl.registerLazySingleton(() => VerifyOtpUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => ForgotPasswordUseCase(sl()));
  sl.registerLazySingleton(() => ResetPasswordUseCase(sl()));

  // Factory: each login/register screen visit gets a fresh flow state.
  sl.registerFactory(
    () => AuthCubit(
      register: sl(),
      verifyOtp: sl(),
      login: sl(),
      logout: sl(),
      forgotPassword: sl(),
      resetPassword: sl(),
    ),
  );
}

void _registerFriends() {
  sl.registerLazySingleton<FriendsRemoteDataSource>(() => FriendsRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<FriendsRepository>(() => FriendsRepositoryImpl(sl(), sl()));

  sl.registerLazySingleton(() => GetFriendsUseCase(sl()));
  sl.registerLazySingleton(() => GetFriendRequestsUseCase(sl()));
  sl.registerLazySingleton(() => SendFriendRequestUseCase(sl()));
  sl.registerLazySingleton(() => AcceptFriendRequestUseCase(sl()));
  sl.registerLazySingleton(() => DeclineFriendRequestUseCase(sl()));
  sl.registerLazySingleton(() => UnfriendUseCase(sl()));

  sl.registerFactory(
    () => FriendsCubit(getFriends: sl(), getRequests: sl(), acceptRequest: sl(), declineRequest: sl(), unfriend: sl()),
  );
}

void _registerNotifications() {
  sl.registerLazySingleton<NotificationRemoteDataSource>(() => NotificationRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<NotificationRepository>(() => NotificationRepositoryImpl(sl(), sl()));

  sl.registerLazySingleton(() => GetNotificationsUseCase(sl()));
  sl.registerLazySingleton(() => GetUnreadNotificationCountUseCase(sl()));
  sl.registerLazySingleton(() => MarkAllNotificationsReadUseCase(sl()));
  sl.registerLazySingleton(() => MarkNotificationReadUseCase(sl()));

  sl.registerFactory(
    () => NotificationsCubit(
      getNotifications: sl(),
      markAllRead: sl(),
      markRead: sl(),
      acceptFriendRequest: sl(),
      declineFriendRequest: sl(),
      getFriendRequests: sl(),
      getFriends: sl(),
    ),
  );
}

void _registerProfile() {
  sl.registerLazySingleton<ProfileRemoteDataSource>(() => ProfileRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<ProfileRepository>(() => ProfileRepositoryImpl(sl(), sl()));

  sl.registerLazySingleton(() => GetMeUseCase(sl()));
  sl.registerLazySingleton(() => UpdateProfileUseCase(sl()));
  sl.registerLazySingleton(() => GetUserUseCase(sl()));
  sl.registerLazySingleton(() => GetUserPostsUseCase(sl()));
  sl.registerLazySingleton(() => UpdateAvatarUseCase(sl()));

  sl.registerFactory(
    () => ProfileCubit(
      getMe: sl(),
      updateProfile: sl(),
      updateAvatar: sl(),
      getUserPosts: sl(),
      getSavedPostIds: sl(),
      getPost: sl(),
      getFriends: sl(),
      likePost: sl(),
      reactToPost: sl(),
      repost: sl(),
      deletePost: sl(),
      toggleSave: sl(),
    ),
  );

  // Fresh cubit per push, same reasoning as `PostDetailCubit`/
  // `PublicProfileCubit` below — see its own doc comment.
  sl.registerFactory(
    () => SharedPostsCubit(
      getMe: sl(),
      getUserPosts: sl(),
      likePost: sl(),
      reactToPost: sl(),
      toggleSave: sl(),
      repost: sl(),
      deletePost: sl(),
    ),
  );

  // `String` param is the viewed user's id — a fresh cubit per profile push,
  // same convention as `PostDetailCubit` below.
  sl.registerFactoryParam<PublicProfileCubit, String, void>(
    (userId, _) => PublicProfileCubit(
      userId: userId,
      getMe: sl(),
      getUser: sl(),
      getUserPosts: sl(),
      getFriends: sl(),
      getFriendRequests: sl(),
      sendFriendRequest: sl(),
      acceptFriendRequest: sl(),
      declineFriendRequest: sl(),
      unfriend: sl(),
      likePost: sl(),
      reactToPost: sl(),
      repost: sl(),
      deletePost: sl(),
      toggleSave: sl(),
    ),
  );
}

void _registerChat() {
  sl.registerLazySingleton(() => ChatLocalDataSource());
  sl.registerLazySingleton<ChatRepository>(() => ChatRepositoryImpl(sl()));

  sl.registerLazySingleton(() => GetConversationsUseCase(sl()));
  sl.registerLazySingleton(() => GetMessagesUseCase(sl()));
  sl.registerLazySingleton(() => SendMessageUseCase(sl()));

  // Long-lived: the Inbox list (and unread counts) survives tab switches.
  sl.registerLazySingleton(() => MessagesCubit(sl()));

  sl.registerFactoryParam<ChatCubit, String, void>(
    (conversationId, _) =>
        ChatCubit(conversationId: conversationId, getMessages: sl(), sendMessage: sl(), repository: sl()),
  );
}

void _registerFeed() {
  // Live backend (posts/comments/reactions/reposts/feed).
  sl.registerLazySingleton<FeedRemoteDataSource>(() => FeedRemoteDataSourceImpl(sl()));
  // No backend endpoint exists for either of these (see each class's doc).
  sl.registerLazySingleton<StoryLocalDataSource>(() => StoryLocalDataSourceImpl());
  sl.registerLazySingleton<BookmarksLocalDataSource>(() => BookmarksLocalDataSourceImpl());

  sl.registerLazySingleton<FeedRepository>(() => FeedRepositoryImpl(sl(), sl(), sl(), sl()));

  sl.registerLazySingleton(() => GetFeedUseCase(sl()));
  sl.registerLazySingleton(() => GetStoriesUseCase(sl()));
  sl.registerLazySingleton(() => MarkStorySeenUseCase(sl()));
  sl.registerLazySingleton(() => LikePostUseCase(sl()));
  sl.registerLazySingleton(() => ReactToPostUseCase(sl()));
  sl.registerLazySingleton(() => ReactToCommentUseCase(sl()));
  sl.registerLazySingleton(() => GetReactionSummaryUseCase(sl()));
  sl.registerLazySingleton(() => GetReactorsUseCase(sl()));
  sl.registerLazySingleton(() => RepostUseCase(sl()));
  sl.registerLazySingleton(() => ToggleSaveUseCase(sl()));
  sl.registerLazySingleton(() => GetPostDetailUseCase(sl()));
  sl.registerLazySingleton(() => GetCommentsUseCase(sl()));
  sl.registerLazySingleton(() => GetPostUseCase(sl()));
  sl.registerLazySingleton(() => GetSavedPostIdsUseCase(sl()));
  sl.registerLazySingleton(() => AddCommentUseCase(sl()));
  sl.registerLazySingleton(() => CreatePostUseCase(sl()));
  sl.registerLazySingleton(() => UpdatePostUseCase(sl()));
  sl.registerLazySingleton(() => DeletePostUseCase(sl()));
  sl.registerLazySingleton(() => DeleteCommentUseCase(sl()));
  sl.registerLazySingleton(() => GetShareLinkUseCase(sl()));

  // Long-lived: the whole Home tab's state (posts, stories, like/save
  // toggles) survives tab switches — see `FeedPage`'s `BlocProvider.value`.
  sl.registerLazySingleton(
    () => FeedCubit(
      getFeed: sl(),
      getStories: sl(),
      likePost: sl(),
      reactToPost: sl(),
      repost: sl(),
      toggleSave: sl(),
      getMe: sl(),
      getUserPosts: sl(),
      getReactionSummary: sl(),
      updatePost: sl(),
      deletePost: sl(),
      getShareLink: sl(),
    ),
  );

  sl.registerFactoryParam<PostDetailCubit, String, void>(
    (postId, _) => PostDetailCubit(
      postId: postId,
      getPostDetail: sl(),
      getComments: sl(),
      addComment: sl(),
      likePost: sl(),
      reactToPost: sl(),
      reactToComment: sl(),
      getReactionSummary: sl(),
      updatePost: sl(),
      deletePost: sl(),
      deleteComment: sl(),
      getShareLink: sl(),
      getMe: sl(),
    ),
  );

  // Fresh per open — this list's state has no reason to survive past the
  // sheet that opened it (see the cubit's own doc).
  sl.registerFactoryParam<ReactorsCubit, ({String targetType, String targetId}), ReactionType?>(
    (ids, type) => ReactorsCubit(targetType: ids.targetType, targetId: ids.targetId, type: type, getReactors: sl()),
  );
  sl.registerFactory(() => StoryCubit(sl(), sl()));
  sl.registerFactory(() => CreatePostCubit(sl()));
}
