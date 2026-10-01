import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yello_social_app/features/call/data/datasources/call_log_local_datasource.dart';
import 'package:yello_social_app/features/call/data/repositories/call_log_repository_impl.dart';
import 'package:yello_social_app/features/call/domain/entities/call_entity.dart';
import 'package:yello_social_app/features/call/domain/entities/call_log_entry.dart';
import 'package:yello_social_app/features/call/domain/usecases/call_log_usecases.dart';
import 'package:yello_social_app/features/call/presentation/bloc/call_log_cubit.dart';
import 'package:yello_social_app/features/call/presentation/widgets/call_log_line.dart';

CallLogEntry _entry({
  String callId = 'call-1',
  String conversationId = 'dm-1',
  CallMedia media = CallMedia.audio,
  bool isGroup = false,
  bool isOutgoing = true,
  CallEndReason endReason = CallEndReason.declined,
  DateTime? at,
  Duration? talkTime,
}) => CallLogEntry(
  callId: callId,
  conversationId: conversationId,
  media: media,
  isGroup: isGroup,
  isOutgoing: isOutgoing,
  endReason: endReason,
  at: at ?? DateTime.utc(2026, 10, 1, 9),
  talkTime: talkTime,
);

void main() {
  late CallLogRepositoryImpl repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = CallLogRepositoryImpl(CallLogLocalDataSourceImpl());
  });

  Future<List<CallLogEntry>> stored(String conversationId) async =>
      (await repository.forConversation(conversationId)).getOrElse(() => fail('the log should read'));

  group('the on-device log', () {
    test('keeps what was noted, per conversation, oldest first', () async {
      await repository.record(_entry(callId: 'b', at: DateTime.utc(2026, 10, 1, 11), talkTime: const Duration(seconds: 65)));
      await repository.record(_entry(callId: 'a', at: DateTime.utc(2026, 10, 1, 10)));
      await repository.record(_entry(callId: 'c', conversationId: 'dm-2'));

      // A fresh repository reads it back from storage, not from memory.
      repository = CallLogRepositoryImpl(CallLogLocalDataSourceImpl());
      final entries = await stored('dm-1');

      expect(entries.map((e) => e.callId), ['a', 'b']);
      expect(entries.last, _entry(callId: 'b', at: DateTime.utc(2026, 10, 1, 11), talkTime: const Duration(seconds: 65)));
    });

    test('a second note for the same call replaces the first', () async {
      await repository.record(_entry(endReason: CallEndReason.hangup));
      await repository.record(_entry(endReason: CallEndReason.hangup, talkTime: const Duration(seconds: 12)));

      final entries = await stored('dm-1');
      expect(entries, hasLength(1));
      expect(entries.single.talkTime, const Duration(seconds: 12));
    });

    test('two notes at once both land', () async {
      await Future.wait([repository.record(_entry(callId: 'a')), repository.record(_entry(callId: 'b'))]);

      expect(await stored('dm-1'), hasLength(2));
    });

    test('drops the oldest once it is full', () async {
      for (var i = 0; i <= CallLogRepositoryImpl.maxEntries; i++) {
        await repository.record(_entry(callId: 'call-$i', at: DateTime.utc(2026, 10, 1).add(Duration(minutes: i))));
      }

      final entries = await stored('dm-1');
      expect(entries, hasLength(CallLogRepositoryImpl.maxEntries));
      expect(entries.first.callId, 'call-1');
    });

    test('a stored value that no longer parses does not block later notes', () async {
      SharedPreferences.setMockInitialValues({'call.log': 'not json'});

      await repository.record(_entry());

      expect(await stored('dm-1'), hasLength(1));
    });

    test('clear forgets everything', () async {
      await repository.record(_entry());
      await repository.clear();

      expect(await stored('dm-1'), isEmpty);
    });
  });

  group('CallLogCubit', () {
    test('loads its conversation and draws a call the moment it is noted', () async {
      await repository.record(_entry(callId: 'a'));
      await repository.record(_entry(callId: 'x', conversationId: 'dm-2'));
      final cubit = CallLogCubit(conversationId: 'dm-1', getCallLog: GetCallLogUseCase(repository), repository: repository);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.map((e) => e.callId), ['a']);

      await repository.record(_entry(callId: 'b', at: DateTime.utc(2026, 10, 1, 12)));
      await repository.record(_entry(callId: 'y', conversationId: 'dm-2'));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.map((e) => e.callId), ['a', 'b']);
    });
  });

  group('what the line says', () {
    test('a declined call, from each side', () {
      expect(callLogLabel(_entry()), 'Voice call declined');
      expect(callLogLabel(_entry(isOutgoing: false)), 'You declined a voice call');
      expect(callLogLabel(_entry(isOutgoing: false, isGroup: true, media: CallMedia.video)), 'Video call declined');
    });

    test('a call nobody took', () {
      expect(callLogLabel(_entry(endReason: CallEndReason.missed)), 'Voice call · no answer');
      expect(callLogLabel(_entry(endReason: CallEndReason.missed, isOutgoing: false)), 'Missed voice call');
      expect(callLogLabel(_entry(endReason: CallEndReason.cancelled)), 'Cancelled voice call');
      expect(
        callLogLabel(_entry(endReason: CallEndReason.cancelled, isOutgoing: false, media: CallMedia.video)),
        'Missed video call',
      );
      expect(callLogLabel(_entry(endReason: CallEndReason.busy)), 'Voice call · line busy');
    });

    test('an answered call carries its length', () {
      expect(
        callLogLabel(_entry(endReason: CallEndReason.hangup, talkTime: const Duration(minutes: 1, seconds: 5))),
        'Voice call · 1:05',
      );
      expect(callLogLabel(_entry(endReason: CallEndReason.hangup)), 'Voice call ended');
    });
  });
}
