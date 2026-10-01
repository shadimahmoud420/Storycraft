import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:subject_cutout/subject_cutout.dart';

import 'image_processing.dart';

typedef Pt = math.Point<double>;

/// Strength of each face retouch, 0 – 1.
@immutable
class BeautySettings {
  const BeautySettings({
    this.skin = 0,
    this.eyes = 0,
    this.lips = 0,
    this.nose = 0,
  });

  /// Light, natural defaults: smooth skin, a hint of sparkle, color and
  /// slimming.
  static const natural =
      BeautySettings(skin: 0.6, eyes: 0.5, lips: 0.45, nose: 0.5);

  final double skin;
  final double eyes;
  final double lips;
  final double nose;

  bool get isNone => skin <= 0 && eyes <= 0 && lips <= 0 && nose <= 0;

  BeautySettings copyWith(
          {double? skin, double? eyes, double? lips, double? nose}) =>
      BeautySettings(
        skin: skin ?? this.skin,
        eyes: eyes ?? this.eyes,
        lips: lips ?? this.lips,
        nose: nose ?? this.nose,
      );

  @override
  bool operator ==(Object other) =>
      other is BeautySettings &&
      other.skin == skin &&
      other.eyes == eyes &&
      other.lips == lips &&
      other.nose == nose;

  @override
  int get hashCode => Object.hash(skin, eyes, lips, nose);
}

/// Face landmarks in image pixels (origin top left).
@immutable
class FaceLandmarks {
  const FaceLandmarks({
    required this.contour,
    required this.leftEye,
    required this.rightEye,
    this.leftBrow = const [],
    this.rightBrow = const [],
    required this.outerLips,
    this.innerLips = const [],
    this.nose = const [],
    this.noseCrest = const [],
  });

  /// From the `subject_cutout` plugin's flat lists; null when a face lacks
  /// the regions the retouch needs.
  static FaceLandmarks? fromMap(Map<String, List<double>> m) {
    List<Pt> pts(String k) {
      final v = m[k] ?? const <double>[];
      return [for (var i = 0; i + 1 < v.length; i += 2) Pt(v[i], v[i + 1])];
    }

    final face = FaceLandmarks(
      contour: pts('contour'),
      leftEye: pts('leftEye'),
      rightEye: pts('rightEye'),
      leftBrow: pts('leftBrow'),
      rightBrow: pts('rightBrow'),
      outerLips: pts('outerLips'),
      innerLips: pts('innerLips'),
      nose: pts('nose'),
      noseCrest: pts('noseCrest'),
    );
    return face.contour.length >= 3 &&
            face.leftEye.length >= 3 &&
            face.rightEye.length >= 3 &&
            face.outerLips.length >= 3
        ? face
        : null;
  }

  final List<Pt> contour;
  final List<Pt> leftEye;
  final List<Pt> rightEye;
  final List<Pt> leftBrow;
  final List<Pt> rightBrow;
  final List<Pt> outerLips;
  final List<Pt> innerLips;
  final List<Pt> nose;
  final List<Pt> noseCrest;

  FaceLandmarks scaled(double k) {
    List<Pt> s(List<Pt> l) => [for (final p in l) Pt(p.x * k, p.y * k)];
    return FaceLandmarks(
      contour: s(contour),
      leftEye: s(leftEye),
      rightEye: s(rightEye),
      leftBrow: s(leftBrow),
      rightBrow: s(rightBrow),
      outerLips: s(outerLips),
      innerLips: s(innerLips),
      nose: s(nose),
      noseCrest: s(noseCrest),
    );
  }
}

enum BeautyError { unsupported, preparing, noFace, failed }

class BeautyException implements Exception {
  const BeautyException(this.error);

  final BeautyError error;

  @override
  String toString() => 'BeautyException($error)';
}

/// A photo ready for interactive retouching: a screen-size upright copy
/// and the faces found in it.
class BeautyPreview {
  const BeautyPreview({
    required this.rgba,
    required this.width,
    required this.height,
    required this.fullWidth,
    required this.faces,
  });

  final Uint8List rgba;
  final int width;
  final int height;

  /// Width of the upright full-resolution photo (landmarks scale to it).
  final int fullWidth;
  final List<FaceLandmarks> faces;
}

/// Face-only retouching: skin smoothing, eye sparkle, lip color and nose
/// slimming, guided by on-device face landmarks. The rest of the photo
/// (hair, beard, background) stays untouched and sharp.
class FaceBeauty {
  FaceBeauty._();

  static const previewEdge = 1280;

  /// Finds faces in an upright JPEG. Replaceable in tests.
  static Future<List<FaceLandmarks>> Function(Uint8List jpg) detector =
      _detectNative;

  static Future<List<FaceLandmarks>> _detectNative(Uint8List jpg) async {
    try {
      final maps = await SubjectCutout.detectFaces(jpg);
      return maps.map(FaceLandmarks.fromMap).nonNulls.toList();
    } on CutoutException catch (e) {
      throw BeautyException(switch (e.error) {
        CutoutError.unsupported => BeautyError.unsupported,
        CutoutError.preparing => BeautyError.preparing,
        _ => BeautyError.failed,
      });
    }
  }

  /// Decodes [bytes] at screen size and finds the faces.
  /// Throws [BeautyException] (noFace when there is none).
  static Future<BeautyPreview> preview(Uint8List bytes) async {
    final p = await compute(_preparePreview, bytes);
    final faces = await detector(p.jpg);
    if (faces.isEmpty) throw const BeautyException(BeautyError.noFace);
    return BeautyPreview(
      rgba: p.rgba,
      width: p.width,
      height: p.height,
      fullWidth: p.fullWidth,
      faces: faces,
    );
  }

  /// The retouched preview as RGBA pixels.
  static Future<Uint8List> render(BeautyPreview p, BeautySettings s) =>
      compute(_renderPreview, (p.rgba, p.width, p.height, p.faces, s));

  /// Retouches the full-resolution photo; returns a JPEG.
  static Future<Uint8List> apply(
          Uint8List bytes, BeautyPreview p, BeautySettings s) =>
      compute(_applyFull, (bytes, p.width, p.faces, s));

  /// One step: detect and retouch at full resolution.
  static Future<Uint8List> auto(Uint8List bytes, BeautySettings s) async =>
      apply(bytes, await preview(bytes), s);
}

typedef _Prepared = ({
  Uint8List rgba,
  int width,
  int height,
  int fullWidth,
  Uint8List jpg,
});

_Prepared _preparePreview(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported image');
  var image = img.bakeOrientation(decoded);
  final fullWidth = image.width;
  final long = math.max(image.width, image.height);
  if (long > FaceBeauty.previewEdge) {
    final k = FaceBeauty.previewEdge / long;
    image = img.copyResize(image,
        width: (image.width * k).round(),
        height: (image.height * k).round(),
        interpolation: img.Interpolation.average);
  }
  if (image.format != img.Format.uint8 || image.numChannels != 4) {
    image = image.convert(format: img.Format.uint8, numChannels: 4);
  }
  return (
    rgba: Uint8List.fromList(image.getBytes(order: img.ChannelOrder.rgba)),
    width: image.width,
    height: image.height,
    fullWidth: fullWidth,
    jpg: img.encodeJpg(image, quality: 90),
  );
}

Uint8List _renderPreview(
    (Uint8List, int, int, List<FaceLandmarks>, BeautySettings) a) {
  final image = RgbaImage(a.$2, a.$3, Uint8List.fromList(a.$1));
  applyBeauty(image, a.$4, a.$5);
  return image.data;
}

Uint8List _applyFull((Uint8List, int, List<FaceLandmarks>, BeautySettings) a) {
  final image = RgbaImage.decode(a.$1, fullSize: true);
  final k = image.width / a.$2;
  applyBeauty(image, [for (final f in a.$3) f.scaled(k)], a.$4);
  return image.encodeJpg(quality: 95);
}

// ---------------------------------------------------------------------------
// The retouch itself (public for unit tests).
// ---------------------------------------------------------------------------

/// Retouches every face in [image] in place.
void applyBeauty(
    RgbaImage image, List<FaceLandmarks> faces, BeautySettings s) {
  if (s.isNone) return;
  for (final face in faces) {
    final g = _FaceGeometry(face);
    if (s.nose > 0) _slimNose(image, g, s.nose);
    _retouch(image, g, s);
  }
}

/// Derived measurements of one face.
class _FaceGeometry {
  _FaceGeometry(this.face) {
    eyeL = _centroid(face.leftEye);
    eyeR = _centroid(face.rightEye);
    eyeMid = Pt((eyeL.x + eyeR.x) / 2, (eyeL.y + eyeR.y) / 2);
    mouth = _centroid(face.outerLips);
    final dx = eyeMid.x - mouth.x, dy = eyeMid.y - mouth.y;
    eyeToMouth = math.max(1, math.sqrt(dx * dx + dy * dy));
    up = Pt(dx / eyeToMouth, dy / eyeToMouth);
    side = Pt(-up.y, up.x);
    eyeDist = math.max(1, eyeL.distanceTo(eyeR));

    // Outline: jaw/oval plus the forehead (brows lifted toward the
    // hairline); hair inside it is rejected later by the skin-tone test.
    final brows = [...face.leftBrow, ...face.rightBrow];
    final browBase = brows.isNotEmpty
        ? brows
        : [
            for (final p in [...face.leftEye, ...face.rightEye])
              _add(p, up, eyeToMouth * 0.35),
          ];
    outline = _hull([
      ...face.contour,
      ...browBase,
      for (final p in browBase) _add(p, up, eyeToMouth * 0.75),
      ...face.leftEye,
      ...face.rightEye,
      ...face.outerLips,
    ]);
  }

  final FaceLandmarks face;
  late final Pt eyeL, eyeR, eyeMid, mouth, up, side;
  late final double eyeToMouth, eyeDist;
  late final List<Pt> outline;
}

/// Smooth skin, eye sparkle and lip color, inside the face only.
void _retouch(RgbaImage image, _FaceGeometry g, BeautySettings s) {
  final w = image.width, h = image.height, d = image.data;

  // Work area: the face plus a margin, at a reduced "work" resolution for
  // masks and the smoothing blur (both are soft anyway).
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final p in g.outline) {
    minX = math.min(minX, p.x);
    minY = math.min(minY, p.y);
    maxX = math.max(maxX, p.x);
    maxY = math.max(maxY, p.y);
  }
  final margin = g.eyeDist * 0.15;
  final int x0 = math.max(0, (minX - margin).floor());
  final int y0 = math.max(0, (minY - margin).floor());
  final int x1 = math.min(w, (maxX + margin).ceil());
  final int y1 = math.min(h, (maxY + margin).ceil());
  if (x1 - x0 < 8 || y1 - y0 < 8) return;
  final int f = math.max(1, ((x1 - x0) / 360).floor());
  final int ww = (x1 - x0 + f - 1) ~/ f, wh = (y1 - y0 + f - 1) ~/ f;
  final n = ww * wh;

  List<Pt> toWork(List<Pt> l) =>
      [for (final p in l) Pt((p.x - x0) / f, (p.y - y0) / f)];
  final eyeW = g.eyeDist / f;

  // Work-resolution copy (box-averaged).
  final wr = Float32List(n), wg = Float32List(n), wb = Float32List(n);
  for (var y = 0; y < wh; y++) {
    for (var x = 0; x < ww; x++) {
      var r = 0, gg = 0, b = 0, c = 0;
      for (var yy = y0 + y * f; yy < math.min(y1, y0 + (y + 1) * f); yy++) {
        for (var xx = x0 + x * f; xx < math.min(x1, x0 + (x + 1) * f); xx++) {
          final i = (yy * w + xx) * 4;
          r += d[i];
          gg += d[i + 1];
          b += d[i + 2];
          c++;
        }
      }
      final o = y * ww + x;
      wr[o] = r / c;
      wg[o] = gg / c;
      wb[o] = b / c;
    }
  }

  // Skin tone from the cheeks (below the eyes, beside the nose).
  final down = Pt(-g.up.x, -g.up.y);
  final cheeks = [
    toWork([_add(g.eyeL, down, g.eyeToMouth * 0.5)]).first,
    toWork([_add(g.eyeR, down, g.eyeToMouth * 0.5)]).first,
    toWork([_add(g.eyeMid, g.up, g.eyeToMouth * 0.45)]).first, // forehead
  ];
  var sy = 0.0, scb = 0.0, scr = 0.0, scb2 = 0.0, scr2 = 0.0;
  var count = 0;
  final rad = math.max(2, (eyeW * 0.12).round());
  for (final c in cheeks) {
    for (var y = c.y.round() - rad; y <= c.y.round() + rad; y++) {
      for (var x = c.x.round() - rad; x <= c.x.round() + rad; x++) {
        if (x < 0 || y < 0 || x >= ww || y >= wh) continue;
        final o = y * ww + x;
        final (yy, cb, cr) = _ycc(wr[o], wg[o], wb[o]);
        sy += yy;
        scb += cb;
        scr += cr;
        scb2 += cb * cb;
        scr2 += cr * cr;
        count++;
      }
    }
  }
  if (count == 0) return;
  final my = sy / count, mcb = scb / count, mcr = scr / count;
  final sdc = math.sqrt(math.max(
      0, (scb2 / count - mcb * mcb) + (scr2 / count - mcr * mcr)));
  final sigma = math.max(9.0, sdc * 2.2);

  // Masks.
  final face = _fill(toWork(g.outline), ww, wh);
  final exclude = Float32List(n);
  void cut(List<Pt> poly, double grow) {
    if (poly.length < 3) return;
    final m = _fill(toWork(_grow(poly, grow)), ww, wh);
    for (var i = 0; i < n; i++) {
      exclude[i] = math.max(exclude[i], m[i]);
    }
  }

  cut(_hull(g.face.leftEye), 1.6);
  cut(_hull(g.face.rightEye), 1.6);
  cut(_hull(g.face.leftBrow), 1.3);
  cut(_hull(g.face.rightBrow), 1.3);
  cut(_star(g.face.outerLips), 1.12);

  final skinW = Float32List(n);
  for (var i = 0; i < n; i++) {
    final (yy, cb, cr) = _ycc(wr[i], wg[i], wb[i]);
    final dc = (cb - mcb) * (cb - mcb) + (cr - mcr) * (cr - mcr);
    final tone = math.exp(-dc / (2 * sigma * sigma));
    // Hair and beard are much darker than skin.
    final light = _smooth(my * 0.38, my * 0.62, yy);
    skinW[i] = tone * light * face[i] * (1 - exclude[i]);
  }
  final skinMask = _blurF(skinW, ww, wh, math.max(1, (eyeW * 0.06).round()), 2);

  // Normalized blur: only skin pixels feed the smoothing, so the face edge
  // never picks up background or hair colors.
  final int sr = math.max(1, (eyeW * 0.07).round());
  final pr = Float32List(n), pg = Float32List(n), pb = Float32List(n);
  for (var i = 0; i < n; i++) {
    pr[i] = wr[i] * skinW[i];
    pg[i] = wg[i] * skinW[i];
    pb[i] = wb[i] * skinW[i];
  }
  final bm = _blurF(skinW, ww, wh, sr, 3);
  final br = _blurF(pr, ww, wh, sr, 3);
  final bg = _blurF(pg, ww, wh, sr, 3);
  final bb = _blurF(pb, ww, wh, sr, 3);

  final eyeMask = Float32List(n);
  for (final eye in [g.face.leftEye, g.face.rightEye]) {
    final m = _fill(toWork(_grow(_hull(eye), 1.08)), ww, wh);
    for (var i = 0; i < n; i++) {
      eyeMask[i] = math.max(eyeMask[i], m[i]);
    }
  }
  final eyeSoft = _blurF(eyeMask, ww, wh, math.max(1, (eyeW * 0.025).round()), 2);

  final lipMask = _fill(toWork(_star(g.face.outerLips)), ww, wh);
  if (g.face.innerLips.length >= 3) {
    final inner = _fill(toWork(_grow(_star(g.face.innerLips), 1.1)), ww, wh);
    for (var i = 0; i < n; i++) {
      lipMask[i] = math.max(0, lipMask[i] - inner[i]);
    }
  }
  final lipSoft = _blurF(lipMask, ww, wh, math.max(1, (eyeW * 0.02).round()), 2);

  // Full-resolution pass over the face area.
  final src = Uint8List.fromList(d);
  final skinK = s.skin * 0.85;
  for (var y = y0; y < y1; y++) {
    final fy = (y - y0 + 0.5) / f - 0.5;
    for (var x = x0; x < x1; x++) {
      final fx = (x - x0 + 0.5) / f - 0.5;
      final ms = _sample(skinMask, ww, wh, fx, fy);
      final me = s.eyes > 0 ? _sample(eyeSoft, ww, wh, fx, fy) : 0.0;
      final ml = s.lips > 0 ? _sample(lipSoft, ww, wh, fx, fy) : 0.0;
      if (ms * skinK < 0.004 && me < 0.004 && ml < 0.004) continue;

      final i = (y * w + x) * 4;
      var r = d[i].toDouble(), gg = d[i + 1].toDouble(), b = d[i + 2].toDouble();

      // Skin: pull toward the smooth skin color where the difference is a
      // blemish or pore; strong detail (nostrils, moles, edges) stays.
      if (ms * skinK >= 0.004) {
        final m = _sample(bm, ww, wh, fx, fy);
        if (m > 0.02) {
          final sr2 = _sample(br, ww, wh, fx, fy) / m;
          final sg2 = _sample(bg, ww, wh, fx, fy) / m;
          final sb2 = _sample(bb, ww, wh, fx, fy) / m;
          final diff = ((r - sr2) * 0.3 + (gg - sg2) * 0.59 + (b - sb2) * 0.11)
              .abs();
          final keep = 1 - _smooth(16, 50, diff);
          final t = skinK * ms * keep;
          r += (sr2 - r) * t;
          gg += (sg2 - gg) * t;
          b += (sb2 - b) * t;
          // A soft, even glow.
          final lift = s.skin * ms * 5;
          r += lift;
          gg += lift;
          b += lift * 0.8;
        }
      }

      // Eyes: crisper detail, brighter iris, whiter whites, livelier
      // catchlights.
      if (me >= 0.004) {
        final k = me * s.eyes;
        var mr = 0.0, mg = 0.0, mb = 0.0, c = 0;
        for (var yy = math.max(0, y - 1); yy <= math.min(h - 1, y + 1); yy++) {
          for (var xx = math.max(0, x - 1); xx <= math.min(w - 1, x + 1); xx++) {
            final j = (yy * w + xx) * 4;
            mr += src[j];
            mg += src[j + 1];
            mb += src[j + 2];
            c++;
          }
        }
        r += (src[i] - mr / c) * 1.1 * k;
        gg += (src[i + 1] - mg / c) * 1.1 * k;
        b += (src[i + 2] - mb / c) * 1.1 * k;
        final l = r * 0.3 + gg * 0.59 + b * 0.11;
        final whites = _smooth(105, 170, l);
        // Desaturate the whites a little (less red), brighten everything.
        r += (l - r) * whites * 0.35 * k;
        gg += (l - gg) * whites * 0.35 * k;
        b += (l - b) * whites * 0.35 * k;
        final bright = 0.13 * k;
        r += (255 - r) * bright;
        gg += (255 - gg) * bright;
        b += (255 - b) * bright;
        final spark = _smooth(175, 235, l) * 30 * k;
        r += spark;
        gg += spark;
        b += spark;
      }

      // Lips: richer, slightly rosier color.
      if (ml >= 0.004) {
        final k = ml * s.lips;
        final l = r * 0.3 + gg * 0.59 + b * 0.11;
        final sat = 1 + 0.5 * k;
        r = l + (r - l) * sat + 4 * k;
        gg = l + (gg - l) * sat - 2 * k;
        b = l + (b - l) * sat + 2 * k;
      }

      d[i] = r.round().clamp(0, 255);
      d[i + 1] = gg.round().clamp(0, 255);
      d[i + 2] = b.round().clamp(0, 255);
    }
  }
}

/// Gently pulls the sides of the nose toward its center line (a local,
/// smooth warp; nothing else moves).
void _slimNose(RgbaImage image, _FaceGeometry g, double amount) {
  final w = image.width, h = image.height, d = image.data;
  final down = Pt(-g.up.x, -g.up.y);
  final nose = g.face.nose.isNotEmpty ? g.face.nose : g.face.noseCrest;
  if (nose.isEmpty) return;

  // Nose bottom: the lowest nose point along the face axis.
  var length = 0.0, minU = double.infinity, maxU = -double.infinity;
  for (final p in nose) {
    final vx = p.x - g.eyeMid.x, vy = p.y - g.eyeMid.y;
    length = math.max(length, vx * down.x + vy * down.y);
    final u = vx * g.side.x + vy * g.side.y;
    minU = math.min(minU, u);
    maxU = math.max(maxU, u);
  }
  length = length.clamp(g.eyeToMouth * 0.4, g.eyeToMouth * 0.85);
  var width = maxU - minU;
  width = width.clamp(g.eyeDist * 0.35, g.eyeDist * 0.8);
  final center = _add(g.eyeMid, down, length * 0.8);
  final cu = ((minU + maxU) / 2).clamp(-width / 2, width / 2);
  final c = _add(center, g.side, g.face.nose.isNotEmpty ? cu : 0);

  final rx = width * 1.0;
  final ryUp = length * 0.75, ryDown = length * 0.45;
  final s = 0.32 * amount;
  final reach = math.max(rx, ryUp) + 2;
  final int bx0 = math.max(0, (c.x - reach).floor());
  final int by0 = math.max(0, (c.y - reach).floor());
  final int bx1 = math.min(w - 1, (c.x + reach).ceil());
  final int by1 = math.min(h - 1, (c.y + reach).ceil());
  if (bx1 <= bx0 || by1 <= by0) return;
  final src = Uint8List.fromList(d);

  for (var y = by0; y <= by1; y++) {
    for (var x = bx0; x <= bx1; x++) {
      final vx = x - c.x, vy = y - c.y;
      final u = vx * g.side.x + vy * g.side.y; // across the nose
      final v = vx * down.x + vy * down.y; // along the nose
      final ry = v < 0 ? ryUp : ryDown;
      final r2 = (u / rx) * (u / rx) + (v / ry) * (v / ry);
      if (r2 >= 1) continue;
      final fall = (1 - r2) * (1 - r2);
      final us = u * (1 + s * fall);
      final sx = c.x + us * g.side.x + v * down.x;
      final sy = c.y + us * g.side.y + v * down.y;
      _bilinear(src, w, h, sx, sy, d, (y * w + x) * 4);
    }
  }
}

// ---------------------------------------------------------------------------
// Geometry and buffer helpers.
// ---------------------------------------------------------------------------

Pt _add(Pt p, Pt dir, double k) => Pt(p.x + dir.x * k, p.y + dir.y * k);

Pt _centroid(List<Pt> l) {
  var x = 0.0, y = 0.0;
  for (final p in l) {
    x += p.x;
    y += p.y;
  }
  return Pt(x / l.length, y / l.length);
}

/// Scales a polygon about its centroid.
List<Pt> _grow(List<Pt> poly, double k) {
  if (poly.isEmpty) return poly;
  final c = _centroid(poly);
  return [for (final p in poly) Pt(c.x + (p.x - c.x) * k, c.y + (p.y - c.y) * k)];
}

/// Points ordered by angle around their centroid: a simple polygon for
/// star-shaped regions (lips), whatever order the platform used.
List<Pt> _star(List<Pt> pts) {
  if (pts.length < 3) return pts;
  final c = _centroid(pts);
  return [...pts]..sort((a, b) =>
      math.atan2(a.y - c.y, a.x - c.x).compareTo(math.atan2(b.y - c.y, b.x - c.x)));
}

/// Convex hull (monotone chain).
List<Pt> _hull(List<Pt> pts) {
  if (pts.length < 3) return pts;
  final p = [...pts]..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
  double cross(Pt o, Pt a, Pt b) =>
      (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
  final lower = <Pt>[], upper = <Pt>[];
  for (final q in p) {
    while (lower.length >= 2 && cross(lower[lower.length - 2], lower.last, q) <= 0) {
      lower.removeLast();
    }
    lower.add(q);
  }
  for (final q in p.reversed) {
    while (upper.length >= 2 && cross(upper[upper.length - 2], upper.last, q) <= 0) {
      upper.removeLast();
    }
    upper.add(q);
  }
  return [...lower..removeLast(), ...upper..removeLast()];
}

/// Rasterizes a polygon (even-odd, pixel centers) into a 0/1 grid.
Float32List _fill(List<Pt> poly, int w, int h) {
  final out = Float32List(w * h);
  if (poly.length < 3) return out;
  final xs = <double>[];
  for (var y = 0; y < h; y++) {
    final cy = y + 0.5;
    xs.clear();
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length];
      if ((a.y <= cy && b.y > cy) || (b.y <= cy && a.y > cy)) {
        xs.add(a.x + (cy - a.y) / (b.y - a.y) * (b.x - a.x));
      }
    }
    xs.sort();
    for (var k = 0; k + 1 < xs.length; k += 2) {
      final int from = math.max(0, (xs[k] - 0.5).ceil());
      final int to = math.min(w - 1, (xs[k + 1] - 0.5).floor());
      for (var x = from; x <= to; x++) {
        out[y * w + x] = 1;
      }
    }
  }
  return out;
}

/// Repeated separable box blur of a float grid (≈ Gaussian).
Float32List _blurF(Float32List src, int w, int h, int r, int passes) {
  var a = Float32List.fromList(src);
  final tmp = Float32List(src.length);
  final div = 2 * r + 1;
  for (var p = 0; p < passes; p++) {
    for (var y = 0; y < h; y++) {
      final row = y * w;
      var sum = 0.0;
      for (var k = -r; k <= r; k++) {
        sum += a[row + k.clamp(0, w - 1)];
      }
      for (var x = 0; x < w; x++) {
        tmp[row + x] = sum / div;
        sum += a[row + math.min(w - 1, x + r + 1)] - a[row + math.max(0, x - r)];
      }
    }
    for (var x = 0; x < w; x++) {
      var sum = 0.0;
      for (var k = -r; k <= r; k++) {
        sum += tmp[k.clamp(0, h - 1) * w + x];
      }
      for (var y = 0; y < h; y++) {
        a[y * w + x] = sum / div;
        sum += tmp[math.min(h - 1, y + r + 1) * w + x] -
            tmp[math.max(0, y - r) * w + x];
      }
    }
  }
  return a;
}

double _sample(Float32List g, int w, int h, double x, double y) {
  final xc = x.clamp(0.0, w - 1.0), yc = y.clamp(0.0, h - 1.0);
  final int ix = xc.floor(), iy = yc.floor();
  final int jx = math.min(w - 1, ix + 1), jy = math.min(h - 1, iy + 1);
  final tx = xc - ix, ty = yc - iy;
  final top = g[iy * w + ix] + (g[iy * w + jx] - g[iy * w + ix]) * tx;
  final bot = g[jy * w + ix] + (g[jy * w + jx] - g[jy * w + ix]) * tx;
  return top + (bot - top) * ty;
}

void _bilinear(Uint8List src, int w, int h, double x, double y, Uint8List dst,
    int o) {
  final xc = x.clamp(0.0, w - 1.0), yc = y.clamp(0.0, h - 1.0);
  final int ix = xc.floor(), iy = yc.floor();
  final int jx = math.min(w - 1, ix + 1), jy = math.min(h - 1, iy + 1);
  final tx = xc - ix, ty = yc - iy;
  for (var c = 0; c < 3; c++) {
    final a = src[(iy * w + ix) * 4 + c], b = src[(iy * w + jx) * 4 + c];
    final e = src[(jy * w + ix) * 4 + c], f = src[(jy * w + jx) * 4 + c];
    final top = a + (b - a) * tx, bot = e + (f - e) * tx;
    dst[o + c] = (top + (bot - top) * ty).round().clamp(0, 255);
  }
}

(double, double, double) _ycc(double r, double g, double b) => (
      0.299 * r + 0.587 * g + 0.114 * b,
      -0.1687 * r - 0.3313 * g + 0.5 * b,
      0.5 * r - 0.4187 * g - 0.0813 * b,
    );

double _smooth(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}
