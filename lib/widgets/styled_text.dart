import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/story_layer.dart';

/// Renders a text layer with its fill (flat, gradient or metallic),
/// outline, shadow, spacing and optional curve.
class StyledText extends StatelessWidget {
  const StyledText({super.key, required this.layer, required this.direction});

  final StoryLayer layer;
  final TextDirection direction;

  bool get _curved => layer.curve.abs() > 0.02;

  Widget _paint(TextStyle style) {
    if (_curved) {
      return CurvedText(
        // Curved text is a single line.
        text: layer.text.replaceAll('\n', ' '),
        style: style,
        curve: layer.curve,
        textDirection: direction,
      );
    }
    return Text(
      layer.text,
      textAlign: layer.align,
      textDirection: direction,
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradient = layer.fillGradient;
    final children = <Widget>[];

    // Shadow drawn separately so gradients don't tint it.
    if (layer.shadow && gradient != null) {
      children.add(_paint(
        layer.textStyle(color: Colors.transparent, withShadow: true),
      ));
    }
    if (layer.strokeWidth > 0) {
      children.add(_paint(layer.textStyle(
        withShadow: layer.shadow && gradient == null,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = layer.strokeWidth * 2
          ..strokeJoin = StrokeJoin.round
          ..color = layer.strokeColor,
      )));
    }
    if (gradient == null) {
      children.add(_paint(layer.textStyle(
        withShadow: layer.shadow && layer.strokeWidth == 0,
      )));
    } else {
      // Calligraphic tails (e.g. Ruqaa) can overflow the line box, and a
      // mask only tints inside its bounds: enlarge the masked area with
      // negative insets while the invisible copy keeps the layout size.
      final text = _paint(layer.textStyle(color: Colors.white));
      final px = layer.fontSize * 0.2, py = layer.fontSize * 0.45;
      children.add(Stack(
        clipBehavior: Clip.none,
        children: [
          Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: text,
          ),
          Positioned(
            left: -px,
            right: -px,
            top: -py,
            bottom: -py,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: gradient.createShader,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: px, vertical: py),
                child: text,
              ),
            ),
          ),
        ],
      ));
    }

    return children.length == 1
        ? children.single
        : Stack(alignment: Alignment.center, children: children);
  }
}

/// Text bent along a circular arc. The line is laid out once (so Arabic
/// letters keep their joined shapes) and then painted in thin vertical
/// slices, each rotated onto the arc.
class CurvedText extends StatelessWidget {
  const CurvedText({
    super.key,
    required this.text,
    required this.style,
    required this.curve,
    required this.textDirection,
  });

  final String text;
  final TextStyle style;

  /// -1 … 1; positive bends like a rainbow, negative like a smile.
  final double curve;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: TextScaler.noScaling,
    )..layout();
    final geometry = _ArcGeometry(painter.width, painter.height, curve);
    return CustomPaint(
      size: geometry.size,
      painter: _CurvedTextPainter(painter, geometry),
    );
  }
}

class _ArcGeometry {
  _ArcGeometry(this.width, this.height, double curve)
      : up = curve > 0,
        // Up to a half circle at full curve.
        angle = math.max(curve.abs(), 0.02) * math.pi {
    radius = width / angle;
    // Bounding box of the band between inner and outer radius.
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    const samples = 48;
    for (var i = 0; i <= samples; i++) {
      final t = -angle / 2 + angle * i / samples;
      for (final r in [radius - height / 2 - _pad, radius + height / 2 + _pad]) {
        final p = _point(t, r);
        minX = math.min(minX, p.dx);
        maxX = math.max(maxX, p.dx);
        minY = math.min(minY, p.dy);
        maxY = math.max(maxY, p.dy);
      }
    }
    center = Offset(-minX, -minY);
    size = Size(maxX - minX, maxY - minY);
  }

  static const _pad = 6.0; // room for strokes and shadows

  final double width;
  final double height;
  final bool up;
  final double angle;
  late final double radius;
  late final Offset center;
  late final Size size;

  /// Point on the arc at angle [t] (0 = middle of the text).
  Offset _point(double t, double r) => up
      ? Offset(r * math.sin(t), -r * math.cos(t))
      : Offset(r * math.sin(t), r * math.cos(t));
}

class _CurvedTextPainter extends CustomPainter {
  _CurvedTextPainter(this.text, this.g);

  final TextPainter text;
  final _ArcGeometry g;

  @override
  void paint(Canvas canvas, Size size) {
    const step = 2.0;
    final h = g.height;
    // Slices fan out away from the center: widen them so tall letters
    // (ك، ل، ط) stay solid on the outer edge of the arc.
    final spread = (g.radius + h) / g.radius;
    final clipWidth = step * spread + 1.2;
    for (double x = 0; x < g.width; x += step) {
      final mid = x + step / 2;
      final t = (mid - g.width / 2) / g.radius;
      final p = g.center + g._point(t, g.radius);
      canvas
        ..save()
        ..translate(p.dx, p.dy)
        ..rotate(g.up ? t : -t)
        // Slightly wider than the step so slices overlap without gaps.
        ..clipRect(Rect.fromLTWH(-clipWidth / 2, -h, clipWidth, h * 2));
      text.paint(canvas, Offset(-mid, -h / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CurvedTextPainter old) =>
      old.text != text || old.g.angle != g.angle || old.g.up != g.up;
}
