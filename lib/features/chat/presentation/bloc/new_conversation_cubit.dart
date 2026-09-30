import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../friends/domain/entities/friendship_entity.dart';
import '../../../friends/domain/repositories/friends_repository.dart';
import '../../../friends/domain/usecases/friends_usecases.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/usecases/chat_usecases.dart';
import 'messages_cubit.dart';

enum NewConversationStatus { loading, loaded, error }

class NewConversationState extends Equatable {
  const NewConversationState({
    this.status = NewConversationStatus.loading,
    this.friends = const [],
    this.isCreating = false,
    this.errorMessage,
  });

  final NewConversationStatus status;

  /// Every friend, all pages at once — the same call `GroupInfoCubit` makes
  /// for its pickers. Only friends can be picked; the backend has no "any
  /// user" directory to pick from.
  final List<FriendshipEntity> friends;

  /// A create request is in flight. Doubles as the double-tap guard.
  final bool isCreating;

  /// The last failure, for the dialog to show inline. Cleared on retry.
  final String? errorMessage;

  NewConversationState copyWith({
    NewConversationStatus? status,
    List<FriendshipEntity>? friends,
    bool? isCreating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NewConversationState(
      status: status ?? this.status,
      friends: friends ?? this.friends,
      isCreating: isCreating ?? this.isCreating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, friends, isCreating, errorMessage];
}

/// Backs the Inbox's "New message" dialog: one friend opens (or reuses) a
/// DM, two or more create a named group. The result is folded into
/// `MessagesCubit` so the Inbox has the row before the chat is even open.
class NewConversationCubit extends Cubit<NewConversationState> {
  NewConversationCubit({
    required GetFriendsUseCase getFriends,
    required StartDirectConversationUseCase startDirect,
    required StartGroupConversationUseCase startGroup,
    required MessagesCubit inbox,
  })  : _getFriends = getFriends,
        _startDirect = startDirect,
        _startGroup = startGroup,
        _inbox = inbox,
        super(const NewConversationState());

  final GetFriendsUseCase _getFriends;
  final StartDirectConversationUseCase _startDirect;
  final StartGroupConversationUseCase _startGroup;
  final MessagesCubit _inbox;

  Future<void> loadFriends() async {
    emit(state.copyWith(status: NewConversationStatus.loading, clearError: true));
    final all = <FriendshipEntity>[];
    for (var page = 0; page < 25; page++) {
      final result = await _getFriends(PageParams(page: page));
      if (isClosed) return;
      final (friendsPage, failure) = result.fold<(FriendsPage?, Failure?)>((f) => (null, f), (p) => (p, null));
      if (friendsPage == null) {
        appLogger.w('NewConversationCubit.loadFriends: page $page failed — ${failure?.message}');
        // A later page failing still leaves a usable list; only a failed
        // first page is an error worth a retry button.
        if (all.isEmpty) {
          emit(state.copyWith(status: NewConversationStatus.error, errorMessage: failure?.message));
          return;
        }
        break;
      }
      all.addAll(friendsPage.friendships);
      if (!friendsPage.hasMore) break;
    }
    emit(state.copyWith(status: NewConversationStatus.loaded, friends: all));
  }

  /// One member opens the DM; two or more create a group named [title].
  /// Returns the conversation to open, or null when it failed (the reason
  /// is on `errorMessage`) or a create was already in flight.
  Future<ConversationEntity?> start({required List<String> memberIds, String title = ''}) async {
    if (state.isCreating || memberIds.isEmpty) return null;
    emit(state.copyWith(isCreating: true, clearError: true));

    final Either<Failure, ConversationEntity> result = memberIds.length == 1
        ? await _startDirect(memberIds.single)
        : await _startGroup(StartGroupParams(title: title, memberIds: memberIds));
    if (isClosed) return null;

    return result.fold(
      (failure) {
        emit(state.copyWith(isCreating: false, errorMessage: failure.message));
        return null;
      },
      (conversation) {
        _inbox.applyConversation(conversation);
        emit(state.copyWith(isCreating: false));
        return conversation;
      },
    );
  }
}
