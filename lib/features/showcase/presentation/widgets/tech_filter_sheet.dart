import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/showcase_cubit.dart';

/// The showcase's filter picker: "Featured only", then the full tech vocabulary
/// from `GET /projects/tech`.
///
/// The chip row above the grid (`TechChipRow`) shows only the busiest tags;
/// this sheet is the complete list with counts, so a tag the row does not
/// have room for is still one tap away rather than off-screen. The list is
/// server-supplied and open-ended, so the sheet is what scales.
///
/// Both controls act on [ShowcaseCubit] as they are tapped rather than
/// collecting a draft to apply on close, so a swipe-dismiss can never throw a
/// choice away. Picking a tag closes the sheet; toggling Featured does
/// not, since it is not the thing the sheet was opened for.
Future<void> showTechFilterSheet(BuildContext context, ShowcaseCubit cubit) {
  final colors = AppColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.surf,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xxl)),
    ),
    builder: (_) => BlocProvider<ShowcaseCubit>.value(
      value: cubit,
      child: const _TechFilterSheet(),
    ),
  );
}

class _TechFilterSheet extends StatelessWidget {
  const _TechFilterSheet();

  /// Pop first, then fetch: the sheet has no reason to sit over its own
  /// loading spinner, and it keeps the cubit call off the far side of an await
  /// on this `BuildContext`.
  ///
  /// The equality guard matters — `setTech` treats "the value already selected"
  /// as a request to clear it, which is right for a chip you tap twice and
  /// wrong for a list row you tap once.
  void _apply(BuildContext context, ShowcaseCubit cubit, String? tech) {
    Navigator.of(context).pop();
    if (tech != cubit.state.selectedTech) cubit.setTech(tech);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<ShowcaseCubit>();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: BlocBuilder<ShowcaseCubit, ShowcaseState>(
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                  child: Text(
                    'FILTER',
                    style: AppTextStyles.eyebrow.copyWith(color: colors.ink2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _SheetRow(
                    label: 'Featured only',
                    selected: state.featuredOnly,
                    onTap: cubit.toggleFeaturedOnly,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                  child: Text(
                    'TECH',
                    style: AppTextStyles.eyebrow.copyWith(color: colors.ink2),
                  ),
                ),
                Flexible(
                  child: state.tech.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                          child: Text(
                            'No tech tags published yet.',
                            style: AppTextStyles.bodySm.copyWith(
                              color: colors.ink3,
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                          itemCount: state.tech.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _SheetRow(
                                label: 'All tech',
                                selected: state.selectedTech == null,
                                onTap: () => _apply(context, cubit, null),
                              );
                            }
                            final tech = state.tech[index - 1];
                            return _SheetRow(
                              label: tech.name,
                              trailing: '${tech.projectCount}',
                              selected: state.selectedTech == tech.name,
                              onTap: () => _apply(context, cubit, tech.name),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Optional count suffix, kept as a string for the same reason the chip does.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final foreground = selected ? colors.yeld : colors.ink;

    return Material(
      color: selected ? colors.yelb : colors.surf2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        side: BorderSide(color: selected ? colors.yel : colors.line, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMd.copyWith(color: foreground),
                ),
              ),
              if (trailing != null) ...[
                Text(
                  trailing!,
                  style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3),
                ),
                const SizedBox(width: 10),
              ],
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: selected ? colors.yeld : colors.ink3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
