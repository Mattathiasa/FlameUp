// The one thing that genuinely needs a device: does the app actually start.
//
// Everything else -- progression maths, session persistence, timers -- is pure
// domain logic and lives in test/journeys/, where it runs in seconds rather
// than minutes.
//
//   flutter test integration_test/app_launch_test.dart -d <device>

import 'package:flameup/core/services/local_store.dart';
import 'package:flameup/features/auth/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('local storage opens on a real device', (tester) async {
    // Hive and SharedPreferences both touch the platform; a failure here means
    // the app cannot start at all, which no unit test would catch.
    final store = await LocalStore.open();

    await store.setString('smoke.test', 'ok');
    expect(store.getString('smoke.test'), 'ok');

    await store.writeJson(LocalStore.boxMisc, 'smoke', {'value': 1});
    expect(store.readJson(LocalStore.boxMisc, 'smoke')?['value'], 1);

    await store.remove('smoke.test');
    await store.deleteKey(LocalStore.boxMisc, 'smoke');
  });

  testWidgets('the splash screen renders without Firebase', (tester) async {
    // Firebase is not initialised here on purpose: the splash must be able to
    // paint before, and independently of, the backend coming up.
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
