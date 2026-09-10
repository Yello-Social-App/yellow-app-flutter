import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Cuts down on `Theme.of(context)` / `AppColors.of(context)` boilerplate at
/// every call site — `context.colors.ink`, `context.textTheme.bodyMedium`.
extension ContextX on BuildContext {
  AppColors get colors => AppColors.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  Size get screenSize => MediaQuery.sizeOf(this);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
