import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/auth_controller.dart';
import '../domain/auth_providers.dart';
import '../domain/auth_user.dart';

/// Which form this screen is showing.
enum AuthFormMode { signIn, signUp, forgotPassword, upgradeGuest }

/// Sign in, sign up, password reset, and guest upgrade.
///
/// One screen rather than four near-identical ones: the fields, the title and
/// the submit action vary, but the layout, validation and error handling are
/// the same, and duplicating them would guarantee they drift.
class AuthFormScreen extends ConsumerStatefulWidget {
  const AuthFormScreen({required this.mode, super.key});

  final AuthFormMode mode;

  @override
  ConsumerState<AuthFormScreen> createState() => _AuthFormScreenState();
}

class _AuthFormScreenState extends ConsumerState<AuthFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  bool get _needsName =>
      widget.mode == AuthFormMode.signUp ||
      widget.mode == AuthFormMode.upgradeGuest;
  bool get _needsPassword => widget.mode != AuthFormMode.forgotPassword;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final controller = ref.read(authControllerProvider.notifier);
    final email = _email.text.trim();

    final ok = switch (widget.mode) {
      AuthFormMode.signIn =>
        await controller.signIn(email: email, password: _password.text),
      AuthFormMode.signUp => await controller.signUp(
          email: email,
          password: _password.text,
          displayName: _name.text,
        ),
      AuthFormMode.forgotPassword => await controller.sendPasswordReset(email),
      AuthFormMode.upgradeGuest => await controller.upgradeGuest(
          method: SignInMethod.password,
          email: email,
          password: _password.text,
          displayName: _name.text,
        ),
    };

    if (!mounted || !ok) return;

    if (widget.mode == AuthFormMode.forgotPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).forgotSent)),
      );
      context.pop();
    }
    // Sign-in and sign-up need no navigation: the auth state change moves the
    // router, so pushing here would fight the redirect.
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(authControllerProvider);
    final appleAvailable =
        ref.watch(appleSignInAvailableProvider).valueOrNull ?? false;

    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage(context, next.failure!))),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _title(l10n),
                      style: AppTypography.headlineLarge
                          .copyWith(color: palette.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _subtitle(l10n),
                      style: AppTypography.bodyMedium
                          .copyWith(color: palette.textSecondary),
                    ),
                    const SizedBox(height: 28),
                    if (_needsName) ...[
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(hintText: l10n.fieldName),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? l10n.validationNameRequired
                                : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: _needsPassword
                          ? TextInputAction.next
                          : TextInputAction.done,
                      autocorrect: false,
                      decoration: InputDecoration(hintText: l10n.fieldEmail),
                      validator: (value) => _validateEmail(value, l10n),
                    ),
                    if (_needsPassword) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: l10n.fieldPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (value) => _validatePassword(value, l10n),
                      ),
                    ],
                    if (widget.mode == AuthFormMode.signIn)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push(Routes.forgotPassword),
                          child: Text(l10n.forgotLink),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xxl),
                    FlameButton(
                      label: _submitLabel(l10n),
                      loading: state.submitting,
                      onPressed: state.submitting ? null : _submit,
                    ),
                    if (widget.mode == AuthFormMode.signIn ||
                        widget.mode == AuthFormMode.signUp) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      _Divider(palette: palette),
                      const SizedBox(height: AppSpacing.xxl),
                      _ProviderButton(
                        label: l10n.continueWithGoogle,
                        icon: Icons.g_mobiledata,
                        enabled: !state.submitting,
                        onPressed: () => ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle(),
                      ),
                      if (appleAvailable) ...[
                        const SizedBox(height: AppSpacing.md),
                        _ProviderButton(
                          label: l10n.continueWithApple,
                          icon: Icons.apple,
                          enabled: !state.submitting,
                          onPressed: () => ref
                              .read(authControllerProvider.notifier)
                              .signInWithApple(),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      TextButton(
                        onPressed: () => context.pushReplacement(
                          widget.mode == AuthFormMode.signIn
                              ? Routes.signUp
                              : Routes.signIn,
                        ),
                        child: Text(
                          widget.mode == AuthFormMode.signIn
                              ? l10n.noAccountYet
                              : l10n.haveAccount,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _title(AppLocalizations l10n) => switch (widget.mode) {
        AuthFormMode.signIn => l10n.signInTitle,
        AuthFormMode.signUp => l10n.signUpTitle,
        AuthFormMode.forgotPassword => l10n.forgotTitle,
        AuthFormMode.upgradeGuest => l10n.upgradeTitle,
      };

  String _subtitle(AppLocalizations l10n) => switch (widget.mode) {
        AuthFormMode.signIn => l10n.signInSubtitle,
        AuthFormMode.signUp => l10n.signUpSubtitle,
        AuthFormMode.forgotPassword => l10n.forgotSubtitle,
        AuthFormMode.upgradeGuest => l10n.upgradeSubtitle,
      };

  String _submitLabel(AppLocalizations l10n) => switch (widget.mode) {
        AuthFormMode.signIn => l10n.continueLabel,
        AuthFormMode.signUp => l10n.signUpTitle,
        AuthFormMode.forgotPassword => l10n.forgotTitle,
        AuthFormMode.upgradeGuest => l10n.upgradeCta,
      };

  String? _validateEmail(String? value, AppLocalizations l10n) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return l10n.authErrorInvalidEmail;
    // Deliberately permissive: the server is the real authority, and a strict
    // client regex rejects valid addresses more often than it catches typos.
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return l10n.authErrorInvalidEmail;
    }
    return null;
  }

  String? _validatePassword(String? value, AppLocalizations l10n) {
    final password = value ?? '';
    if (password.isEmpty) return l10n.authErrorWeakPassword;
    // Firebase's own floor is 6; asking for 8 on sign-up is cheap and stops a
    // class of trivially guessable passwords.
    final floor = widget.mode == AuthFormMode.signIn ? 6 : 8;
    if (password.length < floor) return l10n.validationPasswordShort;
    return null;
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: palette.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            AppLocalizations.of(context).orDivider,
            style: AppTypography.label.copyWith(color: palette.textTertiary),
          ),
        ),
        Expanded(child: Divider(color: palette.divider)),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.enabled,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 22),
        label: Text(label),
      ),
    );
  }
}
