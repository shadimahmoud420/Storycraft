import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../core/config.dart';

/// On-device photo processing. Every public method runs in a background
/// isolate via [compute] so the UI stays smooth, and needs no internet.
class ImageProcessing {
  ImageProcessing._();

  /// Normalizes an imported photo: applies EXIF rotation, limits the size
  /// and re-encodes as JPEG.
  static Future<Uint8List> prepareImport(Uint8List bytes) =>
      compute(_prepare, bytes);

  /// One-tap "natural colors": automatic white balance, levels, exposure
  /// and gentle vibrance so the photo looks true to life.
  static Future<Uint8List> naturalColors(Uint8List bytes) =>
      compute(_natural, bytes);

  /// One-tap "smart enhance": upscales small photos, recovers detail
  /// (edge-aware sharpening + local contrast / clarity) and refines tones.
  static Future<Uint8List> enhance(Uint8List bytes) =>
      compute(_enhance, bytes);
}

// ---------------------------------------------------------------------------
// Isolate entry points (must be top-level).
// ---------------------------------------------------------------------------

Uint8List _prepare(Uint8List bytes) {
  final rgba = RgbaImage.decode(bytes);
  return rgba.encodeJpg();
}

Uint8List _natural(Uint8List bytes) {
  final rgba = RgbaImage.decode(bytes);
  applyAutoTone(rgba, strength: 0.8, targetExposure: true);
  applyVibrance(rgba, 0.18);
  return rgba.encodeJpg();
}

Uint8List _enhance(Uint8List bytes) {
  final rgba = RgbaImage.decode(bytes, upscaleLongEdgeTo: 1920);
  applyAutoTone(rgba, strength: 0.4, targetExposure: false);
  applyDetail(rgba);
  applyVibrance(rgba, 0.10);
  return rgba.encodeJpg(quality: 95);
}

// ---------------------------------------------------------------------------
// Pixel buffer helpers (public for unit tests).
// ---------------------------------------------------------------------------

/// Plain RGBA8888 buffer – faster than per-pixel object access.
class RgbaImage {
  RgbaImage(this.width, this.height, this.data)
      : assert(data.length == width * height * 4);

  final int width;
  final int height;
  final Uint8List data;

  factory RgbaImage.decode(Uint8List bytes, {int? upscaleLongEdgeTo}) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Unsupported image format');
    }
    var image = img.bakeOrientation(decoded);

    final longEdge = math.max(image.width, image.height);
    double scale = 1;
    if (longEdge > AppConfig.maxImageEdge) {
      scale = AppConfig.maxImageEdge / longEdge;
    } else if (upscaleLongEdgeTo != null && longEdge < upscaleLongEdgeTo) {
      // Upscale at most 2x; bigger jumps only add blur.
      scale = math.min(2.0, upscaleLongEdgeTo / longEdge);
    }
    if (scale != 1) {
      image = img.copyResize(
        image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round(),
        interpolation:
            scale > 1 ? img.Interpolation.cubic : img.Interpolation.average,
      );
    }

    if (image.format != img.Format.uint8 || image.numChannels != 4) {
      image = image.convert(format: img.Format.uint8, numChannels: 4);
    }
    final data = Uint8List.fromList(
      image.getBytes(order: img.ChannelOrder.rgba),
    );
    return RgbaImage(image.width, image.height, data);
  }

  Uint8List encodeJpg({int quality = 94}) {
    final image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: data.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    return img.encodeJpg(image, quality: quality);
  }
}

/// Per-channel auto levels (acts as auto white balance + contrast) and an
/// optional exposure (gamma) correction toward a mid-tone target.
void applyAutoTone(
  RgbaImage image, {
  required double strength,
  required bool targetExposure,
}) {
  final d = image.data;
  final pixels = image.width * image.height;
  final hist = List.generate(3, (_) => List<int>.filled(256, 0));
  for (var i = 0; i < d.length; i += 4) {
    hist[0][d[i]]++;
    hist[1][d[i + 1]]++;
    hist[2][d[i + 2]]++;
  }

  final clip = (pixels * 0.005).round();
  final luts = List.generate(3, (_) => Uint8List(256));
  for (var c = 0; c < 3; c++) {
    var low = 0, high = 255, acc = 0;
    for (var v = 0; v < 256; v++) {
      acc += hist[c][v];
      if (acc > clip) {
        low = v;
        break;
      }
    }
    acc = 0;
    for (var v = 255; v >= 0; v--) {
      acc += hist[c][v];
      if (acc > clip) {
        high = v;
        break;
      }
    }
    // Nearly flat channels (e.g. a plain wall) are left alone.
    final range = high - low;
    for (var v = 0; v < 256; v++) {
      final stretched =
          range < 32 ? v.toDouble() : (v - low) * 255 / range;
      final mixed = v + (stretched - v) * strength;
      luts[c][v] = mixed.round().clamp(0, 255);
    }
  }

  if (targetExposure) {
    // Mean luminance after levels, estimated from the histograms.
    double mean = 0;
    const w = [0.2126, 0.7152, 0.0722];
    for (var c = 0; c < 3; c++) {
      var sum = 0;
      for (var v = 0; v < 256; v++) {
        sum += hist[c][v] * luts[c][v];
      }
      mean += w[c] * sum / pixels;
    }
    final m = (mean / 255).clamp(0.02, 0.98);
    if (m < 0.40 || m > 0.60) {
      final target = m < 0.40 ? 0.45 : 0.55;
      final gamma = (math.log(target) / math.log(m)).clamp(0.75, 1.35);
      for (var c = 0; c < 3; c++) {
        for (var v = 0; v < 256; v++) {
          final x = luts[c][v] / 255;
          luts[c][v] = (math.pow(x, gamma) * 255).round().clamp(0, 255);
        }
      }
    }
  }

  for (var i = 0; i < d.length; i += 4) {
    d[i] = luts[0][d[i]];
    d[i + 1] = luts[1][d[i + 1]];
    d[i + 2] = luts[2][d[i + 2]];
  }
}

/// Boosts muted colors more than already-saturated ones (avoids neon skin).
void applyVibrance(RgbaImage image, double amount) {
  final d = image.data;
  for (var i = 0; i < d.length; i += 4) {
    final r = d[i], g = d[i + 1], b = d[i + 2];
    final mx = math.max(r, math.max(g, b));
    final mn = math.min(r, math.min(g, b));
    final sat = (mx - mn) / 255;
    final k = 1 + amount * (1 - sat);
    final l = 0.299 * r + 0.587 * g + 0.114 * b;
    d[i] = (l + (r - l) * k).round().clamp(0, 255);
    d[i + 1] = (l + (g - l) * k).round().clamp(0, 255);
    d[i + 2] = (l + (b - l) * k).round().clamp(0, 255);
  }
}

/// Detail recovery: fine unsharp mask with a noise threshold plus a wide,
/// subtle one for local contrast ("clarity").
void applyDetail(
  RgbaImage image, {
  double sharpen = 0.7,
  double clarity = 0.22,
  int threshold = 3,
}) {
  final w = image.width, h = image.height, d = image.data;
  final fine = boxBlur(d, w, h, 1);
  final wideRadius = math.max(4, math.max(w, h) ~/ 160);
  final wide = boxBlur(boxBlur(d, w, h, wideRadius), w, h, wideRadius);

  for (var i = 0; i < d.length; i++) {
    if ((i & 3) == 3) continue; // alpha
    final o = d[i];
    final fineDiff = o - fine[i];
    var v = o + clarity * (o - wide[i]);
    if (fineDiff.abs() > threshold) v += sharpen * fineDiff;
    d[i] = v.round().clamp(0, 255);
  }
}

/// Separable O(n) box blur on RGB channels; alpha is copied through.
Uint8List boxBlur(Uint8List src, int w, int h, int r) {
  final tmp = Uint8List(src.length);
  final out = Uint8List(src.length);
  final div = 2 * r + 1;

  // Horizontal pass.
  for (var y = 0; y < h; y++) {
    final row = y * w * 4;
    for (var c = 0; c < 4; c++) {
      if (c == 3) {
        for (var x = 0; x < w; x++) {
          tmp[row + x * 4 + 3] = src[row + x * 4 + 3];
        }
        continue;
      }
      var sum = 0;
      for (var k = -r; k <= r; k++) {
        sum += src[row + math.min(math.max(k, 0), w - 1) * 4 + c];
      }
      for (var x = 0; x < w; x++) {
        tmp[row + x * 4 + c] = sum ~/ div;
        final add = math.min(x + r + 1, w - 1);
        final sub = math.max(x - r, 0);
        sum += src[row + add * 4 + c] - src[row + sub * 4 + c];
      }
    }
  }

  // Vertical pass.
  final stride = w * 4;
  for (var x = 0; x < w; x++) {
    final col = x * 4;
    for (var c = 0; c < 4; c++) {
      if (c == 3) {
        for (var y = 0; y < h; y++) {
          out[y * stride + col + 3] = tmp[y * stride + col + 3];
        }
        continue;
      }
      var sum = 0;
      for (var k = -r; k <= r; k++) {
        sum += tmp[math.min(math.max(k, 0), h - 1) * stride + col + c];
      }
      for (var y = 0; y < h; y++) {
        out[y * stride + col + c] = sum ~/ div;
        final add = math.min(y + r + 1, h - 1);
        final sub = math.max(y - r, 0);
        sum += tmp[add * stride + col + c] - tmp[sub * stride + col + c];
      }
    }
  }
  return out;
}
