import '../../domain/entities/story_entity.dart';

class StorySegmentModel extends StorySegmentEntity {
  const StorySegmentModel({required super.time, required super.tag, required super.caption});

  factory StorySegmentModel.fromJson(Map<String, dynamic> json) => StorySegmentModel(
        time: json['time'] as String,
        tag: json['tag'] as String,
        caption: json['caption'] as String,
      );

  Map<String, dynamic> toJson() => {'time': time, 'tag': tag, 'caption': caption};
}

class StoryModel extends StoryEntity {
  const StoryModel({
    required super.userId,
    required super.name,
    required super.avatarSeed,
    required super.segments,
    super.seen,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) => StoryModel(
        userId: json['user_id'] as String,
        name: json['name'] as String,
        avatarSeed: json['avatar_seed'] as int? ?? 0,
        seen: json['seen'] as bool? ?? false,
        segments: (json['segments'] as List<dynamic>? ?? [])
            .map((s) => StorySegmentModel.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'avatar_seed': avatarSeed,
        'seen': seen,
        'segments': segments
            .map((s) => StorySegmentModel(time: s.time, tag: s.tag, caption: s.caption).toJson())
            .toList(),
      };
}
