import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/fonts.dart';
import '../models/story_layer.dart';
import 'styled_text.dart';

/// A personal signature: the name in a calligraphic font plus a
/// decoration ([SignatureStyle]). Colors and metallic fills come from the
/// layer, so a gold signature has a gold flourish too.
class SignatureView extends StatelessWidget {
  const SignatureView({super.key, required this.layer});

  final StoryLayer layer;

  /// Flat color used for strokes (flourish, rings, lines).
  Color get inkColor => switch (layer.fill) {
        TextFill.gold => const Color(0xFFD4AF37),
        TextFill.silver => const Color(0xFFC9CED3),
        TextFill.rose => const Color(0xFFE8A0A7),
        _ => layer.color,
      };

  @override
  Widget build(BuildContext context) {
    final rtl = StoryFonts.hasArabic(layer.text);
    final dir = rtl ? TextDirection.rtl : TextDirection.ltr;
    final name = StyledText(layer: layer, direction: dir);
    final fs = layer.fontSize;
    final ink = inkColor;

    switch (layer.signatureStyle) {
      case SignatureStyle.plain:
        return name;

      case SignatureStyle.swash:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            name,
            Transform.translate(
              offset: Offset(0, -fs * 0.25),
              child: CustomPaint(
                size: Size(fs * 4.2, fs * 0.55),
                painter: _SwashPainter(ink, rtl: rtl, stroke: fs * 0.06),
              ),
            ),
          ],
        );

      case SignatureStyle.underline:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            name,
            CustomPaint(
              size: Size(fs * 3.4, fs * 0.3),
              painter: _UnderlinePainter(ink, rtl: rtl, stroke: fs * 0.05),
            ),
          ],
        );

      case SignatureStyle.seal:
        return CustomPaint(
          painter: _SealPainter(ink, stroke: fs * 0.05),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: fs * 0.9,
              vertical: fs * 0.55,
            ),
            child: name,
          ),
        );

      case SignatureStyle.monogram:
        final initial = layer.text.trim().isEmpty
            ? '?'
            : layer.text.trim().characters.first;
        final initialLayer = layer.copyWith(id: layer.id)
          ..text = initial
          ..fontSize = fs * 1.25
          ..curve = 0;
        final smallName = layer.copyWith(id: layer.id)
          ..fontSize = fs * 0.5
          ..curve = 0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: fs * 2.2,
              height: fs * 2.2,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ink, width: fs * 0.05),
              ),
              child: StyledText(layer: initialLayer, direction: dir),
            ),
            SizedBox(height: fs * 0.2),
            StyledText(layer: smallName, direction: dir),
          ],
        );

      case SignatureStyle.framed:
        Widget line() => Container(
              width: fs * 0.9,
              height: fs * 0.05,
              margin: EdgeInsets.symmetric(horizontal: fs * 0.25),
              decoration: BoxDecoration(
                color: ink,
                borderRadius: BorderRadius.circular(fs),
              ),
            );
        return Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: dir,
          children: [line(), Flexible(child: name), line()],
        );

      case SignatureStyle.ornate:
        Widget scroll(bool mirror) => CustomPaint(
              size: Size(fs * 1.3, fs * 1.1),
              painter: _ScrollPainter(ink, mirror: mirror, stroke: fs * 0.05),
            );
        return Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          children: [
            scroll(false),
            Flexible(child: name),
            scroll(true),
          ],
        );

      case SignatureStyle.laurel:
        return CustomPaint(
          painter: _LaurelPainter(ink, stroke: fs * 0.045),
          child: Padding(
            padding: EdgeInsets.fromLTRB(fs * 1.1, fs * 0.35, fs * 1.1, fs * 0.9),
            child: name,
          ),
        );

      case SignatureStyle.royal:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: Size(fs * 1.4, fs * 0.8),
              painter: _CrownPainter(ink, stroke: fs * 0.045),
            ),
            name,
            CustomPaint(
              size: Size(fs * 4.2, fs * 0.5),
              painter: _DividerPainter(ink, stroke: fs * 0.045),
            ),
          ],
        );

      case SignatureStyle.arabesque:
        return CustomPaint(
          painter: _ArabesqueFramePainter(ink, stroke: fs * 0.045),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: fs * 0.95,
              vertical: fs * 0.6,
            ),
            child: name,
          ),
        );

      case SignatureStyle.divider:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            name,
            CustomPaint(
              size: Size(fs * 4.6, fs * 0.55),
              painter: _DividerPainter(ink, stroke: fs * 0.05, curls: true),
            ),
          ],
        );

      case SignatureStyle.sparkle:
        return CustomPaint(
          foregroundPainter: _SparklePainter(ink),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: fs * 0.8,
              vertical: fs * 0.45,
            ),
            child: name,
          ),
        );
    }
  }
}

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Four-pointed star (diamond sparkle) centered at [c].
Path _sparkle(Offset c, double r) => Path()
  ..moveTo(c.dx, c.dy - r)
  ..quadraticBezierTo(c.dx + r * 0.15, c.dy - r * 0.15, c.dx + r, c.dy)
  ..quadraticBezierTo(c.dx + r * 0.15, c.dy + r * 0.15, c.dx, c.dy + r)
  ..quadraticBezierTo(c.dx - r * 0.15, c.dy + r * 0.15, c.dx - r, c.dy)
  ..quadraticBezierTo(c.dx - r * 0.15, c.dy - r * 0.15, c.dx, c.dy - r)
  ..close();

/// Arabesque scroll: an S-curve that ends in a spiral curl, plus a dot.
class _ScrollPainter extends CustomPainter {
  _ScrollPainter(this.color, {required this.mirror, required this.stroke});

  final Color color;
  final bool mirror;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (mirror) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    final w = size.width, h = size.height;
    final p = _stroke(color, stroke);
    // Main sweep from the name outwards.
    final path = Path()
      ..moveTo(w * 0.98, h * 0.5)
      ..cubicTo(w * 0.75, h * 0.5, w * 0.65, h * 0.12, w * 0.42, h * 0.2)
      ..cubicTo(w * 0.2, h * 0.28, w * 0.14, h * 0.62, w * 0.3, h * 0.7)
      ..cubicTo(w * 0.44, h * 0.77, w * 0.5, h * 0.5, w * 0.36, h * 0.47);
    canvas.drawPath(path, p);
    // Lower counter-curl.
    final lower = Path()
      ..moveTo(w * 0.8, h * 0.5)
      ..cubicTo(w * 0.7, h * 0.85, w * 0.45, h * 0.98, w * 0.3, h * 0.88);
    canvas.drawPath(lower, p..strokeWidth = stroke * 0.7);
    canvas.drawCircle(Offset(w * 0.24, h * 0.9), stroke * 1.1,
        Paint()..color = color);
    canvas.drawPath(_sparkle(Offset(w * 0.62, h * 0.08), stroke * 2.2),
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ScrollPainter old) =>
      old.color != color || old.mirror != mirror || old.stroke != stroke;
}

/// Two laurel branches rising from the bottom center around the name.
class _LaurelPainter extends CustomPainter {
  _LaurelPainter(this.color, {required this.stroke});

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final stem = _stroke(color, stroke);
    final leaf = Paint()..color = color;
    for (final side in [-1.0, 1.0]) {
      final p0 = Offset(w / 2 + side * w * 0.04, h * 0.97);
      final c = Offset(w / 2 + side * w * 0.52, h * 0.95);
      final p1 = Offset(w / 2 + side * w * 0.44, h * 0.08);
      canvas.drawPath(
        Path()
          ..moveTo(p0.dx, p0.dy)
          ..quadraticBezierTo(c.dx, c.dy, p1.dx, p1.dy),
        stem,
      );
      // Leaves along the stem, alternating sides.
      const count = 7;
      for (var i = 1; i <= count; i++) {
        final t = i / (count + 1);
        final pt = _quad(p0, c, p1, t);
        final tangent = _quadTangent(p0, c, p1, t);
        final angle = math.atan2(tangent.dy, tangent.dx);
        final len = stroke * (5.5 - t * 1.5);
        for (final lr in [-1.0, 1.0]) {
          canvas
            ..save()
            ..translate(pt.dx, pt.dy)
            ..rotate(angle + lr * side * 0.75)
            ..drawOval(
              Rect.fromCenter(
                center: Offset(len * 0.55, 0),
                width: len,
                height: len * 0.42,
              ),
              leaf,
            )
            ..restore();
        }
      }
    }
    // Small bow where the branches meet.
    canvas.drawCircle(Offset(w / 2, h * 0.97), stroke * 1.4, leaf);
  }

  static Offset _quad(Offset a, Offset b, Offset c, double t) =>
      a * ((1 - t) * (1 - t)) + b * (2 * (1 - t) * t) + c * (t * t);

  static Offset _quadTangent(Offset a, Offset b, Offset c, double t) =>
      (b - a) * (2 * (1 - t)) + (c - b) * (2 * t);

  @override
  bool shouldRepaint(_LaurelPainter old) =>
      old.color != color || old.stroke != stroke;
}

/// Small three-point crown.
class _CrownPainter extends CustomPainter {
  _CrownPainter(this.color, {required this.stroke});

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final fill = Paint()..color = color;
    final crown = Path()
      ..moveTo(w * 0.12, h * 0.85)
      ..lineTo(w * 0.05, h * 0.3)
      ..lineTo(w * 0.32, h * 0.55)
      ..lineTo(w * 0.5, h * 0.12)
      ..lineTo(w * 0.68, h * 0.55)
      ..lineTo(w * 0.95, h * 0.3)
      ..lineTo(w * 0.88, h * 0.85)
      ..close();
    canvas.drawPath(crown, fill);
    for (final x in [0.05, 0.5, 0.95]) {
      canvas.drawCircle(
        Offset(w * x, h * (x == 0.5 ? 0.12 : 0.3)),
        stroke * 1.3,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(_CrownPainter old) =>
      old.color != color || old.stroke != stroke;
}

/// Ornamental divider: tapered lines, a central diamond and small curls.
class _DividerPainter extends CustomPainter {
  _DividerPainter(this.color, {required this.stroke, this.curls = false});

  final Color color;
  final double stroke;
  final bool curls;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cy = h / 2;
    final fill = Paint()..color = color;
    // Tapered lines: thick near the middle, thin at the ends.
    for (final side in [-1.0, 1.0]) {
      final line = Path()
        ..moveTo(w / 2 + side * w * 0.09, cy - stroke * 0.8)
        ..lineTo(w / 2 + side * w * 0.48, cy)
        ..lineTo(w / 2 + side * w * 0.09, cy + stroke * 0.8)
        ..close();
      canvas.drawPath(line, fill);
      if (curls) {
        final x0 = w / 2 + side * w * 0.12;
        final curl = Path()
          ..moveTo(x0, cy)
          ..cubicTo(x0 + side * w * 0.03, cy - h * 0.55,
              x0 + side * w * 0.1, cy - h * 0.2, x0 + side * w * 0.07, cy);
        canvas.drawPath(curl, _stroke(color, stroke * 0.6));
        canvas.drawCircle(
            Offset(w / 2 + side * w * 0.5, cy), stroke * 0.9, fill);
      }
    }
    // Central diamond.
    final d = h * 0.42;
    final diamond = Path()
      ..moveTo(w / 2, cy - d)
      ..lineTo(w / 2 + d * 0.8, cy)
      ..lineTo(w / 2, cy + d)
      ..lineTo(w / 2 - d * 0.8, cy)
      ..close();
    canvas.drawPath(diamond, fill);
  }

  @override
  bool shouldRepaint(_DividerPainter old) =>
      old.color != color || old.stroke != stroke || old.curls != curls;
}

/// Frame with Islamic-style notched corners, an inner line and diamonds
/// at the middle of each side.
class _ArabesqueFramePainter extends CustomPainter {
  _ArabesqueFramePainter(this.color, {required this.stroke});

  final Color color;
  final double stroke;

  Path _notched(Rect r, double n) => Path()
    ..moveTo(r.left + n, r.top)
    ..lineTo(r.right - n, r.top)
    ..arcToPoint(Offset(r.right, r.top + n),
        radius: Radius.circular(n), clockwise: false)
    ..lineTo(r.right, r.bottom - n)
    ..arcToPoint(Offset(r.right - n, r.bottom),
        radius: Radius.circular(n), clockwise: false)
    ..lineTo(r.left + n, r.bottom)
    ..arcToPoint(Offset(r.left, r.bottom - n),
        radius: Radius.circular(n), clockwise: false)
    ..lineTo(r.left, r.top + n)
    ..arcToPoint(Offset(r.left + n, r.top),
        radius: Radius.circular(n), clockwise: false)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final outer = (Offset.zero & size).deflate(stroke * 2);
    final n = math.min(outer.width, outer.height) * 0.18;
    canvas.drawPath(_notched(outer, n), _stroke(color, stroke));
    final inner = outer.deflate(stroke * 3);
    canvas.drawPath(_notched(inner, n * 0.8), _stroke(color, stroke * 0.5));
    final fill = Paint()..color = color;
    for (final c in [
      Offset(outer.center.dx, outer.top),
      Offset(outer.center.dx, outer.bottom),
      Offset(outer.left, outer.center.dy),
      Offset(outer.right, outer.center.dy),
    ]) {
      canvas.drawPath(_sparkle(c, stroke * 3), fill);
    }
  }

  @override
  bool shouldRepaint(_ArabesqueFramePainter old) =>
      old.color != color || old.stroke != stroke;
}

/// Sparkles scattered around the name.
class _SparklePainter extends CustomPainter {
  _SparklePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final fill = Paint()..color = color;
    final r = h * 0.16;
    for (final (x, y, k) in [
      (0.07, 0.22, 1.0), (0.17, 0.08, 0.5), (0.93, 0.8, 1.0),
      (0.84, 0.94, 0.5), (0.96, 0.25, 0.4), (0.04, 0.78, 0.4),
    ]) {
      canvas.drawPath(_sparkle(Offset(w * x, h * y), r * k), fill);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}

/// Handwritten-looking flourish: a tapered sweep with a small loop,
/// mirrored for right-to-left names.
class _SwashPainter extends CustomPainter {
  _SwashPainter(this.color, {required this.rtl, required this.stroke});

  final Color color;
  final bool rtl;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (rtl) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.02, h * 0.55)
      ..cubicTo(w * 0.25, h * 1.05, w * 0.55, h * 0.95, w * 0.78, h * 0.45)
      ..cubicTo(w * 0.86, h * 0.25, w * 0.80, h * 0.05, w * 0.74, h * 0.3)
      ..cubicTo(w * 0.70, h * 0.5, w * 0.84, h * 0.75, w * 0.98, h * 0.35);
    // Draw with increasing width to fake a pen's pressure taper.
    final metrics = path.computeMetrics().toList();
    for (final m in metrics) {
      const segments = 60;
      for (var i = 0; i < segments; i++) {
        final t0 = m.length * i / segments;
        final t1 = m.length * (i + 1) / segments;
        final taper = math.sin(math.pi * (i + 0.5) / segments);
        canvas.drawPath(
          m.extractPath(t0, t1),
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = stroke * (0.35 + 0.9 * taper),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SwashPainter old) =>
      old.color != color || old.rtl != rtl || old.stroke != stroke;
}

class _UnderlinePainter extends CustomPainter {
  _UnderlinePainter(this.color, {required this.rtl, required this.stroke});

  final Color color;
  final bool rtl;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    final start = rtl ? size.width * 0.95 : size.width * 0.05;
    final end = rtl ? size.width * 0.12 : size.width * 0.88;
    canvas.drawLine(Offset(start, y), Offset(end, y), p);
    canvas.drawCircle(
      Offset(rtl ? size.width * 0.04 : size.width * 0.96, y),
      stroke * 1.2,
      p,
    );
  }

  @override
  bool shouldRepaint(_UnderlinePainter old) =>
      old.color != color || old.rtl != rtl || old.stroke != stroke;
}

/// Double oval ring, like a stamp.
class _SealPainter extends CustomPainter {
  _SealPainter(this.color, {required this.stroke});

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final outer = (Offset.zero & size).deflate(stroke);
    canvas.drawOval(outer, p);
    canvas.drawOval(
      outer.deflate(stroke * 3),
      p..strokeWidth = stroke * 0.5,
    );
  }

  @override
  bool shouldRepaint(_SealPainter old) =>
      old.color != color || old.stroke != stroke;
}
