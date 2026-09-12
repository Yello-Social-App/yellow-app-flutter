import 'dart:convert';

import 'package:yello_social_app/features/auth/domain/entities/user_entity.dart';
import 'package:yello_social_app/features/feed/domain/entities/post_entity.dart';

/// Shared fixtures for tests — keep this the one place that knows what a
/// "typical" post/JWT/etc. looks like, so individual tests build on it
/// instead of re-deriving the shape.
PostEntity buildPost({
  String id = 'p1',
  String authorId = 'u1',
  String authorUsername = 'amara',
  String content = 'Atrium light exploration.',
  List<String> imageUrls = const [],
  int likeCount = 0,
  String? viewerReaction,
  bool savedByMe = false,
  bool repostedByMe = false,
  int repostCount = 0,
  DateTime? createdAt,
  // Non-null makes `PostEntity.isRepost` true — a repost of that post.
  PostEntity? originalPost,
}) {
  return PostEntity(
    id: id,
    authorId: authorId,
    authorUsername: authorUsername,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    content: content,
    // No test cares about real image ids — the url doubles as one.
    images: imageUrls.map((url) => (id: url, url: url)).toList(),
    reactionCounts: likeCount == 0 ? const {} : {'LIKE': likeCount},
    viewerReaction: viewerReaction,
    savedByMe: savedByMe,
    repostedByMe: repostedByMe,
    repostCount: repostCount,
    originalPost: originalPost,
  );
}

UserEntity buildUser({
  String id = 'u1',
  String email = 'amara@example.com',
  String username = 'amara',
  String? fullName = 'Amara Chen',
  String? bio,
  String? avatarUrl,
  DateTime? createdAt,
  String status = 'ACTIVE',
}) {
  return UserEntity(
    id: id,
    email: email,
    username: username,
    fullName: fullName,
    bio: bio,
    avatarUrl: avatarUrl,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    status: status,
  );
}

/// Builds an unsigned-but-well-shaped JWT string with the given `exp`
/// (seconds since epoch) — enough for `jwt_decoder` (which never verifies
/// signatures) to exercise `JwtManagerImpl` against.
String buildFakeJwt({required int expSecondsFromNow}) {
  String encode(Map<String, dynamic> part) => base64Url.encode(utf8.encode(jsonEncode(part))).replaceAll('=', '');

  final header = encode({'alg': 'HS256', 'typ': 'JWT'});
  final exp = DateTime.now().add(Duration(seconds: expSecondsFromNow)).millisecondsSinceEpoch ~/ 1000;
  final payload = encode({'sub': 'u1', 'exp': exp});
  return '$header.$payload.fake-signature';
}
