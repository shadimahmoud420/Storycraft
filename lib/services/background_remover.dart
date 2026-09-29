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
  final image = src.numChannels == 4 ? src : src.convert(numChannels: 4);
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
  // Under 0.3% of the pixels: segmentation found no real subject.
  if (maxX < 0 || solid < w * h * 0.003) return null;

  final pad = (math.max(maxX - minX, maxY - minY) * 0.02).round();
  final x = math.max(0, minX - pad), y = math.max(0, minY - pad);
  final cw = math.min(w, maxX + pad + 1) - x;
  final ch = math.min(h, maxY + pad + 1) - y;
  var out = img.copyCrop(image, x: x, y: y, width: cw, height: ch);
  const maxEdge = 1600;
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
