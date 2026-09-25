import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/chat/data/models/message_model.dart';
import 'package:yello_social_app/features/feed/data/models/story_model.dart';
import 'package:yello_social_app/features/feed/domain/entities/story_entity.dart';

/// Wire-shape coverage for the `/v1/stories` resource: every endpoint hands
/// back the same `Story` object, so one bad cast here breaks all ten.
void main() {
  group('StoryMapper', () {
    test('reads an IMAGE story, signed URL and all', () {
      final story = StoryMapper.fromJson({
        'id': 's1',
        'author': {'id': 'u1', 'username': 'rithy', 'fullName': 'Rithy Chea', 'avatarUrl': null},
        'type': 'IMAGE',
        'text': 'Meetup this Saturday',
        'background': null,
        'image': {
          'url': 'https://acc.r2.cloudflarestorage.com/b/stories/5b.jpg?X-Amz-Signature=abc',
          'width': 1080,
          'height': 1920,
          'urlExpiresAt': '2026-09-23T10:30:00Z',
        },
        'visibility': 'PUBLIC',
        'createdAt': '2026-09-23T10:15:00Z',
        'expiresAt': '2026-09-24T10:15:00Z',
        'isExpired': false,
        'isOwner': false,
        'isSeen': false,
        'viewCount': null,
      });

      expect(story.type, StoryType.image);
      expect(story.visibility, StoryVisibility.public);
      expect(story.background, isNull);
      expect(story.image!.width, 1080);
      // The signature query is stripped for the cache key — a re-signed URL
      // for the same object must not be a cache miss (ADR-015).
      expect(story.image!.cacheKey, 'https://acc.r2.cloudflarestorage.com/b/stories/5b.jpg');
      expect(story.viewCount, isNull);
      expect(story.author.displayName, 'Rithy Chea');
    });

    test('reads a TEXT story and maps its cover key to the enum', () {
      final story = StoryMapper.fromJson({
        'id': 's2',
        'author': {'id': 'u2', 'username': 'sokha'},
        'type': 'TEXT',
        'text': 'khtok v2 just hit 1k stars',
        'background': 'cover-2',
        'image': null,
        'visibility': 'FRIENDS',
        'createdAt': '2026-09-23T10:15:00Z',
        'expiresAt': '2026-09-24T10:15:00Z',
        'isOwner': true,
        'isSeen': true,
        'viewCount': 3,
      });

      expect(story.type, StoryType.text);
      expect(story.background, StoryBackground.cover2);
      expect(story.background!.wireValue, 'cover-2');
      expect(story.viewCount, 3);
      // `fullName` is absent on the wire here — the username stands in.
      expect(story.author.displayName, 'sokha');
    });

    test('an unknown cover key still renders as a background, not a blank frame', () {
      expect(StoryBackground.fromWire('cover-99'), StoryBackground.cover0);
      expect(StoryBackground.fromWire(null), isNull);
    });

    test('a missing expiresAt is derived from createdAt, not from now', () {
      final story = StoryMapper.fromJson({
        'id': 's3',
        'author': {'id': 'u1', 'username': 'a'},
        'type': 'TEXT',
        'createdAt': '2026-09-23T10:15:00Z',
      });
      expect(story.expiresAt, DateTime.parse('2026-09-24T10:15:00Z'));
    });
  });

  group('StoryRingEntity', () {
    StoryEntity story(String id, {bool seen = false}) => StoryEntity(
          id: id,
          author: const StoryAuthorEntity(id: 'u1', username: 'rithy'),
          type: StoryType.text,
          createdAt: DateTime(2026, 9, 23, 10),
          expiresAt: DateTime(2026, 9, 24, 10),
          isSeen: seen,
        );

    test('mine() is null for an empty array — the rail shows the add tile', () {
      expect(StoryRingEntity.mine(const []), isNull);
    });

    test('playback resumes at the first unseen slide, and restarts once all are seen', () {
      final partly = StoryRingEntity(
        author: const StoryAuthorEntity(id: 'u1', username: 'rithy'),
        stories: [story('a', seen: true), story('b'), story('c')],
        hasUnseen: true,
        latestAt: DateTime(2026, 9, 23, 10),
      );
      expect(partly.resumeIndex, 1);

      final allSeen = StoryRingEntity(
        author: const StoryAuthorEntity(id: 'u1', username: 'rithy'),
        stories: [story('a', seen: true), story('b', seen: true)],
        hasUnseen: false,
        latestAt: DateTime(2026, 9, 23, 10),
      );
      expect(allSeen.resumeIndex, 0);
    });

    test('withStory recomputes hasUnseen so the rail greys out without a refetch', () {
      final ring = StoryRingEntity(
        author: const StoryAuthorEntity(id: 'u1', username: 'rithy'),
        stories: [story('a', seen: true), story('b')],
        hasUnseen: true,
        latestAt: DateTime(2026, 9, 23, 10),
      );
      expect(ring.withStory(story('b', seen: true)).hasUnseen, isFalse);
    });

    test('withoutStory returns null on the last slide — empty rings are never shown', () {
      final ring = StoryRingEntity(
        author: const StoryAuthorEntity(id: 'u1', username: 'rithy'),
        stories: [story('a')],
        hasUnseen: true,
        latestAt: DateTime(2026, 9, 23, 10),
      );
      expect(ring.withoutStory('a'), isNull);
      expect(ring.withoutStory('nope'), equals(ring));
    });

    test('the rail plays your own ring first, then the feed order', () {
      final mine = StoryRingEntity.mine([story('mine')])!;
      final theirs = StoryRingEntity(
        author: const StoryAuthorEntity(id: 'u2', username: 'sokha'),
        stories: [story('theirs')],
        hasUnseen: true,
        latestAt: DateTime(2026, 9, 23, 10),
      );
      final rail = StoryRailEntity(mine: mine, rings: [theirs]);
      expect(rail.all.length, 2);
      expect(rail.indexOfAuthor('u2'), 1);
      expect(rail.indexOfAuthor('nobody'), -1);
    });
  });

  group('StoryReplyMapper (chat side)', () {
    test('reads the storyReply reference off a message', () {
      final reply = StoryReplyMapper.fromJsonOrNull({
        'storyId': 's1',
        'storyAuthorId': 'u1',
        'storyType': 'IMAGE',
        'storyExpiresAt': '2100-01-01T00:00:00.000Z',
      })!;

      expect(reply.storyIsImage, isTrue);
      expect(reply.hasExpired, isFalse);
      expect(reply.canStillLoad('u2'), isTrue, reason: 'still live — anyone who may see it can load it');
    });

    test('once expired, only the story author can still load it for a preview', () {
      final reply = StoryReplyMapper.fromJsonOrNull({
        'storyId': 's1',
        'storyAuthorId': 'u1',
        'storyType': 'TEXT',
        'storyExpiresAt': '2020-01-01T00:00:00.000Z',
      })!;

      expect(reply.hasExpired, isTrue);
      // The author still reads it from their archive; for everyone else it
      // is a guaranteed 404, so the bubble shows the placeholder instead.
      expect(reply.canStillLoad('u1'), isTrue);
      expect(reply.canStillLoad('u2'), isFalse);
      expect(reply.canStillLoad(null), isFalse);
    });

    test('is null on every message that is not a story reply', () {
      expect(StoryReplyMapper.fromJsonOrNull(null), isNull);
      expect(StoryReplyMapper.fromJsonOrNull(<String, dynamic>{}), isNull);
    });
  });
}
