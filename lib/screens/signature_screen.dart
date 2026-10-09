import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../data/fonts.dart';
import '../models/story_layer.dart';
import '../services/signature_store.dart';
import '../widgets/color_picker.dart';
import '../widgets/signature_view.dart';

/// Signature studio: type a name, pick one of the generated designs,
/// adjust style and color, save. Pops with the chosen signature layer.
class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final _name = TextEditingController();
  int? _selected;
  SignatureStyle? _styleOverride;
  TextFill _fill = TextFill.solid;
  Color _color = Colors.white;
  bool _darkPreview = true;

  static const _arabicFonts = [
    'Aref Ruqaa', 'Gulzar', 'Noto Nastaliq Urdu', 'Alkalami', 'Rakkas',
    'Katibeh', 'Amiri', 'Reem Kufi', 'Lateef', 'Ruwudu', 'El Messiri',
    'Marhey',
  ];
  static const _englishFonts = [
    'Great Vibes', 'Sacramento', 'Allura', 'Parisienne', 'Dancing Script',
    'Satisfy', 'Yellowtail', 'Pacifico', 'Kaushan Script', 'Cinzel',
    'Playfair Display', 'Caveat',
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _text => _name.text.trim();

  /// 18 suggestions: fonts paired with a rotating decoration style.
  List<StoryLayer> _options(S s) {
    final text = _text.isEmpty ? (s.isArabic ? 'اسمك' : 'Your Name') : _text;
    final fonts = StoryFonts.hasArabic(text) ? _arabicFonts : _englishFonts;
    // Ornamental designs first; each font gets its own decoration.
    const styles = [
      SignatureStyle.emblem, SignatureStyle.lockup, SignatureStyle.brush,
      SignatureStyle.arch, SignatureStyle.ribbon, SignatureStyle.corners,
      SignatureStyle.ornate, SignatureStyle.laurel, SignatureStyle.royal,
      SignatureStyle.arabesque, SignatureStyle.swash, SignatureStyle.divider,
      SignatureStyle.sparkle, SignatureStyle.seal, SignatureStyle.monogram,
      SignatureStyle.framed, SignatureStyle.underline, SignatureStyle.plain,
    ];
    return [
      for (var i = 0; i < styles.length; i++)
        StoryLayer(
          id: 'opt$i',
          kind: LayerKind.signature,
          text: text,
          font: StoryFonts.byFamily(fonts[i % fonts.length]),
          fontSize: 40,
          color: _color,
          fill: _fill,
          signatureStyle: styles[i],
        ),
    ];
  }

  StoryLayer? _current(S s) {
    final i = _selected;
    if (i == null) return null;
    final opt = _options(s)[i];
    if (_styleOverride != null) opt.signatureStyle = _styleOverride!;
    return opt;
  }

  Future<void> _save(S s) async {
    final sig = _current(s);
    if (sig == null || _text.isEmpty) return;
    await SignatureStore.instance.add(sig);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.signatureSaved)));
    Navigator.pop(context, sig);
  }

  Future<void> _confirmDelete(S s, StoryLayer sig) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteSignature),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok == true) await SignatureStore.instance.remove(sig.id);
  }

  String _styleLabel(S s, SignatureStyle st) => switch (st) {
        SignatureStyle.swash => s.sigSwash,
        SignatureStyle.plain => s.sigPlain,
        SignatureStyle.underline => s.sigUnderline,
        SignatureStyle.seal => s.sigSeal,
        SignatureStyle.monogram => s.sigMonogram,
        SignatureStyle.framed => s.sigFramed,
        SignatureStyle.ornate => s.sigOrnate,
        SignatureStyle.laurel => s.sigLaurel,
        SignatureStyle.royal => s.sigRoyal,
        SignatureStyle.arabesque => s.sigArabesque,
        SignatureStyle.divider => s.sigDivider,
        SignatureStyle.sparkle => s.sigSparkle,
        SignatureStyle.emblem => s.sigEmblem,
        SignatureStyle.ribbon => s.sigRibbon,
        SignatureStyle.brush => s.sigBrush,
        SignatureStyle.lockup => s.sigLockup,
        SignatureStyle.corners => s.sigCorners,
        SignatureStyle.arch => s.sigArch,
      };

  String _fillLabel(S s, TextFill f) => switch (f) {
        TextFill.solid => s.color,
        TextFill.gradient => s.fillGradient,
        TextFill.gold => s.fillGold,
        TextFill.silver => s.fillSilver,
        TextFill.rose => s.fillRose,
      };

  Widget _card(StoryLayer sig, {bool selected = false, bool dimmed = false,
      VoidCallback? onTap, VoidCallback? onLongPress, double height = 110}) {
    const accent = Color(0xFF7B4DFF);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: selected ? 1.0 : (dimmed ? 0.94 : 1.0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: dimmed ? 0.55 : 1,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: height,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _darkPreview
                      ? const Color(0xFF1C1C22)
                      : const Color(0xFFF3F0EA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? accent : Colors.transparent,
                    width: 4,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.55),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Center(child: FittedBox(child: SignatureView(layer: sig))),
              ),
              // Check badge on the chosen design.
              if (selected)
                PositionedDirectional(
                  top: -8,
                  start: -8,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final options = _options(s);
    final current = _current(s);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.signature),
        actions: [
          IconButton(
            tooltip: 'Preview background',
            onPressed: () => setState(() => _darkPreview = !_darkPreview),
            icon: Icon(_darkPreview
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              // Saved signatures: tap to use, long-press to delete.
              ValueListenableBuilder<List<StoryLayer>>(
                valueListenable: SignatureStore.instance,
                builder: (context, saved, _) {
                  if (saved.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.savedSignatures, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: saved.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, i) => SizedBox(
                            width: 160,
                            child: _card(
                              saved[i],
                              height: 90,
                              onTap: () => Navigator.pop(context, saved[i]),
                              onLongPress: () => _confirmDelete(s, saved[i]),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(s.newSignature, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
              TextField(
                controller: _name,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
                decoration: InputDecoration(
                  hintText: s.yourName,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Color / metallic fill.
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final f in TextFill.values.where((f) => f != TextFill.gradient))
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: ChoiceChip(
                          label: Text(_fillLabel(s, f)),
                          selected: _fill == f,
                          onSelected: (_) => setState(() => _fill = f),
                        ),
                      ),
                  ],
                ),
              ),
              if (_fill == TextFill.solid)
                ColorRow(
                  selected: _color,
                  onChanged: (c) => setState(() => _color = c),
                ),
              const SizedBox(height: 16),

              Text(s.chooseStyle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(6),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisExtent: 120,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                ),
                itemCount: options.length,
                itemBuilder: (context, i) => _card(
                  options[i],
                  selected: _selected == i,
                  dimmed: _selected != null && _selected != i,
                  onTap: () => setState(() {
                    _selected = i;
                    _styleOverride = null;
                  }),
                ),
              ),

              // Fine-tune the chosen design's decoration.
              if (current != null) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final st in SignatureStyle.values)
                      ChoiceChip(
                        label: Text(_styleLabel(s, st)),
                        selected: current.signatureStyle == st,
                        onSelected: (_) => setState(() => _styleOverride = st),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed:
                current == null || _text.isEmpty ? null : () => _save(s),
            icon: const Icon(Icons.check_rounded),
            label: Text(s.saveSignature),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
      ),
    );
  }
}
