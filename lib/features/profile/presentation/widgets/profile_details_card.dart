import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/user_entity.dart';

/// The reference's "Personal details" block, mapped onto the fields this
/// backend actually has on `UserResponse` — name, username, join date, and
/// (once expanded) email, bio and account status. There is no place/work/
/// school data in the API, so those rows have no Yello equivalent.
///
/// [expanded] is driven by the chevron beside the name in `ProfileHeader`.
class ProfileDetailsCard extends StatelessWidget {
  const ProfileDetailsCard({super.key, required this.user, required this.expanded, required this.onEdit});

  final UserEntity user;
  final bool expanded;
  final VoidCallback onEdit;

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final createdAt = user.createdAt;
    final fullName = user.fullName?.trim() ?? '';
    final bio = user.bio?.trim() ?? '';

    final rows = <Widget>[
      _DetailRow(
        icon: Icons.person_outline_rounded,
        value: fullName.isEmpty ? 'Add your name' : fullName,
        muted: fullName.isEmpty,
      ),
      _DetailRow(icon: Icons.alternate_email_rounded, value: user.username),
      _DetailRow(
        icon: Icons.cake_outlined,
        value: 'Joined ${_months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}',
      ),
      if (expanded) ...[
        _DetailRow(icon: Icons.mail_outline_rounded, value: user.email),
        _DetailRow(
          icon: Icons.format_quote_rounded,
          value: bio.isEmpty ? 'Add a bio' : bio,
          muted: bio.isEmpty,
        ),
        _DetailRow(
          icon: Icons.verified_user_outlined,
          value: 'Account ${user.status.toLowerCase()}',
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('PERSONAL DETAILS', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
            const Spacer(),
            Material(
              color: colors.surf2,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onEdit,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(Icons.edit_outlined, size: 16, color: colors.ink2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surf,
            border: Border.all(color: colors.line, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            // Static decoration on a plain DecoratedBox — the sanctioned
            // shape for card depth (ADR-012). It rebuilds with the page, not
            // per animation frame, which is the line `docs/GOTCHAS.md` draws.
            boxShadow: AppShadows.card(context),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: colors.line2),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.value, this.muted = false});

  final IconData icon;
  final String value;

  /// A placeholder rather than real data ("Add a bio") — rendered in [ink3]
  /// so an empty field doesn't read as content.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.surf2, borderRadius: BorderRadius.circular(AppRadii.xs)),
            child: Icon(icon, size: 17, color: colors.ink2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMd.copyWith(color: muted ? colors.ink3 : colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
