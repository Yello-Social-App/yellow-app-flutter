import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// People search's loading skeleton — a structural stand-in for the
/// `_ResultRow` in `search_page.dart`, shown while a typed query is out to
/// `GET /users/search`, so the results swap in without the list re-flowing.
///
/// Every measurement is copied from that row: the chrome (`surf` fill, `line`
/// border at 1.5, [AppRadii.lg] corners — a step tighter than the content
/// cards — and [AppShadows.card]), the 14/12 inset, a 46px avatar, 12px, the
/// display name (titleMd 14/1.15 -> 16) over the handle (metaMono 10.5/1.3 ->
/// 14) 3px apart, 8px, and the 32px-tall dense Add button on the trailing
/// edge.
class ShimmerSearchResultRow extends StatelessWidget {
  const ShimmerSearchResultRow({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            ShimmerBox(width: 46, height: 46, borderRadius: 23),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 132, height: 16),
                  SizedBox(height: 3),
                  ShimmerBox(width: 84, height: 14),
                ],
              ),
            ),
            SizedBox(width: 8),
            ShimmerBox(width: 58, height: 32, borderRadius: AppRadii.pill),
          ],
        ),
      ),
    );
  }
}
