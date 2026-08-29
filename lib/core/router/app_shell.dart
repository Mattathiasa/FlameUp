import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';

/// Chrome around the five tab branches.
///
/// Phase 2 replaces this Material bar with the design's floating glass tab bar
/// (`design/extracted/screens/` — the bar markup lives at the end of the
/// template, shared by every tabbed screen). The branch structure and
/// per-tab navigation stacks are already final.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.tabToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search),
            label: l10n.tabExplore,
          ),
          NavigationDestination(
            icon: const Icon(Icons.soup_kitchen_outlined),
            selectedIcon: const Icon(Icons.soup_kitchen),
            label: l10n.tabCook,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: l10n.tabComm,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.tabYou,
          ),
        ],
      ),
    );
  }

  /// Tapping the active tab pops that branch back to its root, which is the
  /// behaviour people expect from a tab bar.
  void _onTap(int index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
}
