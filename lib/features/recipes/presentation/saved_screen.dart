import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/services/local_store.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/recipe_seed_source.dart';
import 'dish_card.dart';

/// Saved recipe ids, held locally.
///
/// Saving works signed out and offline: it is a bookmark, not a transaction.
class SavedRecipes extends Notifier<Set<String>> {
  static const String _key = 'saved.recipes';

  @override
  Set<String> build() {
    final stored =
        ref.watch(localStoreProvider).readJson(LocalStore.boxMisc, _key);
    final ids = (stored?['ids'] as List?)?.map((e) => e.toString()).toSet();
    return ids ?? <String>{};
  }

  Future<void> toggle(String recipeId) async {
    final next = Set<String>.from(state);
    next.contains(recipeId) ? next.remove(recipeId) : next.add(recipeId);
    state = next;
    await ref
        .read(localStoreProvider)
        .writeJson(LocalStore.boxMisc, _key, {'ids': next.toList()});
  }

  bool contains(String recipeId) => state.contains(recipeId);
}

final savedRecipesProvider =
    NotifierProvider<SavedRecipes, Set<String>>(SavedRecipes.new);

/// 24-saved — Favorites.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final saved = ref.watch(savedRecipesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.savedH1)),
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

              final recipes =
                  catalogue.where((r) => saved.contains(r.id)).toList();

              if (recipes.isEmpty) {
                return EmptyView(
                  title: l10n.empH1,
                  message: l10n.empSub,
                  actionLabel: l10n.empCta,
                  onAction: () => context.go(Routes.discover),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.md,
                  AppSpacing.gutter,
                  AppSpacing.screenBottom,
                ),
                children: [
                  for (final recipe in recipes) DishListTile(recipe: recipe),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
