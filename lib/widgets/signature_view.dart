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
    }
  }
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
