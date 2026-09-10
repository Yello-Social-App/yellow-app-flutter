import 'package:equatable/equatable.dart';

class MessageEntity extends Equatable {
  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.fromMe,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String conversationId;
  final bool fromMe;
  final String text;
  final DateTime sentAt;

  @override
  List<Object?> get props => [id, text, sentAt];
}
