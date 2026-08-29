import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../shared/widgets/flame_tab_bar.dart';

/// Chrome around the five tab branches.
///
/// The bar floats over the content rather than sitting below it, as in the
/// design, so screens extend behind it and pad themselves by
/// [AppSpacing.screenBottom].
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// Icon paths from the design's `TABS` table, in branch order.
  static const List<String> _iconPaths = [
    'M3 10.4 10 4l7 6.4V17H3z',
    'M9 15.5a6.5 6.5 0 1 0 0-13 6.5 6.5 0 0 0 0 13ZM13.8 13.8 17.5 17.5',
    'M4 8.5h12M5 8.5v6a2.5 2.5 0 0 0 2.5 2.5h5A2.5 2.5 0 0 0 15 14.5v-6'
        'M7 5.5c0-1 1-1.5 1-2.5M10 5.5c0-1 1-1.5 1-2.5M13 5.5c0-1 1-1.5 1-2.5',
    'M7.5 9a2.6 2.6 0 1 0 0-5.2 2.6 2.6 0 0 0 0 5.2ZM13.4 9.4a2.1 2.1 0 1 0 '
        '0-4.2 2.1 2.1 0 0 0 0 4.2ZM2.6 16.4c0-2.7 2.2-4.4 4.9-4.4s4.9 1.7 '
        '4.9 4.4M13.6 12.2c2 .2 3.8 1.5 3.8 4.2',
    'M10 9.6a3.3 3.3 0 1 0 0-6.6 3.3 3.3 0 0 0 0 6.6ZM3.8 17c0-3.2 2.8-5 '
        '6.2-5s6.2 1.8 6.2 5',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.tabToday,
      l10n.tabExplore,
      l10n.tabCook,
      l10n.tabComm,
      l10n.tabYou,
    ];

    return Scaffold(
      // The bar is translucent glass, so content must run behind it.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: FlameTabBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
        tabs: [
          for (var i = 0; i < labels.length; i++)
            FlameTab(label: labels[i], iconPath: _iconPaths[i]),
        ],
      ),
    );
  }

  /// Tapping the active tab pops that branch back to its root, which is what
  /// people expect from a tab bar.
  void _onTap(int index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
}
