import 'package:flutter/material.dart';

/// A route that exists but whose screen has not been built yet.
///
/// Deliberately blunt: it names the phase that will build it and the design
/// file it will be built from. Nothing in the app should ever *look* finished
/// while being a stub, so these are unmistakable on sight and every one of them
/// disappears as its phase lands.
class NotBuiltYet extends StatelessWidget {
  const NotBuiltYet({
    required this.screen,
    required this.designFile,
    required this.phase,
    super.key,
  });

  /// Screen id from the design, e.g. `home`.
  final String screen;

  /// Filename under `design/extracted/screens/`.
  final String designFile;

  /// The phase in docs/DEVELOPMENT_PLAN.md that builds it.
  final String phase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(screen)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_outlined, size: 40),
              const SizedBox(height: 14),
              Text(
                'Not built yet',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                '$phase builds this screen from\ndesign/extracted/screens/$designFile',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
