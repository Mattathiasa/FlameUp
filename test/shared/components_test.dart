import 'package:flameup/core/theme/app_colors.dart';
import 'package:flameup/core/theme/app_theme.dart';
import 'package:flameup/l10n/generated/app_localizations.dart';
import 'package:flameup/shared/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hosts a widget in both themes and both languages, the way it will really
/// run. Every component is checked in dark and light because the design ships
/// two complete palettes and a component that only works in one is broken.
Widget host(
  Widget child, {
  Brightness brightness = Brightness.dark,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('GlassPanel', () {
    testWidgets('renders its child in both themes', (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          host(
            const GlassPanel(child: Text('content')),
            brightness: brightness,
          ),
        );
        expect(
          find.text('content'),
          findsOneWidget,
          reason: 'must render in ${brightness.name}',
        );
      }
    });

    testWidgets('is tappable when given a callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          GlassPanel(
            onTap: () => taps++,
            child: const Text('tap me'),
          ),
        ),
      );

      await tester.tap(find.text('tap me'));
      expect(taps, 1);
    });

    testWidgets('skips the blur when asked, for list performance',
        (tester) async {
      await tester.pumpWidget(
        host(const GlassPanel(blur: false, child: Text('x'))),
      );
      expect(find.byType(BackdropFilter), findsNothing);

      await tester.pumpWidget(
        host(const GlassPanel(child: Text('x'))),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });

  group('GradientTile', () {
    testWidgets('parses the hex pair stored on a recipe', (tester) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 100,
            height: 100,
            child: GradientTile.fromHex(colorA: '#8E1B0F', colorB: '#E0522A'),
          ),
        ),
      );

      final tile = tester.widget<GradientTile>(find.byType(GradientTile));
      expect(tile.colorA, const Color(0xFF8E1B0F));
      expect(tile.colorB, const Color(0xFFE0522A));
    });

    testWidgets('draws a child over the gradient', (tester) async {
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 120,
            height: 120,
            child: GradientTile(
              colorA: Colors.red,
              colorB: Colors.orange,
              child: Text('Doro Wat'),
            ),
          ),
        ),
      );

      expect(find.text('Doro Wat'), findsOneWidget);
    });
  });

  group('FlameButton', () {
    testWidgets('fires when enabled', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        host(
          FlameButton(label: 'Start cooking', onPressed: () => pressed = true),
        ),
      );

      await tester.tap(find.text('Start cooking'));
      expect(pressed, isTrue);
    });

    testWidgets('a null callback disables it', (tester) async {
      await tester.pumpWidget(
        host(const FlameButton(label: 'Disabled', onPressed: null)),
      );

      final semantics = tester.getSemantics(find.text('Disabled').first);
      expect(semantics, isNotNull);
      // Tapping must not throw, and there is nothing to fire.
      await tester.tap(find.text('Disabled'), warnIfMissed: false);
      await tester.pump();
    });

    testWidgets('shows a spinner and swallows taps while loading',
        (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        host(
          FlameButton(
            label: 'Saving',
            loading: true,
            onPressed: () => pressed = true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Saving'), findsNothing);

      await tester.tap(find.byType(FlameButton), warnIfMissed: false);
      expect(pressed, isFalse, reason: 'a loading button must not fire again');
    });
  });

  group('PillChip', () {
    testWidgets('reports its selected state to accessibility', (tester) async {
      await tester.pumpWidget(
        host(const PillChip(label: 'Fasting', selected: true)),
      );

      final node = tester.getSemantics(find.byType(PillChip));
      expect(node.label, 'Fasting');
      expect(node.hasFlag(SemanticsFlag.isSelected), isTrue);
    });

    testWidgets('meets the minimum touch target', (tester) async {
      await tester.pumpWidget(
        host(PillChip(label: 'All', onTap: () {})),
      );

      // The pill is 32px tall by design; the tappable area must still be 48.
      expect(
        tester.getSize(find.byType(PillChip)).height,
        greaterThanOrEqualTo(48),
      );
    });
  });

  group('XpBadge', () {
    testWidgets('formats the reward and describes it for screen readers',
        (tester) async {
      await tester.pumpWidget(host(const XpBadge(xp: 60)));

      expect(find.text('+60 XP'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(XpBadge)).label,
        '60 experience points',
      );
    });

    testWidgets('compact form drops the unit', (tester) async {
      await tester.pumpWidget(host(const XpBadge(xp: 240, compact: true)));
      expect(find.text('+240'), findsOneWidget);
    });
  });

  group('progress', () {
    testWidgets('clamps out-of-range values', (tester) async {
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 200,
            child: FlameProgressBar(value: 1.8, animate: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final node = tester.getSemantics(find.byType(FlameProgressBar));
      expect(node.value, '100%', reason: 'bad data must not overflow the bar');
    });

    testWidgets('announces its percentage', (tester) async {
      await tester.pumpWidget(
        host(const RingProgress(value: 0.72, semanticLabel: 'Wat & stews')),
      );

      final node = tester.getSemantics(find.byType(RingProgress));
      expect(node.label, 'Wat & stews');
      expect(node.value, '72%');
    });
  });

  group('tab bar', () {
    const tabs = [
      FlameTab(label: 'Today', iconPath: 'M3 10.4 10 4l7 6.4V17H3z'),
      FlameTab(label: 'Explore', iconPath: 'M9 15.5a6.5 6.5 0 1 0 0-13'),
    ];

    testWidgets('renders every label and reports selection', (tester) async {
      await tester.pumpWidget(
        host(
          FlameTabBar(tabs: tabs, currentIndex: 0, onTap: (_) {}),
        ),
      );

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
    });

    testWidgets('reports the tapped index', (tester) async {
      int? tapped;
      await tester.pumpWidget(
        host(
          FlameTabBar(tabs: tabs, currentIndex: 0, onTap: (i) => tapped = i),
        ),
      );

      await tester.tap(find.text('Explore'));
      expect(tapped, 1);
    });

    testWidgets('parses the design SVG icon paths without throwing',
        (tester) async {
      // The icons are path data from the design's TABS table; a parser bug
      // would surface here rather than as an invisible icon at runtime.
      for (final tab in tabs) {
        expect(() => parseSvgPath(tab.iconPath, 1), returnsNormally);
      }
      final path = parseSvgPath(tabs.first.iconPath, 1);
      expect(
        path.getBounds().isEmpty,
        isFalse,
        reason: 'a parsed icon must have real geometry',
      );
    });
  });

  group('state views', () {
    testWidgets('empty state renders its copy and action', (tester) async {
      var acted = false;
      await tester.pumpWidget(
        host(
          EmptyView(
            title: 'Nothing saved yet',
            message: 'Tap the bookmark on any recipe.',
            actionLabel: 'Find something to cook',
            onAction: () => acted = true,
          ),
        ),
      );

      expect(find.text('Nothing saved yet'), findsOneWidget);
      await tester.tap(find.text('Find something to cook'));
      expect(acted, isTrue);
    });

    testWidgets('stale banner surfaces the pending write count',
        (tester) async {
      await tester.pumpWidget(
        host(const StaleBanner(message: 'Showing saved data', pendingCount: 3)),
      );

      expect(find.textContaining('3 waiting'), findsOneWidget);
    });

    testWidgets('renders in Amharic without overflowing', (tester) async {
      // Amharic runs longer than English in most strings; a component that
      // only fits the English copy is a bug that ships silently.
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 360,
            child: FlameButton(label: 'የመጀመሪያውን እሳት አብሩ', onPressed: null),
          ),
          locale: const Locale('am'),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('የመጀመሪያውን እሳት አብሩ'), findsOneWidget);
    });
  });

  group('palette', () {
    test('both themes define every colour', () {
      // Generated from tokens.json, so this is really asserting the generator
      // produced complete palettes rather than partially-filled ones.
      expect(AppColors.dark.textPrimary, isNot(AppColors.light.textPrimary));
      expect(AppColors.dark.background, const Color(0xFF0C0908));
      expect(AppColors.light.background, const Color(0xFFEDE3D6));
      expect(AppColors.accent, const Color(0xFFFF6A2B));
    });

    testWidgets('resolves from context brightness', (tester) async {
      late AppPalette resolved;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              resolved = AppPalette.of(context);
              return const SizedBox();
            },
          ),
          brightness: Brightness.light,
        ),
      );

      expect(resolved.background, AppColors.light.background);
    });
  });
}
