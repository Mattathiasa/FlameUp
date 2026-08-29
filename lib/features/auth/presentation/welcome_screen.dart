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

/// 02-welcome.
///
/// A full-bleed warm gradient fading into the screen colour, with the headline
/// and both calls to action anchored to the bottom.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage(context, next.failure!))),
        );
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // linear-gradient(165deg, #8E1B0F 0%, #E0522A 52%, #F0B33C 100%)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 560,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-0.26, -1),
                  end: Alignment(0.26, 1),
                  colors: [
                    Color(0xFF8E1B0F),
                    Color(0xFFE0522A),
                    Color(0xFFF0B33C),
                  ],
                  stops: [0, 0.52, 1],
                ),
              ),
              child: Stack(
                children: [
                  // The highlight sweeping the top left.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-0.56, -0.84),
                        radius: 1.1,
                        colors: [Color(0x4DFFFFFF), Color(0x00FFFFFF)],
                        stops: [0, 0.58],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                  // Fades into the screen colour so the copy sits on solid ground.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, palette.surface],
                        stops: const [0.34, 0.96],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 46),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Text(
                    l10n.welcomeH1,
                    style: AppTypography.displayLarge
                        .copyWith(color: palette.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      l10n.welcomeSub,
                      style: AppTypography.bodyLarge
                          .copyWith(color: palette.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FlameButton(
                    label: l10n.getStarted,
                    loading: auth.submitting,
                    onPressed: auth.submitting
                        ? null
                        : () => ref
                            .read(authControllerProvider.notifier)
                            .continueAsGuest(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: auth.submitting
                          ? null
                          : () => context.push(Routes.signIn),
                      child: Text(l10n.haveAccount),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
