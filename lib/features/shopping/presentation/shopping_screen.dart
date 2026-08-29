import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../recipes/domain/ingredient.dart';
import '../../recipes/domain/recipe_providers.dart';
import '../domain/shopping_controller.dart';

/// 25-shop — the shopping list, grouped by aisle.
class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    await ref.read(shoppingControllerProvider.notifier).addManual(_input.text);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final amharic = ref.watch(isAmharicProvider);
    final items = ref.watch(shoppingControllerProvider);
    final controller = ref.read(shoppingControllerProvider.notifier);
    final grouped = controller.grouped;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shopH1),
        actions: [
          if (items.any((i) => i.checked))
            TextButton(
              onPressed: controller.clearChecked,
              child: Text(l10n.clearDone),
            ),
        ],
      ),
      body: Stack(
        children: [
          const AmbientBackground(),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: TextField(
                  controller: _input,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(
                    hintText: l10n.addManualItem,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _add,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? EmptyView(
                        title: l10n.shoppingEmpty,
                        message: l10n.shoppingEmptySub,
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.gutter,
                          0,
                          AppSpacing.gutter,
                          AppSpacing.screenBottom,
                        ),
                        children: [
                          for (final entry in grouped.entries) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.xl,
                                bottom: AppSpacing.sm,
                              ),
                              child: Eyebrow(_aisleLabel(entry.key, l10n)),
                            ),
                            for (final item in entry.value)
                              Dismissible(
                                key: ValueKey(item.id),
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) => controller.remove(item.id),
                                background: const ColoredBox(
                                  color: Color(0x33C0301C),
                                ),
                                child: CheckboxListTile(
                                  value: item.checked,
                                  onChanged: (_) => controller.toggle(item.id),
                                  activeColor: AppColors.accent,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    amharic ? item.nameAm : item.name,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: item.checked
                                          ? palette.textTertiary
                                          : palette.textPrimary,
                                      decoration: item.checked
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  secondary: Text(
                                    item.displayAmount(amharic: amharic),
                                    style: AppTypography.caption.copyWith(
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _aisleLabel(Aisle aisle, AppLocalizations l10n) =>
      switch (aisle) {
        Aisle.spice => l10n.aisleSpice,
        Aisle.fresh => l10n.aisleFresh,
        Aisle.meatDairy => l10n.aisleMeat,
        Aisle.pantry => l10n.aislePantry,
      };
}
