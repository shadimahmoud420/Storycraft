import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/strings.dart';
import '../data/art.dart';
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

class ArtChoice extends StickerChoice {
  const ArtChoice(this.name);
  final String name;
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
  ArtGroup _group = ArtGroup.ramadan;

  String _groupLabel(S s, ArtGroup g) => switch (g) {
        ArtGroup.ramadan => s.ramadan,
        ArtGroup.eid => s.eid,
        ArtGroup.friday => s.friday,
        ArtGroup.morning => s.morning,
        ArtGroup.celebrate => s.congrats,
        ArtGroup.graduation => s.graduation,
      };

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
                ButtonSegment(value: 0, label: Text(s.illustrations)),
                ButtonSegment(value: 1, label: Text(s.emoji)),
                ButtonSegment(value: 2, label: Text(s.symbols)),
                ButtonSegment(value: 3, label: Text(s.shapes)),
              ],
              selected: {_tab},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _tab = v.first),
            ),
          ),
          if (_tab == 0)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                children: [
                  for (final g in ArtGroup.values)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        label: Text(_groupLabel(s, g)),
                        selected: g == _group,
                        onSelected: (_) => setState(() => _group = g),
                      ),
                    ),
                ],
              ),
            ),
          Flexible(
            child: switch (_tab) {
              0 => GridView.extent(
                  maxCrossAxisExtent: 110,
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    for (final name in StoryArt.groups[_group]!)
                      cell(
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: SvgPicture.asset(StoryArt.asset(name)),
                        ),
                        ArtChoice(name),
                      ),
                  ],
                ),
              1 => grid([
                  for (final e in stickerEmoji)
                    cell(Text(e, style: const TextStyle(fontSize: 32)),
                        EmojiChoice(e)),
                ]),
              2 => grid([
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
