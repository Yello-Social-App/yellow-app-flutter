import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../bloc/auth_cubit.dart';
import '../widgets/auth_form_field.dart';
import '../widgets/auth_hero.dart';
import '../widgets/otp_code_field.dart';
import '../widgets/toggle_switch.dart';

/// Sign-up screen, in the same illustrated-hero layout as `login_page.dart`
/// (see `AuthHero`, `AuthFormField`) — the reference "Insightlancer" mock
/// redrawn in Yello's own palette/typography.
///
/// Only collects what the live `RegisterRequest` actually accepts — email,
/// username, password, full name (see `AuthRemoteDataSourceImpl.register`).
/// The reference form asks for a username + mobile number instead; ours
/// swaps in email (a mobile-number field would just be dead UI, since
/// nothing on the backend reads it) and keeps full name + a confirm-
/// password check for basic account-recovery/typo safety.
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthCubit>(),
      child: const _RegisterView(),
    );
  }
}

class _RegisterView extends StatefulWidget {
  const _RegisterView();

  @override
  State<_RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<_RegisterView> {
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: BlocListener<AuthCubit, AuthState>(
        listenWhen: (prev, curr) =>
            curr.status == AuthStatus.success ||
            curr.status == AuthStatus.failure,
        listener: (context, state) {
          if (state.status == AuthStatus.success) {
            context.goNamed(RouteNames.feed);
          } else if (state.errorMessage != null) {
            AppStatusSnackbar.showError(context, message: state.errorMessage!);
          }
        },
        child: SafeArea(
          bottom: false,
          child: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 32),
                child: state.status == AuthStatus.awaitingOtp
                    ? _OtpCard(
                        controller: _otpController,
                        email: state.pendingEmail ?? '',
                      )
                    : const _DetailsCard(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatefulWidget {
  const _DetailsCard();

  @override
  State<_DetailsCard> createState() => _DetailsCardState();
}

class _DetailsCardState extends State<_DetailsCard> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _usernameRe = RegExp(r'^[a-zA-Z0-9_.]{3,32}$');
  static const _minPasswordLength = 12;

  bool _obscurePassword = true;
  bool _usernameTouched = false;
  bool _passwordTouched = false;
  bool _confirmTouched = false;
  bool _rememberMe = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _emailLooksValid => _emailRe.hasMatch(_emailController.text.trim());
  bool get _usernameLooksValid =>
      _usernameRe.hasMatch(_usernameController.text.trim());
  bool get _passwordLooksValid =>
      _passwordController.text.length >= _minPasswordLength;
  bool get _confirmMismatch =>
      _confirmTouched &&
      _confirmPasswordController.text != _passwordController.text;

  bool get _canSubmit =>
      _fullNameController.text.trim().isNotEmpty &&
      _usernameLooksValid &&
      _emailLooksValid &&
      _passwordLooksValid &&
      _confirmPasswordController.text == _passwordController.text;

  void _submit(BuildContext context) {
    setState(() {
      _usernameTouched = true;
      _passwordTouched = true;
      _confirmTouched = true;
    });
    if (!_canSubmit) return;
    context.read<AuthCubit>().register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      username: _usernameController.text.trim(),
      fullName: _fullNameController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthHero(
          icon: Icons.person_add_alt_1,
          badgeA: Icons.celebration_outlined,
          badgeB: Icons.badge_outlined,
          filled: false,
          leading: _BackButton(onTap: () => Navigator.of(context).maybePop()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Register',
                style: AppTextStyles.displayXl.copyWith(
                  color: colors.ink,
                  fontSize: 36,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create your premium sanctuary.',
                style: AppTextStyles.bodyMd.copyWith(
                  color: colors.ink2,
                ),
              ),
              const SizedBox(height: 28),
              AuthFormField(
                label: 'Full name',
                controller: _fullNameController,
                textInputAction: TextInputAction.next,
                leadingIcon: Icons.badge_outlined,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              AuthFormField(
                label: 'Username',
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                leadingIcon: Icons.alternate_email,
                onChanged: (_) => setState(() {}),
                borderColor:
                    !_usernameTouched || _usernameController.text.isEmpty
                    ? null
                    : (_usernameLooksValid ? colors.grn : colors.red),
                helperText:
                    _usernameTouched &&
                        _usernameController.text.isNotEmpty &&
                        !_usernameLooksValid
                    ? '3-32 characters: letters, numbers, "_" or "."'
                    : null,
                helperColor: colors.red,
              ),
              const SizedBox(height: 14),
              AuthFormField(
                label: 'Email address',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                leadingIcon: Icons.mail_outline,
                onChanged: (_) => setState(() {}),
                borderColor: _emailController.text.isEmpty
                    ? null
                    : (_emailLooksValid ? colors.grn : null),
                trailing: _emailController.text.isNotEmpty && _emailLooksValid
                    ? Icon(Icons.check_circle, size: 19, color: colors.grn)
                    : null,
              ),
              const SizedBox(height: 14),
              AuthFormField(
                label: 'Password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                leadingIcon: Icons.lock_outline,
                onChanged: (_) => setState(() => _passwordTouched = true),
                borderColor:
                    _passwordTouched &&
                        _passwordController.text.isNotEmpty &&
                        !_passwordLooksValid
                    ? colors.red
                    : null,
                helperText:
                    _passwordTouched &&
                        _passwordController.text.isNotEmpty &&
                        !_passwordLooksValid
                    ? '- At least One UPPERCASE letters, \n- $_minPasswordLength characters with numbers and Symbols\n  (@,#,\$,%,^,&,*).\n- Example: Password123@'
                    : null,
                helperColor: colors.red,
                trailing: GestureDetector(
                  onTap: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                    color: colors.ink3,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AuthFormField(
                label: 'Confirm password',
                controller: _confirmPasswordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(context),
                leadingIcon: Icons.lock_outline,
                onChanged: (_) => setState(() => _confirmTouched = true),
                borderColor: _confirmMismatch ? colors.red : null,
                helperText: _confirmMismatch ? 'Passwords do not match.' : null,
                helperColor: colors.red,
                trailing: _confirmMismatch
                    ? Icon(Icons.error, size: 19, color: colors.red)
                    : null,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ToggleSwitch(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Reminder me next time',
                      style: AppTextStyles.bodySm.copyWith(
                        color: colors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) {
                  return AppButton(
                    label: state.isSubmitting ? 'Creating account…' : 'Sign Up',
                    fullWidth: true,
                    onPressed: state.isSubmitting
                        ? null
                        : () => _submit(context),
                  );
                },
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: AppTextStyles.bodySm.copyWith(
                      color: colors.ink2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      child: Text(
                        'Sign In',
                        style: AppTextStyles.buttonLg.copyWith(
                          color: colors.yeld,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OtpCard extends StatelessWidget {
  const _OtpCard({required this.controller, required this.email});
  final TextEditingController controller;
  final String email;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return BlocListener<AuthCubit, AuthState>(
      // Scoped to this step only — [resendOtp] deliberately never touches
      // `status`, so this never fires the outer `_RegisterView` listener's
      // success/failure handling (see `AuthState.infoMessage`'s doc).
      listenWhen: (prev, curr) =>
          curr.status == AuthStatus.awaitingOtp &&
          (curr.infoMessage != prev.infoMessage ||
              curr.errorMessage != prev.errorMessage),
      listener: (context, state) {
        if (state.infoMessage != null) {
          AppStatusSnackbar.showSuccess(context, message: state.infoMessage!);
        } else if (state.errorMessage != null) {
          AppStatusSnackbar.showError(context, message: state.errorMessage!);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHero(
            icon: Icons.password_outlined,
            badgeA: Icons.mail_outline,
            badgeB: Icons.badge_outlined,
            filled: false,
            leading: _BackButton(
              onTap: () => context.read<AuthCubit>().reset(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Check your email',
                  style: AppTextStyles.displayXl.copyWith(
                    color: colors.ink,
                    fontSize: 32,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter the 6-digit code we sent to $email.',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: colors.ink2,
                  ),
                ),
                const SizedBox(height: 28),
                OtpCodeField(
                  controller: controller,
                  onCompleted: (code) =>
                      context.read<AuthCubit>().verifyOtp(code),
                ),
                const SizedBox(height: 24),
                BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, state) {
                    return AppButton(
                      label: state.isSubmitting
                          ? 'Verifying…'
                          : 'Verify & continue',
                      fullWidth: true,
                      onPressed: state.isSubmitting
                          ? null
                          : () => context.read<AuthCubit>().verifyOtp(
                              controller.text,
                            ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, state) {
                    return Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: state.isProcessing
                            ? null
                            : () => context.read<AuthCubit>().resendOtp(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 4,
                          ),
                          child: Text(
                            state.isProcessing
                                ? 'Resending…'
                                : "Didn't get a code? Resend",
                            style: AppTextStyles.buttonLg.copyWith(
                              color: colors.yeld,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.surf,
      shape: CircleBorder(side: BorderSide(color: colors.line, width: 1.5)),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.arrow_back, size: 18, color: colors.ink),
        ),
      ),
    );
  }
}
