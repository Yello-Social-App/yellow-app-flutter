import 'package:equatable/equatable.dart';

class StorySegmentEntity extends Equatable {
  const StorySegmentEntity({required this.time, required this.tag, required this.caption});

  final String time;
  final String tag;
  final String caption;

  @override
  List<Object?> get props => [time, tag, caption];
}

/// One person's story tray — a ring of [segments], each an auto-advancing
/// full-screen frame (see `StoryCubit`).
class StoryEntity extends Equatable {
  const StoryEntity({
    required this.userId,
    required this.name,
    required this.avatarSeed,
    required this.segments,
    this.seen = false,
  });

  final String userId;
  final String name;
  final int avatarSeed;
  final List<StorySegmentEntity> segments;

  /// Drives the ring color: unseen stories get the yellow ring, seen ones
  /// the plain hairline (mirrors the mockup's `i < 2 ? yel : line` rule,
  /// generalized to a real per-story flag).
  final bool seen;

  String get firstName => name.split(' ').first;

  @override
  List<Object?> get props => [userId, name, seen, segments];
}
