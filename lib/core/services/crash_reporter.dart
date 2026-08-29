import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/failure.dart';

/// Crash and non-fatal error reporting.
///
/// Debug builds print instead of uploading, so local runs do not pollute the
/// production Crashlytics dashboard. Breadcrumbs never include user-entered
/// text or credentials.
class CrashReporter {
  CrashReporter(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  Future<void> initialise() async {
    await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      previousOnError?.call(details);
      if (kDebugMode) return;
      _crashlytics.recordFlutterFatalError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// Record a mapped [Failure]. Expected conditions — being offline, a
  /// cancelled sign-in, a validation error — are not worth reporting.
  Future<void> recordFailure(Failure failure) async {
    if (failure is NetworkFailure ||
        failure is CancelledFailure ||
        failure is ValidationFailure) {
      return;
    }
    await recordError(
      failure.cause ?? failure,
      failure.stackTrace,
      reason: failure.messageKey,
    );
  }

  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (kDebugMode) {
      debugPrint('[crash] ${reason ?? ''} $error');
      if (stack != null) debugPrintStack(stackTrace: stack);
      return;
    }
    await _crashlytics.recordError(error, stack, reason: reason, fatal: fatal);
  }

  Future<void> setUser(String? uid) =>
      _crashlytics.setUserIdentifier(uid ?? '');

  /// A short, non-sensitive breadcrumb such as a route name.
  Future<void> leaveBreadcrumb(String message) => _crashlytics.log(message);
}

final crashReporterProvider = Provider<CrashReporter>(
  (ref) => CrashReporter(FirebaseCrashlytics.instance),
);
