import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/audio/voice_note_player.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/features/chat/domain/entities/attachment_entity.dart';
import 'package:yello_social_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:yello_social_app/features/chat/domain/entities/group_invite_entity.dart';
import 'package:yello_social_app/features/chat/domain/entities/message_entity.dart';
import 'package:yello_social_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:yello_social_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:yello_social_app/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:yello_social_app/features/chat/presentation/bloc/messages_cubit.dart';

class _ChatRepository extends Mock implements ChatRepository {}

MessageEntity _message(
  String id, {
  bool fromMe = true,
  String body = 'hello',
  List<ReactionEntity> reactions = const [],
  ReplyPreviewEntity? replyTo,
  GroupInviteCardEntity? groupInvite,
  List<AttachmentEntity> attachments = const [],
}) =>
    MessageEntity(
      id: id,
      conversationId: 'chat',
      senderId: fromMe ? 'me' : 'peer',
      clientId: 'k-$id',
      body: body,
      createdAt: DateTime(2026, 9, 22, 10, int.parse(id.replaceAll(RegExp('[^0-9]'), ''))),
      fromMe: fromMe,
      reactions: reactions,
      replyTo: replyTo,
      groupInvite: groupInvite,
      attachments: attachments,
    );

AttachmentEntity _image(String id, {required String url, required Duration expiresIn}) => AttachmentEntity(
      id: id,
      kind: AttachmentKind.image,
      fileName: '$id.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 2048,
      url: url,
      urlExpiresAt: DateTime.now().add(expiresIn),
    );

void main() {
  late _ChatRepository repository;
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
        voicePlayer: VoiceNotePlayer(),
        acceptInvite: AcceptGroupInviteUseCase(repository),
        declineInvite: DeclineGroupInviteUseCase(repository),
        markRead: MarkReadUseCase(repository),
        repository: repository,
        inbox: inbox,
      );

  setUp(() {
    repository = _ChatRepository();
    events = StreamController<ChatEvent>.broadcast();
    inbox = MessagesCubit(GetConversationsUseCase(repository));
    when(() => repository.watchEvents('chat')).thenAnswer((_) => events.stream);
    when(() => repository.getConversation('chat')).thenAnswer((_) async => const Left(NetworkFailure()));
    when(() => repository.markRead(conversationId: any(named: 'conversationId'), messageId: any(named: 'messageId')))
        .thenAnswer((_) async => const Right(unit));
    when(() => repository.getMessages('chat')).thenAnswer(
      (_) async => Right(MessagesPage(messages: [
        _message('m1', fromMe: false, body: 'lunch?'),
        _message('m2', body: 'yes, 12:30', replyTo: const ReplyPreviewEntity(id: 'm1', senderId: 'peer', body: 'lunch?')),
      ])),
    );
    cubit = build();
  });

  tearDown(() async {
    await cubit.close();
    await inbox.close();
    await events.close();
  });

  test('submitEdit replaces the message and drops unchanged text without a request', () async {
    await cubit.load();
    final edited = _message('m2', body: 'yes, 12:45').copyWith(editedAt: DateTime(2026, 9, 22, 11));
    when(() => repository.editMessage(conversationId: 'chat', messageId: 'm2', body: 'yes, 12:45'))
        .thenAnswer((_) async => Right(edited));

    cubit.startEdit(cubit.state.messages[1]);
    expect(cubit.state.isEditing, isTrue);
    await cubit.submitEdit('yes, 12:30');
    verifyNever(() => repository.editMessage(
        conversationId: any(named: 'conversationId'), messageId: any(named: 'messageId'), body: any(named: 'body')));
    expect(cubit.state.isEditing, isFalse);

    cubit.startEdit(cubit.state.messages[1]);
    await cubit.submitEdit('yes, 12:45');
    expect(cubit.state.messages[1].body, 'yes, 12:45');
    expect(cubit.state.messages[1].isEdited, isTrue);
    expect(cubit.state.busyMessageIds, isEmpty);
  });

  test('startEdit refuses someone else\'s message', () async {
    await cubit.load();
    cubit.startEdit(cubit.state.messages[0]);
    expect(cubit.state.isEditing, isFalse);
  });

  test('deleteMessage leaves a tombstone and flags replies quoting it', () async {
    await cubit.load();
    when(() => repository.deleteMessage(conversationId: 'chat', messageId: 'm1'))
        .thenAnswer((_) async => const Right(unit));
    // Own message so the guard lets it through — the server would refuse
    // a peer's, but the shape of the local update is what is under test.
    final own = _message('m1', body: 'lunch?');
    when(() => repository.getMessages('chat'))
        .thenAnswer((_) async => Right(MessagesPage(messages: [own, cubit.state.messages[1]])));
    await cubit.refreshLatest();

    await cubit.deleteMessage(cubit.state.messages[0]);

    expect(cubit.state.messages[0].isDeleted, isTrue);
    expect(cubit.state.messages[0].body, '');
    expect(cubit.state.messages[1].replyTo?.deleted, isTrue);
  });

  test('toggleReaction sets, then removes, and only one call is in flight per message', () async {
    await cubit.load();
    final setResponse = Completer<Either<Failure, List<ReactionEntity>>>();
    when(() => repository.setReaction(conversationId: 'chat', messageId: 'm1', emoji: '❤️'))
        .thenAnswer((_) => setResponse.future);

    final target = cubit.state.messages[0];
    final first = cubit.toggleReaction(target, '❤️');
    await cubit.toggleReaction(target, '❤️'); // dropped by the guard
    expect(cubit.state.busyMessageIds, {'m1'});
    setResponse.complete(const Right([ReactionEntity(emoji: '❤️', count: 1, userIds: ['me'], reactedByMe: true)]));
    await first;
    verify(() => repository.setReaction(conversationId: 'chat', messageId: 'm1', emoji: '❤️')).called(1);
    expect(cubit.state.messages[0].myReaction?.emoji, '❤️');
    expect(cubit.state.busyMessageIds, isEmpty);

    when(() => repository.removeReaction(conversationId: 'chat', messageId: 'm1'))
        .thenAnswer((_) async => const Right([]));
    await cubit.toggleReaction(cubit.state.messages[0], '❤️');
    verify(() => repository.removeReaction(conversationId: 'chat', messageId: 'm1')).called(1);
    expect(cubit.state.messages[0].reactions, isEmpty);
  });

  test('a failed action surfaces once as actionError, then clears', () async {
    await cubit.load();
    when(() => repository.setReaction(conversationId: 'chat', messageId: 'm1', emoji: '👍'))
        .thenAnswer((_) async => const Left(ValidationFailure('Blocked')));
    final errors = <String>[];
    final sub = cubit.stream.listen((s) {
      if (s.actionError != null) errors.add(s.actionError!);
    });

    await cubit.toggleReaction(cubit.state.messages[0], '👍');
    // The cubit's stream delivers asynchronously; let it drain first.
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(errors, ['Blocked']);
    // The busy-set clear that follows drops it, so it can never re-show.
    expect(cubit.state.actionError, isNull);
    expect(cubit.state.messages[0].reactions, isEmpty);
  });

  test('send carries the reply target and pending attachment ids', () async {
    await cubit.load();
    cubit.startReply(cubit.state.messages[0]);
    when(() => repository.sendMessage(
          conversationId: 'chat',
          body: 'ok',
          clientId: any(named: 'clientId'),
          replyToMessageId: 'm1',
          attachmentIds: const [],
        )).thenAnswer((invocation) async => Right(
          _message('m3', body: 'ok').copyWith(id: 'm3'),
        ));

    await cubit.send('ok');

    expect(cubit.state.isComposingReply, isFalse);
    final captured = verify(() => repository.sendMessage(
          conversationId: 'chat',
          body: 'ok',
          clientId: captureAny(named: 'clientId'),
          replyToMessageId: 'm1',
          attachmentIds: const [],
        )).captured;
    expect(captured.single, isNotEmpty);
  });

  test('accepting an invite updates the card and adds the group to the inbox', () async {
    const card = GroupInviteCardEntity(
      id: 'i1',
      conversationId: 'g1',
      inviterId: 'peer',
      inviteeId: 'me',
      status: GroupInviteStatus.pending,
      title: 'Beach trip',
      memberCount: 3,
      forMe: true,
    );
    when(() => repository.getMessages('chat')).thenAnswer(
      (_) async => Right(MessagesPage(messages: [_message('m1', fromMe: false, body: '', groupInvite: card)])),
    );
    final group = ConversationEntity(
      id: 'g1',
      type: ConversationType.group,
      title: 'Beach trip',
      createdBy: 'peer',
      createdAt: DateTime(2026),
    );
    when(() => repository.acceptInvite('i1')).thenAnswer((_) async => Right(group));
    await cubit.load();

    final joined = await cubit.acceptInvite(card);

    expect(joined?.id, 'g1');
    expect(cubit.state.messages.single.groupInvite?.status, GroupInviteStatus.accepted);
    expect(inbox.state.conversations.map((c) => c.id), contains('g1'));
  });

  test('refreshLatest re-fetches the conversation only every detailRefreshInterval', () async {
    var now = DateTime(2026, 9, 22, 12);
    final group = ConversationEntity(
      id: 'chat',
      type: ConversationType.group,
      title: 'Trip',
      createdBy: 'peer',
      createdAt: DateTime(2026),
    );
    when(() => repository.getConversation('chat')).thenAnswer((_) async => Right(group));
    await cubit.close();
    cubit = ChatCubit(
      conversationId: 'chat',
      getConversation: GetConversationUseCase(repository),
      getMessages: GetMessagesUseCase(repository),
      sendMessage: SendMessageUseCase(repository),
      editMessage: EditMessageUseCase(repository),
      deleteMessage: DeleteMessageUseCase(repository),
      reactToMessage: ReactToMessageUseCase(repository),
      uploadAttachment: UploadAttachmentUseCase(repository),
      refreshAttachment: RefreshAttachmentUseCase(repository),
      voicePlayer: VoiceNotePlayer(),
      acceptInvite: AcceptGroupInviteUseCase(repository),
      declineInvite: DeclineGroupInviteUseCase(repository),
      markRead: MarkReadUseCase(repository),
      repository: repository,
      inbox: inbox,
      now: () => now,
    );

    await cubit.load();
    verify(() => repository.getConversation('chat')).called(1);
    expect(inbox.state.conversations.map((c) => c.id), contains('chat'), reason: 'the detail lands in the inbox too');

    now = now.add(const Duration(seconds: 5));
    await cubit.refreshLatest();
    verifyNever(() => repository.getConversation('chat'));

    now = now.add(const Duration(seconds: 5));
    await cubit.refreshLatest();
    await Future<void>.delayed(Duration.zero);
    verify(() => repository.getConversation('chat')).called(1);
  });

  test('typing: a peer shows, expires or clears on their message; own echo is ignored', () async {
    final group = ConversationEntity(
      id: 'chat',
      type: ConversationType.group,
      title: 'Trip',
      createdBy: 'peer',
      createdAt: DateTime(2026),
      viewerId: 'me',
    );
    when(() => repository.getConversation('chat')).thenAnswer((_) async => Right(group));
    await cubit.load();

    events.add(const TypingChanged(userId: 'me', isTyping: true));
    events.add(const TypingChanged(userId: 'peer', isTyping: true));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.typingUserIds, {'peer'});
    expect(cubit.state.isTyping, isTrue);

    events.add(MessageArrived(_message('m3', fromMe: false, body: 'here')));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.typingUserIds, isEmpty, reason: 'their message landing means they stopped');

    events.add(const TypingChanged(userId: 'peer', isTyping: true));
    events.add(const TypingChanged(userId: 'peer', isTyping: false));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.typingUserIds, isEmpty);
  });

  test('onDraftChanged sends typing once per refresh window and stops on send', () async {
    var now = DateTime(2026, 9, 22, 12);
    await cubit.close();
    cubit = ChatCubit(
      conversationId: 'chat',
      getConversation: GetConversationUseCase(repository),
      getMessages: GetMessagesUseCase(repository),
      sendMessage: SendMessageUseCase(repository),
      editMessage: EditMessageUseCase(repository),
      deleteMessage: DeleteMessageUseCase(repository),
      reactToMessage: ReactToMessageUseCase(repository),
      uploadAttachment: UploadAttachmentUseCase(repository),
      refreshAttachment: RefreshAttachmentUseCase(repository),
      voicePlayer: VoiceNotePlayer(),
      acceptInvite: AcceptGroupInviteUseCase(repository),
      declineInvite: DeclineGroupInviteUseCase(repository),
      markRead: MarkReadUseCase(repository),
      repository: repository,
      inbox: inbox,
      now: () => now,
    );
    when(() => repository.sendTyping(conversationId: 'chat', isTyping: any(named: 'isTyping'))).thenReturn(null);
    when(() => repository.sendMessage(
          conversationId: 'chat',
          body: 'hi',
          clientId: any(named: 'clientId'),
          replyToMessageId: null,
          attachmentIds: const [],
        )).thenAnswer((_) async => Right(_message('m9', body: 'hi')));
    await cubit.load();

    cubit.onDraftChanged('h');
    now = now.add(const Duration(seconds: 1));
    cubit.onDraftChanged('hi');
    verify(() => repository.sendTyping(conversationId: 'chat', isTyping: true)).called(1);

    now = now.add(const Duration(seconds: 3));
    cubit.onDraftChanged('hi ');
    verify(() => repository.sendTyping(conversationId: 'chat', isTyping: true)).called(1);

    await cubit.send('hi');
    verify(() => repository.sendTyping(conversationId: 'chat', isTyping: false)).called(1);

    cubit.onDraftChanged('');
    verifyNever(() => repository.sendTyping(conversationId: 'chat', isTyping: false));
  });

  test('LiveDeliveryChanged drives isLive and clears typists when the socket drops', () async {
    await cubit.load();
    events.add(const LiveDeliveryChanged(true));
    events.add(const TypingChanged(userId: 'peer', isTyping: true));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.isLive, isTrue);
    expect(cubit.state.typingUserIds, {'peer'});

    events.add(const LiveDeliveryChanged(false));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.isLive, isFalse);
    expect(cubit.state.typingUserIds, isEmpty);
  });

  test('viewableImageUrls re-signs only the picture whose link has aged out', () async {
    final current = _image('a1', url: 'https://r2.example/a1.jpg?sig=current', expiresIn: const Duration(minutes: 30));
    final expired = _image('a2', url: 'https://r2.example/a2.jpg?sig=old', expiresIn: const Duration(minutes: -1));
    when(() => repository.getMessages('chat')).thenAnswer(
      (_) async => Right(MessagesPage(messages: [_message('m1', fromMe: false, attachments: [current, expired])])),
    );
    when(() => repository.getAttachment('a2')).thenAnswer((_) async => Right(
          _image('a2', url: 'https://r2.example/a2.jpg?sig=resigned', expiresIn: const Duration(hours: 1)),
        ));
    await cubit.load();

    final urls = await cubit.viewableImageUrls([current, expired]);

    // Order matches the attachments handed in, so the viewer opens on the
    // picture that was tapped.
    expect(urls, ['https://r2.example/a1.jpg?sig=current', 'https://r2.example/a2.jpg?sig=resigned']);
    verifyNever(() => repository.getAttachment('a1'));
    // The fresh link is kept in the transcript too, so the thumbnail behind
    // the viewer stops 403ing as well.
    expect(cubit.state.messages.single.attachments.last.url, 'https://r2.example/a2.jpg?sig=resigned');
  });

  test('live frames: reactions replace, deletes tombstone, removal flags the screen', () async {
    await cubit.load();
    events.add(const MessageReactionsChanged(
      conversationId: 'chat',
      messageId: 'm2',
      reactions: [ReactionEntity(emoji: '😂', count: 1, userIds: ['peer'], reactedByMe: false)],
    ));
    events.add(MessageDeleted(conversationId: 'chat', messageId: 'm1', deletedAt: DateTime(2026, 9, 22, 12)));
    events.add(const ConversationRemoved(conversationId: 'chat', reason: 'REMOVED'));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.messages[1].reactions.single.emoji, '😂');
    expect(cubit.state.messages[0].isDeleted, isTrue);
    expect(cubit.state.messages[1].replyTo?.deleted, isTrue);
    expect(cubit.state.wasRemoved, isTrue);
  });
}
