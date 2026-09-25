import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/showcase/domain/entities/project_entity.dart';
import 'package:yello_social_app/features/showcase/presentation/widgets/project_card.dart';
import 'package:yello_social_app/features/showcase/presentation/widgets/publish_nudge_card.dart';
import 'package:yello_social_app/features/showcase/presentation/widgets/tech_chip_row.dart';
import 'package:yello_social_app/shared/widgets/filter_chip_pill.dart';

/// The showcase's cards and filter row at the narrowest width we ship to
/// (see the 320dp entry in `docs/GOTCHAS.md`), plus the bits of behaviour
/// that are easy to break silently: which tags fold into "+N", what the
/// footer shows, and how the chip row picks what it shows.
void main() {
  const narrowPhone = Size(320, 640);

  ProjectEntity project({
    String id = 'p1',
    String name = 'CacheWraith Explorer',
    List<String> tech = const [],
    bool isFeatured = false,
    bool isLiked = false,
    int? starCount,
    String? repoUrl,
    String? liveUrl,
  }) {
    return ProjectEntity(
      id: id,
      name: name,
      tagline: 'A fast, good-looking file manager for Linux, built around Material You.',
      description: '',
      emoji: '🛠️',
      tech: tech,
      authorId: 'u1',
      authorUsername: 'a_rather_long_handle_here',
      repoUrl: repoUrl,
      liveUrl: liveUrl,
      starCount: starCount,
      likeCount: 1,
      viewCount: 12345,
      createdAt: DateTime(2026, 9, 1),
      isLiked: isLiked,
      isFeatured: isFeatured,
    );
  }

  Future<void> pumpAtNarrowWidth(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = narrowPhone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 24), children: [child]),
        ),
      ),
    );
  }

  group('ProjectCard', () {
    testWidgets('featured hero with every field set lays out without overflow', (tester) async {
      await pumpAtNarrowWidth(
        tester,
        ProjectCard(
          project: project(
            name: 'A deliberately long project name that has to wrap onto a second line',
            tech: const ['Tauri2', 'Rust', 'React', 'TypeScript', 'Tailwind CSS 4', 'Vite'],
            isFeatured: true,
            starCount: 1280,
            repoUrl: 'https://example.com/repo',
            liveUrl: 'https://example.com',
          ),
          onTap: () {},
          onToggleLike: () {},
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('FEATURED'), findsOneWidget);
      // Three tags visible, the other three folded.
      expect(find.text('Tauri2'), findsOneWidget);
      expect(find.text('React'), findsOneWidget);
      expect(find.text('TypeScript'), findsNothing);
      expect(find.text('+3'), findsOneWidget);
      // Views and upstream stars, compacted.
      expect(find.text('12.3K'), findsOneWidget);
      expect(find.text('1.3K'), findsOneWidget);
    });

    testWidgets('standard card shows no fold pill and no stars when there are none', (tester) async {
      await pumpAtNarrowWidth(
        tester,
        ProjectCard(
          project: project(tech: const ['Go', 'SQLite']),
          onTap: () {},
          onToggleLike: () {},
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('FEATURED'), findsNothing);
      expect(find.textContaining('+'), findsNothing);
      expect(find.byIcon(CupertinoIcons.star), findsNothing);
      expect(find.byIcon(CupertinoIcons.eye), findsOneWidget);
    });

    testWidgets('like pill fires once per tap and is inert while busy', (tester) async {
      var likes = 0;
      await pumpAtNarrowWidth(tester, ProjectCard(project: project(), onTap: () {}, onToggleLike: () => likes++));
      await tester.tap(find.byIcon(CupertinoIcons.heart));
      expect(likes, 1);

      await pumpAtNarrowWidth(
        tester,
        ProjectCard(project: project(), busy: true, onTap: () {}, onToggleLike: () => likes++),
      );
      await tester.tap(find.byIcon(CupertinoIcons.heart));
      expect(likes, 1);
    });
  });

  group('TechChipRow', () {
    const facets = [
      TechCountEntity(name: 'Rust', projectCount: 9),
      TechCountEntity(name: 'React', projectCount: 12),
      TechCountEntity(name: 'Laravel', projectCount: 3),
      TechCountEntity(name: 'TypeScript', projectCount: 7),
      TechCountEntity(name: 'Go', projectCount: 6),
      TechCountEntity(name: 'SQLite', projectCount: 5),
      TechCountEntity(name: 'HTMX', projectCount: 4),
      TechCountEntity(name: 'Tauri2', projectCount: 2),
      TechCountEntity(name: 'Vite', projectCount: 1),
      TechCountEntity(name: 'Zig', projectCount: 1),
    ];

    testWidgets('shows All plus the busiest facets, busiest first, and never more than the cap', (tester) async {
      await pumpAtNarrowWidth(
        tester,
        TechChipRow(tech: facets, selected: null, onSelect: (_) {}, onOpenSheet: () {}, sheetActive: false),
      );

      expect(tester.takeException(), isNull);
      final labels = tester.widgetList<FilterChipPill>(find.byType(FilterChipPill)).map((chip) => chip.label).toList();
      expect(labels.first, 'All');
      expect(labels.length, 1 + kTechChipRowMax);
      expect(labels.sublist(1, 3), ['React', 'Rust']);
      expect(labels, isNot(contains('Vite')));
      expect(labels, isNot(contains('Zig')));
    });

    testWidgets('a selected facet outside the cap is pulled to the front so it can be cleared', (tester) async {
      String? cleared = 'unset';
      await pumpAtNarrowWidth(
        tester,
        TechChipRow(
          tech: facets,
          selected: 'Zig',
          onSelect: (value) => cleared = value,
          onOpenSheet: () {},
          sheetActive: false,
        ),
      );

      final chips = tester.widgetList<FilterChipPill>(find.byType(FilterChipPill)).toList();
      expect(chips[0].label, 'All');
      expect(chips[0].selected, isFalse);
      expect(chips[1].label, 'Zig');
      expect(chips[1].selected, isTrue);

      await tester.tap(find.text('ALL'));
      expect(cleared, isNull);
    });

    testWidgets('the sheet button opens the sheet', (tester) async {
      var opened = 0;
      await pumpAtNarrowWidth(
        tester,
        TechChipRow(tech: const [], selected: null, onSelect: (_) {}, onOpenSheet: () => opened++, sheetActive: true),
      );
      await tester.tap(find.byIcon(CupertinoIcons.slider_horizontal_3));
      expect(opened, 1);
    });
  });

  testWidgets('PublishNudgeCard lays out without overflow and publishes', (tester) async {
    var published = 0;
    await pumpAtNarrowWidth(tester, PublishNudgeCard(projectCount: 1, onPublish: () => published++));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Only 1 project so far'), findsOneWidget);
    await tester.tap(find.text('Publish'));
    expect(published, 1);
  });
}
