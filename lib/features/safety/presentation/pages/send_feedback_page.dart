import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../domain/entities/feedback_entity.dart';
import '../../domain/usecases/safety_usecases.dart';
import '../bloc/feedback_cubit.dart';

/// Settings → Send feedback. Rate one feature 1-5, optionally say why, and
/// see what you have already sent.
///
/// Only the features this app actually has are offered — see
/// [FeedbackFeature.pickable].
class SendFeedbackPage extends StatelessWidget {
  const SendFeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<FeedbackCubit>()..load(),
      child: const _SendFeedbackView(),
    );
  }
}

class _SendFeedbackView extends StatefulWidget {
  const _SendFeedbackView();

  @override
  State<_SendFeedbackView> createState() => _SendFeedbackViewState();
}

class _SendFeedbackViewState extends State<_SendFeedbackView> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send(FeedbackCubit cubit) async {
    FocusScope.of(context).unfocus();
    final ok = await cubit.submit(note: _note.text);
    if (!mounted) return;
    if (ok) {
      _note.clear();
      AppStatusSnackbar.showSuccess(context, message: 'Thanks — your feedback is on its way.');
      return;
    }
    AppStatusSnackbar.showError(
      context,
      message: cubit.state.errorMessage ?? 'Could not send your feedback.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<FeedbackCubit>();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: BlocBuilder<FeedbackCubit, FeedbackState>(
          builder: (context, state) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                Row(
                  children: [
                    AppIconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Text('Send feedback', style: AppTextStyles.titleLg.copyWith(color: colors.ink)),
                  ],
                ),
                const SizedBox(height: 18),
                Text('WHAT ARE YOU RATING?', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final feature in FeedbackFeature.pickable)
                      ChoiceChip(
                        label: Text(feature.label),
                        selected: state.feature == feature,
                        onSelected: state.submitting ? null : (_) => cubit.selectFeature(feature),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('HOW IS IT WORKING?', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                const SizedBox(height: 10),
                _RatingPicker(
                  rating: state.rating,
                  onRate: state.submitting ? null : cubit.setRating,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _note,
                  maxLines: 4,
                  minLines: 3,
                  maxLength: kFeedbackNoteMaxLength,
                  style: AppTextStyles.body.copyWith(color: colors.ink),
                  decoration: InputDecoration(
                    hintText: 'Tell us more (optional)',
                    hintStyle: AppTextStyles.bodySm.copyWith(color: colors.ink3),
                    filled: true,
                    fillColor: colors.surf,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      borderSide: BorderSide(color: colors.line, width: 1.5),
                    ),
                  ),
                ),
                AppButton(
                  label: state.submitting ? 'Sending…' : 'Send feedback',
                  fullWidth: true,
                  onPressed: state.canSubmit ? () => _send(cubit) : null,
                ),
                const SizedBox(height: 28),
                Text('YOUR RECENT FEEDBACK', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                const SizedBox(height: 10),
                if (state.status == FeedbackStatus.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.status == FeedbackStatus.error)
                  ErrorView(message: state.errorMessage ?? 'Could not load your feedback.', onRetry: cubit.load)
                else if (state.recent.isEmpty)
                  const EmptyStateCard(
                    title: 'Nothing sent yet',
                    hint: 'Rate a feature above and it will show up here.',
                  )
                else ...[
                  for (final entry in state.recent) ...[
                    _FeedbackRow(entry: entry),
                    const SizedBox(height: 10),
                  ],
                  if (state.hasMore)
                    TextButton(
                      onPressed: state.isLoadingMore ? null : cubit.loadMore,
                      child: Text(state.isLoadingMore ? 'Loading…' : 'Load more'),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Five taps, no gestures — a drag-to-rate bar reads well on a slider and
/// badly on a five-point scale, where the tap targets are already big
/// enough to hit exactly.
class _RatingPicker extends StatelessWidget {
  const _RatingPicker({required this.rating, required this.onRate});

  final int rating;
  final ValueChanged<int>? onRate;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        for (var value = 1; value <= 5; value++)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton(
              onPressed: onRate == null ? null : () => onRate!(value),
              tooltip: '$value out of 5',
              icon: Icon(
                value <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 32,
                color: value <= rating ? colors.yel : colors.ink3,
              ),
            ),
          ),
      ],
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({required this.entry});

  final FeedbackEntity entry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.feature.label,
                  style: AppTextStyles.bodySm.copyWith(color: colors.ink, fontWeight: FontWeight.w700),
                ),
              ),
              for (var value = 1; value <= 5; value++)
                Icon(
                  value <= entry.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 14,
                  color: value <= entry.rating ? colors.yel : colors.ink3,
                ),
            ],
          ),
          if ((entry.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(entry.note!, style: AppTextStyles.bodySm.copyWith(color: colors.ink2)),
          ],
          const SizedBox(height: 6),
          Text(
            Formatters.relativeShort(entry.createdAt),
            style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3),
          ),
        ],
      ),
    );
  }
}
