import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../data/fonts.dart';
import '../models/story_layer.dart';
import 'color_picker.dart';
import 'story_view.dart';

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

enum _Tab { font, color, effects, curve }

class _TextEditorSheetState extends State<_TextEditorSheet> {
  late final TextEditingController _text =
      TextEditingController(text: widget.draft.text);
  late bool _arabicFonts = widget.draft.font.arabic;
  late FontCategory? _category;
  late bool _fontTouched = widget.draft.text.isNotEmpty;
  _Tab _tab = _Tab.font;

  StoryLayer get d => widget.draft;

  @override
  void initState() {
    super.initState();
    _category = null;
  }

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
        _arabicFonts = d.font.arabic;
        _category = null;
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

  String _categoryLabel(S s, FontCategory c) => switch (c) {
        FontCategory.modern => s.catModern,
        FontCategory.kufi => s.catKufi,
        FontCategory.naskh => s.catNaskh,
        FontCategory.calligraphy => s.catCalligraphy,
        FontCategory.display => s.catDisplay,
        FontCategory.sans => s.catSans,
        FontCategory.serif => s.catSerif,
        FontCategory.script => s.catScript,
        FontCategory.hand => s.catHand,
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final isRtl = StoryFonts.hasArabic(_text.text) ||
        (_text.text.isEmpty && s.isArabic);
    final previewBg = d.color.computeLuminance() > 0.5 && d.fill == TextFill.solid
        ? const Color(0xFF2B2B2F)
        : const Color(0xFFEDEDF0);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Live preview with every effect applied.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: d.fill == TextFill.solid ? previewBg : const Color(0xFF2B2B2F),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(8),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: StoryLayerVisual(
                    layer: d.copyWith(id: d.id)
                      ..text = d.text.isEmpty ? s.typeHere : d.text,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _text,
                autofocus: d.text.isEmpty,
                minLines: 1,
                maxLines: 3,
                textAlign: TextAlign.center,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: s.typeHere,
                  filled: true,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _onTextChanged,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<_Tab>(
                segments: [
                  ButtonSegment(value: _Tab.font, label: Text(s.fontTab)),
                  ButtonSegment(value: _Tab.color, label: Text(s.color)),
                  ButtonSegment(value: _Tab.effects, label: Text(s.effects)),
                  ButtonSegment(value: _Tab.curve, label: Text(s.curveTab)),
                ],
                selected: {_tab},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _tab = v.first),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 190,
              child: switch (_tab) {
                _Tab.font => _fontTab(s),
                _Tab.color => _colorTab(s),
                _Tab.effects => _effectsTab(s),
                _Tab.curve => _curveTab(s),
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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

  // --- Tabs -----------------------------------------------------------------

  Widget _chips<T>(List<T> items, T? selected, String Function(T) label,
      ValueChanged<T?> onSelected, {String? allLabel}) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (allLabel != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: ChoiceChip(
                label: Text(allLabel),
                selected: selected == null,
                onSelected: (_) => onSelected(null),
              ),
            ),
          for (final item in items)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: ChoiceChip(
                label: Text(label(item)),
                selected: item == selected,
                onSelected: (_) => onSelected(item),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fontTab(S s) {
    final fonts = (_arabicFonts ? StoryFonts.arabic : StoryFonts.english)
        .where((f) => _category == null || f.category == _category)
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(s.arabicFonts)),
              ButtonSegment(value: false, label: Text(s.englishFonts)),
            ],
            selected: {_arabicFonts},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() {
              _arabicFonts = v.first;
              _category = null;
            }),
          ),
        ),
        const SizedBox(height: 6),
        _chips<FontCategory>(
          StoryFonts.categories(arabic: _arabicFonts),
          _category,
          (c) => _categoryLabel(s, c),
          (c) => setState(() => _category = c),
          allLabel: s.all,
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: fonts.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final font = fonts[i];
              return ChoiceChip(
                selected: font == d.font,
                onSelected: (_) => setState(() {
                  d.font = font;
                  _fontTouched = true;
                }),
                label: Text(
                  font.arabic
                      ? 'أبجد  ${font.displayName}'
                      : font.displayName,
                  style: font.style(const TextStyle(fontSize: 17)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _colorTab(S s) {
    String fillLabel(TextFill f) => switch (f) {
          TextFill.solid => s.fillSolid,
          TextFill.gradient => s.fillGradient,
          TextFill.gold => s.fillGold,
          TextFill.silver => s.fillSilver,
          TextFill.rose => s.fillRose,
        };
    return ListView(
      children: [
        _chips<TextFill>(
          TextFill.values,
          d.fill,
          fillLabel,
          (f) => setState(() => d.fill = f ?? TextFill.solid),
        ),
        if (d.fill == TextFill.solid || d.fill == TextFill.gradient) ...[
          const SizedBox(height: 6),
          ColorRow(
            selected: d.color,
            onChanged: (c) => setState(() => d.color = c),
          ),
        ],
        if (d.fill == TextFill.gradient) ...[
          _Label(s.secondColor),
          ColorRow(
            selected: d.color2,
            onChanged: (c) => setState(() => d.color2 = c),
          ),
        ],
      ],
    );
  }

  Widget _effectsTab(S s) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        Row(
          children: [
            Expanded(
              child: _SliderRow(
                icon: Icons.format_size_rounded,
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
        _Label(s.outline),
        _SliderRow(
          icon: Icons.border_color_rounded,
          value: d.strokeWidth,
          min: 0,
          max: 6,
          onChanged: (v) => setState(() => d.strokeWidth = v),
        ),
        if (d.strokeWidth > 0)
          ColorRow(
            selected: d.strokeColor,
            size: 30,
            onChanged: (c) => setState(() => d.strokeColor = c),
          ),
        _Label(s.letterSpacing),
        _SliderRow(
          icon: Icons.space_bar_rounded,
          value: d.letterSpacing,
          min: -2,
          max: 12,
          onChanged: (v) => setState(() => d.letterSpacing = v),
        ),
        _Label(s.lineHeight),
        _SliderRow(
          icon: Icons.format_line_spacing_rounded,
          value: d.lineHeight,
          min: 0.9,
          max: 2.2,
          onChanged: (v) => setState(() => d.lineHeight = v),
        ),
      ],
    );
  }

  Widget _curveTab(S s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            s.curveHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.sentiment_satisfied_alt_rounded),
              Expanded(
                child: Slider(
                  value: d.curve,
                  min: -1,
                  max: 1,
                  divisions: 40,
                  onChanged: (v) => setState(() => d.curve = v),
                ),
              ),
              const Icon(Icons.architecture_rounded),
            ],
          ),
          TextButton.icon(
            onPressed: () => setState(() => d.curve = 0),
            icon: const Icon(Icons.horizontal_rule_rounded),
            label: Text(s.straight),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final IconData icon;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: Icon(icon, size: 20),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
