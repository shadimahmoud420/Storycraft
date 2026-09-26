import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../data/palettes.dart';
import '../models/story_background.dart';
import '../state/editor_controller.dart';
import 'color_picker.dart';

/// Background picker: classic colors, gradients (ready-made or custom)
/// and replacing the photo. Changes apply live to the canvas.
Future<void> showBackgroundSheet(
  BuildContext context, {
  required EditorController controller,
  required VoidCallback onPickPhoto,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Keep the story visible above the sheet while choosing.
    barrierColor: Colors.transparent,
    builder: (_) => _BackgroundSheet(
      controller: controller,
      onPickPhoto: onPickPhoto,
    ),
  );
}

class _BackgroundSheet extends StatefulWidget {
  const _BackgroundSheet({required this.controller, required this.onPickPhoto});

  final EditorController controller;
  final VoidCallback onPickPhoto;

  @override
  State<_BackgroundSheet> createState() => _BackgroundSheetState();
}

class _BackgroundSheetState extends State<_BackgroundSheet> {
  late int _tab =
      widget.controller.background.kind == BackgroundKind.gradient ? 1 : 0;

  StoryBackground get _bg => widget.controller.background;

  void _set(StoryBackground bg) {
    widget.controller.setBackground(bg);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final height = MediaQuery.sizeOf(context).height;

    return ConstrainedBox(
      // Never cover more than ~42% of the screen, on any phone size.
      constraints: BoxConstraints(maxHeight: height * 0.42),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text(s.classic),
                  icon: const Icon(Icons.circle),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text(s.gradients),
                  icon: const Icon(Icons.gradient_rounded),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text(s.photo),
                  icon: const Icon(Icons.image_rounded),
                ),
              ],
              selected: {_tab},
              showSelectedIcon: false,
              onSelectionChanged: (v) {
                if (v.first == 2) {
                  Navigator.pop(context);
                  widget.onPickPhoto();
                  return;
                }
                setState(() => _tab = v.first);
              },
            ),
          ),
          const SizedBox(height: 12),
          Flexible(child: _tab == 0 ? _classic() : _gradients(s)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _classic() {
    final current = _bg.kind == BackgroundKind.solid ? _bg.color : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _Tile(
            decoration: const BoxDecoration(
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
            icon: Icons.add_rounded,
            selected:
                current != null && !Palettes.classic.contains(current),
            onTap: () async {
              final c = await showCustomColorDialog(
                context,
                current ?? Colors.white,
              );
              if (c != null) _set(StoryBackground.solid(c));
            },
          ),
          for (final color in Palettes.classic)
            _Tile(
              decoration: BoxDecoration(color: color),
              selected: current == color,
              onTap: () => _set(StoryBackground.solid(color)),
            ),
        ],
      ),
    );
  }

  Widget _gradients(S s) {
    final isGradient = _bg.kind == BackgroundKind.gradient;
    final colors = isGradient ? _bg.gradientColors : Palettes.gradients.first;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final g in Palettes.gradients)
                _Tile(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: g,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  selected: isGradient && identical(_bg.gradientColors, g),
                  onTap: () => _set(
                    StoryBackground.gradient(g, angle: _bg.gradientAngle),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Custom gradient: pick the start and end colors yourself.
          Row(
            children: [
              _ColorDot(
                color: colors.first,
                onPicked: (c) => _set(StoryBackground.gradient(
                  [c, colors.last],
                  angle: _bg.gradientAngle,
                )),
              ),
              Expanded(
                child: Container(
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: LinearGradient(colors: colors),
                  ),
                ),
              ),
              _ColorDot(
                color: colors.last,
                onPicked: (c) => _set(StoryBackground.gradient(
                  [colors.first, c],
                  angle: _bg.gradientAngle,
                )),
              ),
            ],
          ),
          if (isGradient)
            Row(
              children: [
                Text(s.angle),
                Expanded(
                  child: Slider(
                    value: _bg.gradientAngle,
                    max: 360,
                    divisions: 24,
                    onChanged: (v) => _set(_bg.withAngle(v)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.decoration,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final BoxDecoration decoration;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 72, // 9:16-ish mini story
        decoration: decoration.copyWith(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withValues(alpha: 0.35),
            width: selected ? 3 : 1,
          ),
        ),
        child: icon == null ? null : Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.onPicked});

  final Color color;
  final ValueChanged<Color> onPicked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final c = await showCustomColorDialog(context, color);
        if (c != null) onPicked(c);
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
        ),
        child: Icon(
          Icons.edit_rounded,
          size: 18,
          color: color.computeLuminance() > 0.5 ? Colors.black54 : Colors.white,
        ),
      ),
    );
  }
}
