import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../data/quotes.dart';
import '../models/story_layer.dart';
import 'story_view.dart';

/// What the user picked in the sticker sheet.
sealed class StickerChoice {
  const StickerChoice();
}

class EmojiChoice extends StickerChoice {
  const EmojiChoice(this.text);
  final String text;
}

class ShapeChoice extends StickerChoice {
  const ShapeChoice(this.shape);
  final ShapeKind shape;
}

Future<StickerChoice?> showStickerSheet(BuildContext context) {
  return showModalBottomSheet<StickerChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _StickerSheet(),
  );
}

class _StickerSheet extends StatefulWidget {
  const _StickerSheet();

  @override
  State<_StickerSheet> createState() => _StickerSheetState();
}

class _StickerSheetState extends State<_StickerSheet> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    Widget grid(List<Widget> children) => GridView.extent(
          maxCrossAxisExtent: 64,
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: children,
        );

    Widget cell(Widget child, StickerChoice choice) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pop(context, choice),
          child: Center(child: child),
        );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.55,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(s.emoji)),
                ButtonSegment(value: 1, label: Text(s.symbols)),
                ButtonSegment(value: 2, label: Text(s.shapes)),
              ],
              selected: {_tab},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _tab = v.first),
            ),
          ),
          Flexible(
            child: switch (_tab) {
              0 => grid([
                  for (final e in stickerEmoji)
                    cell(Text(e, style: const TextStyle(fontSize: 32)),
                        EmojiChoice(e)),
                ]),
              1 => grid([
                  for (final e in stickerSymbols)
                    cell(
                      Text(e, style: TextStyle(fontSize: 30, color: onSurface)),
                      EmojiChoice(e),
                    ),
                ]),
              _ => grid([
                  for (final shape in ShapeKind.values)
                    cell(
                      CustomPaint(
                        size: switch (shape) {
                          ShapeKind.roundedFrame ||
                          ShapeKind.rectFrame =>
                            const Size(32, 40),
                          ShapeKind.circleFrame => const Size(38, 38),
                          ShapeKind.line => const Size(40, 6),
                          ShapeKind.label => const Size(44, 16),
                        },
                        painter: ShapePainter(shape, onSurface),
                      ),
                      ShapeChoice(shape),
                    ),
                ]),
            },
          ),
        ],
      ),
    );
  }
}
