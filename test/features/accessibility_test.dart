import 'package:flameup/core/errors/failure.dart';
import 'package:flameup/core/services/local_store.dart';
import 'package:flameup/core/theme/app_theme.dart';
import 'package:flameup/features/recipes/domain/recipe_providers.dart';
import 'package:flameup/l10n/generated/app_localizations.dart';
import 'package:flameup/shared/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {Locale locale = const Locale('en')}) =>
    ProviderScope(
      overrides: [
        isAmharicProvider.overrideWithValue(locale.languageCode == 'am'),
        localStoreProvider.overrideWith(
          (ref) => throw UnimplementedError('not needed'),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    );

void main() {
  group('touch targets', () {
    testWidgets('meet the accessible minimum even where the design is smaller',
        (tester) async {
      // The design's pills are 32px. The visual stays 32; the tappable box is
      // expanded around it rather than scaling the design up.
      await tester.pumpWidget(
        host(Center(child: PillChip(label: 'All', onTap: () {}))),
      );

      expect(
        tester.getSize(find.byType(PillChip)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('the primary button is comfortably large', (tester) async {
      await tester.pumpWidget(
        host(FlameButton(label: 'Start cooking', onPressed: () {})),
      );

      expect(
        tester.getSize(find.byType(FlameButton)).height,
        greaterThanOrEqualTo(48),
      );
    });
  });

  group('screen reader labels', () {
    testWidgets('a glass panel with a tap target announces itself',
        (tester) async {
      await tester.pumpWidget(
        host(
          GlassPanel(
            onTap: () {},
            semanticLabel: 'Mastery',
            child: const Text('Mastery'),
          ),
        ),
      );

      // The child Text contributes its own node, so the panel's label is
      // asserted by containment rather than equality.
      final node = tester.getSemantics(find.byType(GlassPanel));
      expect(node.label, contains('Mastery'));
    });

    testWidgets('progress announces a percentage, not just a bar',
        (tester) async {
      await tester.pumpWidget(
        host(
          const RingProgress(value: 0.4, semanticLabel: 'Wat & stews'),
        ),
      );

      final node = tester.getSemantics(find.byType(RingProgress));
      expect(node.label, 'Wat & stews');
      expect(node.value, '40%');
    });

    testWidgets('decorative art is hidden from screen readers', (tester) async {
      // The flame and the ambient glow carry no information; announcing them
      // would be noise between the things that matter.
      await tester.pumpWidget(host(const FlameIcon(size: 24)));

      expect(
        find.descendant(
          of: find.byType(FlameIcon),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });
  });

  group('text scaling', () {
    testWidgets('survives a large accessibility text size', (tester) async {
      // Someone with a 2x text setting must still be able to use the app.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        host(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Center(
              child: SizedBox(
                width: 200,
                child: FlameButton(
                  label: 'Light the first flame',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('Amharic at a large scale does not overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        host(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Center(
              child: SizedBox(
                width: 240,
                child: PillChip(label: 'የመጀመሪያውን እሳት አብሩ', onTap: () {}),
              ),
            ),
          ),
          locale: const Locale('am'),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('error states', () {
    testWidgets('offers a retry only when retrying could help', (tester) async {
      // A PermissionFailure is not retryable; offering a button that cannot
      // fix anything wastes the user's time.
      await tester.pumpWidget(
        host(ErrorView(failure: const PermissionFailure(), onRetry: () {})),
      );
      expect(find.byType(FlameButton), findsNothing);

      await tester.pumpWidget(
        host(ErrorView(failure: const NetworkFailure(), onRetry: () {})),
      );
      expect(find.byType(FlameButton), findsOneWidget);
    });

    testWidgets('shows localised copy, never a raw provider message',
        (tester) async {
      await tester.pumpWidget(host(const ErrorView(failure: NetworkFailure())));

      // The key resolves to real words; a messageKey leaking through would be
      // an obvious regression.
      expect(find.textContaining('errorOffline'), findsNothing);
      expect(find.textContaining('connection'), findsOneWidget);
    });
  });
}
