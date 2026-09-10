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
import '../widgets/toggle_switch.dart';

/// Sign-in screen: illustrated hero header, big left-aligned "Login"
/// heading, icon-prefixed pill fields, a remember-me toggle + forgot-
/// password row, and the primary Sign In button — the layout of the
/// reference "Insightlancer" login/register mock, redrawn in Yello's own
/// palette/typography (see `AuthHero`, `AuthFormField`, `ToggleSwitch`).
/// Google/Apple "continue" buttons stay below as a bonus block (visual
/// only — no social-login endpoint exists, tapping shows a "not available
/// yet" snackbar).
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => sl<AuthCubit>(), child: const _LoginView());
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _emailController.text.trim().isNotEmpty && _passwordController.text.isNotEmpty;

  void _submit(BuildContext context) {
    if (!_canSubmit) return;
    context.read<AuthCubit>().login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );
  }

  void _notAvailable(BuildContext context, String provider) {
    AppStatusSnackbar.showError(context, message: '$provider sign-in isn\'t available yet.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: BlocListener<AuthCubit, AuthState>(
        listenWhen: (prev, curr) => curr.status == AuthStatus.success || curr.status == AuthStatus.failure,
        listener: (context, state) {
          if (state.status == AuthStatus.success) {
            context.goNamed(RouteNames.feed);
          } else if (state.errorMessage != null) {
            AppStatusSnackbar.showError(context, message: state.errorMessage!);
          }
        },
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthHero(
                  icon: Icons.mark_email_read_outlined,
                  badgeA: Icons.mail_outline,
                  badgeB: Icons.eco_outlined,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Login', style: AppTextStyles.displayXl.copyWith(color: colors.ink, fontSize: 36)),
                      const SizedBox(height: 6),
                      Text(
                        'Please sign in to continue.',
                        style: AppTextStyles.bodySm.copyWith(color: colors.ink2, fontSize: 14),
                      ),
                      const SizedBox(height: 28),
                      AuthFormField(
                        label: 'Email address',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        leadingIcon: Icons.mail_outline,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),
                      AuthFormField(
                        label: 'Password',
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(context),
                        leadingIcon: Icons.lock_outline,
                        onChanged: (_) => setState(() {}),
                        trailing: GestureDetector(
                          onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                          child: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 19,
                            color: colors.ink3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _rememberMe = !_rememberMe),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ToggleSwitch(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v)),
                                const SizedBox(width: 10),
                                Text(
                                  'Remember me next time',
                                  style: AppTextStyles.bodySm.copyWith(fontSize: 13, color: colors.ink2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => _showForgotPasswordSheet(context),
                          child: Text(
                            'Forgot password?',
                            style: AppTextStyles.metaMono.copyWith(color: colors.yeld, fontSize: 11),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      BlocBuilder<AuthCubit, AuthState>(
                        builder: (context, state) {
                          return AppButton(
                            label: state.isSubmitting ? 'Signing in…' : 'Sign In',
                            fullWidth: true,
                            onPressed: state.isSubmitting || !_canSubmit ? null : () => _submit(context),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: AppTextStyles.bodySm.copyWith(color: colors.ink2, fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => context.pushNamed(RouteNames.register),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                              child: Text(
                                'Sign Up',
                                style: AppTextStyles.button.copyWith(color: colors.yeld, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Expanded(child: Container(height: 1, color: colors.line)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('OR', style: AppTextStyles.metaMono.copyWith(color: colors.ink3)),
                          ),
                          Expanded(child: Container(height: 1, color: colors.line)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SocialButton(
                        label: 'Continue with Google',
                        icon: _googleIcon(),
                        onTap: () => _notAvailable(context, 'Google'),
                      ),
                      const SizedBox(height: 10),
                      _SocialButton(
                        label: 'Continue with Apple',
                        icon: Icon(Icons.apple, size: 20, color: colors.ink),
                        onTap: () => _notAvailable(context, 'Apple'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _googleIcon() {
    return SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GoogleGPainter()));
  }

  void _showForgotPasswordSheet(BuildContext context) {
    final controller = TextEditingController();
    final cubit = context.read<AuthCubit>();
    final colors = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      // Same root-navigator fix as `post_options_sheet.dart`'s
      // `showPostOptionsSheet` (no nav bar on this screen to sit behind, but
      // kept consistent with every other sheet in the app rather than
      // leaving this one call site behaving subtly differently).
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: colors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: BlocProvider.value(
            value: cubit,
            child: BlocConsumer<AuthCubit, AuthState>(
              listener: (context, state) {
                if (state.status == AuthStatus.resetEmailSent) {
                  Navigator.of(sheetContext).pop();
                  AppStatusSnackbar.showSuccess(this.context, message: 'Check your email for a reset link.');
                }
              },
              builder: (context, state) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Reset your password', style: AppTextStyles.titleLg.copyWith(color: colors.ink)),
                    const SizedBox(height: 16),
                    AuthFormField(
                      label: 'Email',
                      controller: controller,
                      keyboardType: TextInputType.emailAddress,
                      leadingIcon: Icons.mail_outline,
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: state.isSubmitting ? 'Sending…' : 'Send reset link',
                      fullWidth: true,
                      onPressed: state.isSubmitting ? null : () => cubit.forgotPassword(controller.text),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: colors.line, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 10),
              Text(label, style: AppTextStyles.button.copyWith(color: colors.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal 4-color "G" mark drawn in code — avoids bundling an SVG/image
/// asset just for one icon.
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final strokeWidth = radius * 0.42;

    void arc(double startDeg, double sweepDeg, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        startDeg * 3.1415926535 / 180,
        sweepDeg * 3.1415926535 / 180,
        false,
        paint,
      );
    }

    arc(-90, 90, const Color(0xFF4285F4));
    arc(0, 90, const Color(0xFF34A853));
    arc(90, 90, const Color(0xFFFBBC05));
    arc(180, 90, const Color(0xFFEA4335));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
