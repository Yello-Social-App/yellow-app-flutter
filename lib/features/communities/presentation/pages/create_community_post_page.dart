import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../domain/entities/community_entity.dart';
import '../../domain/entities/community_post_entity.dart'
    show kCommunityPostBodyMaxChars, kCommunityPostTitleMaxChars;
import '../bloc/create_community_post_cubit.dart';

/// Composer for a new thread in [community].
///
/// The tag picker is populated from the community's own `tags` rather than
/// being free text: `POST /communities/{slug}/posts` requires a `tag` and
/// validates it against that list server-side, so free entry could only ever
/// produce a rejection.
class CreateCommunityPostPage extends StatelessWidget {
  const CreateCommunityPostPage({super.key, required this.community});

  final CommunityEntity community;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CreateCommunityPostCubit>(),
      child: _CreateCommunityPostView(community: community),
    );
  }
}

class _CreateCommunityPostView extends StatefulWidget {
  const _CreateCommunityPostView({required this.community});

  final CommunityEntity community;

  @override
  State<_CreateCommunityPostView> createState() => _CreateCommunityPostViewState();
}

class _CreateCommunityPostViewState extends State<_CreateCommunityPostView> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  String? _tag;

  @override
  void initState() {
    super.initState();
    // Preselect when there is only one choice — a required single-option
    // picker is a step with no decision in it.
    if (widget.community.tags.length == 1) _tag = widget.community.tags.first;
    _titleController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _titleController.removeListener(_onChanged);
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _titleController.text.trim().isNotEmpty && _tag != null;

  Future<void> _publish() async {
    final tag = _tag;
    if (tag == null) return;
    final cubit = context.read<CreateCommunityPostCubit>();
    final created = await cubit.publish(
      slug: widget.community.slug,
      title: _titleController.text,
      tag: tag,
      body: _bodyController.text,
    );
    if (!mounted) return;
    if (created == null) {
      AppStatusSnackbar.showError(
        context,
        message: cubit.state.errorMessage ?? 'Could not publish that.',
      );
      return;
    }
    // Hand the created thread back so the community screen can put it at the
    // top of its list without a refetch.
    context.pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final community = widget.community;

    return BlocBuilder<CreateCommunityPostCubit, CreateCommunityPostState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: colors.bg,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: Row(
                    children: [
                      AppIconButton(
                        icon: const Icon(Icons.close),
                        onPressed: state.isSubmitting ? null : () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'New thread',
                          style: AppTextStyles.titleLg.copyWith(color: colors.ink),
                        ),
                      ),
                      AppButton(
                        label: 'Publish',
                        dense: true,
                        onPressed: (!_canSubmit || state.isSubmitting) ? null : _publish,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: colors.surf2,
                          border: Border.all(color: colors.line, width: 1.5),
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                        ),
                        child: Row(
                          children: [
                            Text(community.emoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                community.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.titleMd.copyWith(color: colors.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text('TITLE', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                      const SizedBox(height: 8),
                      _Field(
                        controller: _titleController,
                        hint: 'What is this about?',
                        maxLength: kCommunityPostTitleMaxChars,
                        autofocus: true,
                      ),
                      const SizedBox(height: 18),
                      Text('TAG', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                      const SizedBox(height: 8),
                      if (community.tags.isEmpty)
                        Text(
                          'This community has no tags set up, so a thread cannot be tagged — '
                          'and the server requires one. Ask a moderator to add tags.',
                          style: AppTextStyles.bodySm.copyWith(color: colors.red),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in community.tags)
                              _TagChoice(
                                tag: tag,
                                selected: _tag == tag,
                                onTap: () => setState(() => _tag = tag),
                              ),
                          ],
                        ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Text('BODY', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                          const SizedBox(width: 8),
                          Text(
                            '(OPTIONAL)',
                            style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _Field(
                        controller: _bodyController,
                        hint: 'Say more, or leave it at the title.',
                        maxLength: kCommunityPostBodyMaxChars,
                        minLines: 6,
                        maxLines: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.minLines = 1,
    this.maxLines = 3,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int minLines;
  final int maxLines;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        minLines: minLines,
        maxLines: maxLines,
        // The same cap the backend enforces, so over-long input is stopped at
        // the keyboard rather than silently truncated on the way out.
        maxLength: maxLength,
        style: AppTextStyles.body.copyWith(color: colors.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.hint.copyWith(color: colors.ink3),
          border: InputBorder.none,
          counterStyle: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3),
        ),
      ),
    );
  }
}

class _TagChoice extends StatelessWidget {
  const _TagChoice({required this.tag, required this.selected, required this.onTap});

  final String tag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: selected ? colors.yel : colors.surf,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        side: BorderSide(color: selected ? colors.ink : colors.line, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            tag.toUpperCase(),
            style: AppTextStyles.metaMono.copyWith(color: selected ? colors.onYel : colors.ink2),
          ),
        ),
      ),
    );
  }
}
