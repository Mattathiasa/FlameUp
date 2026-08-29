/// Values that describe the product itself, not any one screen.
abstract final class AppConstants {
  static const String appName = 'FlameUp';
  static const String tagline = 'Cook. Discover. Master.';

  /// Firebase project this build talks to. Mirrored from
  /// `lib/firebase_options.dart`; kept here so non-Firebase code (docs,
  /// diagnostics, the seeder) has one place to read it from.
  static const String firebaseProjectId = 'flameup-78d15';

  /// Set by `--dart-define=USE_FIREBASE_EMULATOR=true`. Cloud Functions cannot
  /// be deployed until the project is on the Blaze plan, so local development
  /// runs against the emulator suite. See docs/FIREBASE_SETUP.md.
  static const bool useEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

  /// Emulator host. `10.0.2.2` reaches the host machine from the Android
  /// emulator; `localhost` is right for iOS simulators and desktop.
  static const String emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: 'localhost',
  );

  static const int emulatorAuthPort = 9099;
  static const int emulatorFirestorePort = 8080;
  static const int emulatorStoragePort = 9199;
  static const int emulatorFunctionsPort = 5001;

  /// Cloud Functions region. Kept in one place so client and functions agree.
  static const String functionsRegion = 'us-central1';

  /// Page size for every paginated list. Discover, feed and leaderboards all
  /// read from this rather than each choosing their own.
  static const int pageSize = 20;

  /// How long a cached collection is served before a refresh is attempted.
  static const Duration cacheTtl = Duration(hours: 6);

  static const Duration networkTimeout = Duration(seconds: 20);

  static const String supportEmail = 'hello@flameup.app';
}
