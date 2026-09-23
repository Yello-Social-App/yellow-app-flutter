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
import '../../domain/entities/project_entity.dart';
import '../bloc/publish_project_cubit.dart';

/// Publish a project to the showcase — `POST /projects`.
///
/// There is no description field on purpose: the create contract has none (only
/// name, tagline, emoji, tech, repoUrl, liveUrl), even though the response
/// carries a `description`. Offering the field here would collect text with
/// nowhere to send it.
class PublishProjectPage extends StatelessWidget {
  const PublishProjectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PublishProjectCubit>(),
      child: const _PublishProjectView(),
    );
  }
}

class _PublishProjectView extends StatefulWidget {
  const _PublishProjectView();

  @override
  State<_PublishProjectView> createState() => _PublishProjectViewState();
}

class _PublishProjectViewState extends State<_PublishProjectView> {
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _repoController = TextEditingController();
  final _liveController = TextEditingController();
  final _techController = TextEditingController();

  final List<String> _tech = [];
  String _emoji = kProjectEmojis.first;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onChanged);
    _taglineController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.removeListener(_onChanged);
    _taglineController.removeListener(_onChanged);
    _nameController.dispose();
    _taglineController.dispose();
    _repoController.dispose();
    _liveController.dispose();
    _techController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty && _taglineController.text.trim().isNotEmpty;

  void _addTech() {
    final value = _techController.text.trim();
    if (value.isEmpty) return;
    if (_tech.length >= kProjectTechMaxCount) {
      AppStatusSnackbar.showError(
        context,
        message: 'Up to $kProjectTechMaxCount tech tags.',
      );
      return;
    }
    if (_tech.contains(value)) {
      _techController.clear();
      return;
    }
    setState(() {
      _tech.add(value.length > kProjectTechMaxLength ? value.substring(0, kProjectTechMaxLength) : value);
      _techController.clear();
    });
  }

  Future<void> _publish() async {
    final cubit = context.read<PublishProjectCubit>();
    final created = await cubit.publish(
      name: _nameController.text,
      tagline: _taglineController.text,
      emoji: _emoji,
      tech: _tech,
      repoUrl: _repoController.text,
      liveUrl: _liveController.text,
    );
    if (!mounted) return;
    if (created == null) {
      AppStatusSnackbar.showError(
        context,
        message: cubit.state.errorMessage ?? 'Could not publish that.',
      );
      return;
    }
    context.pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return BlocBuilder<PublishProjectCubit, PublishProjectState>(
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
                          'Publish',
                          style: AppTextStyles.titleLg.copyWith(color: colors.ink),
                        ),
                      ),
                      AppButton(
                        label: 'Ship it',
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
                      Text('ICON', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                      const SizedBox(height: 8),
                      // A closed set server-side, so a picker rather than a text
                      // field — any other emoji is a `400 VALIDATION_FAILED`.
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final emoji in kProjectEmojis)
                            _EmojiChoice(
                              emoji: emoji,
                              selected: _emoji == emoji,
                              onTap: () => setState(() => _emoji = emoji),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text('NAME', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                      const SizedBox(height: 8),
                      _Field(
                        controller: _nameController,
                        hint: 'What is it called?',
                        maxLength: kProjectNameMaxChars,
                      ),
                      const SizedBox(height: 18),
                      Text('TAGLINE', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                      const SizedBox(height: 8),
                      _Field(
                        controller: _taglineController,
                        hint: 'One line on what it does.',
                        maxLength: kProjectTaglineMaxChars,
                        minLines: 2,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Text('TECH', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                          const SizedBox(width: 8),
                          Text(
                            '${_tech.length}/$kProjectTechMaxCount',
                            style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              controller: _techController,
                              hint: 'Flutter, Laravel, Redis…',
                              maxLength: kProjectTechMaxLength,
                              onSubmitted: (_) => _addTech(),
                              showCounter: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppButton(label: 'Add', variant: AppButtonVariant.outline, dense: true, onPressed: _addTech),
                        ],
                      ),
                      if (_tech.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final tech in _tech)
                              _RemovableTag(
                                tech: tech,
                                onRemove: () => setState(() => _tech.remove(tech)),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      Text('REPOSITORY', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                      const SizedBox(height: 8),
                      _Field(
                        controller: _repoController,
                        hint: 'github.com/you/thing',
                        maxLength: kProjectUrlMaxChars,
                        keyboardType: TextInputType.url,
                        showCounter: false,
                      ),
                      const SizedBox(height: 18),
                      Text('LIVE LINK', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                      const SizedBox(height: 8),
                      _Field(
                        controller: _liveController,
                        hint: 'yourthing.app',
                        maxLength: kProjectUrlMaxChars,
                        keyboardType: TextInputType.url,
                        showCounter: false,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'A longer write-up cannot be set here — the publish endpoint takes no '
                        'description field.',
                        style: AppTextStyles.bodySm.copyWith(color: colors.ink3),
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
    this.maxLines = 1,
    this.keyboardType,
    this.onSubmitted,
    this.showCounter = true,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final bool showCounter;

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
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onSubmitted: onSubmitted,
        textInputAction: onSubmitted == null ? TextInputAction.next : TextInputAction.done,
        // The server's own cap, so over-long input stops at the keyboard rather
        // than being silently truncated on the way out.
        maxLength: maxLength,
        style: AppTextStyles.body.copyWith(color: colors.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.hint.copyWith(color: colors.ink3),
          border: InputBorder.none,
          // A 2048-character counter under a URL field is noise.
          counterText: showCounter ? null : '',
          counterStyle: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3),
        ),
      ),
    );
  }
}

class _EmojiChoice extends StatelessWidget {
  const _EmojiChoice({required this.emoji, required this.selected, required this.onTap});

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: selected ? colors.yel : colors.surf,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xs),
        side: BorderSide(color: selected ? colors.ink : colors.line, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xs),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
        ),
      ),
    );
  }
}

class _RemovableTag extends StatelessWidget {
  const _RemovableTag({required this.tech, required this.onRemove});

  final String tech;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: colors.surf2,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: [
          Text(tech, style: AppTextStyles.metaMono.copyWith(color: colors.ink)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: colors.ink3),
          ),
        ],
      ),
    );
  }
}
