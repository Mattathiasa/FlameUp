import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/cache/outbox.dart';
import 'core/services/analytics_service.dart';
import 'core/services/crash_reporter.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/services/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await FirebaseBootstrap.initialise();

  // Opened before the first frame so theme, language and the onboarding flag
  // are readable synchronously and the app never flashes the wrong shell.
  final localStore = await LocalStore.open();

  final container = ProviderContainer(
    overrides: [localStoreProvider.overrideWithValue(localStore)],
  );

  await container.read(crashReporterProvider).initialise();

  // Start draining writes queued while the app was offline. Handlers are
  // registered by each feature as it loads; anything without one yet stays
  // queued rather than being dropped.
  container.read(outboxProvider).start();
  unawaited(
    container.read(analyticsServiceProvider).log(AnalyticsService.appOpen),
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FlameUpApp(),
    ),
  );
}
