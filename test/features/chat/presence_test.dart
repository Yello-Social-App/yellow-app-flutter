import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/features/chat/data/datasources/chat_socket.dart';
import 'package:yello_social_app/features/chat/data/datasources/presence_tracker.dart';
import 'package:yello_social_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:yello_social_app/features/chat/domain/entities/participant_entity.dart';
import 'package:yello_social_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:yello_social_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:yello_social_app/features/chat/presentation/bloc/messages_cubit.dart';

class _ChatRepository extends Mock implements ChatRepository {}

class _ChatSocket extends Mock implements ChatSocket {}

ParticipantEntity _participant(String userId) =>
    ParticipantEntity(userId: userId, role: ParticipantRole.member, joinedAt: DateTime(2026));

ConversationEntity _direct(String id, String peerId) => ConversationEntity(
      id: id,
      type: ConversationType.direct,
      createdBy: peerId,
      createdAt: DateTime(2026),
      viewerId: 'me',
      participants: [_participant('me'), _participant(peerId)],
    );

ConversationEntity _group(String id, List<String> memberIds) => ConversationEntity(
      id: id,
      type: ConversationType.group,
      title: 'Crew',
      createdBy: 'me',
      createdAt: DateTime(2026),
      viewerId: 'me',
      participants: [for (final member in memberIds) _participant(member)],
    );

void main() {
  group('PresenceTracker', () {
    late _ChatSocket socket;
    late StreamController<Map<String, dynamic>> frames;
    late StreamController<bool> connection;
    late PresenceTracker tracker;

    setUp(() {
      socket = _ChatSocket();
      frames = StreamController<Map<String, dynamic>>.broadcast();
      connection = StreamController<bool>.broadcast();
      when(() => socket.frames).thenAnswer((_) => frames.stream);
      when(() => socket.connectionChanges).thenAnswer((_) => connection.stream);
      tracker = PresenceTracker(socket);
    });

    tearDown(() async {
      await frames.close();
      await connection.close();
    });

    test('folds presence frames into one set and drops it when the socket goes', () async {
      final seen = <Set<String>>[];
      final sub = tracker.watch().listen(seen.add);
      // The stream's first value is the current set; the generator subscribes
      // to changes only once that has been delivered.
      await Future<void>.delayed(Duration.zero);

      frames.add({
        'event': 'presence',
        'data': {
          'online': ['u2', 'u3'],
        },
      });
      await Future<void>.delayed(Duration.zero);
      expect(tracker.onlineUserIds, {'u2', 'u3'});
      expect(tracker.isOnline('u2'), isTrue);

      frames.add({
        'event': 'presence',
        'data': {'userId': 'u2', 'isOnline': false},
      });
      await Future<void>.delayed(Duration.zero);
      expect(tracker.onlineUserIds, {'u3'});

      // A frame that says nothing new must not emit — the inbox would rebuild
      // every row for it.
      frames.add({
        'event': 'presence',
        'data': {'userId': 'u2', 'isOnline': false},
      });
      frames.add({
        'event': 'typing',
        'data': {'userId': 'u3'},
      });
      await Future<void>.delayed(Duration.zero);

      // A dropped connection is not "everybody left", but it is the end of
      // what this client can claim.
      connection.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(tracker.onlineUserIds, isEmpty);

      expect(seen, [
        <String>{},
        {'u2', 'u3'},
        {'u3'},
        <String>{},
      ]);
      await sub.cancel();
    });

    test('the last listener leaving releases the socket and forgets the set', () async {
      final sub = tracker.watch().listen((_) {});
      await Future<void>.delayed(Duration.zero);
      frames.add({
        'event': 'presence',
        'data': {'userId': 'u2', 'isOnline': true},
      });
      await Future<void>.delayed(Duration.zero);
      expect(tracker.onlineUserIds, {'u2'});

      await sub.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(tracker.onlineUserIds, isEmpty, reason: 'nothing is listening, so nothing is known');

      // And it comes back: a second watcher re-opens the frame subscription.
      final again = tracker.watch().listen((_) {});
      await Future<void>.delayed(Duration.zero);
      frames.add({
        'event': 'presence',
        'data': {'userId': 'u3', 'isOnline': true},
      });
      await Future<void>.delayed(Duration.zero);
      expect(tracker.onlineUserIds, {'u3'});
      await again.cancel();
    });
  });

  group('MessagesCubit presence', () {
    late _ChatRepository repository;
    late StreamController<Set<String>> presence;
    late MessagesCubit cubit;

    setUp(() {
      repository = _ChatRepository();
      presence = StreamController<Set<String>>.broadcast();
      when(repository.watchPresence).thenAnswer((_) => presence.stream);
      when(() => repository.getConversations()).thenAnswer(
        (_) async => Right(
          ConversationsPage(conversations: [
            _direct('c1', 'u2'),
            _group('g1', ['me', 'u2']),
          ]),
        ),
      );
      cubit = MessagesCubit(GetConversationsUseCase(repository), repository);
    });

    tearDown(() async {
      await cubit.close();
      await presence.close();
    });

    test('a DM peer coming online lights its row; a group never gets a dot', () async {
      cubit.watchPresence();
      await cubit.load();
      expect(cubit.state.conversations.every((c) => !c.isOnline), isTrue);

      presence.add({'u2'});
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.conversations.firstWhere((c) => c.id == 'c1').isOnline, isTrue);
      expect(cubit.state.conversations.firstWhere((c) => c.id == 'g1').isOnline, isFalse,
          reason: 'a group avatar is not a person');
      expect(cubit.state.onlineNow.map((c) => c.id), ['c1']);

      // A refetch must not lose the dot: no endpoint reports presence, so a
      // server-supplied row always arrives offline.
      await cubit.refresh();
      expect(cubit.state.conversations.firstWhere((c) => c.id == 'c1').isOnline, isTrue);

      presence.add(const {});
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.conversations.every((c) => !c.isOnline), isTrue);
    });

    test('presence is leased: the last release turns every dot off', () async {
      cubit.watchPresence();
      cubit.watchPresence();
      await cubit.load();
      presence.add({'u2'});
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.conversations.first.isOnline, isTrue);

      // One holder leaving (the Inbox branch) must not blind the other (an
      // open chat screen).
      cubit.releasePresence();
      expect(cubit.state.conversations.first.isOnline, isTrue);
      presence.add({'u2'});
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.conversations.first.isOnline, isTrue);

      cubit.releasePresence();
      expect(cubit.state.conversations.first.isOnline, isFalse);
      // An unbalanced release is ignored rather than driving the count below
      // zero, which would make the next lease a no-op.
      cubit.releasePresence();
      verify(repository.watchPresence).called(1);
    });
  });
}
