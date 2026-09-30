import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_style.dart';

/// Wraps a piece of chrome (a round icon button, a pill) in the ink-outline
/// look: a solid outline in the `ink` token plus a hard offset shadow in
/// near-black `shell`, unless told otherwise.
///
/// Returns [child] untouched outside [AppStyle.outlined], so a call site can
/// wrap unconditionally and the soft flavors keep drawing exactly what they
/// drew before. [radius] null means a circle.
///
/// The shadow has no blur (see [AppStyle.hardShadow]), so this is safe on a
/// widget that rebuilds with Cubit state (docs/GOTCHAS.md).
class InkOutline extends StatelessWidget {
  const InkOutline({
    super.key,
    required this.child,
    this.radius,
    this.offset = AppStyle.buttonOffset,
    this.fill,
    this.borderColor,
    this.shadowColor,
  });

  final Widget child;

  /// Corner radius; null draws a circle.
  final double? radius;
  final double offset;

  /// Background painted under [child]. Defaults to the `surf` token, so a
  /// transparent icon button gets a solid face for its shadow to sit under.
  final Color? fill;
  final Color? borderColor;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    if (!style.outlined) return child;
    final colors = AppColors.of(context);
    final radius = this.radius;
    // Its own transparent Material, so an InkWell inside ripples on top of
    // [fill] instead of on some ancestor Material that [fill] now covers.
    final inked = Material(type: MaterialType.transparency, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill ?? colors.surf,
        shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radius == null ? null : BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? colors.ink, width: style.borderWidth),
        boxShadow: style.hardShadow(colors, offset, color: shadowColor),
      ),
      child: radius == null
          ? ClipOval(child: inked)
          : ClipRRect(borderRadius: BorderRadius.circular(radius), child: inked),
    );
  }
}
