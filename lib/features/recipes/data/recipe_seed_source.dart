import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/recipe.dart';

/// The catalogue bundled with the app.
///
/// A first run has a full recipe book before it has ever reached the network,
/// which is what makes the app usable on a phone that installs on bad signal
/// and then goes into a kitchen with none. Firestore refreshes and extends it;
/// this is the floor, not a placeholder.
class RecipeSeedSource {
  RecipeSeedSource({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static const String _path = 'assets/seed/recipes.json';

  List<Recipe>? _cache;

  Future<List<Recipe>> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await _bundle.loadString(_path);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final recipes = (json['recipes'] as Map<String, dynamic>)
        .entries
        .map((e) => Recipe.fromJson(e.key, (e.value as Map).cast()))
        .toList(growable: false);

    return _cache = recipes;
  }

  Future<Recipe?> byId(String id) async {
    final all = await load();
    return all.where((r) => r.id == id).firstOrNull;
  }
}

final recipeSeedSourceProvider =
    Provider<RecipeSeedSource>((ref) => RecipeSeedSource());

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
