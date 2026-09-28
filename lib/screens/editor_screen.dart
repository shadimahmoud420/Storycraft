import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../data/fonts.dart';
import '../data/formats.dart';
import '../models/story_background.dart';
import '../models/story_layer.dart';
import '../services/brand_kit.dart';
import '../services/draft_store.dart';
import '../services/image_processing.dart';
import '../services/signature_store.dart';
import '../services/story_exporter.dart';
import '../state/editor_controller.dart';
import '../widgets/background_sheet.dart';
import '../widgets/color_picker.dart';
import '../widgets/signature_view.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/quotes_sheet.dart';
import '../widgets/sticker_sheet.dart';
import '../widgets/story_canvas.dart';
import '../widgets/text_editor_sheet.dart';
import 'brand_kit_screen.dart';
import 'signature_screen.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.initialBackground,
    this.initialLayers = const [],
    this.initialFormat = StoryFormat.story,
    this.draftId,
    this.openBackgroundSheet = false,
  });

  final StoryBackground initialBackground;
  final List<StoryLayer> initialLayers;
  final StoryFormat initialFormat;

  /// Set when reopening a saved draft; a new id is created otherwise.
  final String? draftId;
  final bool openBackgroundSheet;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditorController _controller = EditorController(
    widget.initialBackground,
    layers: widget.initialLayers,
    format: widget.initialFormat,
  );
  final _boundaryKey = GlobalKey();
  late final _exporter = StoryExporter(_boundaryKey);
  late final String _draftId = widget.draftId ?? DraftStore.instance.newId();
  Timer? _autosave;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_scheduleAutosave);
    if (widget.openBackgroundSheet) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => mounted ? _openBackground() : null);
    }
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // --- Drafts ---------------------------------------------------------------

  void _scheduleAutosave() {
    if (!_controller.hasChanges) return;
    _autosave?.cancel();
    _autosave = Timer(const Duration(seconds: 2), _saveDraft);
  }

  Future<void> _saveDraft() async {
    _autosave?.cancel();
    if (!_controller.hasChanges || _controller.isBusy) return;
    _controller.markSaved();
    Uint8List? thumb;
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null && !boundary.debugNeedsPaint) {
        final image = await boundary.toImage(pixelRatio: 0.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        thumb = data?.buffer.asUint8List();
      }
    } catch (_) {}
    try {
      await DraftStore.instance.save(
        _draftId,
        _controller.background,
        _controller.layers,
        format: _controller.format,
        thumbnail: thumb,
      );
    } catch (_) {}
  }

  // --- Actions --------------------------------------------------------------

  StoryFont _defaultFont(S s) =>
      BrandKitStore.instance.value.font ??
      (s.isArabic ? StoryFonts.arabic.first : StoryFonts.english.first);

  Future<void> _addText() async {
    final s = S.of(context);
    final draft = StoryLayer(
      id: 'draft',
      font: _defaultFont(s),
      color: _controller.suggestTextColor(),
      shadow: _controller.background.isImage,
    );
    final result = await showTextEditorSheet(context, draft);
    if (result == null) return;
    _controller.addLayer(result);
  }

  Future<void> _addQuote() async {
    final text = await showQuotesSheet(context);
    if (text == null || !mounted) return;
    final kitFont = BrandKitStore.instance.value.font;
    final font = kitFont != null && kitFont.arabic == StoryFonts.hasArabic(text)
        ? kitFont
        : StoryFonts.hasArabic(text)
            ? StoryFonts.byFamily('Amiri')
            : StoryFonts.byFamily('Playfair Display');
    _controller.addText(text, font: font, fontSize: 28);
  }

  Future<void> _addSticker() async {
    final choice = await showStickerSheet(context);
    switch (choice) {
      case ArtChoice(:final name):
        _controller.addArt(name);
      case EmojiChoice(:final text):
        _controller.addEmoji(text);
      case ShapeChoice(:final shape):
        _controller.addShape(shape);
      case null:
        break;
    }
  }

  Future<void> _editLayer(StoryLayer layer) async {
    switch (layer.kind) {
      case LayerKind.text:
        final result = await showTextEditorSheet(context, layer);
        if (result == null) return;
        _controller.updateLayer(layer.id, (l) {
          l
            ..text = result.text
            ..font = result.font
            ..color = result.color
            ..fontSize = result.fontSize
            ..align = result.align
            ..highlight = result.highlight
            ..shadow = result.shadow
            ..fill = result.fill
            ..color2 = result.color2
            ..strokeWidth = result.strokeWidth
            ..strokeColor = result.strokeColor
            ..letterSpacing = result.letterSpacing
            ..lineHeight = result.lineHeight
            ..curve = result.curve;
        });
      case LayerKind.shape:
      case LayerKind.emoji:
      case LayerKind.signature:
        await _editColor(layer);
      case LayerKind.image:
      case LayerKind.art:
        break;
    }
  }

  /// Degrees folded into (-180, 180], so +15° past 180° wraps around.
  static double _wrapDegrees(double d) {
    final x = d % 360;
    return x > 180 ? x - 360 : x;
  }

  /// Exact rotation (degrees) and size (%) for any layer: a slider with
  /// fine steps and quick presets. The whole session is one undo step.
  Future<void> _editTransform(StoryLayer layer) async {
    final s = S.of(context);
    _controller.checkpoint();
    double deg() => _wrapDegrees(layer.rotation * 180 / math.pi);

    void setDeg(double d) => _controller.updateLayer(
          layer.id,
          (l) => l.rotation = _wrapDegrees(d) * math.pi / 180,
          record: false,
        );
    void setScale(double v) => _controller.updateLayer(
          layer.id,
          (l) => l.scale = v.clamp(0.3, 6.0),
          record: false,
        );

    await showModalBottomSheet<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final theme = Theme.of(context);
          final d = deg();
          Widget step(String label, double delta) => Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () => setDeg(delta == 0 ? 0 : d + delta),
                  child: FittedBox(
                    child: Text(label, textDirection: TextDirection.ltr),
                  ),
                ),
              );
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(s.rotation, style: theme.textTheme.titleMedium),
                      const Spacer(),
                      Text(
                        '${d.round()}°',
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  Directionality(
                    // Degrees read left-to-right like a protractor.
                    textDirection: TextDirection.ltr,
                    child: Slider(
                      value: d.clamp(-180.0, 180.0),
                      min: -180,
                      max: 180,
                      divisions: 360,
                      label: '${d.round()}°',
                      onChanged: setDeg,
                    ),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      spacing: 4,
                      children: [
                        step('−90°', -90),
                        step('−15°', -15),
                        step('−1°', -1),
                        step('0°', 0),
                        step('+1°', 1),
                        step('+15°', 15),
                        step('+90°', 90),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(s.scaleLabel, style: theme.textTheme.titleMedium),
                      const Spacer(),
                      Text(
                        '${(layer.scale * 100).round()}%',
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Slider(
                      value: layer.scale.clamp(0.3, 6.0),
                      min: 0.3,
                      max: 6,
                      label: '${(layer.scale * 100).round()}%',
                      onChanged: setScale,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setDeg(0);
                      setScale(1);
                    },
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: Text(s.reset),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Color for shapes and symbols, applied live (one undo step).
  Future<void> _editColor(StoryLayer layer) async {
    final s = S.of(context);
    _controller.checkpoint();
    await showModalBottomSheet<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.color, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ColorRow(
                  selected: layer.color,
                  onChanged: (c) {
                    _controller.updateLayer(layer.id, (l) {
                      l.color = c;
                      l.fill = TextFill.solid;
                    }, record: false);
                    setSheet(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFormat() async {
    final s = S.of(context);
    final items = [
      (StoryFormat.story, s.fmtStory, s.fmtStoryHint),
      (StoryFormat.portrait, s.fmtPortrait, s.fmtPortraitHint),
      (StoryFormat.square, s.fmtSquare, s.fmtSquareHint),
      (StoryFormat.wide, s.fmtWide, s.fmtWideHint),
    ];
    final picked = await showModalBottomSheet<StoryFormat>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (format, title, hint) in items)
              ListTile(
                leading: SizedBox(
                  width: 36,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: format.aspectRatio,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                title: Text(title),
                subtitle: Text(hint),
                trailing: format == _controller.format
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, format),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) _controller.setFormat(picked);
  }

  /// Saved signatures (tap to add) + create a new one.
  Future<void> _openSignatures() async {
    final s = S.of(context);
    final saved = SignatureStore.instance.value;
    Future<void> create() async {
      final sig = await Navigator.of(context).push<StoryLayer>(
        MaterialPageRoute(builder: (_) => const SignatureScreen()),
      );
      if (sig != null) _controller.addSignature(sig);
    }

    if (saved.isEmpty) return create();
    final picked = await showModalBottomSheet<Object>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.savedSignatures,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: saved.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => Navigator.pop(context, saved[i]),
                    child: Container(
                      width: 160,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C22),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: FittedBox(child: SignatureView(layer: saved[i])),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'new'),
                icon: const Icon(Icons.add_rounded),
                label: Text(s.newSignature),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked is StoryLayer) {
      _controller.addSignature(picked);
    } else if (picked == 'new' && mounted) {
      await create();
    }
  }

  Future<void> _openBackground() => showBackgroundSheet(
        context,
        controller: _controller,
        onPickPhoto: _pickPhoto,
      );

  Future<void> _openBrandKit() async {
    final s = S.of(context);
    final kit = BrandKitStore.instance.value;
    if (kit.isEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BrandKitScreen()),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (kit.logo != null)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _controller.addImage(kit.logo!);
                  },
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: Text(s.addLogo),
                ),
              if (kit.colors.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(s.useAsBackground),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in kit.colors)
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _controller.setBackground(StoryBackground.solid(c));
                        },
                        child: CircleAvatar(radius: 20, backgroundColor: c),
                      ),
                    if (kit.colors.length > 1)
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _controller.setBackground(
                              StoryBackground.gradient(kit.colors));
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: kit.colors),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const BrandKitScreen(),
                  ));
                },
                icon: const Icon(Icons.tune_rounded),
                label: Text(s.brandKit),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final s = S.of(context);
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 95,
    );
    if (picked == null) return;
    try {
      final bytes =
          await ImageProcessing.prepareImport(await picked.readAsBytes());
      _controller.setBackground(StoryBackground.image(bytes));
    } catch (_) {
      if (mounted) _toast(s.processFailed);
    }
  }

  Future<void> _runImageOp(ImageOperation op) async {
    final s = S.of(context);
    final ok = await _controller.runImageOperation(op);
    if (!mounted) return;
    _toast(ok
        ? (op == ImageOperation.natural ? s.naturalDone : s.enhanceDone)
        : s.processFailed);
  }

  Future<void> _export(Future<void> Function() action) async {
    if (_exporting) return;
    _controller.select(null); // hide the selection frame in the export
    setState(() => _exporting = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _save() => _export(() async {
        final s = S.of(context);
        final ok = await _exporter.saveToGallery();
        if (mounted) _toast(ok ? s.saved : s.saveFailed);
      });

  Future<void> _share() async {
    final s = S.of(context);
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: Text(s.shareToStory),
              onTap: () => Navigator.pop(context, 0),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: Text(s.shareOther),
              onTap: () => Navigator.pop(context, 1),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await _export(() async {
      if (choice == 0) {
        final result = await _exporter.shareToInstagramStory();
        if (result == StoryShareOutcome.failed && mounted) {
          _toast(s.instagramMissing);
        }
      } else {
        await _exporter.shareViaSheet();
      }
    });
  }

  /// Leaving never loses work: unsaved changes go to "My drafts".
  Future<void> _leave() async {
    final s = S.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final hadChanges = _controller.hasChanges;
    _controller.select(null);
    await WidgetsBinding.instance.endOfFrame;
    await _saveDraft();
    if (hadChanges) {
      messenger.showSnackBar(SnackBar(content: Text(s.draftSaved)));
    }
    navigator.pop();
  }

  // --- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Theme(
        data: AppTheme.build(Brightness.dark),
        child: Scaffold(
          backgroundColor: const Color(0xFF0E0E10),
          body: SafeArea(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final c = _controller;
                final bg = c.background;
                return Column(
                  children: [
                    _TopBar(
                      exporting: _exporting,
                      canUndo: c.canUndo,
                      canRedo: c.canRedo,
                      onClose: _leave,
                      onUndo: c.undo,
                      onRedo: c.redo,
                      onSave: _save,
                      onShare: _share,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: StoryCanvas(
                                controller: c,
                                boundaryKey: _boundaryKey,
                                onEditLayer: _editLayer,
                              ),
                            ),
                            if (c.layers.isEmpty && !c.isBusy)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 24,
                                child: IgnorePointer(
                                  child: Center(
                                    child: _Hint(bg.isImage
                                        ? s.photoHint
                                        : s.tapToAddText),
                                  ),
                                ),
                              ),
                            if (c.isBusy)
                              Positioned.fill(
                                  child: _BusyOverlay(s.processing)),
                          ],
                        ),
                      ),
                    ),
                    if (c.selected != null)
                      _SelectionBar(
                        canEdit: c.selected!.kind != LayerKind.image &&
                            c.selected!.kind != LayerKind.art,
                        editLabel: c.selected!.isText ? s.text : s.style,
                        onEdit: () => _editLayer(c.selected!),
                        onTransform: () => _editTransform(c.selected!),
                        onDuplicate: () => c.duplicateLayer(c.selectedId!),
                        onDelete: () => c.removeLayer(c.selectedId!),
                      ),
                    _ToolBar(
                      children: [
                        _Tool(
                          icon: Icons.text_fields_rounded,
                          label: s.text,
                          onTap: _addText,
                        ),
                        _Tool(
                          icon: Icons.format_quote_rounded,
                          label: s.quotes,
                          onTap: _addQuote,
                        ),
                        _Tool(
                          icon: Icons.emoji_emotions_rounded,
                          label: s.stickers,
                          onTap: _addSticker,
                        ),
                        _Tool(
                          icon: Icons.palette_rounded,
                          label: s.background,
                          onTap: _openBackground,
                        ),
                        _Tool(
                          icon: Icons.draw_rounded,
                          label: s.signature,
                          onTap: _openSignatures,
                        ),
                        _Tool(
                          icon: Icons.storefront_rounded,
                          label: s.brandKit,
                          onTap: _openBrandKit,
                        ),
                        _Tool(
                          icon: Icons.aspect_ratio_rounded,
                          label: s.format,
                          onTap: _openFormat,
                        ),
                        if (bg.isImage) ...[
                          _Tool(
                            icon: Icons.wb_sunny_rounded,
                            label: s.natural,
                            busy: c.busy == ImageOperation.natural,
                            onTap: c.isBusy
                                ? null
                                : () => _runImageOp(ImageOperation.natural),
                          ),
                          _Tool(
                            icon: Icons.auto_awesome_rounded,
                            label: s.enhance,
                            highlight: true,
                            busy: c.busy == ImageOperation.enhance,
                            onTap: c.isBusy
                                ? null
                                : () => _runImageOp(ImageOperation.enhance),
                          ),
                          _Tool(
                            icon: Icons.filter_vintage_rounded,
                            label: s.filters,
                            onTap: c.isBusy
                                ? null
                                : () => showFilterSheet(context, c),
                          ),
                          _Tool(
                            icon: Icons.contrast_rounded,
                            label: bg.dim == 0
                                ? s.dim
                                : '${s.dim} ${(bg.dim * 100).round()}%',
                            onTap: c.cycleDim,
                          ),
                          _Tool(
                            icon: bg.imageFit == ImageFit.cover
                                ? Icons.fit_screen_rounded
                                : Icons.crop_portrait_rounded,
                            label: s.fit,
                            onTap: c.toggleImageFit,
                          ),
                          if (bg.isModified)
                            _Tool(
                              icon: Icons.restore_rounded,
                              label: s.original,
                              onTap:
                                  c.isBusy ? null : c.restoreOriginalImage,
                            ),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.exporting,
    required this.canUndo,
    required this.canRedo,
    required this.onClose,
    required this.onUndo,
    required this.onRedo,
    required this.onSave,
    required this.onShare,
  });

  final bool exporting;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onClose;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            tooltip: s.cancel,
          ),
          // Undo/redo arrows follow the reading direction automatically.
          IconButton(
            onPressed: canUndo ? onUndo : null,
            icon: const Icon(Icons.undo_rounded),
            tooltip: s.undo,
          ),
          IconButton(
            onPressed: canRedo ? onRedo : null,
            icon: const Icon(Icons.redo_rounded),
            tooltip: s.redo,
          ),
          const Spacer(),
          IconButton.filledTonal(
            onPressed: exporting ? null : onSave,
            icon: const Icon(Icons.download_rounded),
            tooltip: s.save,
          ),
          const SizedBox(width: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextButton.icon(
              onPressed: exporting ? null : onShare,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              icon: exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              label: Text(s.share),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolBar extends StatelessWidget {
  const _ToolBar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ConstrainedBox(
            // Spread evenly on wide screens, scroll on narrow ones.
            constraints: BoxConstraints(minWidth: constraints.maxWidth - 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: enabled || busy ? 1 : 0.4,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: highlight ? AppTheme.brandGradient : null,
                  color: highlight ? null : Colors.white.withValues(alpha: 0.1),
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(icon, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.canEdit,
    required this.editLabel,
    required this.onEdit,
    required this.onTransform,
    required this.onDuplicate,
    required this.onDelete,
  });

  final bool canEdit;
  final String editLabel;
  final VoidCallback onEdit;
  final VoidCallback onTransform;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      // One scrollable row, so the canvas never loses height to a 2nd line.
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            spacing: 8,
            children: [
          if (canEdit)
            ActionChip(
              avatar: const Icon(Icons.edit_rounded, size: 18),
              label: Text(editLabel),
              onPressed: onEdit,
            ),
          ActionChip(
            avatar: const Icon(Icons.rotate_right_rounded, size: 18),
            label: Text(s.rotateResize),
            onPressed: onTransform,
          ),
          ActionChip(
            avatar: const Icon(Icons.copy_rounded, size: 18),
            label: Text(s.duplicate),
            onPressed: onDuplicate,
          ),
          ActionChip(
            avatar: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(s.delete),
            onPressed: onDelete,
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black38,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 12),
            Text(text, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
