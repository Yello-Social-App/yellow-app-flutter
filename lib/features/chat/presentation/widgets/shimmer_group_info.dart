import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// Group info's loading skeleton — the identity card, the action button and
/// the members card, laid out like the loaded page (group_info_page.dart).
///
/// `_IdentityCard`: 16px inset, `line` border at 1.5, [AppRadii.lg], card
/// shadow; an 88px avatar, 14px, the centred name (titleLg) and member
/// count. Then 20px, the full-width dense "Add people" button, 20px, and
/// `_MembersCard`'s rows — `fromLTRB(12, 10, 4, 10)`, a 40px avatar, 12px,
/// name (bodyMd) over role (metaMono) — split by `line2` rules indented 64.
class ShimmerGroupInfo extends StatelessWidget {
  const ShimmerGroupInfo({super.key, this.memberCount = 4});

  final int memberCount;

  static const _nameWidths = [128.0, 96.0, 142.0, 110.0];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final card = BoxDecoration(
      color: colors.surf,
      border: Border.all(color: colors.line, width: 1.5),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      boxShadow: AppShadows.card(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: card,
          child: const Column(
            children: [
              ShimmerBox(width: 88, height: 88, borderRadius: 44),
              SizedBox(height: 16),
              ShimmerBox(width: 150, height: 18),
              SizedBox(height: 10),
              ShimmerBox(width: 72, height: 10),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const ShimmerBox(height: 34, borderRadius: AppRadii.pill),
        const SizedBox(height: 20),
        Container(
          decoration: card,
          child: Column(
            children: [
              for (var i = 0; i < memberCount; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 64),
                    child: Divider(height: 1, thickness: 1, color: colors.line2),
                  ),
                ShimmerListTile(
                  padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                  titleWidth: _nameWidths[i % _nameWidths.length],
                  titleHeight: 13,
                  subtitleWidth: 48,
                  subtitleHeight: 9,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
