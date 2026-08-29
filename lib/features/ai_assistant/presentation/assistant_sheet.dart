import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/assistant_service.dart';
import '../domain/assistant_message.dart';

/// The cooking assistant, as a sheet over cook mode.
///
/// A sheet rather than a screen: questions come up mid-cook, and losing the
/// step you were on to ask one would be a poor trade.
class AssistantSheet extends ConsumerStatefulWidget {
  const AssistantSheet({this.recipeId, this.stepIndex, super.key});

  final String? recipeId;
  final int? stepIndex;

  static Future<void> show(
    BuildContext context, {
    String? recipeId,
    int? stepIndex,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) =>
            AssistantSheet(recipeId: recipeId, stepIndex: stepIndex),
      );

  @override
  ConsumerState<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends ConsumerState<AssistantSheet> {
  final _input = TextEditingController();
  final _messages = <AssistantMessage>[];
  bool _asking = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _input.text.trim();
    if (question.isEmpty || _asking) return;

    setState(() {
      _messages.add(AssistantMessage.user(question));
      _asking = true;
    });
    _input.clear();

    final result = await ref.read(assistantServiceProvider).ask(
          question: question,
          recipeId: widget.recipeId,
          stepIndex: widget.stepIndex,
        );

    if (!mounted) return;

    setState(() {
      _asking = false;
      _messages.add(
        result.fold(
          (message) => message,
          (failure) => AssistantMessage.error(
            failureMessage(context, failure),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                const FlameIcon(size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.appName,
                    style: AppTypography.titleMedium
                        .copyWith(color: palette.textPrimary),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxxl),
                      child: Text(
                        l10n.assistantHint,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium
                            .copyWith(color: palette.textSecondary),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.gutter,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _Bubble(message: _messages[index], l10n: l10n),
                  ),
          ),
          if (_asking)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
            ),
            child: TextField(
              controller: _input,
              enabled: !_asking,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _ask(),
              decoration: InputDecoration(
                hintText: l10n.assistantPlaceholder,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _asking ? null : _ask,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.l10n});

  final AssistantMessage message;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (message.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          decoration: const BoxDecoration(
            color: AppColors.accent,
            borderRadius: AppRadii.lgAll,
          ),
          child: Text(
            message.text,
            style: AppTypography.bodyMedium.copyWith(color: Colors.white),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final claim in message.claims)
            _ClaimBlock(claim: claim, l10n: l10n, failed: message.failed),
        ],
      ),
    );
  }
}

/// One claim, visually separated by what kind of statement it is.
///
/// A suggestion must not look like an instruction, and neither must look like
/// a statement about culture — that separation is the feature's whole reason
/// for being labelled.
class _ClaimBlock extends StatelessWidget {
  const _ClaimBlock({
    required this.claim,
    required this.l10n,
    required this.failed,
  });

  final Claim claim;
  final AppLocalizations l10n;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final (label, tint) = switch (claim.kind) {
      ClaimKind.recipe => (l10n.claimRecipe, AppColors.accent),
      ClaimKind.tradition => (l10n.claimTradition, AppColors.green),
      ClaimKind.suggestion => (l10n.claimSuggestion, AppColors.gold),
      ClaimKind.plain => (null, palette.textTertiary),
    };

    return GlassPanel(
      blur: false,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Eyebrow(label, color: tint),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            claim.text,
            style: AppTypography.bodyMedium.copyWith(
              color: failed ? palette.textTertiary : palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
