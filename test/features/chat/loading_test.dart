import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/features/chat/data/datasources/user_directory.dart';
import 'package:yello_social_app/features/chat/domain/entities/participant_entity.dart';
import 'package:yello_social_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:yello_social_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:yello_social_app/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:yello_social_app/features/chat/presentation/bloc/messages_cubit.dart';
import 'package:yello_social_app/features/profile/domain/entities/public_user_entity.dart';
import 'package:yello_social_app/features/profile/domain/usecases/profile_usecases.dart';

class _GetUser extends Mock implements GetUserUseCase {}

class _ChatRepository extends Mock implements ChatRepository {}

void main() {
  final user = PublicUserEntity(
    id: 'peer',
    username: 'peer',
    createdAt: DateTime(2026),
  );
  // Bound the wait so the original self-dependent future fails promptly.
  const deadline = Duration(seconds: 1);

  test(
    'participant hydration completes after successful profile response',
    () async {
      final getUser = _GetUser();
      when(() => getUser('peer')).thenAnswer((_) async => Right(user));
      final directory = UserDirectory(getUser);
      final participants = await directory
          .hydrate([
            ParticipantEntity(
              userId: 'peer',
              role: ParticipantRole.member,
              joinedAt: DateTime(2026),
            ),
          ])
          .timeout(deadline);
      expect(participants.single.username, 'peer');
      expect(await directory.lookup('peer').timeout(deadline), user);
      verify(() => getUser('peer')).called(1);
    },
  );

  test('concurrent profile lookups share a request and both finish', () async {
    final getUser = _GetUser();
    final response = Completer<Either<Failure, PublicUserEntity>>();
    when(() => getUser('peer')).thenAnswer((_) => response.future);
    final directory = UserDirectory(getUser);
    final first = directory.lookup('peer');
    final second = directory.lookup('peer');
    response.complete(Right(user));
    expect(await Future.wait([first, second]).timeout(deadline), [user, user]);
    verify(() => getUser('peer')).called(1);
  });

  test('failed profile lookup finishes and allows a later retry', () async {
    final getUser = _GetUser();
    when(
      () => getUser('peer'),
    ).thenAnswer((_) async => const Left(NetworkFailure()));
    final directory = UserDirectory(getUser);
    expect(await directory.lookup('peer').timeout(deadline), isNull);
    when(() => getUser('peer')).thenAnswer((_) async => Right(user));
    expect(await directory.lookup('peer').timeout(deadline), user);
    verify(() => getUser('peer')).called(2);
  });

  test('repeated inbox loads do not duplicate a pending request', () async {
    final repository = _ChatRepository();
    final response = Completer<Either<Failure, ConversationsPage>>();
    when(
      () => repository.getConversations(),
    ).thenAnswer((_) => response.future);
    final cubit = MessagesCubit(GetConversationsUseCase(repository));
    addTearDown(cubit.close);
    final pending = cubit.load();
    await cubit.load();
    await cubit.refresh();
    response.complete(const Right(ConversationsPage(conversations: [])));
    await pending.timeout(deadline);
    expect(cubit.state.status, MessagesStatus.loaded);
    verify(() => repository.getConversations()).called(1);
  });

  test('inbox errors remain visible until explicit retry', () async {
    final repository = _ChatRepository();
    when(
      () => repository.getConversations(),
    ).thenAnswer((_) async => const Left(NetworkFailure()));
    final cubit = MessagesCubit(GetConversationsUseCase(repository));
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.load();
    expect(cubit.state.status, MessagesStatus.error);
    verify(() => repository.getConversations()).called(1);
    when(() => repository.getConversations()).thenAnswer(
      (_) async => const Right(ConversationsPage(conversations: [])),
    );
    await cubit.refresh();
    expect(cubit.state.status, MessagesStatus.loaded);
  });

  test(
    'chat can retry a failed load without duplicating requests or subscriptions',
    () async {
      final repository = _ChatRepository();
      when(
        () => repository.getMessages('chat'),
      ).thenAnswer((_) async => const Left(NetworkFailure()));
      when(
        () => repository.watchEvents('chat'),
      ).thenAnswer((_) => const Stream.empty());
      final inbox = MessagesCubit(GetConversationsUseCase(repository));
      final cubit = ChatCubit(
        conversationId: 'chat',
        getMessages: GetMessagesUseCase(repository),
        sendMessage: SendMessageUseCase(repository),
        markRead: MarkReadUseCase(repository),
        repository: repository,
        inbox: inbox,
      );
      addTearDown(cubit.close);
      addTearDown(inbox.close);
      await cubit.load();
      expect(cubit.state.status, ChatStatus.error);
      final response = Completer<Either<Failure, MessagesPage>>();
      when(
        () => repository.getMessages('chat'),
      ).thenAnswer((_) => response.future);
      final pending = cubit.load();
      expect(cubit.state.status, ChatStatus.loading);
      await cubit.load();
      response.complete(const Right(MessagesPage(messages: [])));
      await pending.timeout(deadline);
      expect(cubit.state.status, ChatStatus.loaded);
      verify(() => repository.getMessages('chat')).called(2);
      verify(() => repository.watchEvents('chat')).called(1);
    },
  );
}
