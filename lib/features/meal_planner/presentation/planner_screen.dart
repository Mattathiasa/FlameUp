import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../recipes/data/recipe_seed_source.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/domain/recipe_providers.dart';
import '../domain/meal_plan.dart';
import '../domain/planner_controller.dart';

/// 26-planner — the weekly meal plan.
class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  static const List<String> _weekdaysEn = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<String> _weekdaysAm = [
    'ሰኞ',
    'ማክሰኞ',
    'ረቡዕ',
    'ሐሙስ',
    'ዓርብ',
    'ቅዳሜ',
    'እሁድ',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final amharic = ref.watch(isAmharicProvider);
    final plan = ref.watch(plannerControllerProvider);
    final controller = ref.read(plannerControllerProvider.notifier);
    final today = DateTime.now().weekday;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.planH1)),
      body: Stack(
        children: [
          const AmbientBackground(),
          FutureBuilder(
            future: ref.watch(recipeSeedSourceProvider).load(),
            builder: (context, snapshot) {
              final catalogue = snapshot.data;
              if (catalogue == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final byId = {for (final r in catalogue) r.id: r};

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.md,
                  AppSpacing.gutter,
                  AppSpacing.screenBottom,
                ),
                children: [
                  Text(
                    l10n.planSub,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppPalette.of(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  for (var weekday = 1; weekday <= 7; weekday++)
                    _DayCard(
                      label: amharic
                          ? _weekdaysAm[weekday - 1]
                          : _weekdaysEn[weekday - 1],
                      isToday: weekday == today,
                      weekday: weekday,
                      plan: plan,
                      catalogue: catalogue,
                      byId: byId,
                      amharic: amharic,
                      l10n: l10n,
                      onSet: controller.setMeal,
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  if (!plan.isEmpty)
                    FlameButton(
                      label: l10n.generateList,
                      onPressed: () async {
                        final added = await controller.buildShoppingList();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              added == 0 ? l10n.plannerEmpty : l10n.addedToList,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.label,
    required this.isToday,
    required this.weekday,
    required this.plan,
    required this.catalogue,
    required this.byId,
    required this.amharic,
    required this.l10n,
    required this.onSet,
  });

  final String label;
  final bool isToday;
  final int weekday;
  final MealPlan plan;
  final List<Recipe> catalogue;
  final Map<String, Recipe> byId;
  final bool amharic;
  final AppLocalizations l10n;
  final Future<void> Function(int, MealSlot, String?) onSet;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return GlassPanel(
      blur: false,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: AppTypography.titleSmall.copyWith(
                  color: isToday ? AppColors.accent : palette.textPrimary,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.today,
                  style: AppTypography.label.copyWith(color: AppColors.accent),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final slot in MealSlot.values)
            _SlotRow(
              slot: slot,
              recipe: byId[plan.recipeAt(weekday, slot)],
              amharic: amharic,
              l10n: l10n,
              onTap: () => _pick(context, slot),
            ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context, MealSlot slot) async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RecipePicker(
        catalogue: catalogue,
        amharic: amharic,
        l10n: l10n,
        hasExisting: plan.recipeAt(weekday, slot) != null,
      ),
    );

    // A sheet dismissed without choosing must not clear the slot; only the
    // explicit "remove" action does that, and it returns an empty string.
    if (selected == null) return;
    await onSet(weekday, slot, selected.isEmpty ? null : selected);
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.slot,
    required this.recipe,
    required this.amharic,
    required this.l10n,
    required this.onTap,
  });

  final MealSlot slot;
  final Recipe? recipe;
  final bool amharic;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final slotLabel = switch (slot) {
      MealSlot.breakfast => l10n.breakfast,
      MealSlot.lunch => l10n.lunch,
      MealSlot.dinner => l10n.dinner,
    };
    final dish = recipe;

    return Semantics(
      button: true,
      label: '$slotLabel. '
          '${dish?.localisedTitle(amharic: amharic) ?? l10n.planEmpty}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              SizedBox(
                width: 74,
                child: Text(
                  slotLabel,
                  style:
                      AppTypography.label.copyWith(color: palette.textTertiary),
                ),
              ),
              Expanded(
                child: dish == null
                    ? Text(
                        l10n.planEmpty,
                        style: AppTypography.bodySmall
                            .copyWith(color: palette.textTertiary),
                      )
                    : Row(
                        children: [
                          GradientTile.fromHex(
                            colorA: dish.gradientA,
                            colorB: dish.gradientB,
                            width: 26,
                            height: 26,
                            borderRadius: AppRadii.smAll,
                            sheen: false,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              dish.localisedTitle(amharic: amharic),
                              style: AppTypography.bodySmall
                                  .copyWith(color: palette.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
              Icon(Icons.chevron_right, size: 16, color: palette.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipePicker extends StatelessWidget {
  const _RecipePicker({
    required this.catalogue,
    required this.amharic,
    required this.l10n,
    required this.hasExisting,
  });

  final List<Recipe> catalogue;
  final bool amharic;
  final AppLocalizations l10n;
  final bool hasExisting;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          if (hasExisting)
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(l10n.removeFromPlan),
              // Empty string means "clear", distinct from null which means
              // "dismissed without choosing".
              onTap: () => Navigator.of(context).pop(''),
            ),
          for (final recipe in catalogue)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: GradientTile.fromHex(
                colorA: recipe.gradientA,
                colorB: recipe.gradientB,
                width: 40,
                height: 40,
                borderRadius: AppRadii.mdAll,
              ),
              title: Text(
                recipe.localisedTitle(amharic: amharic),
                style: AppTypography.bodyMedium
                    .copyWith(color: palette.textPrimary),
              ),
              subtitle: Text(
                recipe.formattedTime(amharic: amharic),
                style:
                    AppTypography.caption.copyWith(color: palette.textTertiary),
              ),
              onTap: () => Navigator.of(context).pop(recipe.id),
            ),
        ],
      ),
    );
  }
}
