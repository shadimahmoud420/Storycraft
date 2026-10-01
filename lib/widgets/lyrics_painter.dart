import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/lyrics.dart';

/// Design width: lyrics are laid out at 360 logical px and scaled to the
/// video, so the preview and the exported video match exactly.
const double lyricsDesignWidth = 360;

final _arabic = RegExp(r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]');

/// Paints one lyric line in the state [frame] onto a [size] canvas.
void paintLyrics(
  Canvas canvas,
  Size size, {
  required String text,
  required LyricsStyle style,
  required LyricsFrame frame,
}) {
  if (text.isEmpty) return;
  final scale = size.width / lyricsDesignWidth;
  final w = lyricsDesignWidth, h = size.height / scale;
  final rtl = _arabic.hasMatch(text);
  final dir = rtl ? TextDirection.rtl : TextDirection.ltr;
  final effect = style.effect;
  final appear = Curves.easeOutCubic.transform(frame.appearT);
  final p = frame.progressT;

  List<Shadow> shadows(double alpha) => [
        if (style.glow)
          Shadow(
              color: style.accent.withValues(alpha: 0.75 * alpha),
              blurRadius: 16),
        Shadow(
            color: Colors.black.withValues(alpha: 0.55 * alpha),
            blurRadius: 6,
            offset: const Offset(0, 2)),
      ];

  TextStyle base(Color color, [double alpha = 1]) => TextStyle(
        fontFamily: style.fontFamily,
        fontSize: style.size,
        fontWeight: FontWeight.w700,
        height: 1.35,
        color: color.withValues(alpha: color.a * alpha),
        shadows: shadows(alpha),
      );

  TextPainter layout(InlineSpan span) => TextPainter(
        text: span,
        textDirection: dir,
        textAlign: TextAlign.center,
      )..layout(maxWidth: w - 48);

  // Words appear one after another.
  final InlineSpan span;
  if (effect == LyricEffect.words) {
    final parts = text.split(' ');
    final n = parts.length;
    span = TextSpan(children: [
      for (var i = 0; i < n; i++)
        TextSpan(
          text: i == n - 1 ? parts[i] : '${parts[i]} ',
          style: base(style.color, (p * n - i).clamp(0.0, 1.0)),
        ),
    ]);
  } else {
    span = TextSpan(text: text, style: base(style.color));
  }
  final tp = layout(span);

  var dx = (w - tp.width) / 2;
  var dy = style.y * h - tp.height / 2;
  dy = dy.clamp(8.0, math.max(8.0, h - tp.height - 8));
  var zoom = 1.0;
  switch (effect) {
    case LyricEffect.fade:
      dy += (1 - appear) * 14;
    case LyricEffect.slide:
      dx += (1 - appear) * 60 * (rtl ? 1 : -1);
    case LyricEffect.zoom:
      zoom = 0.55 + 0.45 * Curves.elasticOut.transform(frame.appearT);
    case LyricEffect.karaoke || LyricEffect.wipe || LyricEffect.words:
      break;
  }

  // Overall opacity: entrance (except wipe/words, which reveal
  // themselves) and exit.
  final fadeIn = effect == LyricEffect.wipe || effect == LyricEffect.words
      ? 1.0
      : appear;
  final alpha = math.min(fadeIn, frame.leaveT).clamp(0.0, 1.0);
  if (alpha <= 0) return;

  canvas.save();
  canvas.scale(scale);
  final rect = Rect.fromLTWH(dx, dy, tp.width, tp.height);
  final center = rect.center;
  if (zoom != 1) {
    canvas.translate(center.dx, center.dy);
    canvas.scale(zoom);
    canvas.translate(-center.dx, -center.dy);
  }
  final bounds = rect.inflate(40);
  canvas.saveLayer(
      bounds, Paint()..color = Colors.black.withValues(alpha: alpha));

  if (style.box) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(12), const Radius.circular(14)),
      Paint()..color = Colors.black.withValues(alpha: 0.42),
    );
  }

  switch (effect) {
    case LyricEffect.karaoke:
      // Dimmed line, then the sung part in the accent color.
      layout(TextSpan(text: text, style: base(style.color, 0.55)))
          .paint(canvas, rect.topLeft);
      canvas.saveLayer(bounds, Paint());
      final lit = layout(TextSpan(text: text, style: base(style.accent)))
        ..paint(canvas, rect.topLeft);
      _reveal(canvas, lit, rect, bounds, p, rtl, soft: 10);
      canvas.restore();
    case LyricEffect.wipe:
      canvas.saveLayer(bounds, Paint());
      tp.paint(canvas, rect.topLeft);
      _reveal(canvas, tp, rect, bounds, p, rtl, soft: 28);
      canvas.restore();
    default:
      tp.paint(canvas, rect.topLeft);
  }

  canvas.restore(); // alpha layer
  canvas.restore();
}

/// Keeps the first [p] of the text in reading order (row by row, right
/// to left for Arabic), with a soft edge, by masking the current layer.
void _reveal(Canvas canvas, TextPainter tp, Rect rect, Rect bounds, double p,
    bool rtl,
    {required double soft}) {
  if (p >= 1) return;
  final rows = tp.computeLineMetrics();
  if (rows.isEmpty) return;
  final total = rows.fold<double>(0, (a, r) => a + r.width);
  // The mask (white = visible) is drawn in its own slightly blurred layer
  // and applied with dstIn, so row boundaries never cut glows sharply.
  canvas.saveLayer(
    bounds,
    Paint()
      ..blendMode = BlendMode.dstIn
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
  );
  var done = 0.0;
  for (var k = 0; k < rows.length; k++) {
    final r = rows[k];
    double split(int i) => rect.top +
        rows[i].baseline +
        (rows[i + 1].baseline - rows[i].baseline) * 0.28;
    final top = k == 0 ? bounds.top : split(k - 1);
    final bottom = k == rows.length - 1 ? bounds.bottom : split(k);
    final band = Rect.fromLTRB(bounds.left, top, bounds.right, bottom);
    final rp = ((p * total - done) / r.width).clamp(0.0, 1.0);
    done += r.width;
    if (rp <= 0) continue;
    final paint = Paint()..color = Colors.white;
    if (rp < 1) {
      final left = rect.left + r.left, right = left + r.width;
      final travel = r.width + soft;
      final Offset from, to;
      if (rtl) {
        final edge = right + soft - travel * rp;
        from = Offset(edge, 0);
        to = Offset(edge - soft, 0);
      } else {
        final edge = left - soft + travel * rp;
        from = Offset(edge, 0);
        to = Offset(edge + soft, 0);
      }
      paint.shader =
          ui.Gradient.linear(from, to, const [Colors.white, Colors.transparent]);
    }
    canvas.drawRect(band, paint);
  }
  canvas.restore();
}

/// Live lyrics over the video preview.
class LyricsOverlay extends StatelessWidget {
  const LyricsOverlay({
    super.key,
    required this.lines,
    required this.timings,
    required this.style,
    required this.positionMs,
  });

  final List<LyricLine> lines;
  final List<LyricTiming> timings;
  final LyricsStyle style;
  final ValueNotifier<int> positionMs;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: positionMs,
      builder: (context, ms, _) {
        final frame = Lyrics.frameAt(timings, style.effect, ms);
        return CustomPaint(
          size: Size.infinite,
          painter: frame == null
              ? null
              : _LyricsPainter(lines[frame.line].text, style, frame),
        );
      },
    );
  }
}

class _LyricsPainter extends CustomPainter {
  _LyricsPainter(this.text, this.style, this.frame);

  final String text;
  final LyricsStyle style;
  final LyricsFrame frame;

  @override
  void paint(Canvas canvas, Size size) =>
      paintLyrics(canvas, size, text: text, style: style, frame: frame);

  @override
  bool shouldRepaint(_LyricsPainter old) =>
      old.text != text || old.style != style || old.frame != frame;
}
