import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/story_layer.dart';

/// Draws an [OrnamentKind] in [color]. Randomized patterns use [seed] so
/// they look the same every time (and in the export).
class OrnamentPainter extends CustomPainter {
  OrnamentPainter(this.kind, this.color, this.seed);

  final OrnamentKind kind;
  final Color color;
  final int seed;

  Paint get _fill => Paint()..color = color;
  Paint _stroke(double w) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static Path star(Offset c, double r, {int points = 8, double inner = 0.45}) {
    final p = Path();
    for (var i = 0; i < points * 2; i++) {
      final rr = i.isEven ? r : r * inner;
      final a = math.pi / points * i - math.pi / 2;
      final pt = c + Offset(rr * math.cos(a), rr * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rnd = math.Random(seed);
    switch (kind) {
      case OrnamentKind.stars:
        const step = 40.0;
        for (var y = -step / 2, row = 0; y < h + step; y += step, row++) {
          for (var x = row.isOdd ? step / 2 : 0.0; x < w + step; x += step) {
            canvas.drawPath(star(Offset(x, y), 8), _fill);
          }
        }
      case OrnamentKind.bokeh:
        final paint = Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        for (var i = 0; i < 55; i++) {
          final r = 7 + rnd.nextDouble() * 22;
          final c = Offset(rnd.nextDouble() * (w + 20) - 10,
              h * 0.45 + rnd.nextDouble() * h * 0.6);
          paint.color =
              color.withValues(alpha: color.a * (0.35 + rnd.nextDouble() * 0.65));
          canvas.drawCircle(c, r, paint);
        }
      case OrnamentKind.waves:
        for (var k = 0; k < 5; k++) {
          final p = Path()..moveTo(0, h);
          for (var x = 0.0; x <= w + 6; x += 6) {
            p.lineTo(x, h * 0.74 + k * 18 + 13 * math.sin(x / 53 + k * 1.3));
          }
          p
            ..lineTo(w, h)
            ..close();
          canvas.drawPath(p, _fill);
        }
      case OrnamentKind.rays:
        final c = Offset(w / 2, -h * 0.1);
        for (var i = 0; i < 24; i++) {
          final a = math.pi / 24 * i;
          final p = Path()
            ..moveTo(c.dx, c.dy)
            ..lineTo(c.dx + 2 * h * math.cos(a - 0.03), c.dy + 2 * h * math.sin(a - 0.03))
            ..lineTo(c.dx + 2 * h * math.cos(a + 0.03), c.dy + 2 * h * math.sin(a + 0.03))
            ..close();
          canvas.drawPath(p, _fill);
        }
      case OrnamentKind.dots:
        for (var y = 12.0; y < h; y += 23) {
          for (var x = 12.0; x < w; x += 23) {
            canvas.drawCircle(Offset(x, y), 1.4, _fill);
          }
        }
      case OrnamentKind.frame:
        for (final (inset, width) in [(0.0, 1.8), (6.0, 0.8)]) {
          const c = 20.0;
          final a = inset + 1, b = w - inset - 1, t = inset + 1, bt = h - inset - 1;
          canvas.drawPath(
            Path()
              ..moveTo(a + c, t)
              ..lineTo(b - c, t)
              ..lineTo(b, t + c)
              ..lineTo(b, bt - c)
              ..lineTo(b - c, bt)
              ..lineTo(a + c, bt)
              ..lineTo(a, bt - c)
              ..lineTo(a, t + c)
              ..close(),
            _stroke(width),
          );
        }
        for (final c in [Offset(w / 2, 1), Offset(w / 2, h - 1)]) {
          canvas.drawPath(star(c, 7), _fill);
        }
      case OrnamentKind.crescent:
        final r = math.min(w, h) / 2;
        final c = Offset(w / 2, h / 2);
        canvas.drawPath(
          Path.combine(
            PathOperation.difference,
            Path()..addOval(Rect.fromCircle(center: c, radius: r)),
            Path()
              ..addOval(Rect.fromCircle(
                  center: c + Offset(r * 0.42, -r * 0.2), radius: r * 0.86)),
          ),
          _fill,
        );
      case OrnamentKind.sun:
        final c = Offset(w / 2, h / 2);
        final r = math.min(w, h) * 0.26;
        canvas.drawCircle(c, r * 1.9,
            Paint()..color = color.withValues(alpha: color.a * 0.25));
        canvas.drawCircle(c, r, _fill);
        for (var i = 0; i < 12; i++) {
          final a = math.pi / 6 * i;
          final d = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(c + d * r * 1.3, c + d * r * 1.62, _stroke(r * 0.12));
        }
      case OrnamentKind.flowers:
        for (var i = 0; i < 5; i++) {
          final c = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
          final s = 0.7 + rnd.nextDouble() * 0.6;
          for (var k = 0; k < 5; k++) {
            final a = 2 * math.pi / 5 * k;
            canvas.drawCircle(
                c + Offset(9 * s * math.cos(a), 9 * s * math.sin(a)), 7.5 * s, _fill);
          }
          canvas.drawCircle(c, 5 * s, Paint()..color = const Color(0xFFFFC857));
        }
      case OrnamentKind.divider:
        final y = h / 2;
        canvas.drawLine(Offset(0, y), Offset(w / 2 - 14, y), _stroke(1.2));
        canvas.drawLine(Offset(w / 2 + 14, y), Offset(w, y), _stroke(1.2));
        canvas.drawPath(star(Offset(w / 2, y), 6), _fill);
      case OrnamentKind.ring:
        final c = Offset(w / 2, h / 2);
        final r = math.min(w, h) / 2;
        canvas.drawCircle(c, r - 1, _stroke(1.4));
        canvas.drawCircle(c, r - 7, _fill);
      case OrnamentKind.card:
        final rect = RRect.fromRectAndRadius(
            Offset.zero & size, const Radius.circular(20));
        canvas.drawRRect(
            rect.shift(const Offset(0, 6)),
            Paint()
              ..color = const Color(0x33000000)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
        canvas.drawRRect(rect, _fill);
      case OrnamentKind.pill:
        canvas.drawRRect(
            RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(h / 2)),
            _fill);
    }
  }

  @override
  bool shouldRepaint(OrnamentPainter old) =>
      old.kind != kind || old.color != color || old.seed != seed;
}

/// The app's small brand mark ("StoryCraft") placed on designs. [dark]
/// picks the variant for dark backgrounds.
class WatermarkBadge extends StatelessWidget {
  const WatermarkBadge({super.key, required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 4, 11, 4),
      decoration: BoxDecoration(
        color: dark ? const Color(0x47000000) : const Color(0x80FFFFFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.ltr,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.asset('assets/icon/icon.png', width: 17, height: 17),
          ),
          const SizedBox(width: 5),
          Text(
            'StoryCraft',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              height: 1.1,
              color: dark ? const Color(0xEEFFFFFF) : const Color(0xE6281E32),
            ),
          ),
        ],
      ),
    );
  }
}
