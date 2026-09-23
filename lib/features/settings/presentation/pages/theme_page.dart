import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../widgets/settings_card.dart';

/// Account menu → Theme. Light and dark only, because that is what
/// [ThemeCubit] stores and what `AppColors` is built for — no "match the
/// system" option until the cubit can persist a third value.
///
/// Reads the app-level [ThemeCubit] through the tree (`lib/app.dart` puts it
/// above `MaterialApp.router`), so picking an option repaints this screen
/// along with everything behind it.
class ThemePage extends StatelessWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            Row(
              children: [
                AppIconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 12),
                Text('Theme', style: AppTextStyles.titleLg.copyWith(color: colors.ink)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Choose how Yello looks on this device. Your choice is remembered between launches.',
              style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
            ),
            const SizedBox(height: 20),
            Text('APPEARANCE', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
            const SizedBox(height: 12),
            BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, mode) {
                final cubit = context.read<ThemeCubit>();
                return SettingsCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ThemeOption(
                        icon: Icons.light_mode_outlined,
                        label: 'Light',
                        subtitle: 'Paper background, dark ink. The default.',
                        selected: mode != ThemeMode.dark,
                        onTap: () => cubit.setMode(ThemeMode.light),
                      ),
                      Divider(height: 1, thickness: 1, color: colors.line),
                      _ThemeOption(
                        icon: Icons.dark_mode_outlined,
                        label: 'Dark',
                        subtitle: 'Dimmed surfaces, easier at night.',
                        selected: mode == ThemeMode.dark,
                        onTap: () => cubit.setMode(ThemeMode.dark),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colors.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.bodySm.copyWith(color: colors.ink, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Flat colour swap rather than an animated, shadowed marker —
              // this row rebuilds on every theme change (docs/GOTCHAS.md).
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? colors.yel : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? colors.ink : colors.line, width: 1.5),
                ),
                child: selected ? Icon(Icons.check_rounded, size: 14, color: colors.onYel) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
