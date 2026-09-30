import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Cuts down on `Theme.of(context)` / `AppColors.of(context)` boilerplate at
/// every call site — `context.colors.ink`, `context.textTheme.bodyMedium`.
extension ContextX on BuildContext {
  AppColors get colors => AppColors.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  Size get screenSize => MediaQuery.sizeOf(this);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// What a photo's transparent pixels are filled with: black in dark mode,
  /// white in light. Pass it as an image's `color` with
  /// `colorBlendMode: BlendMode.dstOver` (or `ColorFilter.mode` on a
  /// `DecorationImage`) — `dstOver` paints it *behind* the picture and only
  /// within the picture's own bounds, so a `contain`-letterboxed photo keeps
  /// its surrounding background. Stickers deliberately don't use this.
  Color get imageBackdrop => isDark ? Colors.black : Colors.white;
}
