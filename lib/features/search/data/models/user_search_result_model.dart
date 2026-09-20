import '../../../feed/domain/entities/reactor_entity.dart' show FriendRelationStatus;
import '../../domain/entities/user_search_result_entity.dart';

class UserSearchResultModel extends UserSearchResultEntity {
  const UserSearchResultModel({
    required super.id,
    required super.username,
    super.fullName,
    super.avatarUrl,
    super.friendStatus,
  });

  factory UserSearchResultModel.fromJson(Map<String, dynamic> json) => UserSearchResultModel(
    id: json['id'] as String,
    username: json['username'] as String? ?? 'unknown',
    fullName: json['fullName'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    friendStatus: FriendRelationStatus.fromWire(json['friendStatus'] as String?),
  );
}
