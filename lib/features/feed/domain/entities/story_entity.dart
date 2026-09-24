import 'package:equatable/equatable.dart';

import '../../../../core/utils/presigned_url.dart';

/// What a story's frame actually is. There is no `VIDEO` — the backend's
/// Stories reference lists video stories as not built.
enum StoryType {
  text,
  image;

  static StoryType fromWire(String? value) => value == 'IMAGE' ? StoryType.image : StoryType.text;

  String get wireValue => this == StoryType.image ? 'IMAGE' : 'TEXT';
}

/// Who may see a story. There is deliberately no `PRIVATE`: a story only you
/// can see is just an archived one.
enum StoryVisibility {
  friends,
  public;

  static StoryVisibility fromWire(String? value) =>
      value == 'PUBLIC' ? StoryVisibility.public : StoryVisibility.friends;

  String get wireValue => this == StoryVisibility.public ? 'PUBLIC' : 'FRIENDS';

  String get label => this == StoryVisibility.public ? 'Public' : 'Friends';
}

/// The background of a `TEXT` story, as one of eight server-side **keys**
/// (`cover-0` … `cover-7`). The server never stores CSS or a colour — the
/// key is ours to map to a gradient (see `storyBackgroundGradient`), so a
/// palette change is a client release, not a data migration.
///
/// [fromWire] falls back to [cover0] rather than null for an unknown key:
/// a newer backend adding `cover-8` should render as *some* background
/// instead of a blank frame.
enum StoryBackground {
  cover0,
  cover1,
  cover2,
  cover3,
  cover4,
  cover5,
  cover6,
  cover7;

  static const List<StoryBackground> all = values;

  static StoryBackground? fromWire(String? value) {
    if (value == null) return null;
    final index = int.tryParse(value.replaceFirst('cover-', ''));
    if (index == null || index < 0 || index >= values.length) return cover0;
    return values[index];
  }

  String get wireValue => 'cover-$index';
}

/// The stored image behind an `IMAGE` story. [url] is a **signed, 15-minute**
/// link served from R2's S3 API host — it needs no `Authorization` header,
/// and it stops working at [urlExpiresAt], after which the story has to be
/// re-fetched for a fresh one.
class StoryImageEntity extends Equatable {
  const StoryImageEntity({
    required this.url,
    required this.width,
    required this.height,
    required this.urlExpiresAt,
  });

  final String url;

  /// The stored pixel size (the server scales down to fit 1080x1920 and
  /// never scales up) — enough to reserve the right box before the bytes
  /// land, so the viewer doesn't jump when it does.
  final int width;
  final int height;
  final DateTime? urlExpiresAt;

  double get aspectRatio => height == 0 ? 9 / 16 : width / height;

  /// See `presignedObjectKey` and ADR-015 — the signature query changes on
  /// every read, so caching by raw URL re-downloads an unchanged photo.
  String get cacheKey => presignedObjectKey(url);

  bool get isUrlExpired => urlExpiresAt != null && DateTime.now().isAfter(urlExpiresAt!);

  @override
  List<Object?> get props => [cacheKey, width, height, urlExpiresAt];
}

/// The trimmed author a story, ring or viewer row carries (`AuthorSummary`).
class StoryAuthorEntity extends Equatable {
  const StoryAuthorEntity({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;

  /// Display name, preferring the real one — `fullName` is not required on
  /// the wire and is frequently absent.
  String get displayName {
    final name = fullName?.trim();
    return (name != null && name.isNotEmpty) ? name : username;
  }

  String get firstName => displayName.split(' ').first;

  @override
  List<Object?> get props => [id, username, fullName, avatarUrl];
}

/// One story — **one slide**, not a tray. The app groups them by author into
/// rings ([StoryRingEntity]); every endpoint returns this one shape.
class StoryEntity extends Equatable {
  const StoryEntity({
    required this.id,
    required this.author,
    required this.type,
    this.text,
    this.background,
    this.image,
    this.visibility = StoryVisibility.friends,
    required this.createdAt,
    required this.expiresAt,
    this.isExpired = false,
    this.isOwner = false,
    this.isSeen = false,
    this.viewCount,
  });

  final String id;
  final StoryAuthorEntity author;
  final StoryType type;

  /// `TEXT`: the story itself. `IMAGE`: an optional caption. Untrusted user
  /// text either way — render as text, never as markup.
  final String? text;

  /// `TEXT` only; null on an `IMAGE` story.
  final StoryBackground? background;

  /// `IMAGE` only; null on a `TEXT` story.
  final StoryImageEntity? image;

  final StoryVisibility visibility;
  final DateTime createdAt;

  /// Always `createdAt + 24h`, set server-side. Sending it is ignored.
  final DateTime expiresAt;

  /// Only ever true in your own archive — other people are never handed an
  /// expired story at all.
  final bool isExpired;

  /// Computed server-side from the token, so it needs no `/users/me` call to
  /// be trustworthy (same contract as `PostEntity.isOwner`).
  final bool isOwner;

  /// Whether **you** viewed it. Always true on your own.
  final bool isSeen;

  /// Distinct viewers — owner only, null for everyone else. Survives the
  /// 48 h trim of the viewer *list*, so the archive can say "Seen by 23"
  /// long after the names are gone.
  final int? viewCount;

  bool get hasText => (text?.trim().isNotEmpty) ?? false;
  bool get isImage => type == StoryType.image;

  /// True once the 24 h window has passed by the device's own clock. Kept
  /// separate from [isExpired], which is the server's verdict at fetch time
  /// — a viewer left open across the boundary needs the live answer.
  bool get hasElapsed => DateTime.now().isAfter(expiresAt);

  StoryEntity copyWith({bool? isSeen, int? viewCount, StoryImageEntity? image}) => StoryEntity(
        id: id,
        author: author,
        type: type,
        text: text,
        background: background,
        image: image ?? this.image,
        visibility: visibility,
        createdAt: createdAt,
        expiresAt: expiresAt,
        isExpired: isExpired,
        isOwner: isOwner,
        isSeen: isSeen ?? this.isSeen,
        viewCount: viewCount ?? this.viewCount,
      );

  @override
  List<Object?> get props => [id, type, text, background, image, visibility, isSeen, isOwner, isExpired, viewCount];
}

/// One author's ring: every active story of theirs, in the order they play.
/// `GET /stories/feed` returns these directly; the "Your story" ring is
/// built client-side from `GET /stories/me`, which that feed deliberately
/// leaves out.
class StoryRingEntity extends Equatable {
  const StoryRingEntity({
    required this.author,
    required this.stories,
    required this.hasUnseen,
    required this.latestAt,
    this.isMine = false,
  });

  /// Builds the "Your story" ring out of `/stories/me`'s bare array. Returns
  /// null for an empty array — you have no active story, so the rail shows
  /// the "Add to your story" tile instead of an empty ring.
  static StoryRingEntity? mine(List<StoryEntity> stories) {
    if (stories.isEmpty) return null;
    return StoryRingEntity(
      author: stories.first.author,
      stories: stories,
      // Your own stories are always `isSeen: true`, so a "your story" ring
      // is never highlighted as unseen.
      hasUnseen: false,
      latestAt: stories.map((s) => s.createdAt).reduce((a, b) => a.isAfter(b) ? a : b),
      isMine: true,
    );
  }

  final StoryAuthorEntity author;

  /// Oldest first — the order they play in.
  final List<StoryEntity> stories;

  /// Any slide in the ring you have not viewed. Drives the yellow ring;
  /// false greys it out.
  final bool hasUnseen;

  /// `createdAt` of the newest slide — what the feed orders rings by.
  final DateTime latestAt;

  /// This is your own ring (from `/stories/me`, never from `/stories/feed`).
  /// Its slides show view counts and a delete action instead of a reply box.
  final bool isMine;

  /// Where playback should start: the first unseen slide, or the beginning
  /// once the whole ring has been seen — the behaviour every story app has.
  int get resumeIndex {
    final index = stories.indexWhere((s) => !s.isSeen);
    return index == -1 ? 0 : index;
  }

  /// Replaces one slide by id, recomputing [hasUnseen] from the result so
  /// the rail's ring colour follows a local "seen" flip without a re-fetch.
  StoryRingEntity withStory(StoryEntity story) {
    final index = stories.indexWhere((s) => s.id == story.id);
    if (index == -1) return this;
    final next = [...stories]..[index] = story;
    return StoryRingEntity(
      author: author,
      stories: next,
      hasUnseen: !isMine && next.any((s) => !s.isSeen),
      latestAt: latestAt,
      isMine: isMine,
    );
  }

  /// Drops one slide by id (after a delete). Returns null when it was the
  /// ring's last one, which is the caller's cue to drop the ring entirely —
  /// empty rings are never shown.
  StoryRingEntity? withoutStory(String storyId) {
    final next = stories.where((s) => s.id != storyId).toList();
    if (next.isEmpty) return null;
    return StoryRingEntity(
      author: author,
      stories: next,
      hasUnseen: !isMine && next.any((s) => !s.isSeen),
      latestAt: next.map((s) => s.createdAt).reduce((a, b) => a.isAfter(b) ? a : b),
      isMine: isMine,
    );
  }

  @override
  List<Object?> get props => [author, stories, hasUnseen, latestAt, isMine];
}

/// The whole stories rail in one value: your own ring (null when you have no
/// active story) plus everyone else's, already ordered by the server.
class StoryRailEntity extends Equatable {
  const StoryRailEntity({this.mine, this.rings = const []});

  static const StoryRailEntity empty = StoryRailEntity();

  final StoryRingEntity? mine;
  final List<StoryRingEntity> rings;

  /// Your ring first, then the feed's — the order the rail draws, and the
  /// index space the story viewer plays through.
  List<StoryRingEntity> get all => [?mine, ...rings];

  bool get isEmpty => mine == null && rings.isEmpty;

  int indexOfAuthor(String authorId) => all.indexWhere((r) => r.author.id == authorId);

  @override
  List<Object?> get props => [mine, rings];
}

/// One row of `GET /stories/{id}/viewers` — owner only.
class StoryViewerEntity extends Equatable {
  const StoryViewerEntity({required this.user, required this.viewedAt});

  final StoryAuthorEntity user;
  final DateTime viewedAt;

  @override
  List<Object?> get props => [user, viewedAt];
}

/// What `POST /stories/{id}/replies` hands back. A `202`: the DM has been
/// accepted, not yet delivered — the message itself arrives over the chat
/// socket as a `message.new` frame carrying the same [clientId].
class StoryReplyReceipt extends Equatable {
  const StoryReplyReceipt({required this.storyId, required this.recipientId, required this.clientId});

  final String storyId;
  final String recipientId;
  final String clientId;

  @override
  List<Object?> get props => [storyId, recipientId, clientId];
}
