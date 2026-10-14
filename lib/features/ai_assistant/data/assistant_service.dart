import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../../recipes/data/recipe_seed_source.dart';
import '../../recipes/domain/recipe_providers.dart';
import '../domain/assistant_engine.dart';
import '../domain/assistant_message.dart';

/// Answers cooking questions on the device.
///
/// The assistant's entire knowledge is the catalogue the app already bundles
/// — no network call, no Cloud Function, no provider key. That is what makes
/// it work in a kitchen with no signal and cost nothing to run, and why it
/// can only ever claim what the recipes themselves say: every answer passes
/// through [AssistantEngine] and is split into labelled claims by
/// [AssistantMessage.fromAnswer], so the UI's claim-labelling contract is
/// kept on this path too.
class AssistantService {
  AssistantService({RecipeSeedSource? seedSource, bool Function()? isAmharic})
      : _seedSource = seedSource ?? RecipeSeedSource(),
        _isAmharic = isAmharic ?? _defaultAmharic;

  final RecipeSeedSource _seedSource;
  final bool Function() _isAmharic;

  static bool _defaultAmharic() => false;

  Future<Result<AssistantMessage>> ask({
    required String question,
    String? recipeId,
    int? stepIndex,
  }) =>
      ErrorMapper.guard(() async {
        final recipes = await _seedSource.load();

        final answer = AssistantEngine(recipes).answer(
          question: question,
          recipeId: recipeId,
          stepIndex: stepIndex,
          amharic: _isAmharic(),
        );

        return AssistantMessage.fromAnswer(answer);
      });
}

final assistantServiceProvider = Provider<AssistantService>(
  (ref) => AssistantService(
    seedSource: ref.watch(recipeSeedSourceProvider),
    isAmharic: () => ref.read(isAmharicProvider),
  ),
);
