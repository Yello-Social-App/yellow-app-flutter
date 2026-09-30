import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// Notification settings' loading skeleton — the master "Push
/// notifications" card, the "MUTE PUSH FOR" heading and hint, and the card
/// of per-type toggles (notification_preferences_page.dart).
///
/// `_SettingsCard` is a 14px inset with a `line` border at 1.5,
/// [AppRadii.lg] corners and the card shadow; each `_ToggleRow` is the label
/// (bodySm 13/1.4), an optional subtitle (metaMonoSm), 12px, and the 38×22
/// `ToggleSwitch`. Type rows carry 4px of vertical padding each.
class ShimmerPreferences extends StatelessWidget {
  const ShimmerPreferences({super.key, this.typeCount = 6});

  final int typeCount;

  static const _labelWidths = [96.0, 124.0, 80.0, 142.0, 110.0, 88.0];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Card(child: _ToggleBones(labelWidth: 132, subtitle: true)),
        const SizedBox(height: 20),
        const ShimmerBox(width: 104, height: 11),
        const SizedBox(height: 8),
        const ShimmerTextLines(lineWidthFactors: [0.92, 0.5], lineHeight: 12, gap: 6, padding: EdgeInsets.zero),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            children: [
              for (var i = 0; i < typeCount; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _ToggleBones(labelWidth: _labelWidths[i % _labelWidths.length]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card(context),
      ),
      child: child,
    );
  }
}

class _ToggleBones extends StatelessWidget {
  const _ToggleBones({required this.labelWidth, this.subtitle = false});

  final double labelWidth;
  final bool subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 18,
                child: Align(alignment: Alignment.centerLeft, child: ShimmerBox(width: labelWidth, height: 12)),
              ),
              if (subtitle)
                const ShimmerTextLines(
                  lineWidthFactors: [0.94, 0.6],
                  lineHeight: 9,
                  gap: 5,
                  padding: EdgeInsets.only(top: 5),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const ShimmerBox(width: 38, height: 22, borderRadius: AppRadii.pill),
      ],
    );
  }
}
