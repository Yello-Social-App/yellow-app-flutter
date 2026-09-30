import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/features/call/domain/entities/call_entity.dart';
import 'package:yello_social_app/features/call/domain/repositories/call_repository.dart';
import 'package:yello_social_app/features/call/domain/usecases/call_usecases.dart';
import 'package:yello_social_app/features/call/presentation/bloc/conversation_call_cubit.dart';

class _CallRepository extends Mock implements CallRepository {}

CallEntity _call({String conversationId = 'group-1', CallStatus status = CallStatus.active, int joined = 2}) =>
    CallEntity(
      id: 'call-9',
      conversationId: conversationId,
      kind: CallKind.group,
      initiatorId: 'ana',
      media: CallMedia.audio,
      status: status,
      createdAt: DateTime(2026, 9, 30, 8),
      participants: [
        for (var i = 0; i < joined; i++) CallParticipant(userId: 'u$i', state: CallParticipantState.joined),
      ],
      isOutgoing: false,
    );

void main() {
  late _CallRepository calls;
  late StreamController<CallEvent> events;
  late ConversationCallCubit cubit;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    calls = _CallRepository();
    events = StreamController<CallEvent>.broadcast();
    when(() => calls.watchCalls()).thenAnswer((_) => events.stream);
    when(() => calls.getConversationCall(any())).thenAnswer((_) async => Right(_call()));
    cubit = ConversationCallCubit(
      conversationId: 'group-1',
      getConversationCall: GetConversationCallUseCase(calls),
      repository: calls,
    )..start();
  });

  tearDown(() async {
    await cubit.close();
    await events.close();
  });

  test('loads the live call when the chat opens', () async {
    await cubit.refresh();
    expect(cubit.state?.id, 'call-9');
    expect(cubit.state?.joinedCount, 2);
  });

  test('roster changes and the end arrive over the socket', () async {
    await cubit.refresh();

    events.add(CallUpdated(_call(joined: 3)));
    await settle();
    expect(cubit.state?.joinedCount, 3);

    events.add(CallEnded(_call(status: CallStatus.ended)));
    await settle();
    expect(cubit.state, isNull);
  });

  test('another conversation’s call is ignored', () async {
    events.add(CallAccepted(_call(conversationId: 'group-2')));
    await settle();
    expect(cubit.state, isNull);
  });

  test('a lookup overtaken by a frame does not overwrite it', () async {
    final lookup = Completer<Either<Never, CallEntity?>>();
    when(() => calls.getConversationCall(any())).thenAnswer((_) => lookup.future);

    final refreshing = cubit.refresh();
    events.add(CallEnded(_call(status: CallStatus.ended)));
    await settle();
    lookup.complete(Right(_call()));
    await refreshing;

    expect(cubit.state, isNull);
  });
}
