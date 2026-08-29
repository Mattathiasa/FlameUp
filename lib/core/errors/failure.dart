/// The single error currency of the app.
///
/// Repositories never leak `FirebaseException`, `PlatformException` or raw
/// `Exception` upward. They map to a [Failure], which carries a key the UI can
/// localise plus enough detail for Crashlytics. Nothing user-facing is ever
/// built from a raw exception message.
sealed class Failure implements Exception {
  const Failure({
    required this.messageKey,
    this.cause,
    this.stackTrace,
  });

  /// A localisation key, resolved by the UI. Never a raw provider string.
  final String messageKey;

  /// The underlying error, kept for logging only.
  final Object? cause;
  final StackTrace? stackTrace;

  /// Whether offering the user a "try again" affordance makes sense.
  bool get isRetryable => switch (this) {
        NetworkFailure() => true,
        ServerFailure() => true,
        CacheFailure() => true,
        AuthFailure() => false,
        PermissionFailure() => false,
        ValidationFailure() => false,
        NotFoundFailure() => false,
        CancelledFailure() => false,
        UnknownFailure() => true,
      };

  @override
  String toString() => '$runtimeType($messageKey)'
      '${cause == null ? '' : ' <- $cause'}';
}

/// No usable connection, or the request timed out.
final class NetworkFailure extends Failure {
  const NetworkFailure({
    super.messageKey = 'errorOffline',
    super.cause,
    super.stackTrace,
  });
}

/// The backend answered, but with an error.
final class ServerFailure extends Failure {
  const ServerFailure({
    super.messageKey = 'errorServer',
    super.cause,
    super.stackTrace,
    this.code,
  });

  final String? code;
}

/// Sign-in, sign-up, token refresh or account linking failed.
final class AuthFailure extends Failure {
  const AuthFailure({
    required super.messageKey,
    super.cause,
    super.stackTrace,
    this.code,
  });

  final String? code;
}

/// Firestore or Storage rules rejected the operation.
final class PermissionFailure extends Failure {
  const PermissionFailure({
    super.messageKey = 'errorPermission',
    super.cause,
    super.stackTrace,
  });
}

/// Client-side validation rejected the input before it left the device.
final class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.messageKey,
    this.field,
    super.cause,
    super.stackTrace,
  });

  final String? field;
}

/// The requested document or file does not exist.
final class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.messageKey = 'errorNotFound',
    super.cause,
    super.stackTrace,
  });
}

/// Local cache read/write failed.
final class CacheFailure extends Failure {
  const CacheFailure({
    super.messageKey = 'errorCache',
    super.cause,
    super.stackTrace,
  });
}

/// The user backed out — never surfaced as an error.
final class CancelledFailure extends Failure {
  const CancelledFailure({
    super.messageKey = 'errorCancelled',
    super.cause,
    super.stackTrace,
  });
}

/// Anything unmapped. Always reported to Crashlytics.
final class UnknownFailure extends Failure {
  const UnknownFailure({
    super.messageKey = 'errorUnknown',
    super.cause,
    super.stackTrace,
  });
}
