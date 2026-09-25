import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/story_entity.dart';

/// One page of `GET /stories/archive` (or any other page-number-paginated
/// story list that returns bare `Story` rows).
class StoryArchivePage {
  const StoryArchivePage({required this.stories, required this.hasMore});
  final List<StoryEntity> stories;
  final bool hasMore;
}

/// One page of `GET /stories/{id}/viewers`.
class StoryViewersPage {
  const StoryViewersPage({required this.viewers, required this.hasMore, required this.totalElements});
  final List<StoryViewerEntity> viewers;
  final bool hasMore;

  /// The server's own count for this page's query. Distinct from
  /// `StoryEntity.viewCount`, which survives the 48 h trim of the list —
  /// once trimmed this is 0 while the story still says "Seen by 23".
  final int totalElements;
}

/// Optional filters on the archive (`from`/`to` are UTC calendar days, not
/// timestamps — the server takes `YYYY-MM-DD` and rejects `to` before
/// `from` with `400 VALIDATION_FAILED`).
class StoryArchiveFilter {
  const StoryArchiveFilter({this.from, this.to, this.type});

  final DateTime? from;
  final DateTime? to;
  final StoryType? type;

  bool get isEmpty => from == null && to == null && type == null;
}

/// Everything the Stories feature needs, against the live backend's
/// `/v1/stories` resource. Split out of [FeedRepository] rather than added
/// to it: these ten operations share nothing with posts beyond living on
/// the Home tab, and the story rail is the only place the two meet.
///
/// Replies are the one method here that is not purely a story operation —
/// it posts to yello-api, which hands the message to yello-chat. The DM
/// itself never comes back through this call; it arrives on the chat socket
/// (see `MessageEntity.storyReply`).
abstract interface class StoryRepository {
  /// The whole rail in one call: `GET /stories/me` for your own ring and
  /// `GET /stories/feed` for everyone else's, fetched together.
  Future<Either<Failure, StoryRailEntity>> getRail();

  /// `GET /users/{id}/stories` — one user's active stories, for opening a
  /// ring straight from their profile. Empty means "visible, but nothing
  /// you may see"; a missing/blocked/suspended user is a [ServerFailure]
  /// carrying `RESOURCE_NOT_FOUND`.
  Future<Either<Failure, List<StoryEntity>>> getUserStories(String userId);

  /// `GET /stories/{id}` — one story, for a deep link or to re-sign an
  /// image URL that passed `urlExpiresAt`.
  Future<Either<Failure, StoryEntity>> getStory(String storyId);

  /// `POST /stories`. [image] null posts a `TEXT` story (which then needs
  /// [background]); non-null posts an `IMAGE` story, where [text] is an
  /// optional caption and [background] is ignored server-side.
  Future<Either<Failure, StoryEntity>> createStory({
    String? text,
    StoryBackground? background,
    File? image,
    StoryVisibility visibility = StoryVisibility.friends,
  });

  /// `POST /stories/{id}/view` — marks it seen by you. Idempotent, and a
  /// no-op on your own story.
  Future<Either<Failure, void>> markViewed(String storyId);

  /// `GET /stories/{id}/viewers` — owner only; anyone else gets a
  /// `RESOURCE_NOT_FOUND` failure rather than a permission error.
  Future<Either<Failure, StoryViewersPage>> getViewers(String storyId, {int page = 0});

  /// `GET /stories/archive` — your own stories, expired ones included,
  /// newest first.
  Future<Either<Failure, StoryArchivePage>> getArchive({
    int page = 0,
    StoryArchiveFilter filter = const StoryArchiveFilter(),
  });

  /// `DELETE /stories/{id}` — owner only. Works on an active story (it
  /// vanishes for everyone at once) and on an archived one.
  Future<Either<Failure, void>> deleteStory(String storyId);

  /// `POST /stories/{id}/replies` — sends a DM to the story's author.
  /// [clientId] is the caller's idempotency key: reuse the *same* one when
  /// retrying, and the message is still delivered exactly once.
  Future<Either<Failure, StoryReplyReceipt>> replyToStory({
    required String storyId,
    required String text,
    required String clientId,
  });
}
