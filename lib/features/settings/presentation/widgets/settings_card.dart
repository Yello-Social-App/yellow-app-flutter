import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// The bordered surface every settings group sits on — same shape as the
/// notification-preferences page's own private card, kept here so the two
/// new settings screens share one copy rather than growing a third.
///
/// [padding] is zero for a card whose rows draw their own dividers edge to
/// edge; the default matches a card holding a single block of content.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(AppRadii.lg);
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: colors.surf, borderRadius: radius, boxShadow: AppShadows.card(context)),
      // Border in `foregroundDecoration`, not `decoration`: a zero-padding
      // card lets its rows and dividers reach the edge, and `decoration`
      // paints *behind* the child — the border would quietly vanish along
      // those edges. See docs/GOTCHAS.md.
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: colors.line, width: 1.5),
      ),
      child: child,
    );
  }
}
