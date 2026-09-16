import '../../../profile/domain/entities/public_user_entity.dart';
import '../../../profile/domain/usecases/profile_usecases.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/participant_entity.dart';

/// Resolves chat participant ids into display identities.
///
/// `yello-chat` stores no usernames or avatars — a participant is a bare
/// `userId` — so every name and photo in the inbox comes from yello-api's
/// `GET /v1/users/{id}`. This sits between the two services and keeps that
/// fan-out survivable:
///
///  * results are cached for the process lifetime (profiles change rarely,
///    and a wrong-for-a-while display name is cheaper than re-fetching on
///    every inbox rebuild),
///  * concurrent lookups of the same id share one request,
///  * a failed lookup resolves to null instead of throwing — an unhydrated
///    participant renders as "Unknown", it does not take the inbox down.
///
/// yello-api has no bulk user endpoint, so an inbox of N conversations costs
/// N first-time lookups. If that becomes a problem, the fix belongs
/// server-side: either a `GET /v1/users?ids=` batch route, or have
/// yello-chat denormalise username/avatar onto its participant rows.
class UserDirectory {
  UserDirectory(this._getUser);

  final GetUserUseCase _getUser;

  final Map<String, PublicUserEntity> _cache = {};
  final Map<String, Future<PublicUserEntity?>> _inFlight = {};

  PublicUserEntity? cached(String userId) => _cache[userId];

  Future<PublicUserEntity?> lookup(String userId) {
    if (userId.isEmpty) return Future.value(null);

    final hit = _cache[userId];
    if (hit != null) return Future.value(hit);

    return _inFlight[userId] ??= _getUser(userId).then((result) {
      return result.fold((_) => null, (user) {
        _cache[userId] = user;
        return user;
      });
    }).whenComplete(() => _inFlight.remove(userId));
  }

  /// Fills in every participant whose profile is missing, fetching each
  /// unknown id at most once per call.
  Future<List<ParticipantEntity>> hydrate(List<ParticipantEntity> participants) async {
    final missing = <String>{
      for (final p in participants)
        if (p.username == null && _cache[p.userId] == null && p.userId.isNotEmpty) p.userId,
    };
    if (missing.isNotEmpty) await Future.wait(missing.map(lookup));

    return participants.map((p) {
      final user = _cache[p.userId];
      if (user == null) return p;
      return p.withProfile(username: user.username, fullName: user.fullName, avatarUrl: user.avatarUrl);
    }).toList(growable: false);
  }

  Future<ConversationEntity> hydrateConversation(ConversationEntity conversation) async {
    if (conversation.participants.isEmpty) return conversation;
    return conversation.copyWith(participants: await hydrate(conversation.participants));
  }

  /// Hydrates a whole page in one pass, so shared participants across
  /// conversations are fetched once rather than once per row.
  Future<List<ConversationEntity>> hydrateAll(List<ConversationEntity> conversations) async {
    final everyone = <ParticipantEntity>[for (final c in conversations) ...c.participants];
    await hydrate(everyone);
    return [
      for (final c in conversations)
        c.copyWith(
          participants: [
            for (final p in c.participants)
              if (_cache[p.userId] case final user?)
                p.withProfile(username: user.username, fullName: user.fullName, avatarUrl: user.avatarUrl)
              else
                p,
          ],
        ),
    ];
  }

  /// Dropped on sign-out — see `SessionManager`'s identity-change reset.
  void clear() {
    _cache.clear();
    _inFlight.clear();
  }
}
