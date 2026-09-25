import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../widgets/settings_card.dart';

/// Account menu → Theme. Four choices: the two [AppThemeFlavor]s, each in
/// light and dark. Still no "match the system" option, because [ThemeCubit]
/// persists a concrete brightness rather than a third value.
///
/// One card per flavor rather than one flat list of four, so the two axes
/// stay legible — the card header says *which palette*, the rows say *which
/// brightness* — and so adding a third flavor later is a third card, not a
/// six-row list with no structure.
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
                AppIconButton(icon: const Icon(CupertinoIcons.back), onPressed: () => Navigator.of(context).maybePop()),
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
            BlocBuilder<ThemeCubit, ThemeState>(
              builder: (context, theme) {
                final cubit = context.read<ThemeCubit>();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final flavor in AppThemeFlavor.values) ...[
                      Text(flavor.label.toUpperCase(), style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                      const SizedBox(height: 4),
                      Text(flavor.blurb, style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3)),
                      const SizedBox(height: 12),
                      SettingsCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _ThemeOption(
                              flavor: flavor,
                              brightness: Brightness.light,
                              icon: CupertinoIcons.sun_max,
                              label: 'Light',
                              selected: theme.flavor == flavor && !theme.isDark,
                              onTap: () => cubit.setTheme(mode: ThemeMode.light, flavor: flavor),
                            ),
                            Divider(height: 1, thickness: 1, color: colors.line),
                            _ThemeOption(
                              flavor: flavor,
                              brightness: Brightness.dark,
                              icon: CupertinoIcons.moon,
                              label: 'Dark',
                              selected: theme.flavor == flavor && theme.isDark,
                              onTap: () => cubit.setTheme(mode: ThemeMode.dark, flavor: flavor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                  ],
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
    required this.flavor,
    required this.brightness,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppThemeFlavor flavor;
  final Brightness brightness;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // The set this row *offers*, not the one the app is currently wearing —
    // that is what the swatch has to show.
    final preview = AppColors.resolve(flavor, brightness);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              _Swatch(preview: preview),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 16, color: colors.ink2),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: AppTextStyles.bodySm.copyWith(color: colors.ink, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(_subtitle(flavor, brightness), style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2)),
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
                child: selected ? Icon(CupertinoIcons.checkmark, size: 14, color: colors.onYel) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _subtitle(AppThemeFlavor flavor, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (flavor) {
      AppThemeFlavor.classic => isDark ? 'Dimmed surfaces, easier at night.' : 'Paper background, dark ink.',
      AppThemeFlavor.quietRails => isDark ? 'Near-black layers, hairline seams.' : 'White cards on a grey canvas.',
    };
  }
}

/// A miniature of the palette a row selects: the page, a card on it, and the
/// accent, stacked the way the app stacks them.
///
/// A plain [DecoratedBox] tree with no blur anywhere — it is rebuilt on every
/// theme change, which is the exact shape that crashed Impeller when it
/// carried a blurred `BoxShadow` (docs/GOTCHAS.md).
class _Swatch extends StatelessWidget {
  const _Swatch({required this.preview});

  final AppColors preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: preview.bg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.of(context).line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: preview.surf,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: preview.line),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(color: preview.yel, borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
