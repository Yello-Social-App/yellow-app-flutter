import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../auth/presentation/widgets/toggle_switch.dart';
import '../../domain/entities/notification_entity.dart';
import '../bloc/notification_preferences_cubit.dart';

/// Human label for each wire [NotificationType] — used only by this screen;
/// the inbox itself never renders a type-derived sentence anymore (see
/// `NotificationEntity`'s doc on `title`/`body`).
String _labelFor(String type) => switch (type) {
  NotificationTypes.postCreated => 'New posts from friends',
  NotificationTypes.postCommented => 'Comments on your posts',
  NotificationTypes.commentReplied => 'Replies to your comments',
  NotificationTypes.postReposted => 'Reposts of your posts',
  NotificationTypes.postReacted => 'Reactions to your posts',
  NotificationTypes.commentReacted => 'Reactions to your comments',
  NotificationTypes.friendRequestReceived => 'Friend requests',
  NotificationTypes.friendRequestAccepted => 'Accepted friend requests',
  NotificationTypes.chatMessage => 'Chat messages',
  _ => type,
};

class NotificationPreferencesPage extends StatelessWidget {
  const NotificationPreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<NotificationPreferencesCubit>()..load(),
      child: const _PreferencesView(),
    );
  }
}

class _PreferencesView extends StatelessWidget {
  const _PreferencesView();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<NotificationPreferencesCubit>();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: BlocBuilder<NotificationPreferencesCubit, NotificationPreferencesState>(
          builder: (context, state) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                Row(
                  children: [
                    AppIconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
                    const SizedBox(width: 12),
                    Text('Notifications', style: AppTextStyles.titleLg.copyWith(color: colors.ink)),
                  ],
                ),
                const SizedBox(height: 20),
                if (state.status == PreferencesStatus.loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.status == PreferencesStatus.error)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: ErrorView(message: state.errorMessage ?? 'Could not load your settings.', onRetry: cubit.load),
                  )
                else ...[
                  _SettingsCard(
                    child: _ToggleRow(
                      label: 'Push notifications',
                      subtitle: 'Turn every push off at once, without changing what lands in your inbox.',
                      value: state.preferences.pushEnabled,
                      busy: state.savingKey == 'push',
                      onChanged: cubit.setPushEnabled,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('MUTE PUSH FOR', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                  const SizedBox(height: 4),
                  Text(
                    "Muted types still show up in your inbox — this only stops the phone buzzing.",
                    style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                  ),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    child: Column(
                      children: [
                        for (final type in NotificationTypes.all)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: _ToggleRow(
                              label: _labelFor(type),
                              // Muted = switch OFF ("notify me" reads more
                              // naturally as the on-state than "muted").
                              value: !state.preferences.mutedTypes.contains(type),
                              busy: state.savingKey == type,
                              disabled: !state.preferences.pushEnabled,
                              onChanged: (_) => cubit.toggleMuted(type),
                            ),
                          ),
                      ],
                    ),
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});
  final Widget child;

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
      child: child,
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.busy = false,
    this.disabled = false,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool busy;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySm.copyWith(color: disabled ? colors.ink3 : colors.ink, fontWeight: FontWeight.w600),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: AppTextStyles.metaMono.copyWith(color: colors.ink2, fontSize: 9.5)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (busy)
          const SizedBox(width: 38, height: 22, child: Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))))
        else
          Opacity(
            opacity: disabled ? 0.4 : 1,
            child: IgnorePointer(
              ignoring: disabled,
              child: ToggleSwitch(value: value, onChanged: onChanged),
            ),
          ),
      ],
    );
  }
}
