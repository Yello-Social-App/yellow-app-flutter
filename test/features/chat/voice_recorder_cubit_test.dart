import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/audio/voice_recorder.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/features/chat/domain/entities/attachment_entity.dart';
import 'package:yello_social_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:yello_social_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:yello_social_app/features/chat/presentation/bloc/voice_recorder_cubit.dart';

class _MockRecorder extends Mock implements VoiceRecorder {}

class _MockRepository extends Mock implements ChatRepository {}

class _MockPreviewPlayer extends Mock implements AudioPlayer {}

final _attachment = AttachmentEntity(
  id: 'att-1',
  kind: AttachmentKind.voice,
  fileName: 'voice-message.m4a',
  mimeType: 'audio/mp4',
  sizeBytes: 30412,
  voice: const VoiceMetaEntity(durationMs: 4870, waveform: [10, 90, 40]),
);

void main() {
  late _MockRecorder recorder;
  late _MockRepository repository;
  late _MockPreviewPlayer preview;
  late Directory scratch;
  late File take;

  setUpAll(() {
    registerFallbackValue(File('fallback.m4a'));
    registerFallbackValue(Duration.zero);
  });

  setUp(() async {
    recorder = _MockRecorder();
    repository = _MockRepository();
    preview = _MockPreviewPlayer();
    scratch = await Directory.systemTemp.createTemp('yello-voice-test');
    take = await File('${scratch.path}/take.m4a').writeAsBytes(List.filled(2048, 7));

    when(recorder.hasPermission).thenAnswer((_) async => true);
    when(recorder.start).thenAnswer((_) async {});
    when(recorder.stop).thenAnswer((_) async => take);
    when(recorder.discard).thenAnswer((_) async {});
    when(() => recorder.amplitudes(interval: any(named: 'interval'))).thenAnswer((_) => const Stream.empty());
    when(() => preview.playing).thenReturn(false);
    when(preview.dispose).thenAnswer((_) async {});
  });

  tearDown(() async {
    if (scratch.existsSync()) await scratch.delete(recursive: true);
  });

  VoiceRecorderCubit build() => VoiceRecorderCubit(
    conversationId: 'conv-1',
    recorder: recorder,
    upload: UploadVoiceAttachmentUseCase(repository),
    previewPlayer: preview,
  );

  test('a refused microphone is terminal — nothing is recorded and nothing is asked twice', () async {
    when(recorder.hasPermission).thenAnswer((_) async => false);
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.start();

    expect(cubit.state.status, VoiceRecorderStatus.denied);
    verifyNever(recorder.start);
  });

  test('start records, stop moves to review with the take on disk', () async {
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.start();
    expect(cubit.state.status, VoiceRecorderStatus.recording);
    expect(cubit.state.levels, hasLength(kVoiceRadialBars));

    await cubit.stop();
    expect(cubit.state.status, VoiceRecorderStatus.review);
    expect(cubit.state.levels, hasLength(kVoiceRadialBars));
    verify(recorder.stop).called(1);
  });

  test('a mis-tap is refused before it reaches the network', () async {
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.start();
    // Stopped immediately: well under `voiceMinDuration`.
    await cubit.stop();
    await cubit.send();

    expect(cubit.state.status, VoiceRecorderStatus.review);
    expect(cubit.state.errorMessage, isNotNull);
    verifyNever(() => repository.uploadVoiceAttachment(conversationId: any(named: 'conversationId'), file: any(named: 'file')));
  });

  test('send uploads the take and ends holding the attachment', () async {
    when(
      () => repository.uploadVoiceAttachment(conversationId: 'conv-1', file: take),
    ).thenAnswer((_) async => Right(_attachment));
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.start();
    // The only real wait in here: `send` refuses anything under a second,
    // and the cubit's clock is the wall clock.
    await Future<void>.delayed(voiceMinDuration + const Duration(milliseconds: 150));
    await cubit.stop();
    expect(cubit.state.canSend, isTrue);

    await cubit.send();

    expect(cubit.state.status, VoiceRecorderStatus.sent);
    expect(cubit.state.attachment, _attachment);
    verify(() => repository.uploadVoiceAttachment(conversationId: 'conv-1', file: take)).called(1);
  });

  test('a failed upload keeps the recording so Send can be pressed again', () async {
    when(
      () => repository.uploadVoiceAttachment(conversationId: any(named: 'conversationId'), file: any(named: 'file')),
    ).thenAnswer((_) async => const Left(NetworkFailure()));
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.start();
    await Future<void>.delayed(voiceMinDuration + const Duration(milliseconds: 150));
    await cubit.stop();
    await cubit.send();

    expect(cubit.state.status, VoiceRecorderStatus.review);
    expect(cubit.state.errorMessage, const NetworkFailure().message);
    // Still sendable: the file was never thrown away.
    expect(cubit.state.canSend, isTrue);
  });

  test('closing the sheet mid-recording releases the microphone', () async {
    final cubit = build();

    await cubit.start();
    await cubit.close();

    verify(recorder.discard).called(1);
  });
}
