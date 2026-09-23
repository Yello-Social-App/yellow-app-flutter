import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../friends/domain/entities/friendship_entity.dart';
import '../../../friends/domain/usecases/friends_usecases.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/participant_entity.dart';
import '../../domain/usecases/chat_usecases.dart';
import 'messages_cubit.dart';

enum GroupInfoStatus { loading, loaded, error }

class GroupInfoState extends Equatable {
  const GroupInfoState({
    this.status = GroupInfoStatus.loading,
    this.conversation,
    this.errorMessage,
    this.isSaving = false,
    this.busyUserIds = const {},
    this.friends = const [],
    this.isLoadingFriends = false,
    this.actionError,
    this.notice,
    this.hasLeft = false,
  });

  final GroupInfoStatus status;
  final ConversationEntity? conversation;
  final String? errorMessage;

  /// A rename, photo change or leave in flight — the whole screen's actions
  /// are disabled, since each of those replaces the conversation.
  final bool isSaving;

  /// Members with a remove / role change in flight; their row alone is
  /// disabled.
  final Set<String> busyUserIds;

  /// The viewer's friends, for the add-member and invite pickers. Loaded on
  /// demand, all pages at once — a friends list is short in practice.
  final List<FriendshipEntity> friends;
  final bool isLoadingFriends;

  /// One-shot messages for a snackbar; both drop on the next emit.
  final String? actionError;
  final String? notice;

  /// The viewer left: the screen pops back past the conversation.
  final bool hasLeft;

  ParticipantRole get myRole => conversation?.myRole ?? ParticipantRole.member;
  bool get canManage => myRole.canManage;
  bool get isOwner => myRole == ParticipantRole.owner;

  /// Who is not yet in the group — what the add / invite pickers list.
  List<FriendshipEntity> get friendsNotInGroup {
    final members = {for (final p in conversation?.participants ?? const <ParticipantEntity>[]) p.userId};
    return friends.where((f) => !members.contains(f.userId)).toList(growable: false);
  }

  GroupInfoState copyWith({
    GroupInfoStatus? status,
    ConversationEntity? conversation,
    String? errorMessage,
    bool? isSaving,
    Set<String>? busyUserIds,
    List<FriendshipEntity>? friends,
    bool? isLoadingFriends,
    String? actionError,
    String? notice,
    bool? hasLeft,
  }) {
    return GroupInfoState(
      status: status ?? this.status,
      conversation: conversation ?? this.conversation,
      errorMessage: errorMessage,
      isSaving: isSaving ?? this.isSaving,
      busyUserIds: busyUserIds ?? this.busyUserIds,
      friends: friends ?? this.friends,
      isLoadingFriends: isLoadingFriends ?? this.isLoadingFriends,
      actionError: actionError,
      notice: notice,
      hasLeft: hasLeft ?? this.hasLeft,
    );
  }

  @override
  List<Object?> get props => [
        status,
        conversation,
        errorMessage,
        isSaving,
        busyUserIds,
        friends,
        isLoadingFriends,
        actionError,
        notice,
        hasLeft,
      ];
}

/// Backs the group screen: rename, photo, members, roles, invites, leave.
/// A fresh cubit per push; every successful change is pushed into the
/// long-lived [MessagesCubit] so the inbox row and the chat header (which
/// reads that row first) catch up without a refetch.
///
/// Permission checks here only decide what to *show* — the server enforces
/// the real rule and answers 403, which surfaces as [GroupInfoState.actionError].
class GroupInfoCubit extends Cubit<GroupInfoState> {
  GroupInfoCubit({
    required this.conversationId,
    required GetConversationUseCase getConversation,
    required RenameGroupUseCase rename,
    required SetGroupPhotoUseCase setPhoto,
    required RemoveGroupPhotoUseCase removePhoto,
    required AddGroupMembersUseCase addMembers,
    required RemoveGroupMemberUseCase removeMember,
    required ChangeMemberRoleUseCase changeRole,
    required LeaveGroupUseCase leave,
    required InviteToGroupUseCase invite,
    required GetFriendsUseCase getFriends,
    required MessagesCubit inbox,
  })  : _getConversation = getConversation,
        _rename = rename,
        _setPhoto = setPhoto,
        _removePhoto = removePhoto,
        _addMembers = addMembers,
        _removeMember = removeMember,
        _changeRole = changeRole,
        _leave = leave,
        _invite = invite,
        _getFriends = getFriends,
        _inbox = inbox,
        super(const GroupInfoState());

  final String conversationId;
  final GetConversationUseCase _getConversation;
  final RenameGroupUseCase _rename;
  final SetGroupPhotoUseCase _setPhoto;
  final RemoveGroupPhotoUseCase _removePhoto;
  final AddGroupMembersUseCase _addMembers;
  final RemoveGroupMemberUseCase _removeMember;
  final ChangeMemberRoleUseCase _changeRole;
  final LeaveGroupUseCase _leave;
  final InviteToGroupUseCase _invite;
  final GetFriendsUseCase _getFriends;
  final MessagesCubit _inbox;

  /// In-flight guards (`FeedCubit._pendingReactions` shape): one for the
  /// whole-conversation actions, one keyed by member.
  bool _saving = false;
  final Set<String> _pendingUserIds = {};

  Future<void> load() async {
    emit(state.copyWith(status: GroupInfoStatus.loading));
    final result = await _getConversation(conversationId);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(status: GroupInfoStatus.error, errorMessage: failure.message)),
      (conversation) => emit(state.copyWith(status: GroupInfoStatus.loaded, conversation: conversation)),
    );
  }

  /// Friends are only needed once a picker opens; fetched lazily and kept.
  Future<void> loadFriends() async {
    if (state.isLoadingFriends || state.friends.isNotEmpty) return;
    emit(state.copyWith(isLoadingFriends: true));
    final all = <FriendshipEntity>[];
    for (var page = 0; page < 25; page++) {
      final result = await _getFriends(PageParams(page: page));
      if (isClosed) return;
      final more = result.fold((failure) {
        appLogger.w('GroupInfoCubit.loadFriends: page $page failed — ${failure.message}');
        return false;
      }, (p) {
        all.addAll(p.friendships);
        return p.hasMore;
      });
      if (!more) break;
    }
    emit(state.copyWith(isLoadingFriends: false, friends: all));
  }

  Future<void> rename(String title) => _replaceConversation(
        () => _rename(RenameGroupParams(conversationId: conversationId, title: title)),
        notice: 'Group renamed.',
      );

  Future<void> setPhoto(File file) => _replaceConversation(
        () => _setPhoto(SetGroupPhotoParams(conversationId: conversationId, file: file)),
        notice: 'Photo updated.',
      );

  Future<void> removePhoto() => _replaceConversation(() => _removePhoto(conversationId), notice: 'Photo removed.');

  /// Rename, photo and remove-photo all answer with the whole conversation
  /// (participants included, hydrated by the repository).
  Future<void> _replaceConversation(
    Future<Either<Failure, ConversationEntity>> Function() action, {
    required String notice,
  }) async {
    if (_saving) return;
    _saving = true;
    emit(state.copyWith(isSaving: true));
    try {
      final result = await action();
      if (isClosed) return;
      result.fold(
        (failure) => emit(state.copyWith(isSaving: false, actionError: failure.message)),
        (conversation) {
          _inbox.applyConversation(conversation);
          emit(state.copyWith(isSaving: false, conversation: conversation, notice: notice));
        },
      );
    } finally {
      _saving = false;
    }
  }

  /// Answers with the new member list only; the rest of the conversation
  /// is kept as loaded.
  Future<void> addMembers(List<String> userIds) async {
    if (userIds.isEmpty || _saving) return;
    final current = state.conversation;
    if (current != null && current.participants.length + userIds.length > groupMaxMembers) {
      emit(state.copyWith(actionError: 'A group can hold up to $groupMaxMembers people.'));
      return;
    }
    _saving = true;
    emit(state.copyWith(isSaving: true));
    try {
      final result = await _addMembers(GroupMembersParams(conversationId: conversationId, userIds: userIds));
      if (isClosed) return;
      result.fold(
        (failure) => emit(state.copyWith(isSaving: false, actionError: failure.message)),
        (participants) => _applyParticipants(
          participants,
          notice: userIds.length == 1 ? 'Added to the group.' : 'Added ${userIds.length} people.',
        ),
      );
    } finally {
      _saving = false;
    }
  }

  /// Not for the viewer — that is [leave]; the server answers 400 and the
  /// screen never offers it (`_MemberRow` hides the menu on your own row).
  Future<void> removeMember(String userId) async {
    if (!_pendingUserIds.add(userId)) return;
    emit(state.copyWith(busyUserIds: {...state.busyUserIds, userId}));
    try {
      final result = await _removeMember(GroupMemberParams(conversationId: conversationId, userId: userId));
      if (isClosed) return;
      result.fold(
        (failure) => emit(state.copyWith(actionError: failure.message)),
        (_) {
          final current = state.conversation;
          if (current == null) return;
          _applyParticipants(
            current.participants.where((p) => p.userId != userId).toList(growable: false),
            notice: 'Removed from the group.',
          );
        },
      );
    } finally {
      _pendingUserIds.remove(userId);
      if (!isClosed) emit(state.copyWith(busyUserIds: {...state.busyUserIds}..remove(userId)));
    }
  }

  Future<void> setRole(String userId, ParticipantRole role) async {
    if (!_pendingUserIds.add(userId)) return;
    emit(state.copyWith(busyUserIds: {...state.busyUserIds, userId}));
    try {
      final result = await _changeRole(
        ChangeMemberRoleParams(conversationId: conversationId, userId: userId, role: role),
      );
      if (isClosed) return;
      result.fold(
        (failure) => emit(state.copyWith(actionError: failure.message)),
        (participants) => _applyParticipants(
          participants,
          notice: role == ParticipantRole.admin ? 'Made an admin.' : 'Admin removed.',
        ),
      );
    } finally {
      _pendingUserIds.remove(userId);
      if (!isClosed) emit(state.copyWith(busyUserIds: {...state.busyUserIds}..remove(userId)));
    }
  }

  /// Drops an invite card into the viewer's DM with [userId]. Re-inviting
  /// the same person is safe — the server returns the same pending invite.
  Future<void> invite(String userId) async {
    if (!_pendingUserIds.add(userId)) return;
    emit(state.copyWith(busyUserIds: {...state.busyUserIds, userId}));
    try {
      final result = await _invite(GroupMemberParams(conversationId: conversationId, userId: userId));
      if (isClosed) return;
      result.fold(
        (failure) => emit(state.copyWith(actionError: failure.message)),
        (sent) {
          // The card is a real message in that DM — bump its inbox row.
          _inbox.applyIncomingMessage(sent.message);
          emit(state.copyWith(notice: 'Invite sent.'));
        },
      );
    } finally {
      _pendingUserIds.remove(userId);
      if (!isClosed) emit(state.copyWith(busyUserIds: {...state.busyUserIds}..remove(userId)));
    }
  }

  /// The viewer's access ends immediately on success — the conversation is
  /// dropped from the inbox and the screen pops.
  Future<void> leave() async {
    if (_saving) return;
    _saving = true;
    emit(state.copyWith(isSaving: true));
    try {
      final result = await _leave(conversationId);
      if (isClosed) return;
      result.fold(
        (failure) => emit(state.copyWith(isSaving: false, actionError: failure.message)),
        (_) {
          _inbox.removeConversation(conversationId);
          emit(state.copyWith(isSaving: false, hasLeft: true));
        },
      );
    } finally {
      _saving = false;
    }
  }

  void _applyParticipants(List<ParticipantEntity> participants, {required String notice}) {
    final current = state.conversation;
    if (current == null) return;
    final next = current.copyWith(participants: participants);
    _inbox.applyConversation(next);
    emit(state.copyWith(isSaving: false, conversation: next, notice: notice));
  }
}
