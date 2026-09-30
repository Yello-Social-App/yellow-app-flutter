import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/auth/domain/entities/user_entity.dart';
import 'package:yello_social_app/features/profile/domain/entities/public_user_entity.dart';
import 'package:yello_social_app/features/profile/presentation/widgets/profile_details_card.dart';

void main() {
  final user = UserEntity(
    id: 'u1',
    email: 'amara@example.com',
    username: 'amara',
    fullName: 'Amara Chen',
    createdAt: DateTime(2026, 3, 14),
    status: 'ACTIVE',
  );

  Future<void> pumpCard(WidgetTester tester, {Widget? card}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: card ?? ProfileDetailsCard(user: user, onEdit: () {}),
          ),
        ),
      ),
    );
  }

  // The card is a plain list now, not an expander: every row it has is on
  // screen from the first frame, with no chevron to reveal the rest.
  testWidgets('shows every row without an expander', (tester) async {
    await pumpCard(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Amara Chen'), findsOneWidget);
    expect(find.text('amara'), findsOneWidget);
    expect(find.text('Joined Mar 14, 2026'), findsOneWidget);
    expect(find.text('amara@example.com'), findsOneWidget);
  });

  // Bio reads in the header, account status beside the connections row.
  testWidgets('carries neither bio nor account status', (tester) async {
    await pumpCard(tester);

    expect(find.text('Add a bio'), findsNothing);
    expect(find.text('Account active'), findsNothing);
  });

  // Someone else's profile: the API has no email for them, and an empty name
  // is left out rather than asking the viewer to "Add your name".
  testWidgets('public variant drops email and the empty-name prompt', (tester) async {
    await pumpCard(
      tester,
      card: ProfileDetailsCard.public(
        user: PublicUserEntity(id: 'u2', username: 'bo', createdAt: DateTime(2025, 11, 2)),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('bo'), findsOneWidget);
    expect(find.text('Joined Nov 2, 2025'), findsOneWidget);
    expect(find.text('Add your name'), findsNothing);
    expect(find.text('amara@example.com'), findsNothing);
  });
}
