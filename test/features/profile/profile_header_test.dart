import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/auth/domain/entities/user_entity.dart';
import 'package:yello_social_app/features/friends/domain/entities/friendship_entity.dart';
import 'package:yello_social_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:yello_social_app/shared/widgets/app_avatar.dart';

/// The profile header overlaps its avatar and camera badge into the cover,
/// and both have to stay tappable there. `Transform.translate` can't carry
/// taps past its own box (`docs/GOTCHAS.md`) — these tests pin the
/// `Stack`/`Positioned` layout that can, plus the narrow-width fit, since
/// neither is something `flutter analyze` can see.
void main() {
  UserEntity user({int friendsCount = 0, int postsCount = 0, String? bio}) => UserEntity(
    id: 'u1',
    email: 'amara@example.com',
    username: 'amara',
    fullName: 'Amara Chen',
    bio: bio,
    postsCount: postsCount,
    friendsCount: friendsCount,
    createdAt: DateTime(2026, 3, 14),
    status: 'ACTIVE',
  );

  FriendshipEntity friend(String id) =>
      FriendshipEntity(userId: id, username: id, fullName: 'Friend $id', status: FriendshipStatus.friends);

  Future<void> pumpHeader(
    WidgetTester tester, {
    UserEntity? withUser,
    List<FriendshipEntity> connections = const [],
    VoidCallback? onEditAvatar,
    VoidCallback? onOpenConnections,
    Size size = const Size(320, 1000),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileHeader(
              user: withUser ?? user(),
              connections: connections,
              isUploadingImage: false,
              onEditAvatar: onEditAvatar ?? () {},
              onEditCover: () {},
              onEditProfile: () {},
              onAddStory: () {},
              onCompose: () {},
              onOpenConnections: onOpenConnections ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('lays out without overflow on a narrow phone', (tester) async {
    await pumpHeader(
      tester,
      withUser: user(friendsCount: 4800, postsCount: 3000, bio: 'Building small things on purpose.'),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Amara Chen'), findsOneWidget);
    // Joined date and the e-mail read in the details card below, not here.
    expect(find.text('Building small things on purpose.'), findsOneWidget);
  });

  testWidgets('the avatar camera badge takes a tap where it overlaps the cover', (tester) async {
    var tapped = false;
    await pumpHeader(tester, onEditAvatar: () => tapped = true);

    await tester.tap(find.byIcon(CupertinoIcons.camera_fill));
    expect(tapped, isTrue, reason: 'the avatar overlaps the cover — the overlap must stay hit-testable');
  });

  // Circle is shell branch 1 and has no bottom-nav button; this row is its
  // main entry point, so it has to render at zero connections too.
  testWidgets('the connections row still renders and navigates with no connections', (tester) async {
    var tapped = false;
    await pumpHeader(tester, onOpenConnections: () => tapped = true);

    expect(find.text('Find your circle'), findsOneWidget);
    await tester.tap(find.text('Find your circle'));
    expect(tapped, isTrue);
  });

  // Moved out of the details card when that card stopped being an expander.
  testWidgets('account status renders beside the connections row', (tester) async {
    await pumpHeader(tester, withUser: user(friendsCount: 12));

    expect(tester.takeException(), isNull);
    expect(find.text('Account active'), findsOneWidget);
  });

  testWidgets('the face-pile shows at most three friends beside the real count', (tester) async {
    await pumpHeader(
      tester,
      withUser: user(friendsCount: 12),
      connections: [friend('a'), friend('b'), friend('c'), friend('d'), friend('e')],
    );

    expect(find.text('12 connections'), findsOneWidget);
    // Three faces plus the profile's own avatar.
    expect(find.byType(AppAvatar), findsNWidgets(4));
  });
}
