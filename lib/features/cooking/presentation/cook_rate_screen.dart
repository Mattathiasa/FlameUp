import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/domain/auth_providers.dart';
import '../../recipes/data/review_repository.dart';
import '../../recipes/domain/review.dart';
import '../data/cooking_repository.dart';

/// 10-rate — rating a dish after cooking it.
///
/// Only reachable from a completed session, and the review carries that
/// session id: the server requires it, which is how "you can only rate what
/// you actually cooked" is enforced rather than merely encouraged.
class CookRateScreen extends ConsumerStatefulWidget {
  const CookRateScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<CookRateScreen> createState() => _CookRateScreenState();
}

class _CookRateScreenState extends ConsumerState<CookRateScreen> {
  final _note = TextEditingController();
  int _taste = 4;
  bool _share = false;
  bool _submitting = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = ref.read(cookingRepositoryProvider).byId(widget.sessionId);
    final uid = ref.read(currentUidProvider);
    if (session == null || uid == null) return;

    setState(() => _submitting = true);

    final review = Review(
      recipeId: session.recipeId,
      sessionId: session.id,
      uid: uid,
      taste: _taste,
      body: _note.text,
      shareToCommunity: _share,
    );

    // Queued, not awaited against the network: a rating left with no signal
    // still counts, and replays with the session's key so it cannot double.
    final result = await ref.read(reviewRepositoryProvider).submit(review);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.isErr) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage(context, result.failureOrNull!))),
      );
      return;
    }
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    final words = [l10n.r1, l10n.r2, l10n.r3, l10n.r4, l10n.r5];

    return Scaffold(
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => context.go(Routes.home),
                    icon: const Icon(Icons.close),
                    tooltip: l10n.skip,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.rateH1,
                          style: AppTypography.headlineLarge
                              .copyWith(color: palette.textPrimary),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.rateSub,
                          style: AppTypography.bodyMedium
                              .copyWith(color: palette.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                        Semantics(
                          label: 'Rating',
                          value: words[_taste - 1],
                          slider: true,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (var n = 1; n <= 5; n++)
                                GestureDetector(
                                  onTap: () => setState(() => _taste = n),
                                  behavior: HitTestBehavior.opaque,
                                  child: ExcludeSemantics(
                                    child: SizedBox(
                                      width: 52,
                                      height: AppTouch.minTarget,
                                      child: Center(
                                        child: AnimatedScale(
                                          duration: AppMotion.fast,
                                          scale: n == _taste ? 1.2 : 1,
                                          child: FlameIcon(
                                            size: 32,
                                            color: n <= _taste
                                                ? AppColors.accent
                                                : palette.textTertiary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Center(
                          child: Text(
                            words[_taste - 1],
                            style: AppTypography.titleLarge
                                .copyWith(color: palette.textPrimary),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                        TextField(
                          controller: _note,
                          maxLines: 4,
                          maxLength: 500,
                          decoration: InputDecoration(hintText: l10n.noteP),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        GlassPanel(
                          blur: false,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.xs,
                          ),
                          child: SwitchListTile(
                            value: _share,
                            onChanged: (value) =>
                                setState(() => _share = value),
                            title: Text(
                              l10n.postToComm,
                              style: AppTypography.bodyMedium
                                  .copyWith(color: palette.textPrimary),
                            ),
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: FlameButton(
                    label: l10n.submit,
                    loading: _submitting,
                    onPressed: _submitting ? null : _submit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
