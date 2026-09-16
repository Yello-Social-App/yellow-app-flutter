import 'package:equatable/equatable.dart';

/// Where an outgoing message is in its lifecycle. Incoming messages are
/// always [sent]; [sending] and [failed] only ever describe the optimistic
/// copy this client created before the server acknowledged it.
enum MessageDeliveryStatus { sending, sent, failed }

/// A message as `yello-chat` models it.
///
/// [clientId] is the idempotency key *this* client generates before sending:
/// the server echoes it back on the created message, which is how an
/// optimistic bubble is matched to its confirmed version instead of being
/// rendered twice. It is also what makes a retry safe.
class MessageEntity extends Equatable {
  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.clientId,
    required this.body,
    required this.createdAt,
    required this.fromMe,
    this.status = MessageDeliveryStatus.sent,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String clientId;
  final String body;
  final DateTime createdAt;

  /// Derived at mapping time by comparing [senderId] with the signed-in
  /// user's id — the wire format has no such field.
  final bool fromMe;

  final MessageDeliveryStatus status;

  // Names the existing chat UI reads. Kept as getters so the presentation
  // layer did not have to change when this entity moved to the real API.
  String get text => body;
  DateTime get sentAt => createdAt;

  MessageEntity copyWith({String? id, MessageDeliveryStatus? status, DateTime? createdAt}) {
    return MessageEntity(
      id: id ?? this.id,
      conversationId: conversationId,
      senderId: senderId,
      clientId: clientId,
      body: body,
      createdAt: createdAt ?? this.createdAt,
      fromMe: fromMe,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [id, clientId, body, createdAt, status];
}
