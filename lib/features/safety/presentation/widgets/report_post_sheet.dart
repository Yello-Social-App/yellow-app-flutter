import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/post_report_entity.dart';
import '../../domain/usecases/safety_usecases.dart';
import '../bloc/report_post_cubit.dart';

/// "Report post" — pick a reason, optionally say more, send. Answers what
/// happened so the caller can confirm it; null if the sheet was dismissed
/// without sending.
///
/// [ReportOutcome.alreadyReported] comes back when the viewer already has an
/// open report on this post. That is not an error — see `ReportPostCubit`.
Future<ReportOutcome?> showReportPostSheet(BuildContext context, {required String postId}) {
  return showModalBottomSheet<ReportOutcome>(
    context: context,
    // Same root-Navigator reasoning as `showPostOptionsSheet`, which is
    // what opens this: the feed's floating pill nav bar is painted over
    // `body`, so a sheet on the nested Navigator renders behind it.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider(
      create: (_) => sl<ReportPostCubit>(param1: postId),
      child: const _ReportPostSheet(),
    ),
  );
}

class _ReportPostSheet extends StatefulWidget {
  const _ReportPostSheet();

  @override
  State<_ReportPostSheet> createState() => _ReportPostSheetState();
}

class _ReportPostSheetState extends State<_ReportPostSheet> {
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit(ReportPostCubit cubit) async {
    final outcome = await cubit.submit(details: _details.text);
    if (!mounted || outcome == ReportOutcome.none) return;
    if (outcome == ReportOutcome.failed) return; // the inline message says why
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<ReportPostCubit>();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
          border: Border.all(color: colors.line, width: 1.5),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('REPORT POST', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
              const SizedBox(height: 6),
              Text(
                "Tell us what's wrong with it. The author is never told who reported them.",
                style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
              ),
              const SizedBox(height: 14),
              // Only the reason rows and the button read this — the details
              // field is a plain controller and must not be rebuilt under
              // the user's cursor.
              BlocBuilder<ReportPostCubit, ReportPostState>(
                builder: (context, state) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final reason in ReportReason.values)
                      _ReasonRow(
                        reason: reason,
                        selected: state.reason == reason,
                        onTap: state.submitting ? null : () => cubit.selectReason(reason),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _details,
                maxLines: 3,
                minLines: 2,
                maxLength: kReportDetailsMaxLength,
                style: AppTextStyles.body.copyWith(color: colors.ink),
                decoration: InputDecoration(
                  hintText: 'Anything else we should know? (optional)',
                  hintStyle: AppTextStyles.bodySm.copyWith(color: colors.ink3),
                  filled: true,
                  fillColor: colors.surf,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    borderSide: BorderSide(color: colors.line, width: 1.5),
                  ),
                ),
              ),
              BlocBuilder<ReportPostCubit, ReportPostState>(
                builder: (context, state) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.errorMessage != null) ...[
                      Text(state.errorMessage!, style: AppTextStyles.bodySm.copyWith(color: colors.red)),
                      const SizedBox(height: 10),
                    ],
                    AppButton(
                      label: state.submitting ? 'Sending…' : 'Submit report',
                      fullWidth: true,
                      onPressed: state.canSubmit ? () => _submit(cubit) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({required this.reason, required this.selected, required this.onTap});

  final ReportReason reason;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(
              selected ? CupertinoIcons.largecircle_fill_circle : CupertinoIcons.circle,
              size: 20,
              // A colour change, not a glow — see `docs/GOTCHAS.md` on
              // blurred shadows in anything that rebuilds.
              color: selected ? colors.ink : colors.ink3,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reason.label,
                style: AppTextStyles.bodySm.copyWith(
                  color: colors.ink,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
