import 'package:equatable/equatable.dart';

/// Chat has no backend endpoint at all — the live API's spec has no
/// `/conversations` or `/messages` resource. This entity (and the whole
/// feature) is served entirely by `ChatLocalDataSource`, seeded with demo
/// content from the Yello Mobile v2 design source, until real-time
/// messaging exists server-side.
class ConversationEntity extends Equatable {
  const ConversationEntity({
    required this.id,
    required this.name,
    required this.avatarSeed,
    this.isOnline = false,
    required this.lastMessagePreview,
    required this.lastMessageAt,
    this.unreadCount = 0,
  });

  final String id;
  final String name;
  final int avatarSeed;
  final bool isOnline;
  final String lastMessagePreview;
  final DateTime lastMessageAt;
  final int unreadCount;

  String get firstName => name.split(' ').first;

  ConversationEntity copyWith({String? lastMessagePreview, DateTime? lastMessageAt, int? unreadCount}) {
    return ConversationEntity(
      id: id,
      name: name,
      avatarSeed: avatarSeed,
      isOnline: isOnline,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  List<Object?> get props => [id, lastMessagePreview, lastMessageAt, unreadCount];
}
