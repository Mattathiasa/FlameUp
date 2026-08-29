import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';

/// What the server granted for a completed cook.
class RewardResult {
  const RewardResult({
    required this.xpAwarded,
    required this.level,
    required this.streak,
    this.leveledUp = false,
    this.alreadyGranted = false,
    this.awards = const [],
  });

  final int xpAwarded;
  final int level;
  final int streak;
  final bool leveledUp;

  /// True when the reward had already been granted — a replay, not an error.
  final bool alreadyGranted;

  /// The breakdown, so a total can be explained rather than merely shown.
  final List<({int amount, String reason, String? detail})> awards;

  static RewardResult fromJson(Map<String, dynamic> json) => RewardResult(
        xpAwarded: json['xpAwarded'] as int? ?? 0,
        level: json['level'] as int? ?? 1,
        streak: json['streak'] as int? ?? 0,
        leveledUp: json['leveledUp'] as bool? ?? false,
        alreadyGranted: json['alreadyGranted'] as bool? ?? false,
        awards: (json['awards'] as List?)?.map((raw) {
              final award = (raw as Map).cast<String, dynamic>();
              return (
                amount: award['amount'] as int? ?? 0,
                reason: award['reason'] as String? ?? '',
                detail: award['detail'] as String?,
              );
            }).toList(growable: false) ??
            const [],
      );
}

/// Claims rewards from the server.
///
/// The client never writes its own XP: Firestore rules forbid it, and this
/// calls the function that does. The session's idempotency key means a replay
/// is safe — the server returns `alreadyGranted` rather than paying twice.
///
/// **Not yet deployed.** Cloud Functions require the Blaze plan and the
/// project is on Spark, so this reaches the emulator during development and
/// fails against the live project until the upgrade. That is a documented gap,
/// not a silent one: see docs/FIREBASE_SETUP.md.
class RewardService {
  RewardService([FirebaseFunctions? functions])
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: AppConstants.functionsRegion);

  final FirebaseFunctions _functions;

  Future<Result<RewardResult>> claimForSession(String sessionId) =>
      ErrorMapper.guard(() async {
        final callable = _functions.httpsCallable(
          'claimCookingReward',
          options: HttpsCallableOptions(timeout: AppConstants.networkTimeout),
        );

        final response = await callable.call<Map<String, dynamic>>({
          'sessionId': sessionId,
        });

        return RewardResult.fromJson(response.data);
      });
}

final rewardServiceProvider = Provider<RewardService>((ref) => RewardService());
