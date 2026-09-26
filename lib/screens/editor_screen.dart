import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../data/fonts.dart';
import '../models/story_background.dart';
import '../models/text_layer.dart';
import '../services/image_processing.dart';
import '../services/story_exporter.dart';
import '../state/editor_controller.dart';
import '../widgets/background_sheet.dart';
import '../widgets/story_canvas.dart';
import '../widgets/text_editor_sheet.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.initialBackground,
    this.openBackgroundSheet = false,
  });

  final StoryBackground initialBackground;
  final bool openBackgroundSheet;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditorController _controller =
      EditorController(widget.initialBackground);
  final _boundaryKey = GlobalKey();
  late final _exporter = StoryExporter(_boundaryKey);
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    if (widget.openBackgroundSheet) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => mounted ? _openBackground() : null);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // --- Actions --------------------------------------------------------------

  Future<void> _addText() async {
    final s = S.of(context);
    final draft = TextLayer(
      id: 'draft',
      text: '',
      font: s.isArabic ? StoryFonts.arabic.first : StoryFonts.english.first,
      color: _controller.suggestTextColor(),
      shadow: _controller.background.isImage,
    );
    final result = await showTextEditorSheet(context, draft);
    if (result == null) return;
    final layer = _controller.addText(result.text, font: result.font);
    _controller.updateLayer(layer.id, (l) {
      l
        ..color = result.color
        ..fontSize = result.fontSize
        ..align = result.align
        ..highlight = result.highlight
        ..shadow = result.shadow;
    });
  }

  Future<void> _editLayer(TextLayer layer) async {
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
        ..shadow = result.shadow;
    });
  }

  Future<void> _openBackground() => showBackgroundSheet(
        context,
        controller: _controller,
        onPickPhoto: _pickPhoto,
      );

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

  Future<bool> _confirmLeave() async {
    if (!_controller.hasChanges) return true;
    final s = S.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.discardTitle),
        content: Text(s.discardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.discard),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  // --- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) navigator.pop();
      },
      child: Theme(
        data: AppTheme.build(Brightness.dark),
        child: Scaffold(
          backgroundColor: const Color(0xFF0E0E10),
          body: SafeArea(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => Column(
                children: [
                  _TopBar(
                    exporting: _exporting,
                    onClose: () => Navigator.maybePop(context),
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
                              controller: _controller,
                              boundaryKey: _boundaryKey,
                              onEditLayer: _editLayer,
                            ),
                          ),
                          if (_controller.layers.isEmpty && !_controller.isBusy)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 24,
                              child: IgnorePointer(
                                child: Center(child: _Hint(s.tapToAddText)),
                              ),
                            ),
                          if (_controller.isBusy)
                            Positioned.fill(child: _BusyOverlay(s.processing)),
                        ],
                      ),
                    ),
                  ),
                  if (_controller.selected != null)
                    _SelectionBar(
                      onEdit: () => _editLayer(_controller.selected!),
                      onDuplicate: () =>
                          _controller.duplicateLayer(_controller.selectedId!),
                      onDelete: () =>
                          _controller.removeLayer(_controller.selectedId!),
                    ),
                  _ToolBar(
                    children: [
                      _Tool(
                        icon: Icons.text_fields_rounded,
                        label: s.text,
                        onTap: _addText,
                      ),
                      _Tool(
                        icon: Icons.palette_rounded,
                        label: s.background,
                        onTap: _openBackground,
                      ),
                      if (_controller.background.isImage) ...[
                        _Tool(
                          icon: Icons.wb_sunny_rounded,
                          label: s.natural,
                          busy: _controller.busy == ImageOperation.natural,
                          onTap: _controller.isBusy
                              ? null
                              : () => _runImageOp(ImageOperation.natural),
                        ),
                        _Tool(
                          icon: Icons.auto_awesome_rounded,
                          label: s.enhance,
                          highlight: true,
                          busy: _controller.busy == ImageOperation.enhance,
                          onTap: _controller.isBusy
                              ? null
                              : () => _runImageOp(ImageOperation.enhance),
                        ),
                        _Tool(
                          icon: _controller.background.imageFit ==
                                  ImageFit.cover
                              ? Icons.fit_screen_rounded
                              : Icons.crop_portrait_rounded,
                          label: s.fit,
                          onTap: _controller.toggleImageFit,
                        ),
                        if (_controller.background.isModified)
                          _Tool(
                            icon: Icons.undo_rounded,
                            label: s.original,
                            onTap: _controller.isBusy
                                ? null
                                : _controller.restoreOriginalImage,
                          ),
                      ],
                    ],
                  ),
                ],
              ),
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
    required this.onClose,
    required this.onSave,
    required this.onShare,
  });

  final bool exporting;
  final VoidCallback onClose;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            tooltip: s.cancel,
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
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        alignment: WrapAlignment.center,
        children: [
          ActionChip(
            avatar: const Icon(Icons.edit_rounded, size: 18),
            label: Text(s.text),
            onPressed: onEdit,
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
