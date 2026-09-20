import 'package:equatable/equatable.dart';

/// `GET /communities`' `sort` parameter. `popular` is the server default.
enum CommunitySort {
  popular,
  newest,
  name;

  /// The wire values happen to match the Dart names here, but go through this
  /// getter anyway so a future rename on either side is a one-line change.
  String get wireValue => switch (this) {
    CommunitySort.popular => 'popular',
    CommunitySort.newest => 'newest',
    CommunitySort.name => 'name',
  };

  String get label => switch (this) {
    CommunitySort.popular => 'Popular',
    CommunitySort.newest => 'New',
    CommunitySort.name => 'A-Z',
  };
}

/// `GET /communities`' optional `membership` filter. Omitting it (null at the
/// call site) means "no filter" — not a third enum value, so this stays a
/// two-value enum used as a nullable.
enum CommunityMembershipFilter {
  joined,
  notJoined;

  String get wireValue => switch (this) {
    CommunityMembershipFilter.joined => 'joined',
    // Snake_case on the wire, unlike `sort`'s values — the one place these
    // two query parameters disagree on casing.
    CommunityMembershipFilter.notJoined => 'not_joined',
  };

  String get label => switch (this) {
    CommunityMembershipFilter.joined => 'Joined',
    CommunityMembershipFilter.notJoined => 'Not joined',
  };
}

/// The `{community}` path segment on every community route is this [slug],
/// never [id] — the uuid is only useful for local identity/equality. Mirrors
/// the backend's `Community` schema.
class CommunityEntity extends Equatable {
  const CommunityEntity({
    required this.id,
    required this.slug,
    required this.name,
    required this.tagline,
    required this.description,
    required this.emoji,
    this.tags = const [],
    this.rules = const [],
    this.memberCount = 0,
    this.onlineCount,
    required this.createdAt,
    this.isMember = false,
  });

  final String id;

  /// URL-safe handle (`^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$`, 3-32 chars). This
  /// is what every `/communities/{community}/...` route takes.
  final String slug;
  final String name;
  final String tagline;
  final String description;

  /// A single emoji chosen by the community, used as its avatar throughout —
  /// no image upload exists for communities.
  final String emoji;

  /// The flair values a post in this community may carry. `POST
  /// /communities/{slug}/posts` requires a `tag`, and the server validates it
  /// against this list, so a composer must offer these rather than free text.
  final List<String> tags;

  /// House rules, shown on the community's own screen. Free text, ordered.
  final List<String> rules;
  final int memberCount;

  /// Members currently online — nullable on the wire, so absent rather than
  /// zero when the backend isn't tracking presence.
  final int? onlineCount;
  final DateTime createdAt;

  /// Whether the *viewer* has joined. Drives Join/Leave and gates posting:
  /// `POST /communities/{slug}/posts` answers
  /// `403 COMMUNITY_MEMBERSHIP_REQUIRED` for a non-member.
  final bool isMember;

  CommunityEntity copyWith({bool? isMember, int? memberCount}) {
    return CommunityEntity(
      id: id,
      slug: slug,
      name: name,
      tagline: tagline,
      description: description,
      emoji: emoji,
      tags: tags,
      rules: rules,
      memberCount: memberCount ?? this.memberCount,
      onlineCount: onlineCount,
      createdAt: createdAt,
      isMember: isMember ?? this.isMember,
    );
  }

  @override
  List<Object?> get props => [id, slug, name, memberCount, onlineCount, isMember];
}

/// The trimmed community reference that rides along on every
/// `CommunityPost` (the backend's `CommunitySummary`) — enough to render the
/// "posted in 🇰🇭 Hushstack Cambodia" line and to navigate, without
/// re-sending the whole community on every row.
class CommunitySummaryEntity extends Equatable {
  const CommunitySummaryEntity({required this.slug, required this.name, required this.emoji});

  final String slug;
  final String name;
  final String emoji;

  @override
  List<Object?> get props => [slug, name, emoji];
}
