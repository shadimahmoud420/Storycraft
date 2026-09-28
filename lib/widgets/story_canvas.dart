import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/config.dart';
import '../models/story_layer.dart';
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
  });

  final EditorController controller;
  final GlobalKey boundaryKey;
  final ValueChanged<StoryLayer> onEditLayer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewScale = math.min(
          constraints.maxWidth / AppConfig.canvasWidth,
          constraints.maxHeight / AppConfig.canvasHeight,
        );
        return Center(
          child: SizedBox(
            width: AppConfig.canvasWidth * viewScale,
            height: AppConfig.canvasHeight * viewScale,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: FittedBox(
                child: SizedBox(
                  width: AppConfig.canvasWidth,
                  height: AppConfig.canvasHeight,
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => _CanvasContent(
                      controller: controller,
                      boundaryKey: boundaryKey,
                      viewScale: viewScale,
                      onEditLayer: onEditLayer,
                    ),
                  ),
                ),
              ),
            ),
          ),
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
  });

  final EditorController controller;
  final GlobalKey boundaryKey;
  final double viewScale;
  final ValueChanged<StoryLayer> onEditLayer;

  @override
  State<_CanvasContent> createState() => _CanvasContentState();
}

class _CanvasContentState extends State<_CanvasContent> {
  static const _snapDistance = 6.0;
  static const _center = Offset(
    AppConfig.canvasWidth / 2,
    AppConfig.canvasHeight / 2,
  );

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

  EditorController get _c => widget.controller;

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
          (_freePosition.dx + delta.dx).clamp(0.0, AppConfig.canvasWidth),
          (_freePosition.dy + delta.dy).clamp(0.0, AppConfig.canvasHeight),
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
        l.rotation = _baseRotation + d.rotation;
      }
    });
  }

  void _gestureEnd(ScaleEndDetails _) {
    if (_dragging || _snapX || _snapY) {
      setState(() => _dragging = _snapX = _snapY = false);
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
                  child: GestureDetector(
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
                      layer: layer,
                      selected: layer.id == _c.selectedId,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_dragging)
          IgnorePointer(
            child: CustomPaint(
              painter: SafeZonePainter(snapX: _snapX, snapY: _snapY),
            ),
          ),
      ],
    );
  }
}
