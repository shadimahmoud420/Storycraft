import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/config.dart';
import '../data/art.dart';
import '../data/formats.dart';
import '../data/fonts.dart';
import '../models/story_background.dart';
import '../models/story_layer.dart';
import 'styled_text.dart';

/// Paints a story background (solid, gradient or pan/zoomed photo + dim).
class StoryBackgroundView extends StatelessWidget {
  const StoryBackgroundView({super.key, required this.background});

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
        final image = MemoryImage(background.imageBytes!);
        final matrix = background.filterMatrix;
        Widget filtered(Widget child) => matrix == null
            ? child
            : ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: child);
        final photo = Transform.translate(
          offset: background.imageOffset,
          child: Transform.scale(
            scale: background.imageScale,
            child: SizedBox.expand(
              child: Image(
                image: image,
                fit: background.imageFit == ImageFit.cover
                    ? BoxFit.cover
                    : BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
        );
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // "Fit" mode: whole photo over a blurred copy of itself.
              if (background.imageFit == ImageFit.contain) ...[
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: filtered(Image(
                    image: image,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )),
                ),
                const ColoredBox(color: Color(0x33000000)),
              ],
              filtered(photo),
              if (background.dim > 0)
                ColoredBox(
                  color: Colors.black.withValues(alpha: background.dim),
                ),
            ],
          ),
        );
    }
  }
}

/// Visual of a single layer, without gestures or positioning.
class StoryLayerVisual extends StatelessWidget {
  const StoryLayerVisual({
    super.key,
    required this.layer,
    this.selected = false,
  });

  final StoryLayer layer;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? Border.all(color: Colors.white, width: 1.2)
        : null;
    final selectionShadow = selected
        ? const [BoxShadow(color: Color(0x55000000), blurRadius: 4)]
        : null;

    switch (layer.kind) {
      case LayerKind.text:
        final isRtl = StoryFonts.hasArabic(layer.text);
        Widget box = Container(
          constraints:
              const BoxConstraints(maxWidth: AppConfig.canvasWidth - 24),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: layer.highlightColor,
            borderRadius: BorderRadius.circular(10),
            border: border,
            boxShadow: selectionShadow,
          ),
          child: StyledText(
            layer: layer,
            direction: isRtl ? TextDirection.rtl : TextDirection.ltr,
          ),
        );
        if (layer.highlight == TextHighlight.blur) {
          // Frosted glass behind the text: readable on any photo.
          box = ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: box,
            ),
          );
        }
        return box;
      case LayerKind.emoji:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: border,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(layer.text, style: layer.style),
        );
      case LayerKind.shape:
        final size = _shapeSize(layer);
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: border,
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomPaint(
            size: size,
            painter: ShapePainter(layer.shape, layer.color),
          ),
        );
      case LayerKind.art:
        return Container(
          decoration: BoxDecoration(
            border: border,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SvgPicture.asset(
            StoryArt.asset(layer.text),
            width: layer.size,
            fit: BoxFit.contain,
          ),
        );
      case LayerKind.image:
        return Container(
          decoration: BoxDecoration(border: border),
          child: layer.imageBytes == null
              ? const SizedBox.shrink()
              : Image.memory(
                  layer.imageBytes!,
                  width: layer.size,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
        );
    }
  }

  static Size _shapeSize(StoryLayer l) => switch (l.shape) {
        ShapeKind.roundedFrame || ShapeKind.rectFrame =>
          Size(l.size, l.size * 1.25),
        ShapeKind.circleFrame => Size(l.size, l.size),
        ShapeKind.line => Size(l.size, 6),
        ShapeKind.label => Size(l.size, l.size * 0.32),
      };
}

class ShapePainter extends CustomPainter {
  ShapePainter(this.shape, this.color);

  final ShapeKind shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    switch (shape) {
      case ShapeKind.roundedFrame:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(24)),
          paint,
        );
      case ShapeKind.rectFrame:
        canvas.drawRect(rect, paint);
      case ShapeKind.circleFrame:
        canvas.drawOval(rect, paint);
      case ShapeKind.line:
        final y = size.height / 2;
        canvas.drawLine(Offset(stroke, y), Offset(size.width - stroke, y), paint);
      case ShapeKind.label:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Offset.zero & size,
            Radius.circular(size.height / 2),
          ),
          paint..style = PaintingStyle.fill,
        );
    }
  }

  @override
  bool shouldRepaint(ShapePainter old) =>
      old.shape != shape || old.color != color;
}

/// Places a layer on the 360 x 640 canvas (center-anchored, rotated,
/// scaled). [child] is usually the gesture-wrapped visual.
class PositionedLayer extends StatelessWidget {
  const PositionedLayer({super.key, required this.layer, required this.child});

  final StoryLayer layer;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: layer.position.dx,
      top: layer.position.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Transform.rotate(
          angle: layer.rotation,
          child: Transform.scale(scale: layer.scale, child: child),
        ),
      ),
    );
  }
}

/// Non-interactive rendering of a whole story, scaled to fit its box.
/// Used for template and draft previews.
class StoryPreview extends StatelessWidget {
  const StoryPreview({
    super.key,
    required this.background,
    required this.layers,
    this.format = StoryFormat.story,
    this.borderRadius = 12,
  });

  final StoryFormat format;
  final StoryBackground background;
  final List<StoryLayer> layers;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: format.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: FittedBox(
          child: SizedBox(
            width: format.size.width,
            height: format.size.height,
            child: IgnorePointer(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                fit: StackFit.expand,
                children: [
                  StoryBackgroundView(background: background),
                  for (final l in layers)
                    PositionedLayer(
                      layer: l,
                      child: StoryLayerVisual(layer: l),
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

/// Instagram overlays its UI on the top ~14% and bottom ~20% of a story.
/// Shown while dragging so users keep text out of those areas, plus
/// center guides when a layer snaps to the middle.
class SafeZonePainter extends CustomPainter {
  SafeZonePainter({
    required this.snapX,
    required this.snapY,
    this.showZones = true,
  });

  static const topFraction = 0.14;
  static const bottomFraction = 0.20;

  final bool snapX;
  final bool snapY;
  final bool showZones;

  @override
  void paint(Canvas canvas, Size size) {
    if (showZones) _paintZones(canvas, size);
    _paintGuides(canvas, size);
  }

  void _paintZones(Canvas canvas, Size size) {
    final shade = Paint()..color = const Color(0x40FF3B6B);
    final top = size.height * topFraction;
    final bottom = size.height * (1 - bottomFraction);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, top), shade);
    canvas.drawRect(
      Rect.fromLTWH(0, bottom, size.width, size.height - bottom),
      shade,
    );
    final dash = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = 1;
    _dashed(canvas, Offset(0, top), Offset(size.width, top), dash);
    _dashed(canvas, Offset(0, bottom), Offset(size.width, bottom), dash);
  }

  void _paintGuides(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = const Color(0xFFFFD54F)
      ..strokeWidth = 1.2;
    if (snapX) {
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        guide,
      );
    }
    if (snapY) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        guide,
      );
    }
  }

  void _dashed(Canvas c, Offset a, Offset b, Paint p) {
    const dash = 6.0, gap = 4.0;
    final len = (b - a).distance;
    final dir = (b - a) / len;
    for (double d = 0; d < len; d += dash + gap) {
      c.drawLine(a + dir * d, a + dir * math.min(d + dash, len), p);
    }
  }

  @override
  bool shouldRepaint(SafeZonePainter old) =>
      old.snapX != snapX || old.snapY != snapY || old.showZones != showZones;
}
