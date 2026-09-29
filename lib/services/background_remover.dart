import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:subject_cutout/subject_cutout.dart';

export 'package:subject_cutout/subject_cutout.dart' show CutoutError, CutoutException;

/// A cut-out subject, trimmed to its bounds.
class Cutout {
  const Cutout(this.png, this.width, this.height, this.widthFraction);

  final Uint8List png;
  final int width;
  final int height;

  /// Trimmed width / source width: keeps an image layer's on-canvas scale.
  final double widthFraction;

  double get aspect => height / width;
}

/// On-device background removal ("تفريغ الصورة"), free and offline.
class BackgroundRemover {
  BackgroundRemover._();

  /// Throws [CutoutException].
  static Future<Cutout> cutout(Uint8List imageBytes) async {
    final png = await SubjectCutout.removeBackground(imageBytes);
    final trimmed = await compute(trimTransparent, png);
    if (trimmed == null) throw const CutoutException(CutoutError.noSubject);
    return trimmed;
  }
}

/// Crops away (nearly) transparent borders, adds a small margin and caps the
/// size. Returns null when almost nothing is left. Public for tests.
Cutout? trimTransparent(Uint8List png) {
  final src = img.decodeImage(png);
  if (src == null) return null;
  return _trim(src.numChannels == 4 ? src : src.convert(numChannels: 4));
}

Cutout? _trim(img.Image image, {int maxEdge = 1600}) {
  final w = image.width, h = image.height;
  var minX = w, minY = h, maxX = -1, maxY = -1;
  var solid = 0;
  for (final p in image) {
    if (p.a > 24) {
      solid++;
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
  }
  // Under 0.3% of the pixels: nothing real is left.
  if (maxX < 0 || solid < w * h * 0.003) return null;

  final pad = (math.max(maxX - minX, maxY - minY) * 0.02).round();
  final x = math.max(0, minX - pad), y = math.max(0, minY - pad);
  final cw = math.min(w, maxX + pad + 1) - x;
  final ch = math.min(h, maxY + pad + 1) - y;
  var out = img.copyCrop(image, x: x, y: y, width: cw, height: ch);
  if (math.max(cw, ch) > maxEdge) {
    out = cw >= ch
        ? img.copyResize(out, width: maxEdge,
            interpolation: img.Interpolation.average)
        : img.copyResize(out, height: maxEdge,
            interpolation: img.Interpolation.average);
  }
  return Cutout(
    img.encodePng(out, level: 4),
    out.width,
    out.height,
    cw / w,
  );
}

// ---------------------------------------------------------------------------
// Color-key removal: signatures, logos, drawings on a plain background.
// ---------------------------------------------------------------------------

/// Settings for [removeColorBackground].
class ColorKeyOptions {
  const ColorKeyOptions({
    this.tolerance = 0.12,
    this.edgesOnly = false,
    this.recolor,
    this.maxEdge = 2000,
  });

  /// 0…0.5: how different from the background a pixel must be to stay.
  final double tolerance;

  /// Only remove background connected to the image border, keeping
  /// enclosed areas of the same color (e.g. white inside a logo).
  final bool edgesOnly;

  /// Paints the kept drawing in one color (ARGB), e.g. white or gold.
  final int? recolor;

  /// Longest edge processed (smaller for quick previews).
  final int maxEdge;
}

/// Removes a plain background (paper, white, any solid color) and keeps the
/// drawing, with soft anti-aliased edges and no light halo. Runs in an
/// isolate; throws [CutoutException] ([CutoutError.noSubject]) when nothing
/// is left.
Future<Cutout> removeColorBackground(
  Uint8List bytes, [
  ColorKeyOptions options = const ColorKeyOptions(),
]) async {
  final cut = await compute(_colorKeyEntry, (bytes, options));
  if (cut == null) throw const CutoutException(CutoutError.noSubject);
  return cut;
}

Cutout? _colorKeyEntry((Uint8List, ColorKeyOptions) args) =>
    colorKey(args.$1, args.$2);

/// True when the photo's border is (nearly) one flat color, i.e. it looks
/// like a scan or a drawing: a good hint to prefer the color mode.
Future<bool> hasPlainBackground(Uint8List bytes) =>
    compute(_plainEntry, bytes);

bool _plainEntry(Uint8List bytes) {
  final src = img.decodeImage(bytes);
  if (src == null) return false;
  final small = img.copyResize(src, width: math.min(src.width, 300));
  final bg = _borderColor(small);
  var near = 0, total = 0;
  for (final (x, y) in _borderPoints(small.width, small.height)) {
    final p = small.getPixel(x, y);
    total++;
    if (_dist(p.r.toInt(), p.g.toInt(), p.b.toInt(), bg) < 0.12) near++;
  }
  return total > 0 && near / total > 0.85;
}

/// Synchronous core of the color key (public for tests).
Cutout? colorKey(Uint8List bytes, ColorKeyOptions o) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var src = decoded.numChannels == 4
      ? decoded
      : decoded.convert(numChannels: 4);
  if (math.max(src.width, src.height) > o.maxEdge) {
    src = src.width >= src.height
        ? img.copyResize(src, width: o.maxEdge,
            interpolation: img.Interpolation.average)
        : img.copyResize(src, height: o.maxEdge,
            interpolation: img.Interpolation.average);
  }
  final w = src.width, h = src.height;
  final bg = _borderColor(src);

  // Distance of every pixel from the background color, 0…1.
  final dist = Float32List(w * h);
  for (final p in src) {
    dist[p.y * w + p.x] = _dist(p.r.toInt(), p.g.toInt(), p.b.toInt(), bg);
  }

  // Ink contrast: how far the drawing's solid strokes are from the
  // background (90th percentile of the clearly-not-background pixels).
  final lo = o.tolerance.clamp(0.01, 0.5);
  final strong = [for (final d in dist) if (d > lo) d]..sort();
  if (strong.isEmpty) return null;
  final ink = math.max(lo + 0.08, strong[(strong.length * 0.9).floor()]);

  // Edges-only: background = pixels close to the key color that are
  // connected to the border.
  Uint8List? outside;
  if (o.edgesOnly) {
    outside = Uint8List(w * h);
    final queue = <int>[];
    for (final (x, y) in _borderPoints(w, h, step: 1)) {
      final i = y * w + x;
      if (outside[i] == 0 && dist[i] < ink * 0.6) {
        outside[i] = 1;
        queue.add(i);
      }
    }
    while (queue.isNotEmpty) {
      final i = queue.removeLast();
      final x = i % w, y = i ~/ w;
      for (final n in [
        if (x > 0) i - 1,
        if (x < w - 1) i + 1,
        if (y > 0) i - w,
        if (y < h - 1) i + w,
      ]) {
        if (outside[n] == 0 && dist[n] < ink * 0.6) {
          outside[n] = 1;
          queue.add(n);
        }
      }
    }
  }

  final rc = o.recolor;
  final out = img.Image(width: w, height: h, numChannels: 4);
  for (final p in src) {
    final i = p.y * w + p.x;
    var a = ((dist[i] - lo) / (ink - lo)).clamp(0.0, 1.0);
    if (outside != null && outside[i] == 0) a = 1;
    if (a <= 0) continue; // stays transparent
    int r, g, b;
    if (rc != null) {
      r = (rc >> 16) & 0xFF;
      g = (rc >> 8) & 0xFF;
      b = rc & 0xFF;
    } else {
      // Un-mix the background from edge pixels: color = bg + (c - bg) / a,
      // so anti-aliased edges keep the ink color instead of a white halo.
      final k = a < 1 && (outside == null || outside[i] == 1) ? a : 1.0;
      r = (bg.$1 + (p.r - bg.$1) / k).round().clamp(0, 255);
      g = (bg.$2 + (p.g - bg.$2) / k).round().clamp(0, 255);
      b = (bg.$3 + (p.b - bg.$3) / k).round().clamp(0, 255);
    }
    out.setPixelRgba(p.x, p.y, r, g, b, (a * p.a).round());
  }
  return _trim(out, maxEdge: o.maxEdge);
}

double _dist(int r, int g, int b, (int, int, int) c) =>
    math.max((r - c.$1).abs(), math.max((g - c.$2).abs(), (b - c.$3).abs())) /
    255;

Iterable<(int, int)> _borderPoints(int w, int h, {int step = 2}) sync* {
  for (var x = 0; x < w; x += step) {
    yield (x, 0);
    yield (x, h - 1);
  }
  for (var y = 0; y < h; y += step) {
    yield (0, y);
    yield (w - 1, y);
  }
}

/// Background color: per-channel median of the border pixels.
(int, int, int) _borderColor(img.Image im) {
  final rs = <int>[], gs = <int>[], bs = <int>[];
  for (final (x, y) in _borderPoints(im.width, im.height)) {
    final p = im.getPixel(x, y);
    rs.add(p.r.toInt());
    gs.add(p.g.toInt());
    bs.add(p.b.toInt());
  }
  int median(List<int> v) => (v..sort())[v.length ~/ 2];
  return (median(rs), median(gs), median(bs));
}
