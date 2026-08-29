import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import 'glass_panel.dart';

/// One destination in the tab bar.
class FlameTab {
  const FlameTab({
    required this.label,
    required this.iconPath,
  });

  final String label;

  /// The SVG path data from the design's `TABS` table, on a 20x20 viewBox.
  final String iconPath;
}

/// The design's floating tab bar.
///
/// Not a Material `NavigationBar`: the design floats a glass pill 22px above
/// the bottom edge, inset 12px on each side, 64px tall with a 26px radius, and
/// marks the active tab with a filled rounded rect behind it.
class FlameTabBar extends StatelessWidget {
  const FlameTabBar({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final List<FlameTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
      child: GlassPanel(
        height: 64,
        borderRadius: AppRadii.barAll,
        shadow: true,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: _TabButton(
                  tab: tabs[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                  palette: palette,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  final FlameTab tab;
  final bool selected;
  final VoidCallback onTap;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : palette.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.xxlAll,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          height: 52,
          decoration: BoxDecoration(
            color: selected ? palette.glassRaised : Colors.transparent,
            borderRadius: AppRadii.xxlAll,
            border: selected
                ? Border.all(
                    color: palette.glassBorder,
                    width: AppGlass.hairline,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomPaint(
                size: const Size.square(20),
                painter: _TabIconPainter(path: tab.iconPath, color: color),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                tab.label,
                style: AppTypography.tabLabel.copyWith(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws a tab icon from the design's SVG path data.
///
/// The five icons are stroked outlines on a 20x20 grid. Parsing the subset of
/// path syntax they use (M, L, H, V, A, Z, absolute and relative) keeps them as
/// data in one table rather than five hand-written painters.
class _TabIconPainter extends CustomPainter {
  const _TabIconPainter({required this.path, required this.color});

  final String path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(parseSvgPath(path, size.width / 20), paint);
  }

  @override
  bool shouldRepaint(_TabIconPainter old) =>
      old.color != color || old.path != path;
}

/// A minimal SVG path parser covering the commands the design's icons use.
///
/// Deliberately small: adding `flutter_svg` for five 20x20 outlines would pull
/// a full XML parser and rasteriser into the app for no benefit.
Path parseSvgPath(String data, double scale) {
  final path = Path();
  final tokens = RegExp(r'([MmLlHhVvAaZz])|(-?\d*\.?\d+)').allMatches(data);

  final values = <String>[];
  for (final match in tokens) {
    values.add(match.group(0)!);
  }

  var i = 0;
  var cx = 0.0;
  var cy = 0.0;
  var command = '';

  double next() => double.parse(values[i++]) * scale;

  while (i < values.length) {
    final token = values[i];
    if (RegExp(r'^[MmLlHhVvAaZz]$').hasMatch(token)) {
      command = token;
      i++;
    }

    switch (command) {
      case 'M':
        cx = next();
        cy = next();
        path.moveTo(cx, cy);
        command = 'L'; // implicit lineto for repeated pairs
      case 'm':
        cx += next();
        cy += next();
        path.moveTo(cx, cy);
        command = 'l';
      case 'L':
        cx = next();
        cy = next();
        path.lineTo(cx, cy);
      case 'l':
        cx += next();
        cy += next();
        path.lineTo(cx, cy);
      case 'H':
        cx = next();
        path.lineTo(cx, cy);
      case 'h':
        cx += next();
        path.lineTo(cx, cy);
      case 'V':
        cy = next();
        path.lineTo(cx, cy);
      case 'v':
        cy += next();
        path.lineTo(cx, cy);
      case 'A':
      case 'a':
        final rx = next();
        final ry = next();
        i++; // x-axis-rotation, always 0 in these icons
        final largeArc = values[i++] == '1';
        final sweep = values[i++] == '1';
        if (command == 'A') {
          cx = next();
          cy = next();
        } else {
          cx += next();
          cy += next();
        }
        path.arcToPoint(
          Offset(cx, cy),
          radius: Radius.elliptical(rx, ry),
          largeArc: largeArc,
          clockwise: sweep,
        );
      case 'Z':
      case 'z':
        path.close();
      default:
        i++; // unknown command: skip rather than loop forever
    }
  }

  return path;
}
