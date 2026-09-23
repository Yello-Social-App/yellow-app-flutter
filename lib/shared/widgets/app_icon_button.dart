import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Circular bordered icon button used for the design's many chrome controls
/// (back arrow, search, more-options "···", call, close "✕").
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 42,
    this.filled = false,
    this.borderColor,
    this.iconColor,
    this.backgroundColor,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final double size;
  final bool filled;
  final Color? borderColor;
  final Color? iconColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: backgroundColor ?? (filled ? colors.yel : colors.surf),
      shape: CircleBorder(
        side: BorderSide(color: borderColor ?? colors.line, width: 1.5),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: IconTheme(
            data: IconThemeData(color: iconColor ?? colors.ink, size: size * 0.4),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}
