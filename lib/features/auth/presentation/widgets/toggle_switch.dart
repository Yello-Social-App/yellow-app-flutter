import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Small pill toggle for "Remember me next time" — hand-drawn (rather than
/// Material's `Switch`) to match the app's own bordered, flat-color design
/// tokens instead of platform switch styling. Purely visual itself; the
/// login page reads [value] on submit and passes it through to
/// `AuthCubit.login`'s `rememberMe` param, which decides whether a future
/// cold start of the app can silently resume this session.
class ToggleSwitch extends StatelessWidget {
  const ToggleSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 38,
        height: 22,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          color: value ? colors.yel : colors.surf2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: value ? colors.ink : colors.line,
            width: 1.5,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: value ? colors.onYel : colors.ink3,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
