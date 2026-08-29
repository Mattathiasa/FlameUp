import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../constants/app_constants.dart';

/// Brings Firebase up before the first frame.
///
/// Cloud Functions cannot be deployed until the project moves to the Blaze
/// plan (see docs/FIREBASE_SETUP.md), so development runs against the emulator
/// suite. Pass `--dart-define=USE_FIREBASE_EMULATOR=true` to point every SDK at
/// localhost; the app code is identical either way.
abstract final class FirebaseBootstrap {
  static bool _done = false;

  static Future<void> initialise() async {
    if (_done) return;

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (AppConstants.useEmulator) {
      await _useEmulators();
    } else {
      // App Check attestation needs the network and a registered device. A
      // failure here must not stop the app from starting -- the backend still
      // enforces its own rules, and an unattested client simply gets refused
      // on the calls that require it.
      try {
        await _activateAppCheck();
      } catch (error, stack) {
        debugPrint('[firebase] App Check activation failed: $error');
        await FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          reason: 'app-check-activate',
          fatal: false,
        );
      }
    }

    // Firestore keeps a local mirror so recipes and in-flight cooking sessions
    // survive a dead connection. Phase 6 depends on this being on.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    _done = true;
  }

  static Future<void> _useEmulators() async {
    const host = AppConstants.emulatorHost;
    await FirebaseAuth.instance
        .useAuthEmulator(host, AppConstants.emulatorAuthPort);
    FirebaseFirestore.instance
        .useFirestoreEmulator(host, AppConstants.emulatorFirestorePort);
    await FirebaseStorage.instance
        .useStorageEmulator(host, AppConstants.emulatorStoragePort);
    FirebaseFunctions.instanceFor(region: AppConstants.functionsRegion)
        .useFunctionsEmulator(host, AppConstants.emulatorFunctionsPort);
    debugPrint('[firebase] using emulator suite at $host');
  }

  /// App Check keeps the backend from answering requests that did not come
  /// from a genuine build. Debug providers are used in debug builds; the
  /// device token has to be registered in the console once per machine.
  static Future<void> _activateAppCheck() async {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
  }
}
