import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../data/fonts.dart';
import '../models/story_layer.dart';
import 'color_picker.dart';

/// Opens the text editor. Edits a copy of [draft]; returns it on "Done"
/// (or null if dismissed / left empty).
Future<StoryLayer?> showTextEditorSheet(BuildContext context, StoryLayer draft) {
  return showModalBottomSheet<StoryLayer>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TextEditorSheet(draft: draft.copyWith(id: draft.id)),
  );
}

class _TextEditorSheet extends StatefulWidget {
  const _TextEditorSheet({required this.draft});

  final StoryLayer draft;

  @override
  State<_TextEditorSheet> createState() => _TextEditorSheetState();
}

class _TextEditorSheetState extends State<_TextEditorSheet> {
  late final TextEditingController _text =
      TextEditingController(text: widget.draft.text);
  late bool _arabicTab = widget.draft.font.arabic;
  late bool _fontTouched = widget.draft.text.isNotEmpty;

  StoryLayer get d => widget.draft;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    setState(() {
      d.text = value;
      // Typing Arabic with a Latin-only font? Switch automatically.
      if (!_fontTouched && StoryFonts.hasArabic(value) != d.font.arabic) {
        d.font = StoryFonts.defaultFor(value);
        _arabicTab = d.font.arabic;
      }
    });
  }

  void _done() {
    final text = _text.text.trim();
    Navigator.pop(context, text.isEmpty ? null : (d..text = text));
  }

  IconData get _alignIcon => switch (d.align) {
        TextAlign.left => Icons.format_align_left_rounded,
        TextAlign.right => Icons.format_align_right_rounded,
        _ => Icons.format_align_center_rounded,
      };

  void _cycleAlign() => setState(() {
        d.align = switch (d.align) {
          TextAlign.center => TextAlign.left,
          TextAlign.left => TextAlign.right,
          _ => TextAlign.center,
        };
      });

  void _cycleHighlight() => setState(() {
        d.highlight = TextHighlight
            .values[(d.highlight.index + 1) % TextHighlight.values.length];
      });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final fonts = _arabicTab ? StoryFonts.arabic : StoryFonts.english;
    final isRtl = StoryFonts.hasArabic(_text.text) ||
        (_text.text.isEmpty && s.isArabic);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Live preview + input.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                constraints: const BoxConstraints(minHeight: 110),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: d.color.computeLuminance() > 0.5
                      ? const Color(0xFF2B2B2F)
                      : const Color(0xFFEDEDF0),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: d.highlightColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _text,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 5,
                    textAlign: d.align,
                    textDirection:
                        isRtl ? TextDirection.rtl : TextDirection.ltr,
                    cursorColor: d.color,
                    style: d.style.copyWith(
                      fontSize: d.fontSize.clamp(18, 40).toDouble(),
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: s.typeHere,
                      hintStyle: d.style.copyWith(
                        fontSize: 24,
                        color: d.color.withValues(alpha: 0.5),
                      ),
                    ),
                    onChanged: _onTextChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Font family.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text(s.arabicFonts)),
                  ButtonSegment(value: false, label: Text(s.englishFonts)),
                ],
                selected: {_arabicTab},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _arabicTab = v.first),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: fonts.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final font = fonts[i];
                  final selected = font == d.font;
                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) => setState(() {
                      d.font = font;
                      _fontTouched = true;
                    }),
                    label: Text(
                      font.arabic ? 'أبجد  ${font.displayName}' : font.displayName,
                      style: font.style(const TextStyle(fontSize: 17)),
                    ),
                  );
                },
              ),
            ),

            // Color.
            _Label(s.color),
            ColorRow(
              selected: d.color,
              onChanged: (c) => setState(() => d.color = c),
            ),

            // Size + style toggles.
            _Label(s.size),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: d.fontSize,
                      min: 14,
                      max: 96,
                      onChanged: (v) => setState(() => d.fontSize = v),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Align',
                    onPressed: _cycleAlign,
                    icon: Icon(_alignIcon),
                  ),
                  IconButton.filledTonal(
                    tooltip: s.highlight,
                    isSelected: d.highlight != TextHighlight.none,
                    onPressed: _cycleHighlight,
                    icon: Icon(switch (d.highlight) {
                      TextHighlight.none => Icons.format_color_text_rounded,
                      TextHighlight.solid => Icons.rectangle_rounded,
                      TextHighlight.soft => Icons.rectangle_outlined,
                      TextHighlight.blur => Icons.blur_circular_rounded,
                    }),
                  ),
                  IconButton.filledTonal(
                    tooltip: s.shadow,
                    isSelected: d.shadow,
                    onPressed: () => setState(() => d.shadow = !d.shadow),
                    icon: const Icon(Icons.blur_on_rounded),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                onPressed: _done,
                icon: const Icon(Icons.check_rounded),
                label: Text(s.done),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  textStyle: theme.textTheme.titleMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
