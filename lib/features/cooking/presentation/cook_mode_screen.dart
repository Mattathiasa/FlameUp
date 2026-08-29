import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/domain/recipe_providers.dart';
import '../domain/cooking_controller.dart';
import '../domain/cooking_session.dart';

/// 08-cook — cook mode.
///
/// Full screen, no tab bar, and it keeps the display awake while a timer runs.
class CookModeScreen extends ConsumerWidget {
  const CookModeScreen({required this.recipeId, super.key});

  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeProvider(recipeId));

    return recipe.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: ErrorView(
          failure: error is Failure ? error : const UnknownFailure(),
          onRetry: () => ref.invalidate(recipeProvider(recipeId)),
        ),
      ),
      data: (cached) => _CookMode(recipe: cached.value),
    );
  }
}

class _CookMode extends ConsumerStatefulWidget {
  const _CookMode({required this.recipe});

  final Recipe recipe;

  @override
  ConsumerState<_CookMode> createState() => _CookModeState();
}

class _CookModeState extends ConsumerState<_CookMode> {
  @override
  void initState() {
    super.initState();
    // Start or resume once the first frame is up, so the provider is not
    // mutated during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cookingControllerProvider.notifier).start(widget.recipe);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final amharic = ref.watch(isAmharicProvider);
    final session = ref.watch(cookingControllerProvider);
    final controller = ref.read(cookingControllerProvider.notifier);

    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final step = widget.recipe.steps[session.currentStep];
    final remaining = session.remainingFor(session.currentStep);
    final expired = session.hasExpiredTimer(session.currentStep);
    final paused = session.isTimerPaused(session.currentStep);

    return PopScope(
      // Backing out of a cook by accident would lose the thread of what you
      // were doing, so leaving is always deliberate.
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final leave = await _confirmExit(context, l10n);
        if (leave == true && context.mounted) context.pop();
      },
      child: Scaffold(
        body: Stack(
          children: [
            const AmbientBackground(),
            SafeArea(
              child: Column(
                children: [
                  _Header(
                    recipe: widget.recipe,
                    session: session,
                    amharic: amharic,
                    l10n: l10n,
                    onExit: () async {
                      final leave = await _confirmExit(context, l10n);
                      if (leave == true && context.mounted) context.pop();
                    },
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: AppSpacing.xxl),
                          if (step.hasTimer)
                            _Timer(
                              remaining: remaining,
                              total: step.duration!,
                              expired: expired,
                              paused: paused,
                              palette: palette,
                            ),
                          const SizedBox(height: AppSpacing.xxxl),
                          Text(
                            step.localisedText(amharic: amharic),
                            textAlign: TextAlign.center,
                            style: AppTypography.headlineMedium
                                .copyWith(color: palette.textPrimary),
                          ),
                          if (step.localisedTip(amharic: amharic) != null) ...[
                            const SizedBox(height: AppSpacing.xl),
                            GlassPanel(
                              blur: false,
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Text(
                                step.localisedTip(amharic: amharic)!,
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMedium
                                    .copyWith(color: AppColors.accent),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xxxl),
                        ],
                      ),
                    ),
                  ),
                  _Controls(
                    recipe: widget.recipe,
                    session: session,
                    controller: controller,
                    step: step,
                    paused: paused,
                    l10n: l10n,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmExit(BuildContext context, AppLocalizations l10n) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pause),
        content: Text(l10n.doneSub),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.back),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.recipe,
    required this.session,
    required this.amharic,
    required this.l10n,
    required this.onExit,
  });

  final Recipe recipe;
  final CookingSession session;
  final bool amharic;
  final AppLocalizations l10n;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onExit,
                icon: const Icon(Icons.close),
                tooltip: l10n.back,
              ),
              Expanded(
                child: Text(
                  recipe.localisedTitle(amharic: amharic),
                  textAlign: TextAlign.center,
                  style: AppTypography.titleSmall
                      .copyWith(color: palette.textSecondary),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${l10n.stepOf} ${session.currentStep + 1} '
            '${l10n.ofWord} ${session.totalSteps}',
            style: AppTypography.eyebrow.copyWith(color: palette.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
          FlameProgressBar(value: session.progress, animate: false),
        ],
      ),
    );
  }
}

/// The 54px hairline countdown — the visual centre of the screen.
class _Timer extends StatelessWidget {
  const _Timer({
    required this.remaining,
    required this.total,
    required this.expired,
    required this.paused,
    required this.palette,
  });

  final Duration remaining;
  final Duration total;
  final bool expired;
  final bool paused;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final progress = total.inSeconds == 0
        ? 0.0
        : 1 - (remaining.inSeconds / total.inSeconds);

    return Semantics(
      liveRegion: true,
      label: expired
          ? 'Timer finished'
          : '$minutes minutes $seconds seconds remaining',
      excludeSemantics: true,
      child: RingProgress(
        value: progress.clamp(0.0, 1.0),
        size: 220,
        strokeWidth: 6,
        color: expired ? AppColors.green : AppColors.accent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$minutes:${seconds.toString().padLeft(2, '0')}',
              // Weight 200, tabular figures -- the digits must not jitter as
              // they change.
              style: AppTypography.timer.copyWith(
                color: expired ? AppColors.green : palette.textPrimary,
              ),
            ),
            if (paused)
              Text(
                'paused',
                style:
                    AppTypography.label.copyWith(color: palette.textTertiary),
              ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.recipe,
    required this.session,
    required this.controller,
    required this.step,
    required this.paused,
    required this.l10n,
  });

  final Recipe recipe;
  final CookingSession session;
  final CookingController controller;
  final RecipeStep step;
  final bool paused;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          if (step.hasTimer)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed:
                      paused ? controller.resumeTimer : controller.pauseTimer,
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                  label: Text(paused ? l10n.resume : l10n.pause),
                ),
                const SizedBox(width: AppSpacing.xl),
                TextButton.icon(
                  onPressed: () => controller.restartTimer(recipe),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retry),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (session.currentStep > 0) ...[
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () => controller.previousStep(recipe),
                    child: const Icon(Icons.arrow_back),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: FlameButton(
                  label: session.isOnLastStep ? l10n.finish : l10n.nextStep,
                  onPressed: () async {
                    if (session.isOnLastStep) {
                      final done = await controller.finish();
                      if (done != null && context.mounted) {
                        context.pushReplacement(Routes.cookDoneOf(done.id));
                      }
                    } else {
                      await controller.nextStep(recipe);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
