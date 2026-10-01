import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:instagram_story_share/instagram_story_share.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/strings.dart';
import '../data/fonts.dart';
import '../models/story_layer.dart';
import '../widgets/story_view.dart';
import '../widgets/text_editor_sheet.dart';

/// Text sticker: text in the app's fonts and styles, exported as a PNG
/// with a transparent background to copy, save or share — e.g. pasted as
/// a sticker on an Instagram story.
class TextStickerScreen extends StatefulWidget {
  const TextStickerScreen({super.key});

  /// Export resolution relative to the preview (sharp on any phone).
  static const pixelRatio = 4.0;

  @override
  State<TextStickerScreen> createState() => _TextStickerScreenState();
}

class _TextStickerScreenState extends State<TextStickerScreen> {
  final _boundary = GlobalKey();
  StoryLayer _layer = StoryLayer(
    id: 'sticker',
    font: StoryFonts.byFamily('Aref Ruqaa'),
    color: Colors.white,
    fontSize: 40,
  );
  bool _darkPreview = true;
  bool _busy = false;

  bool get _empty => _layer.text.trim().isEmpty;

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _edit() async {
    final result = await showTextEditorSheet(context, _layer.clone());
    if (result != null && mounted) setState(() => _layer = result);
  }

  /// Renders the sticker to a transparent PNG file.
  Future<File> _render() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image =
        await boundary.toImage(pixelRatio: TextStickerScreen.pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/StoryCraft_sticker_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
    return file;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _empty) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() => _run(() async {
        final s = S.of(context);
        final ok = await InstagramStoryShare.copyImage((await _render()).path);
        if (mounted) _toast(ok ? s.tsCopied : s.tsCopyFailed);
      });

  Future<void> _save() => _run(() async {
        final s = S.of(context);
        try {
          if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
            throw StateError('denied');
          }
          await Gal.putImage((await _render()).path);
          if (mounted) _toast(s.tsSaved);
        } catch (_) {
          if (mounted) _toast(s.saveFailed);
        }
      });

  Future<void> _share() => _run(() async {
        final file = await _render();
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ));
      });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.tsTitle),
        actions: [
          IconButton(
            tooltip: s.tsDarkCheck,
            onPressed: () => setState(() => _darkPreview = !_darkPreview),
            icon: Icon(_darkPreview
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _edit,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: CustomPaint(
                    painter: _CheckerPainter(dark: _darkPreview),
                    child: Center(
                      child: _empty
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_rounded,
                                    size: 40,
                                    color: _darkPreview
                                        ? Colors.white70
                                        : Colors.black54),
                                const SizedBox(height: 8),
                                Text(s.tsTapToWrite,
                                    style: TextStyle(
                                        color: _darkPreview
                                            ? Colors.white
                                            : Colors.black87)),
                              ],
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: RepaintBoundary(
                                key: _boundary,
                                child: Padding(
                                  // Room for shadows and glows.
                                  padding: const EdgeInsets.all(14),
                                  child: Transform.rotate(
                                    angle: _layer.rotation,
                                    child: StoryLayerVisual(layer: _layer),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(s.tsHow,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                spacing: 8,
                children: [
                  IconButton.filledTonal(
                    tooltip: s.tsEdit,
                    onPressed: _edit,
                    icon: const Icon(Icons.text_fields_rounded),
                    style: IconButton.styleFrom(
                        minimumSize: const Size(50, 50)),
                  ),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _empty || _busy ? null : _copy,
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(s.tsCopy),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50)),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: s.save,
                    onPressed: _empty || _busy ? null : _save,
                    icon: const Icon(Icons.download_rounded),
                    style: IconButton.styleFrom(
                        minimumSize: const Size(50, 50)),
                  ),
                  IconButton.filledTonal(
                    tooltip: s.share,
                    onPressed: _empty || _busy ? null : _share,
                    icon: const Icon(Icons.ios_share_rounded),
                    style: IconButton.styleFrom(
                        minimumSize: const Size(50, 50)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The usual "transparent" checkerboard.
class _CheckerPainter extends CustomPainter {
  _CheckerPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 14.0;
    final a = Paint()
      ..color = dark ? const Color(0xFF2A2A2E) : const Color(0xFFFFFFFF);
    final b = Paint()
      ..color = dark ? const Color(0xFF3A3A40) : const Color(0xFFE6E6E6);
    canvas.drawRect(Offset.zero & size, a);
    for (var y = 0; y * cell < size.height; y++) {
      for (var x = (y % 2); x * cell < size.width; x += 2) {
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), b);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter old) => old.dark != dark;
}
