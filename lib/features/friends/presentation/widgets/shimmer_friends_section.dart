import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// Circle's loading skeleton — a stand-in for `_SectionCard` full of
/// `_FriendRow`s (friends_page.dart).
///
/// The card: `surf` fill, `line` border at 1.5, [AppRadii.xl], the card
/// shadow, and a `fromLTRB(16, 14, 16, 12)` header carrying the eyebrow over
/// a `line2` rule. Each row is `symmetric(horizontal: 14, vertical: 13)` over
/// its own `line2` rule: a 46px avatar, 12px, the username (titleMd), 8px,
/// and the dense outline button (34px tall) on the right.
class ShimmerFriendsSection extends StatelessWidget {
  const ShimmerFriendsSection({super.key, this.rowCount = 5});

  final int rowCount;

  static const _nameWidths = [112.0, 86.0, 134.0, 98.0, 120.0];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final rule = Border(bottom: BorderSide(color: colors.line2));
    return Container(
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.card(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(border: rule),
            alignment: Alignment.centerLeft,
            child: const ShimmerBox(width: 92, height: 11),
          ),
          for (var i = 0; i < rowCount; i++)
            DecoratedBox(
              decoration: BoxDecoration(border: rule),
              child: ShimmerListTile(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                avatarSize: 46,
                titleWidth: _nameWidths[i % _nameWidths.length],
                trailingGap: 8,
                trailing: const ShimmerBox(width: 78, height: 34, borderRadius: AppRadii.pill),
              ),
            ),
        ],
      ),
    );
  }
}
