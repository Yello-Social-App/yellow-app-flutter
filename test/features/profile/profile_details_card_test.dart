import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/auth/domain/entities/user_entity.dart';
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

  Future<void> pumpCard(WidgetTester tester, {required bool expanded}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileDetailsCard(user: user, expanded: expanded, onEdit: () {}),
          ),
        ),
      ),
    );
  }

  testWidgets('collapsed shows the always-on rows and hides the rest', (tester) async {
    await pumpCard(tester, expanded: false);

    expect(tester.takeException(), isNull);
    expect(find.text('Amara Chen'), findsOneWidget);
    expect(find.text('amara'), findsOneWidget);
    expect(find.text('Joined Mar 14, 2026'), findsOneWidget);
    expect(find.text('amara@example.com'), findsNothing);
  });

  testWidgets('expanded adds email, the bio placeholder and account status', (tester) async {
    await pumpCard(tester, expanded: true);

    expect(tester.takeException(), isNull);
    expect(find.text('amara@example.com'), findsOneWidget);
    expect(find.text('Add a bio'), findsOneWidget);
    expect(find.text('Account active'), findsOneWidget);
  });
}
