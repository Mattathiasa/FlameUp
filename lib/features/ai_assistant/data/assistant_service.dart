import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../domain/assistant_message.dart';

/// Talks to the assistant.
///
/// A callable Cloud Function, never the provider directly: the API key stays
/// server-side, because a key in the app binary is a key anyone can pull out
/// of the APK.
class AssistantService {
  AssistantService([FirebaseFunctions? functions])
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: AppConstants.functionsRegion);

  final FirebaseFunctions _functions;

  Future<Result<AssistantMessage>> ask({
    required String question,
    String? recipeId,
    int? stepIndex,
  }) =>
      ErrorMapper.guard(() async {
        final callable = _functions.httpsCallable(
          'askAssistant',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
        );

        final response = await callable.call<Map<String, dynamic>>({
          'question': question,
          if (recipeId != null) 'recipeId': recipeId,
          if (stepIndex != null) 'stepIndex': stepIndex,
        });

        return AssistantMessage.fromAnswer(
          response.data['answer'] as String? ?? '',
        );
      });
}

final assistantServiceProvider =
    Provider<AssistantService>((ref) => AssistantService());
