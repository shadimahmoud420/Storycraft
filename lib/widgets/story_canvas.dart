import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/formats.dart';
import '../models/story_background.dart';
import '../models/story_layer.dart';
import '../services/app_settings.dart';
import 'ornament_painter.dart';
import '../state/editor_controller.dart';
import 'story_view.dart';

/// The 9:16 story. Everything inside [boundaryKey] is what gets exported,
/// designed on a fixed 360 x 640 canvas and scaled to fit any screen.
class StoryCanvas extends StatelessWidget {
  const StoryCanvas({
    super.key,
    required this.controller,
    required this.boundaryKey,
    required this.onEditLayer,
    this.onWatermarkTap,
  });

  final EditorController controller;
  final GlobalKey boundaryKey;
  final ValueChanged<StoryLayer> onEditLayer;
  final VoidCallback? onWatermarkTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final canvas = controller.canvasSize;
        return LayoutBuilder(
          builder: (context, constraints) {
            final viewScale = math.min(
              constraints.maxWidth / canvas.width,
              constraints.maxHeight / canvas.height,
            );
            return Center(
              child: SizedBox(
                width: canvas.width * viewScale,
                height: canvas.height * viewScale,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: FittedBox(
                    child: SizedBox(
                      width: canvas.width,
                      height: canvas.height,
                      child: _CanvasContent(
                        controller: controller,
                        boundaryKey: boundaryKey,
                        viewScale: viewScale,
                        onEditLayer: onEditLayer,
                        onWatermarkTap: onWatermarkTap,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CanvasContent extends StatefulWidget {
  const _CanvasContent({
    required this.controller,
    required this.boundaryKey,
    required this.viewScale,
    required this.onEditLayer,
    this.onWatermarkTap,
  });

  final EditorController controller;
  final GlobalKey boundaryKey;
  final double viewScale;
  final ValueChanged<StoryLayer> onEditLayer;
  final VoidCallback? onWatermarkTap;

  @override
  State<_CanvasContent> createState() => _CanvasContentState();
}

class _CanvasContentState extends State<_CanvasContent> {
  static const _snapDistance = 6.0;

  // Gesture bookkeeping.
  Offset _lastFocal = Offset.zero;
  double _baseScale = 1;
  double _baseRotation = 0;
  bool _recorded = false;
  bool _dragging = false;
  bool _snapX = false;
  bool _snapY = false;
  // Unsnapped position, so snapping never "sticks" the layer.
  Offset _freePosition = Offset.zero;
  // Live rotation/scale readout while pinching ("45° · 120%").
  String? _hud;
  bool _rotationSnapped = false;

  /// Snap to multiples of 45° within ±4° so straight text is easy.
  static const _rotationSnapDeg = 4.0;

  // App mark placement: the first candidate spot not covered by a layer.
  final _visualKeys = <String, GlobalKey>{};
  Offset? _markSpot;
  static const _markSize = Size(106, 28);

  GlobalKey _keyFor(String id) => _visualKeys.putIfAbsent(id, GlobalKey.new);

  /// Candidate spots, best first: above Instagram's reply bar, then the
  /// bottom corners, then under the profile header at the top.
  List<Offset> _markCandidates() {
    final w = _c.canvasSize.width, h = _c.canvasSize.height;
    if (h > 600) {
      return [
        Offset(w / 2, h * 0.84), Offset(w * 0.18, h * 0.84),
        Offset(w * 0.82, h * 0.84), Offset(w / 2, h * 0.77),
        Offset(w * 0.18, h * 0.77), Offset(w * 0.82, h * 0.77),
        Offset(w / 2, h * 0.15), Offset(w * 0.18, h * 0.15),
        Offset(w * 0.82, h * 0.15), Offset(w / 2, h * 0.70),
      ];
    }
    return [
      Offset(w / 2, h - 22), Offset(w * 0.25, h - 22),
      Offset(w * 0.75, h - 22), Offset(w / 2, 22),
      Offset(w * 0.25, 22), Offset(w * 0.75, 22),
    ];
  }

  /// Measures every visible layer and moves the mark to the emptiest spot.
  void _placeMark() {
    if (!mounted || _dragging) return;
    final root = widget.boundaryKey.currentContext?.findRenderObject();
    if (root is! RenderBox) return;
    final rects = <Rect>[];
    for (final l in _c.layers) {
      // Background patterns and frames cover everything; ignore them.
      if (l.hidden || (l.locked && l.kind == LayerKind.ornament)) continue;
      final box = _visualKeys[l.id]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final corners = [
        Offset.zero, box.size.topRight(Offset.zero),
        box.size.bottomLeft(Offset.zero), box.size.bottomRight(Offset.zero),
      ].map((p) => box.localToGlobal(p, ancestor: root)).toList();
      var rect = Rect.fromLTRB(
        corners.map((p) => p.dx).reduce(math.min),
        corners.map((p) => p.dy).reduce(math.min),
        corners.map((p) => p.dx).reduce(math.max),
        corners.map((p) => p.dy).reduce(math.max),
      );
      // Illustrations have transparent margins around the drawing.
      if (l.kind == LayerKind.art) {
        rect = rect.deflate(rect.shortestSide * 0.12);
      }
      rects.add(rect);
    }
    Offset? best;
    var bestOverlap = double.infinity;
    for (final spot in _markCandidates()) {
      final mark = Rect.fromCenter(
          center: spot, width: _markSize.width, height: _markSize.height)
          .inflate(3);
      var overlap = 0.0;
      for (final r in rects) {
        final i = mark.intersect(r);
        if (i.width > 0 && i.height > 0) overlap += i.width * i.height;
      }
      if (overlap < bestOverlap) {
        best = spot;
        bestOverlap = overlap;
        if (overlap == 0) break;
      }
    }
    if (best != null && best != _markSpot) setState(() => _markSpot = best);
  }

  EditorController get _c => widget.controller;
  Offset get _center => _c.canvasSize.center(Offset.zero);

  /// One undo step per gesture, taken lazily on the first real movement.
  void _recordOnce() {
    if (_recorded) return;
    _c.checkpoint();
    _recorded = true;
  }

  Offset _delta(ScaleUpdateDetails d) {
    // Global finger movement converted to canvas units.
    final delta = (d.focalPoint - _lastFocal) / widget.viewScale;
    _lastFocal = d.focalPoint;
    return delta;
  }

  // --- Layer gestures -------------------------------------------------------

  void _layerStart(StoryLayer layer, ScaleStartDetails d) {
    _c.select(layer.id);
    _lastFocal = d.focalPoint;
    _baseScale = layer.scale;
    _baseRotation = layer.rotation;
    _freePosition = layer.position;
    _recorded = false;
  }

  void _layerUpdate(StoryLayer layer, ScaleUpdateDetails d, {bool move = true}) {
    final delta = _delta(d);
    _recordOnce();
    if (move && !_dragging) setState(() => _dragging = true);
    _c.updateLayer(layer.id, record: false, (l) {
      if (move) {
        _freePosition = Offset(
          (_freePosition.dx + delta.dx).clamp(0.0, _c.canvasSize.width),
          (_freePosition.dy + delta.dy).clamp(0.0, _c.canvasSize.height),
        );
        _snapX = (_freePosition.dx - _center.dx).abs() < _snapDistance;
        _snapY = (_freePosition.dy - _center.dy).abs() < _snapDistance;
        l.position = Offset(
          _snapX ? _center.dx : _freePosition.dx,
          _snapY ? _center.dy : _freePosition.dy,
        );
      }
      if (d.pointerCount > 1) {
        l.scale = (_baseScale * d.scale).clamp(0.3, 6.0);
        var deg = normalizeDegrees((_baseRotation + d.rotation) * 180 / math.pi);
        final nearest = (deg / 45).round() * 45.0;
        _rotationSnapped = (deg - nearest).abs() <= _rotationSnapDeg;
        if (_rotationSnapped) deg = normalizeDegrees(nearest);
        l.rotation = deg * math.pi / 180;
        _hud = '${deg.round()}°  ·  ${(l.scale * 100).round()}%';
      }
    });
  }

  /// Degrees in (-180, 180].
  static double normalizeDegrees(double deg) {
    var d = deg % 360;
    if (d > 180) d -= 360;
    if (d <= -180) d += 360;
    return d;
  }

  void _gestureEnd(ScaleEndDetails _) {
    if (_dragging || _snapX || _snapY || _hud != null) {
      setState(() {
        _dragging = _snapX = _snapY = _rotationSnapped = false;
        _hud = null;
      });
    }
  }

  // --- Empty-area gestures --------------------------------------------------
  // With a layer selected: pinch resizes/rotates it (easier than pinching a
  // small word). Otherwise, on a photo: drag/pinch moves and zooms the photo.

  Offset _baseOffset = Offset.zero;

  void _bgStart(ScaleStartDetails d) {
    _lastFocal = d.focalPoint;
    _recorded = false;
    final layer = _c.selected;
    if (layer != null) {
      _baseScale = layer.scale;
      _baseRotation = layer.rotation;
    } else {
      _baseScale = _c.background.imageScale;
      _baseOffset = _c.background.imageOffset;
    }
  }

  void _bgUpdate(ScaleUpdateDetails d) {
    final layer = _c.selected;
    if (layer != null) {
      _layerUpdate(layer, d, move: false);
      return;
    }
    if (!_c.background.isImage) return;
    final delta = _delta(d);
    _recordOnce();
    _baseOffset += delta;
    _c.transformImage(_baseOffset, _baseScale * d.scale);
  }

  bool get _darkBackground {
    final bg = _c.background;
    return switch (bg.kind) {
      BackgroundKind.solid => bg.color.computeLuminance() < 0.5,
      BackgroundKind.gradient =>
        bg.gradientColors.last.computeLuminance() < 0.5,
      BackgroundKind.image => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Only this RepaintBoundary is exported; gesture detectors paint
        // nothing, and the guides below sit outside it.
        RepaintBoundary(
          key: widget.boundaryKey,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _c.select(null),
                onDoubleTap: () {
                  // Double-tap the photo to reset pan/zoom.
                  if (_c.selected == null && _c.background.isImage) {
                    _c.checkpoint();
                    _c.transformImage(Offset.zero, 1);
                  }
                },
                onScaleStart: _bgStart,
                onScaleUpdate: _bgUpdate,
                onScaleEnd: _gestureEnd,
                child: StoryBackgroundView(background: _c.background),
              ),
              for (final layer in _c.layers)
                PositionedLayer(
                  key: ValueKey(layer.id),
                  layer: layer,
                  // Locked layers (background patterns) let touches through.
                  child: layer.locked
                      ? IgnorePointer(
                          child: StoryLayerVisual(
                            key: _keyFor(layer.id),
                            layer: layer,
                            selected: layer.id == _c.selectedId,
                          ),
                        )
                      : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (layer.id == _c.selectedId) {
                        widget.onEditLayer(layer);
                      } else {
                        _c.select(layer.id);
                      }
                    },
                    onScaleStart: (d) => _layerStart(layer, d),
                    onScaleUpdate: (d) => _layerUpdate(layer, d),
                    onScaleEnd: _gestureEnd,
                    child: StoryLayerVisual(
                      key: _keyFor(layer.id),
                      layer: layer,
                      selected: layer.id == _c.selectedId,
                    ),
                  ),
                ),
              // App mark (setting), unless the design already has one.
              Positioned.fill(
                child: ValueListenableBuilder<AppSettingsData>(
                  valueListenable: AppSettings.instance,
                  builder: (context, settings, child) {
                    if (!settings.showWatermark ||
                        _c.layers.any((l) =>
                            l.kind == LayerKind.watermark && !l.hidden)) {
                      return const SizedBox.shrink();
                    }
                    // Re-check the free spot after this frame is laid out.
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _placeMark());
                    final spot = _markSpot ?? _markCandidates().first;
                    return Stack(
                      children: [
                        Positioned(
                          left: spot.dx,
                          top: spot.dy,
                          child: FractionalTranslation(
                            translation: const Offset(-0.5, -0.5),
                            child: GestureDetector(
                              onTap: widget.onWatermarkTap,
                              child: WatermarkBadge(dark: _darkBackground),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // The selected layer keeps its place in the stack, but an
              // invisible copy on top receives the touches, so a layer
              // under a photo can still be moved, and its frame stays
              // visible.
              if (_c.selected case final sel? when !sel.hidden && !sel.locked)
                PositionedLayer(
                  key: const ValueKey('selection-handle'),
                  layer: sel,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onEditLayer(sel),
                    onScaleStart: (d) => _layerStart(sel, d),
                    onScaleUpdate: (d) => _layerUpdate(sel, d),
                    onScaleEnd: _gestureEnd,
                    child: Container(
                      foregroundDecoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Opacity(
                        opacity: 0,
                        child: StoryLayerVisual(layer: sel, selected: true),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_hud != null)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _rotationSnapped
                        ? const Color(0xE6FFB300)
                        : const Color(0xCC000000),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.rotate_right_rounded,
                        size: 16,
                        color: _rotationSnapped ? Colors.black : Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _hud!,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color:
                              _rotationSnapped ? Colors.black : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_dragging)
          IgnorePointer(
            child: CustomPaint(
              painter: SafeZonePainter(
                snapX: _snapX,
                snapY: _snapY,
                // Instagram's UI only overlays stories.
                showZones: _c.format == StoryFormat.story,
              ),
            ),
          ),
      ],
    );
  }
}
