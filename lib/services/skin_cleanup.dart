import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:subject_cutout/subject_cutout.dart';

import 'image_processing.dart';

typedef Pt = math.Point<double>;

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

/// Skin cleanup: removes spots, blemishes and redness and evens the tone
/// of the face, while keeping the natural skin texture (pores, fine
/// detail) — nothing is blurred. Guided by on-device face landmarks, so
/// only the face's skin is touched (eyes, brows, lips, beard, hair and
/// background stay exactly as shot).
class SkinCleanup {
  SkinCleanup._();

  static const defaultStrength = 0.7;
  static const previewEdge = 1280;

  /// Finds faces in an upright JPEG. Replaceable in tests.
  static Future<List<FaceLandmarks>> Function(Uint8List jpg) detector =
      _detectNative;

  static Future<List<FaceLandmarks>> _detectNative(Uint8List jpg) async {
    try {
      final maps = await SubjectCutout.detectFaces(jpg);
      return maps.map(FaceLandmarks.fromMap).nonNulls.toList();
    } on CutoutException {
      return const [];
    }
  }

  /// Cleans every face in [bytes] at full resolution; returns a JPEG, or
  /// null when no face was found (the photo is then left as it is).
  static Future<Uint8List?> apply(Uint8List bytes, double strength) async {
    final p = await compute(_preparePreview, bytes);
    final faces = await detector(p.jpg);
    if (faces.isEmpty) return null;
    return compute(_applyFull, (bytes, p.width, faces, strength));
  }
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
  if (long > SkinCleanup.previewEdge) {
    final k = SkinCleanup.previewEdge / long;
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

Uint8List _applyFull((Uint8List, int, List<FaceLandmarks>, double) a) {
  final image = RgbaImage.decode(a.$1, fullSize: true);
  final k = image.width / a.$2;
  applySkinCleanup(image, [for (final f in a.$3) f.scaled(k)], a.$4);
  return image.encodeJpg(quality: 95);
}

// ---------------------------------------------------------------------------
// The cleanup itself (public for unit tests).
// ---------------------------------------------------------------------------

/// Cleans the skin of every face in [image] in place; [strength] 0 – 1.
void applySkinCleanup(
    RgbaImage image, List<FaceLandmarks> faces, double strength) {
  if (strength <= 0) return;
  for (final face in faces) {
    _cleanFace(image, _FaceGeometry(face), strength);
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
  late final Pt eyeL, eyeR, eyeMid, mouth, up;
  late final double eyeToMouth, eyeDist;
  late final List<Pt> outline;
}

/// Frequency separation on the face's skin:
/// - texture (finer than a pore-sized blur): kept;
/// - spot layer (pore-sized vs. spot-sized blur): spots, pimples and
///   blotches are removed from it, the rest is gently evened;
/// - tone layer (the spot-sized blur): redness pulled toward the
///   surrounding skin.
void _cleanFace(RgbaImage image, _FaceGeometry g, double strength) {
  final w = image.width, d = image.data;

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
  final int y1 = math.min(image.height, (maxY + margin).ceil());
  if (x1 - x0 < 8 || y1 - y0 < 8) return;
  // Work grid: about 360 px across the face.
  final int f = math.max(1, ((x1 - x0) / 360).floor());
  final int ww = (x1 - x0 + f - 1) ~/ f, wh = (y1 - y0 + f - 1) ~/ f;
  final n = ww * wh;

  List<Pt> toWork(List<Pt> l) =>
      [for (final p in l) Pt((p.x - x0) / f, (p.y - y0) / f)];
  final eyeW = g.eyeDist / f;

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

  // Skin tone sampled on the cheeks and forehead.
  final down = Pt(-g.up.x, -g.up.y);
  final probes = [
    toWork([_add(g.eyeL, down, g.eyeToMouth * 0.5)]).first,
    toWork([_add(g.eyeR, down, g.eyeToMouth * 0.5)]).first,
    toWork([_add(g.eyeMid, g.up, g.eyeToMouth * 0.45)]).first,
  ];
  var sy = 0.0, scb = 0.0, scr = 0.0, scb2 = 0.0, scr2 = 0.0;
  var count = 0;
  final rad = math.max(2, (eyeW * 0.12).round());
  for (final c in probes) {
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
  // Generous: blemishes are redder than the average skin.
  final sigma = math.max(12.0, sdc * 2.8);

  // Skin mask: inside the face, skin-colored, not too dark (beard, hair),
  // away from eyes, brows and lips.
  final face = _fill(toWork(g.outline), ww, wh);
  final exclude = Float32List(n);
  void cut(List<Pt> poly, double grow) {
    if (poly.length < 3) return;
    final m = _fill(toWork(_grow(poly, grow)), ww, wh);
    for (var i = 0; i < n; i++) {
      exclude[i] = math.max(exclude[i], m[i]);
    }
  }

  cut(_hull(g.face.leftEye), 1.5);
  cut(_hull(g.face.rightEye), 1.5);
  cut(_hull(g.face.leftBrow), 1.3);
  cut(_hull(g.face.rightBrow), 1.3);
  cut(_star(g.face.outerLips), 1.1);

  final skinW = Float32List(n);
  for (var i = 0; i < n; i++) {
    final (yy, cb, cr) = _ycc(wr[i], wg[i], wb[i]);
    final dc = (cb - mcb) * (cb - mcb) + (cr - mcr) * (cr - mcr);
    final tone = math.exp(-dc / (2 * sigma * sigma));
    final light = _smooth(my * 0.35, my * 0.6, yy);
    skinW[i] = tone * light * face[i] * (1 - exclude[i]);
  }
  final skinMask =
      _blurF(skinW, ww, wh, math.max(1, (eyeW * 0.05).round()), 2);

  // Spot-sized and wide skin-only blurs (normalized by the skin weight so
  // nothing outside the skin leaks in).
  final pr = Float32List(n), pg = Float32List(n), pb = Float32List(n);
  for (var i = 0; i < n; i++) {
    pr[i] = wr[i] * skinW[i];
    pg[i] = wg[i] * skinW[i];
    pb[i] = wb[i] * skinW[i];
  }
  // Pore-sized blur: finer than this is texture, kept as it is.
  final int fr = math.max(1, (eyeW * 0.018).round());
  final fR = _blurF(wr, ww, wh, fr, 2);
  final fG = _blurF(wg, ww, wh, fr, 2);
  final fB = _blurF(wb, ww, wh, fr, 2);
  final int sr = math.max(fr + 1, (eyeW * 0.07).round());
  final sm = _blurF(skinW, ww, wh, sr, 3);
  final sR = _blurF(pr, ww, wh, sr, 3);
  final sG = _blurF(pg, ww, wh, sr, 3);
  final sB = _blurF(pb, ww, wh, sr, 3);
  final int lr = math.max(2, (eyeW * 0.22).round());
  final lm = _blurF(skinW, ww, wh, lr, 3);
  final lR = _blurF(pr, ww, wh, lr, 3);
  final lG = _blurF(pg, ww, wh, lr, 3);
  final lB = _blurF(pb, ww, wh, lr, 3);

  for (var y = y0; y < y1; y++) {
    final fy = (y - y0 + 0.5) / f - 0.5;
    for (var x = x0; x < x1; x++) {
      final fx = (x - x0 + 0.5) / f - 0.5;
      final ms = _sample(skinMask, ww, wh, fx, fy);
      final k = strength * ms;
      if (k < 0.004) continue;
      final m = _sample(sm, ww, wh, fx, fy);
      final ml = _sample(lm, ww, wh, fx, fy);
      if (m <= 0.02 || ml <= 0.02) continue;

      final i = (y * w + x) * 4;
      final (oy, ocb, ocr) = _ycc(d[i].toDouble(), d[i + 1].toDouble(),
          d[i + 2].toDouble());
      final (gy, gcb, gcr) = _ycc(_sample(fR, ww, wh, fx, fy),
          _sample(fG, ww, wh, fx, fy), _sample(fB, ww, wh, fx, fy));
      final (my2, mcb2, mcr2) = _ycc(_sample(sR, ww, wh, fx, fy) / m,
          _sample(sG, ww, wh, fx, fy) / m, _sample(sB, ww, wh, fx, fy) / m);
      final (by, bcb, bcr) = _ycc(_sample(lR, ww, wh, fx, fy) / ml,
          _sample(lG, ww, wh, fx, fy) / ml, _sample(lB, ww, wh, fx, fy) / ml);

      // Layers.
      final ty = oy - gy, tcb = ocb - gcb, tcr = ocr - gcr; // texture
      var dy = gy - my2, dcb = gcb - mcb2, dcr = gcr - mcr2; // spot layer
      var ly = my2, lcb = mcb2, lcr = mcr2; // tone layer

      // Spots: darker or redder than around, but not deep features
      // (nostrils, beard edges, lash line).
      final dark = -dy;
      final spotDark = _smooth(2.5, 9, dark) * (1 - _smooth(38, 65, dark));
      final spotRed = _smooth(1.5, 6, dcr);
      final spot = math.max(spotDark, spotRed);
      // Gentle evening for small unevenness only; deep features untouched.
      final uneven = 1 - _smooth(18, 40, dy.abs());
      final keep = 1 - k * (0.15 * uneven + 0.85 * spot);
      dy *= keep;
      dcb *= keep;
      dcr *= keep;

      // Tone: redness and blotches toward the surrounding skin (only
      // reduce redness, never add it); shadows lifted a little.
      if (lcr > bcr) lcr += (bcr - lcr) * k * 0.6;
      lcb += (bcb - lcb) * k * 0.35;
      if (ly < by) {
        final lift = (by - ly) * k * 0.45 * (1 - _smooth(25, 60, by - ly));
        ly += lift;
      }

      // Texture kept, minus the part of it that belongs to a spot.
      final tk = 1 - k * spot * 0.35;
      final yy = ly + dy + ty * tk;
      final cb = lcb + dcb + tcb * tk;
      final cr = lcr + dcr + tcr * tk;
      d[i] = (yy + 1.402 * cr).round().clamp(0, 255);
      d[i + 1] = (yy - 0.344136 * cb - 0.714136 * cr).round().clamp(0, 255);
      d[i + 2] = (yy + 1.772 * cb).round().clamp(0, 255);
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

(double, double, double) _ycc(double r, double g, double b) => (
      0.299 * r + 0.587 * g + 0.114 * b,
      -0.1687 * r - 0.3313 * g + 0.5 * b,
      0.5 * r - 0.4187 * g - 0.0813 * b,
    );

double _smooth(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}
