import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:yello_social_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:yello_social_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:yello_social_app/features/chat/presentation/bloc/messages_cubit.dart';
import 'package:yello_social_app/features/chat/presentation/bloc/new_conversation_cubit.dart';
import 'package:yello_social_app/features/friends/domain/entities/friendship_entity.dart';
import 'package:yello_social_app/features/friends/domain/repositories/friends_repository.dart';
import 'package:yello_social_app/features/friends/domain/usecases/friends_usecases.dart';

class _ChatRepository extends Mock implements ChatRepository {}

class _FriendsRepository extends Mock implements FriendsRepository {}

FriendshipEntity _friend(String id) =>
    FriendshipEntity(userId: id, username: id, status: FriendshipStatus.friends);

ConversationEntity _conversation(String id, ConversationType type) =>
    ConversationEntity(id: id, type: type, createdBy: 'me', createdAt: DateTime(2026, 9, 30));

void main() {
  late _ChatRepository chat;
  late _FriendsRepository friends;
  late MessagesCubit inbox;
  late NewConversationCubit cubit;

  setUp(() {
    chat = _ChatRepository();
    friends = _FriendsRepository();
    inbox = MessagesCubit(GetConversationsUseCase(chat), chat);
    cubit = NewConversationCubit(
      getFriends: GetFriendsUseCase(friends),
      startDirect: StartDirectConversationUseCase(chat),
      startGroup: StartGroupConversationUseCase(chat),
      inbox: inbox,
    );
  });

  tearDown(() async {
    await cubit.close();
    await inbox.close();
  });

  test('loadFriends collects every page', () async {
    when(() => friends.getFriends(page: 0))
        .thenAnswer((_) async => Right(FriendsPage(friendships: [_friend('a')], hasMore: true)));
    when(() => friends.getFriends(page: 1))
        .thenAnswer((_) async => Right(FriendsPage(friendships: [_friend('b')], hasMore: false)));

    await cubit.loadFriends();

    expect(cubit.state.status, NewConversationStatus.loaded);
    expect(cubit.state.friends.map((f) => f.userId), ['a', 'b']);
  });

  test('a failed first page is an error the dialog can retry', () async {
    when(() => friends.getFriends(page: 0)).thenAnswer((_) async => const Left(NetworkFailure()));

    await cubit.loadFriends();

    expect(cubit.state.status, NewConversationStatus.error);
    expect(cubit.state.errorMessage, isNotNull);
  });

  test('one friend opens the DM and adds it to the inbox', () async {
    final dm = _conversation('dm', ConversationType.direct);
    when(() => chat.startDirect('a')).thenAnswer((_) async => Right(dm));

    final result = await cubit.start(memberIds: ['a'], title: 'ignored');

    expect(result, dm);
    expect(inbox.state.conversations.map((c) => c.id), ['dm']);
    verifyNever(() => chat.startGroup(title: any(named: 'title'), memberIds: any(named: 'memberIds')));
  });

  test('two or more friends create a named group', () async {
    final group = _conversation('g', ConversationType.group);
    when(() => chat.startGroup(title: 'Crew', memberIds: ['a', 'b'])).thenAnswer((_) async => Right(group));

    final result = await cubit.start(memberIds: ['a', 'b'], title: 'Crew');

    expect(result, group);
    expect(cubit.state.isCreating, isFalse);
  });

  test('a second tap while creating is ignored', () async {
    final pending = Completer<Either<Failure, ConversationEntity>>();
    when(() => chat.startDirect('a')).thenAnswer((_) => pending.future);

    final first = cubit.start(memberIds: ['a']);
    final second = await cubit.start(memberIds: ['a']);
    pending.complete(Right(_conversation('dm', ConversationType.direct)));

    expect(second, isNull);
    expect(await first, isNotNull);
    verify(() => chat.startDirect('a')).called(1);
  });

  test('a failed create keeps the dialog open with the reason', () async {
    when(() => chat.startGroup(title: 'Crew', memberIds: ['a', 'b']))
        .thenAnswer((_) async => const Left(ServerFailure('Nope')));

    final result = await cubit.start(memberIds: ['a', 'b'], title: 'Crew');

    expect(result, isNull);
    expect(cubit.state.errorMessage, 'Nope');
    expect(cubit.state.isCreating, isFalse);
    expect(inbox.state.conversations, isEmpty);
  });
}
