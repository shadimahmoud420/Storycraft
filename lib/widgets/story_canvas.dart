import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/config.dart';
import '../data/fonts.dart';
import '../models/story_background.dart';
import '../models/text_layer.dart';
import '../state/editor_controller.dart';

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
  final ValueChanged<TextLayer> onEditLayer;

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
  final ValueChanged<TextLayer> onEditLayer;

  @override
  State<_CanvasContent> createState() => _CanvasContentState();
}

class _CanvasContentState extends State<_CanvasContent> {
  // Gesture bookkeeping for the layer being transformed.
  Offset _lastFocal = Offset.zero;
  double _baseScale = 1;
  double _baseRotation = 0;

  EditorController get _c => widget.controller;

  void _start(TextLayer layer, ScaleStartDetails d) {
    _lastFocal = d.focalPoint;
    _baseScale = layer.scale;
    _baseRotation = layer.rotation;
  }

  void _update(TextLayer layer, ScaleUpdateDetails d, {bool move = true}) {
    // Global finger movement converted to canvas units.
    final delta = (d.focalPoint - _lastFocal) / widget.viewScale;
    _lastFocal = d.focalPoint;
    _c.updateLayer(layer.id, (l) {
      if (move) {
        l.position = Offset(
          (l.position.dx + delta.dx).clamp(0.0, AppConfig.canvasWidth),
          (l.position.dy + delta.dy).clamp(0.0, AppConfig.canvasHeight),
        );
      }
      if (d.pointerCount > 1) {
        l.scale = (_baseScale * d.scale).clamp(0.3, 6.0);
        l.rotation = _baseRotation + d.rotation;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Only this RepaintBoundary is exported; gesture detectors paint nothing.
    return RepaintBoundary(
      key: widget.boundaryKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Empty area: tap to deselect, pinch to resize/rotate the selected
          // text (easier than pinching a small word).
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _c.select(null),
            onScaleStart: (d) {
              final layer = _c.selected;
              if (layer != null) _start(layer, d);
            },
            onScaleUpdate: (d) {
              final layer = _c.selected;
              if (layer != null) _update(layer, d, move: false);
            },
            child: _Background(background: _c.background),
          ),
          for (final layer in _c.layers)
            _TextLayerView(
              key: ValueKey(layer.id),
              layer: layer,
              selected: layer.id == _c.selectedId,
              onTap: () {
                if (layer.id == _c.selectedId) {
                  widget.onEditLayer(layer);
                } else {
                  _c.select(layer.id);
                }
              },
              onScaleStart: (d) {
                _c.select(layer.id);
                _start(layer, d);
              },
              onScaleUpdate: (d) => _update(layer, d),
            ),
        ],
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background({required this.background});

  final StoryBackground background;

  @override
  Widget build(BuildContext context) {
    switch (background.kind) {
      case BackgroundKind.solid:
        return ColoredBox(color: background.color);
      case BackgroundKind.gradient:
        return DecoratedBox(
          decoration: BoxDecoration(gradient: background.linearGradient),
        );
      case BackgroundKind.image:
        final bytes = background.imageBytes!;
        final image = MemoryImage(bytes);
        if (background.imageFit == ImageFit.cover) {
          return Image(image: image, fit: BoxFit.cover, gaplessPlayback: true);
        }
        // "Fit": whole photo visible over a blurred copy of itself.
        return Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Image(
                image: image,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
            const ColoredBox(color: Color(0x33000000)),
            Image(image: image, fit: BoxFit.contain, gaplessPlayback: true),
          ],
        );
    }
  }
}

class _TextLayerView extends StatelessWidget {
  const _TextLayerView({
    super.key,
    required this.layer,
    required this.selected,
    required this.onTap,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  final TextLayer layer;
  final bool selected;
  final VoidCallback onTap;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;

  @override
  Widget build(BuildContext context) {
    final isRtl = StoryFonts.hasArabic(layer.text);
    return Positioned(
      left: layer.position.dx,
      top: layer.position.dy,
      child: FractionalTranslation(
        // position is the center of the text block
        translation: const Offset(-0.5, -0.5),
        child: Transform.rotate(
          angle: layer.rotation,
          child: Transform.scale(
            scale: layer.scale,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onScaleStart: onScaleStart,
              onScaleUpdate: onScaleUpdate,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: AppConfig.canvasWidth - 24),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: layer.highlightColor,
                    borderRadius: BorderRadius.circular(10),
                    border: selected
                        ? Border.all(color: Colors.white, width: 1.2)
                        : null,
                    boxShadow: selected
                        ? const [
                            BoxShadow(color: Color(0x55000000), blurRadius: 4)
                          ]
                        : null,
                  ),
                  child: Text(
                    layer.text,
                    textAlign: layer.align,
                    textDirection:
                        isRtl ? TextDirection.rtl : TextDirection.ltr,
                    style: layer.style,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
