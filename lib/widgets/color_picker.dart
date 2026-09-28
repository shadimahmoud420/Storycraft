import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../data/palettes.dart';
import '../services/brand_kit.dart';

/// Horizontal row of color swatches, starting with a "custom color" button.
class ColorRow extends StatelessWidget {
  const ColorRow({
    super.key,
    required this.selected,
    required this.onChanged,
    this.colors,
    this.size = 36,
  });

  final Color? selected;
  final ValueChanged<Color> onChanged;
  /// Defaults to the brand kit colors followed by the classic palette.
  final List<Color>? colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: BrandKitStore.instance,
      builder: (context, kit, _) => _build(context, [
        ...kit.colors,
        ...(colors ?? Palettes.classic).where((c) => !kit.colors.contains(c)),
      ]),
    );
  }

  Widget _build(BuildContext context, List<Color> colors) {
    return SizedBox(
      height: size + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: colors.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _Swatch(
              size: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [
                  Colors.red,
                  Colors.yellow,
                  Colors.green,
                  Colors.cyan,
                  Colors.blue,
                  Colors.purple,
                  Colors.red,
                ]),
              ),
              selected: selected != null && !colors.contains(selected),
              icon: Icons.add_rounded,
              onTap: () async {
                final c = await showCustomColorDialog(
                  context,
                  selected ?? Colors.white,
                );
                if (c != null) onChanged(c);
              },
            );
          }
          final color = colors[i - 1];
          return _Swatch(
            size: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            selected: selected == color,
            onTap: () => onChanged(color),
          );
        },
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.size,
    required this.decoration,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final double size;
  final BoxDecoration decoration;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? ring : Colors.grey.withValues(alpha: 0.4),
            width: selected ? 3 : 1,
          ),
        ),
        child: DecoratedBox(
          decoration: decoration,
          child: icon == null
              ? null
              : Icon(icon, size: size * 0.5, color: Colors.white),
        ),
      ),
    );
  }
}

/// Hue / saturation / brightness picker.
Future<Color?> showCustomColorDialog(BuildContext context, Color initial) {
  var hsv = HSVColor.fromColor(initial);
  final s = S.of(context);
  return showDialog<Color>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        Widget slider(
          double value,
          double max,
          List<Color> track,
          ValueChanged<double> onChanged,
        ) {
          return Container(
            height: 28,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: track),
            ),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 0,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: Colors.white,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(value: value, max: max, onChanged: onChanged),
            ),
          );
        }

        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 72,
                decoration: BoxDecoration(
                  color: hsv.toColor(),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
              ),
              const SizedBox(height: 8),
              slider(
                hsv.hue,
                360,
                [
                  for (var h = 0; h <= 360; h += 60)
                    HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor(),
                ],
                (v) => setState(() => hsv = hsv.withHue(v)),
              ),
              slider(
                hsv.saturation,
                1,
                [
                  hsv.withSaturation(0).withValue(1).toColor(),
                  hsv.withSaturation(1).withValue(1).toColor(),
                ],
                (v) => setState(() => hsv = hsv.withSaturation(v)),
              ),
              slider(
                hsv.value,
                1,
                [Colors.black, hsv.withValue(1).toColor()],
                (v) => setState(() => hsv = hsv.withValue(v)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, hsv.toColor()),
              child: Text(s.done),
            ),
          ],
        );
      },
    ),
  );
}
