import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/audio/voice_note_player.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:yello_social_app/features/chat/domain/entities/message_entity.dart';
import 'package:yello_social_app/features/chat/domain/entities/sticker_entity.dart';
import 'package:yello_social_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:yello_social_app/features/chat/domain/repositories/sticker_repository.dart';
import 'package:yello_social_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:yello_social_app/features/chat/domain/usecases/sticker_usecases.dart';
import 'package:yello_social_app/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:yello_social_app/features/chat/presentation/bloc/messages_cubit.dart';
import 'package:yello_social_app/features/chat/presentation/bloc/sticker_creator_cubit.dart';

class _ChatRepository extends Mock implements ChatRepository {}

class _StickerRepository extends Mock implements StickerRepository {}

StickerEntity _sticker(String id, {String? packId}) => StickerEntity(
  id: id,
  packId: packId,
  background: StickerBackground.removed,
  image: StickerImage(url: 'https://r2.example/$id.webp'),
);

MessageEntity _serverSticker(String id, {required String clientId}) => MessageEntity(
  id: id,
  conversationId: 'chat',
  senderId: 'me',
  clientId: clientId,
  body: '',
  createdAt: DateTime(2026, 9, 28, 10, 20),
  fromMe: true,
  sticker: _sticker('s1'),
);

void main() {
  // `any()` on a non-nullable argument needs a fallback instance mocktail can
  // pass around — one per type matched that way.
  setUpAll(() {
    registerFallbackValue(File('fallback.png'));
    registerFallbackValue(StickerBackground.kept);
  });

  late _ChatRepository repository;
  late _StickerRepository stickers;
  late StreamController<ChatEvent> events;
  late MessagesCubit inbox;
  late ChatCubit cubit;

  ChatCubit build() => ChatCubit(
    conversationId: 'chat',
    getConversation: GetConversationUseCase(repository),
    getMessages: GetMessagesUseCase(repository),
    sendMessage: SendMessageUseCase(repository),
    editMessage: EditMessageUseCase(repository),
    deleteMessage: DeleteMessageUseCase(repository),
    reactToMessage: ReactToMessageUseCase(repository),
    uploadAttachment: UploadAttachmentUseCase(repository),
    refreshAttachment: RefreshAttachmentUseCase(repository),
    saveStickerFromMessage: SaveStickerFromMessageUseCase(stickers),
    voicePlayer: VoiceNotePlayer(),
    acceptInvite: AcceptGroupInviteUseCase(repository),
    declineInvite: DeclineGroupInviteUseCase(repository),
    markRead: MarkReadUseCase(repository),
    repository: repository,
    inbox: inbox,
  );

  setUp(() {
    repository = _ChatRepository();
    stickers = _StickerRepository();
    events = StreamController<ChatEvent>.broadcast();
    inbox = MessagesCubit(GetConversationsUseCase(repository), repository);
    when(() => repository.watchEvents('chat')).thenAnswer((_) => events.stream);
    when(() => repository.markRead(conversationId: any(named: 'conversationId'), messageId: any(named: 'messageId')))
        .thenAnswer((_) async => const Right(unit));
    cubit = build();
  });

  tearDown(() async {
    await cubit.close();
    await inbox.close();
    await events.close();
  });

  group('sending a sticker', () {
    test('draws the bubble at once, then swaps in the server copy', () async {
      when(
        () => repository.sendMessage(
          conversationId: 'chat',
          body: '',
          clientId: any(named: 'clientId'),
          replyToMessageId: null,
          stickerId: 's1',
        ),
      ).thenAnswer((invocation) async {
        final clientId = invocation.namedArguments[const Symbol('clientId')] as String;
        return Right(_serverSticker('m-server', clientId: clientId));
      });

      final sending = cubit.sendSticker(_sticker('s1'));

      // Before the request resolves there is already a bubble, carrying the
      // sticker and nothing else.
      expect(cubit.state.messages.single.sticker!.id, 's1');
      expect(cubit.state.messages.single.body, isEmpty);
      expect(cubit.state.messages.single.status, MessageDeliveryStatus.sending);

      await sending;

      expect(cubit.state.messages.single.id, 'm-server');
      expect(cubit.state.messages.single.status, MessageDeliveryStatus.sent);
      expect(cubit.state.messages.length, 1);
    });

    test('goes out with no body and no attachments, ever', () async {
      when(
        () => repository.sendMessage(
          conversationId: any(named: 'conversationId'),
          body: any(named: 'body'),
          clientId: any(named: 'clientId'),
          replyToMessageId: any(named: 'replyToMessageId'),
          stickerId: any(named: 'stickerId'),
          attachmentIds: any(named: 'attachmentIds'),
        ),
      ).thenAnswer((_) async => Right(_serverSticker('m1', clientId: 'k')));

      await cubit.sendSticker(_sticker('s1'));

      final call = verify(
        () => repository.sendMessage(
          conversationId: 'chat',
          body: captureAny(named: 'body'),
          clientId: any(named: 'clientId'),
          replyToMessageId: any(named: 'replyToMessageId'),
          stickerId: captureAny(named: 'stickerId'),
        ),
      );
      call.called(1);
      expect(call.captured, ['', 's1']);
    });

    test('a reply target rides along, and the composer banner is cleared', () async {
      when(
        () => repository.sendMessage(
          conversationId: any(named: 'conversationId'),
          body: any(named: 'body'),
          clientId: any(named: 'clientId'),
          replyToMessageId: any(named: 'replyToMessageId'),
          stickerId: any(named: 'stickerId'),
        ),
      ).thenAnswer((_) async => Right(_serverSticker('m2', clientId: 'k')));

      final quoted = MessageEntity(
        id: 'm1',
        conversationId: 'chat',
        senderId: 'peer',
        clientId: 'k1',
        body: 'look at this',
        createdAt: DateTime(2026, 9, 28, 10, 10),
        fromMe: false,
      );
      cubit.startReply(quoted);
      await cubit.sendSticker(_sticker('s1'));

      expect(cubit.state.replyingTo, isNull);
      verify(
        () => repository.sendMessage(
          conversationId: 'chat',
          body: '',
          clientId: any(named: 'clientId'),
          replyToMessageId: 'm1',
          stickerId: 's1',
        ),
      ).called(1);
    });

    test('a failure leaves a retryable bubble that resends the same sticker and clientId', () async {
      when(
        () => repository.sendMessage(
          conversationId: any(named: 'conversationId'),
          body: any(named: 'body'),
          clientId: any(named: 'clientId'),
          replyToMessageId: any(named: 'replyToMessageId'),
          stickerId: any(named: 'stickerId'),
        ),
      ).thenAnswer((_) async => const Left(NetworkFailure()));

      await cubit.sendSticker(_sticker('s1'));

      final failed = cubit.state.messages.single;
      expect(failed.status, MessageDeliveryStatus.failed);
      expect(failed.sticker!.id, 's1');

      when(
        () => repository.sendMessage(
          conversationId: 'chat',
          body: '',
          clientId: failed.clientId,
          replyToMessageId: null,
          stickerId: 's1',
        ),
      ).thenAnswer((_) async => Right(_serverSticker('m1', clientId: failed.clientId)));

      await cubit.retry(failed);

      expect(cubit.state.messages.single.id, 'm1');
      expect(cubit.state.messages.length, 1);
    });

    test('the inbox row says "Sent a sticker"', () async {
      when(
        () => repository.sendMessage(
          conversationId: any(named: 'conversationId'),
          body: any(named: 'body'),
          clientId: any(named: 'clientId'),
          replyToMessageId: any(named: 'replyToMessageId'),
          stickerId: any(named: 'stickerId'),
        ),
      ).thenAnswer((_) async => Right(_serverSticker('m1', clientId: 'k')));
      when(() => repository.getConversations(cursor: null)).thenAnswer(
        (_) async => Right(
          ConversationsPage(
            conversations: [
              ConversationEntity(
                id: 'chat',
                type: ConversationType.direct,
                createdBy: 'me',
                createdAt: DateTime(2026, 9, 28),
                viewerId: 'me',
              ),
            ],
          ),
        ),
      );
      await inbox.load();

      await cubit.sendSticker(_sticker('s1'));

      expect(inbox.state.conversations.single.lastMessagePreview, 'Sent a sticker');
    });
  });

  group('SendMessageUseCase with a stickerId', () {
    test('refuses text or attachments beside it, without a request', () async {
      final usecase = SendMessageUseCase(repository);

      final withText = await usecase(
        const SendMessageParams(conversationId: 'chat', text: 'hi', clientId: 'k', stickerId: 's1'),
      );
      expect(withText.isLeft(), isTrue);

      final withFiles = await usecase(
        const SendMessageParams(
          conversationId: 'chat',
          text: '',
          clientId: 'k',
          stickerId: 's1',
          attachmentIds: ['a1'],
        ),
      );
      expect(withFiles.isLeft(), isTrue);

      verifyNever(
        () => repository.sendMessage(
          conversationId: any(named: 'conversationId'),
          body: any(named: 'body'),
          clientId: any(named: 'clientId'),
        ),
      );
    });

    test('an empty body is fine when a sticker is what is being sent', () async {
      when(
        () => repository.sendMessage(
          conversationId: 'chat',
          body: '',
          clientId: 'k',
          replyToMessageId: null,
          stickerId: 's1',
        ),
      ).thenAnswer((_) async => Right(_serverSticker('m1', clientId: 'k')));

      final result = await SendMessageUseCase(
        repository,
      )(const SendMessageParams(conversationId: 'chat', text: '', clientId: 'k', stickerId: 's1'));

      expect(result.isRight(), isTrue);
    });
  });

  group('saving a sticker off a message', () {
    MessageEntity theirs({String? packId}) => MessageEntity(
      id: 'm1',
      conversationId: 'chat',
      senderId: 'peer',
      clientId: 'k1',
      body: '',
      createdAt: DateTime(2026, 9, 28, 10, 10),
      fromMe: false,
      sticker: _sticker('s1', packId: packId),
    );

    test('reports whether it was new or already there', () async {
      when(
        () => stickers.saveStickerFromMessage(conversationId: 'chat', messageId: 'm1'),
      ).thenAnswer((_) async => Right((sticker: _sticker('s1'), alreadyMine: false)));

      final added = await cubit.saveSticker(theirs());
      expect(added!.alreadyMine, isFalse);
      expect(added.sticker.id, 's1');
      expect(cubit.state.busyMessageIds, isEmpty);

      when(
        () => stickers.saveStickerFromMessage(conversationId: 'chat', messageId: 'm1'),
      ).thenAnswer((_) async => Right((sticker: _sticker('s1'), alreadyMine: true)));

      final again = await cubit.saveSticker(theirs());
      expect(again!.alreadyMine, isTrue);
    });

    test('a failure answers null and surfaces the message once', () async {
      when(
        () => stickers.saveStickerFromMessage(conversationId: 'chat', messageId: 'm1'),
      ).thenAnswer((_) async => const Left(ValidationFailure('Your sticker library is full.')));

      final errors = <String>[];
      final sub = cubit.stream.listen((s) {
        if (s.actionError != null) errors.add(s.actionError!);
      });

      expect(await cubit.saveSticker(theirs()), isNull);
      // The cubit's stream delivers asynchronously; let it drain first.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(errors, ['Your sticker library is full.']);
      // The busy-set clear that follows drops it, so it can never re-show —
      // the same contract as every other bubble action.
      expect(cubit.state.actionError, isNull);
    });

    test('a message with no sticker, and a tombstone, are not even asked about', () async {
      final plain = MessageEntity(
        id: 'm2',
        conversationId: 'chat',
        senderId: 'peer',
        clientId: 'k2',
        body: 'hello',
        createdAt: DateTime(2026, 9, 28, 10, 11),
        fromMe: false,
      );
      expect(await cubit.saveSticker(plain), isNull);
      expect(await cubit.saveSticker(theirs().asDeleted(DateTime(2026, 9, 28, 10, 12))), isNull);
      verifyNever(
        () => stickers.saveStickerFromMessage(
          conversationId: any(named: 'conversationId'),
          messageId: any(named: 'messageId'),
        ),
      );
    });
  });

  group('StickerCreatorCubit', () {
    late StickerCreatorCubit creator;

    /// The usecase measures the file before uploading it, so these have to
    /// exist on disk.
    late Directory tempDir;
    File pictureFile(String name) => File('${tempDir.path}/$name')..writeAsBytesSync(const [1, 2, 3]);

    StickerDraftEntity draft({required bool cutout}) => StickerDraftEntity(
      draftId: 'd1',
      original: const StickerImage(url: 'https://r2.example/orig.webp'),
      cutout: cutout ? const StickerImage(url: 'https://r2.example/cut.webp') : null,
      cutoutStatus: cutout ? StickerCutoutStatus.ready : StickerCutoutStatus.noSubject,
    );

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('yello_stickers');
      creator = StickerCreatorCubit(
        createDraft: CreateStickerDraftUseCase(stickers),
        saveSticker: SaveStickerUseCase(stickers),
      );
    });

    tearDown(() async {
      await creator.close();
      tempDir.deleteSync(recursive: true);
    });

    test('a draft with no subject lands on Keep and will not be moved off it', () async {
      when(() => stickers.createDraft(any())).thenAnswer((_) async => Right(draft(cutout: false)));

      await creator.usePicture(pictureFile('shot.png'));

      expect(creator.state.step, StickerCreatorStep.edit);
      expect(creator.state.background, StickerBackground.kept);
      expect(creator.state.canRemoveBackground, isFalse);

      creator.setBackground(StickerBackground.removed);
      expect(creator.state.background, StickerBackground.kept);
      expect(creator.state.preview!.url, 'https://r2.example/orig.webp');
    });

    test('a draft with a cut-out defaults to Remove and can be switched', () async {
      when(() => stickers.createDraft(any())).thenAnswer((_) async => Right(draft(cutout: true)));

      await creator.usePicture(pictureFile('shot.png'));

      expect(creator.state.background, StickerBackground.removed);
      expect(creator.state.preview!.url, 'https://r2.example/cut.webp');

      creator.setBackground(StickerBackground.kept);
      expect(creator.state.preview!.url, 'https://r2.example/orig.webp');
    });

    test('a rejected picture shows why, inside the picker step', () async {
      when(
        () => stickers.createDraft(any()),
      ).thenAnswer((_) async => const Left(ValidationFailure('That picture is over 5 MB.')));

      await creator.usePicture(pictureFile('huge.png'));

      expect(creator.state.step, StickerCreatorStep.pick);
      expect(creator.state.pickError, 'That picture is over 5 MB.');
      expect(creator.state.draft, isNull);
    });

    test('a file that is plainly not a picture never reaches the network', () async {
      // Refused on the extension alone, so it is not even measured.
      await creator.usePicture(File('trip-notes.pdf'));

      expect(creator.state.step, StickerCreatorStep.pick);
      expect(creator.state.pickError, contains("isn't a picture"));
      verifyNever(() => stickers.createDraft(any()));
    });

    test('save sends the chosen background and the trimmed name', () async {
      when(() => stickers.createDraft(any())).thenAnswer((_) async => Right(draft(cutout: false)));
      when(
        () => stickers.saveSticker(draftId: 'd1', background: StickerBackground.kept, name: 'Mochi'),
      ).thenAnswer((_) async => Right(_sticker('s9')));

      await creator.usePicture(pictureFile('shot.png'));
      creator.setName('  Mochi  ');
      final saved = await creator.save();

      expect(saved!.id, 's9');
      verify(() => stickers.saveSticker(draftId: 'd1', background: StickerBackground.kept, name: 'Mochi')).called(1);
    });

    test('a failed save stays on the edit step so it can be tried again', () async {
      when(() => stickers.createDraft(any())).thenAnswer((_) async => Right(draft(cutout: false)));
      when(
        () => stickers.saveSticker(
          draftId: any(named: 'draftId'),
          background: any(named: 'background'),
          name: any(named: 'name'),
        ),
      ).thenAnswer((_) async => const Left(ValidationFailure('Your sticker library is full.')));

      await creator.usePicture(pictureFile('shot.png'));
      expect(await creator.save(), isNull);

      expect(creator.state.step, StickerCreatorStep.edit);
      expect(creator.state.actionError, 'Your sticker library is full.');
      expect(creator.state.draft, isNotNull);
    });

    test('changing the picture drops the draft — it saves once, so keeping it would save the wrong one', () async {
      when(() => stickers.createDraft(any())).thenAnswer((_) async => Right(draft(cutout: false)));
      await creator.usePicture(pictureFile('shot.png'));
      creator.setName('Mochi');

      creator.changePicture();

      expect(creator.state.step, StickerCreatorStep.pick);
      expect(creator.state.draft, isNull);
      expect(creator.state.name, isEmpty);
      expect(await creator.save(), isNull);
    });
  });
}
