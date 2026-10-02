import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/strings.dart';
import '../data/surfaces.dart';
import '../models/story_background.dart';
import '../services/background_remover.dart';
import '../services/image_processing.dart';
import '../widgets/product_scene.dart';
import 'editor_screen.dart';

/// Product studio: the product is cut out of its photo and placed on a
/// ready-made surface (marble, wood, linen, studio…) with natural shadows,
/// an optional reflection and matched light — free and on the device.
class ProductStudioScreen extends StatefulWidget {
  const ProductStudioScreen({super.key});

  @override
  State<ProductStudioScreen> createState() => _ProductStudioScreenState();
}

class _ProductStudioScreenState extends State<ProductStudioScreen> {
  final _boundary = GlobalKey();
  Cutout? _cutout;
  StudioSurface _surface = studioSurfaces.first;
  Uint8List? _customBackground;
  ProductLook _look = const ProductLook();
  Offset _center = Offset.zero;
  double _width = 200;
  bool _busy = false;

  // Gesture start values.
  Offset _startCenter = Offset.zero;
  double _startWidth = 200;
  Offset _startFocal = Offset.zero;

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickProduct() async {
    final s = S.of(context);
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 95,
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final cut = await BackgroundRemover.cutout(await picked.readAsBytes());
      if (!mounted) return;
      setState(() {
        _cutout = cut;
        _placeDefault();
      });
    } on CutoutException catch (e) {
      _toast(switch (e.error) {
        CutoutError.unsupported => s.removeBgUnsupported,
        CutoutError.preparing => s.removeBgPreparing,
        CutoutError.noSubject => s.removeBgNoSubject,
        CutoutError.failed => s.processFailed,
      });
    } catch (_) {
      _toast(s.processFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Centered on the table (or low on a studio backdrop), sized to fit.
  void _placeDefault() {
    final cut = _cutout;
    if (cut == null) return;
    const size = productSceneSize;
    _width = math.min(size.width * 0.66, size.height * 0.48 / cut.aspect);
    final floor = _customBackground == null ? _surface.floor : null;
    final bottom = floor == null ? 0.86 : floor + (1 - floor) * 0.82;
    _center = Offset(size.width / 2, size.height * bottom);
  }

  Future<void> _pickBackground() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 2000, maxHeight: 2000);
    if (picked == null || !mounted) return;
    try {
      final bytes =
          await ImageProcessing.prepareImport(await picked.readAsBytes());
      if (mounted) setState(() => _customBackground = bytes);
    } catch (_) {
      if (mounted) _toast(S.of(context).processFailed);
    }
  }

  // --- Export ----------------------------------------------------------------

  Future<Uint8List> _render() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // 360x640 design space -> 1080x1920.
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) _toast(S.of(context).processFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
        final s = S.of(context);
        if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
          if (mounted) _toast(s.saveFailed);
          return;
        }
        await Gal.putImageBytes(await _render(),
            name: 'StoryCraft_product_${DateTime.now().millisecondsSinceEpoch}');
        if (mounted) _toast(s.saved);
      });

  Future<void> _share() => _run(() async {
        final png = await _render();
        final dir = await getTemporaryDirectory();
        final file = File(
            '${dir.path}/StoryCraft_product_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(png, flush: true);
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ));
      });

  Future<void> _design() => _run(() async {
        final jpg = await ImageProcessing.prepareImport(await _render());
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              EditorScreen(initialBackground: StoryBackground.image(jpg)),
        ));
      });

  // --- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cut = _cutout;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.psTitle),
        actions: [
          if (cut != null)
            IconButton(
              tooltip: s.psChange,
              onPressed: _busy ? null : _pickProduct,
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: cut == null ? _empty(s) : _studio(s, cut),
      ),
    );
  }

  Widget _empty(S s) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 72),
              const SizedBox(height: 16),
              Text(s.psPickHint, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _pickProduct,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_library_rounded),
                label: Text(_busy ? s.psCutting : s.psPick),
              ),
            ],
          ),
        ),
      );

  Widget _studio(S s, Cutout cut) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final k = box.maxWidth / productSceneSize.width;
                    return GestureDetector(
                      onScaleStart: (d) {
                        _startCenter = _center;
                        _startWidth = _width;
                        _startFocal = d.localFocalPoint;
                      },
                      onScaleUpdate: (d) => setState(() {
                        _center = _startCenter +
                            (d.localFocalPoint - _startFocal) / k;
                        _width = (_startWidth * d.scale).clamp(40.0, 520.0);
                      }),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: FittedBox(
                          child: RepaintBoundary(
                            key: _boundary,
                            child: ProductScene(
                              product: cut.png,
                              productAspect: cut.aspect,
                              center: _center,
                              width: _width,
                              look: _look,
                              surface: _surface,
                              customBackground: _customBackground,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Text(s.psDragHint, style: Theme.of(context).textTheme.bodySmall),
        DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(tabs: [Tab(text: s.psSurface), Tab(text: s.psLight)]),
              SizedBox(
                height: 150,
                child: TabBarView(children: [_surfaces(s), _lightTab(s)]),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            spacing: 8,
            children: [
              IconButton.filledTonal(
                tooltip: s.save,
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.download_rounded),
                style: IconButton.styleFrom(minimumSize: const Size(50, 50)),
              ),
              IconButton.filledTonal(
                tooltip: s.share,
                onPressed: _busy ? null : _share,
                icon: const Icon(Icons.ios_share_rounded),
                style: IconButton.styleFrom(minimumSize: const Size(50, 50)),
              ),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _design,
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(s.designStory),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _surfaces(S s) => ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        children: [
          _SurfaceTile(
            label: s.psFromPhotos,
            selected: _customBackground != null,
            onTap: _pickBackground,
            child: _customBackground != null
                ? Image.memory(_customBackground!,
                    fit: BoxFit.cover, cacheWidth: 120)
                : const ColoredBox(
                    color: Color(0x22000000),
                    child: Icon(Icons.add_photo_alternate_outlined),
                  ),
          ),
          for (final surface in studioSurfaces)
            _SurfaceTile(
              label: surface.label(s.isArabic),
              selected: _customBackground == null && surface == _surface,
              onTap: () => setState(() {
                final moved = _surface.floor != surface.floor;
                _surface = surface;
                _customBackground = null;
                if (moved) _placeDefault();
              }),
              child: Image.asset(surface.asset,
                  fit: BoxFit.cover, cacheWidth: 120),
            ),
        ],
      );

  Widget _lightTab(S s) {
    Widget slider(String label, double value, double min,
            ValueChanged<double> onChanged) =>
        Row(
          children: [
            SizedBox(width: 110, child: Text(label)),
            Expanded(
              child: Slider(
                  value: value, min: min, max: 1, onChanged: onChanged),
            ),
          ],
        );
    final glossy = _customBackground == null && _surface.glossy;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      children: [
        Center(
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.crop_landscape_rounded),
                  label: Text(s.psLying)),
              ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.crop_portrait_rounded),
                  label: Text(s.psStanding)),
            ],
            selected: {_look.standing},
            onSelectionChanged: (v) =>
                setState(() => _look = _look.copyWith(standing: v.first)),
          ),
        ),
        slider(s.psShadow, _look.shadow, 0,
            (v) => setState(() => _look = _look.copyWith(shadow: v))),
        if (glossy && _look.standing)
          slider(s.psReflection, _look.reflection, 0,
              (v) => setState(() => _look = _look.copyWith(reflection: v))),
        slider(s.psBrightness, _look.brightness, -1,
            (v) => setState(() => _look = _look.copyWith(brightness: v))),
        if (_customBackground == null)
          slider(s.psMatch, _look.match, 0,
              (v) => setState(() => _look = _look.copyWith(match: v))),
        slider(s.psBlur, _look.blur, 0,
            (v) => setState(() => _look = _look.copyWith(blur: v))),
      ],
    );
  }
}

class _SurfaceTile extends StatelessWidget {
  const _SurfaceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsetsDirectional.only(end: 8),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 92,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 3 : 1,
                ),
              ),
              child: SizedBox.expand(child: child),
            ),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
