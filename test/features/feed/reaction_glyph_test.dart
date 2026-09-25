import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/feed/domain/entities/post_entity.dart';
import 'package:yello_social_app/features/feed/presentation/widgets/reaction_glyph.dart';

/// Regression for the like pill visibly shrinking and growing as the viewer's
/// reaction changed: the glyph slot swaps between an [Icon] and an emoji
/// [Text], and each emoji has its own advance width, so anything laid out at
/// the glyph's natural size resized the button around it.
void main() {
  Future<Size> glyphSize(WidgetTester tester, ReactionType? reaction) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ReactionGlyph(reaction: reaction, color: const Color(0xFF000000), size: 15),
        ),
      ),
    );
    return tester.getSize(find.byType(ReactionGlyph));
  }

  testWidgets('every reaction renders in the same 15x15 box, including no reaction', (tester) async {
    final sizes = <String, Size>{'none': await glyphSize(tester, null)};
    for (final type in ReactionType.values) {
      sizes[type.wireValue] = await glyphSize(tester, type);
    }

    expect(sizes.values, everyElement(const Size(15, 15)), reason: 'measured: $sizes');
  });

  testWidgets('ReactionGlyphSlot pins an oversized child to its own square', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: ReactionGlyphSlot(
            size: 14,
            // Far larger than the slot — `BoxFit.scaleDown` has to bring it
            // back inside instead of letting it push the row open.
            child: Text('😆', style: TextStyle(fontSize: 64, height: 1)),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(ReactionGlyphSlot)), const Size(14, 14));
  });
}
