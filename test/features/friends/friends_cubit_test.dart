import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/features/friends/domain/entities/friendship_entity.dart';
import 'package:yello_social_app/features/friends/domain/repositories/friends_repository.dart';
import 'package:yello_social_app/features/friends/domain/usecases/friends_usecases.dart';
import 'package:yello_social_app/features/friends/presentation/bloc/friends_cubit.dart';

class _FriendsRepository extends Mock implements FriendsRepository {}

FriendshipEntity _person(String id, FriendshipStatus status) =>
    FriendshipEntity(userId: id, username: id, status: status);

FriendsPage _page(List<FriendshipEntity> items) => FriendsPage(friendships: items, hasMore: false);

void main() {
  late _FriendsRepository repo;
  late FriendsCubit cubit;

  final friend = _person('ana', FriendshipStatus.friends);
  final received = _person('bo', FriendshipStatus.requestReceived);
  final sent = _person('cy', FriendshipStatus.requestSent);
  final blocked = _person('dee', FriendshipStatus.none);

  setUp(() {
    repo = _FriendsRepository();
    when(() => repo.getFriends(page: any(named: 'page'))).thenAnswer((_) async => Right(_page([friend])));
    when(
      () => repo.getRequests(page: any(named: 'page'), sent: false),
    ).thenAnswer((_) async => Right(_page([received])));
    when(() => repo.getRequests(page: any(named: 'page'), sent: true)).thenAnswer((_) async => Right(_page([sent])));
    when(() => repo.getBlocked(page: any(named: 'page'))).thenAnswer((_) async => Right(_page([blocked])));
    cubit = FriendsCubit(
      getFriends: GetFriendsUseCase(repo),
      getRequests: GetFriendRequestsUseCase(repo),
      acceptRequest: AcceptFriendRequestUseCase(repo),
      declineRequest: DeclineFriendRequestUseCase(repo),
      cancelRequest: CancelFriendRequestUseCase(repo),
      unfriend: UnfriendUseCase(repo),
      getBlocked: GetBlockedUsersUseCase(repo),
      unblock: UnblockUserUseCase(repo),
    );
  });

  tearDown(() => cubit.close());

  test('refresh loads friends, received and sent requests, and blocked users as separate lists', () async {
    await cubit.refresh();

    expect(cubit.state.status, FriendsStatus.loaded);
    expect(cubit.state.friends, [friend]);
    expect(cubit.state.requests, [received]);
    expect(cubit.state.sentRequests, [sent]);
    expect(cubit.state.blocked, [blocked]);
  });

  test('a failed sent-requests read fails the load', () async {
    when(
      () => repo.getRequests(page: any(named: 'page'), sent: true),
    ).thenAnswer((_) async => const Left(ServerFailure('nope')));

    await cubit.refresh();

    expect(cubit.state.status, FriendsStatus.error);
    expect(cubit.state.errorMessage, 'nope');
  });

  test('cancel withdraws a sent request and clears its busy flag', () async {
    when(() => repo.cancelRequest('cy')).thenAnswer((_) async => const Right(null));
    await cubit.refresh();

    await cubit.cancel('cy');

    expect(cubit.state.sentRequests, isEmpty);
    expect(cubit.state.requests, [received]);
    expect(cubit.state.busyIds, isEmpty);
  });

  test('a failed cancel keeps the row', () async {
    when(() => repo.cancelRequest('cy')).thenAnswer((_) async => const Left(ServerFailure()));
    await cubit.refresh();

    await cubit.cancel('cy');

    expect(cubit.state.sentRequests, [sent]);
    expect(cubit.state.busyIds, isEmpty);
  });

  test('unblock removes the row and clears its busy flag', () async {
    when(() => repo.unblockUser('dee')).thenAnswer((_) async => Right(blocked));
    await cubit.refresh();

    await cubit.unblock('dee');

    expect(cubit.state.blocked, isEmpty);
    expect(cubit.state.busyIds, isEmpty);
  });

  test('a failed unblock keeps the row', () async {
    when(() => repo.unblockUser('dee')).thenAnswer((_) async => const Left(ServerFailure()));
    await cubit.refresh();

    await cubit.unblock('dee');

    expect(cubit.state.blocked, [blocked]);
    expect(cubit.state.busyIds, isEmpty);
  });
}
