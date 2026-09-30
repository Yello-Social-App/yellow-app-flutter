import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// The inbox's loading skeleton — a run of stand-ins for `_ConversationRow`
/// (messages_page.dart), divided the same way, so conversations swap in
/// without the sheet re-flowing.
///
/// Geometry copied from the row: `symmetric(horizontal: 8, vertical: 12)`
/// padding, a 48px avatar, 12px, the name (titleMd 14/1.15) over the preview
/// (bodySm 13/1.4) 5px apart, then 10px and a right-aligned timestamp
/// (metaMono). `_RowDivider`'s 1px `line2` rule indented 68px sits between.
class ShimmerConversationList extends StatelessWidget {
  const ShimmerConversationList({super.key, this.count = 7});

  final int count;

  /// Name / preview bar widths, cycled so the rows don't read as clones.
  static const _widths = [(118.0, 196.0), (92.0, 150.0), (136.0, 176.0), (104.0, 128.0)];

  @override
  Widget build(BuildContext context) {
    final divider = Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Divider(height: 1, thickness: 1, color: AppColors.of(context).line2),
    );
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) divider,
          ShimmerListTile(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            avatarSize: 48,
            titleWidth: _widths[i % _widths.length].$1,
            titleHeight: 14,
            subtitleWidth: _widths[i % _widths.length].$2,
            subtitleHeight: 12,
            lineGap: 9,
            trailing: const Padding(
              // Top-aligned with the name, like the real timestamp.
              padding: EdgeInsets.only(bottom: 24),
              child: ShimmerBox(width: 26, height: 10),
            ),
          ),
        ],
      ],
    );
  }
}
