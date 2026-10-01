import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:storycraft/services/image_processing.dart';
import 'package:storycraft/services/skin_cleanup.dart';

// A synthetic 400x500 portrait: skin oval with fine "pore" noise and a few
// dark/red spots, eyes, brows, lips and a noisy background.
const _cx = 200.0, _cy = 250.0, _rx = 120.0, _ry = 160.0;

List<Pt> _ellipse(double cx, double cy, double rx, double ry, [int n = 24]) => [
      for (var i = 0; i < n; i++)
        Pt(cx + rx * math.cos(2 * math.pi * i / n),
            cy + ry * math.sin(2 * math.pi * i / n)),
    ];

final _face = FaceLandmarks(
  contour: [
    for (var i = 0; i <= 12; i++)
      Pt(_cx - _rx * math.cos(math.pi * i / 12),
          _cy + _ry * math.sin(math.pi * i / 12)),
  ],
  leftEye: _ellipse(155, 220, 22, 9),
  rightEye: _ellipse(245, 220, 22, 9),
  leftBrow: _ellipse(155, 195, 26, 5),
  rightBrow: _ellipse(245, 195, 26, 5),
  outerLips: _ellipse(200, 330, 38, 14),
  innerLips: _ellipse(200, 330, 30, 3),
  nose: [const Pt(180, 290), const Pt(200, 298), const Pt(220, 290)],
);

bool _in(num x, num y, double cx, double cy, double rx, double ry) =>
    math.pow((x - cx) / rx, 2) + math.pow((y - cy) / ry, 2) <= 1;

const _spots = [(130, 280, true), (260, 300, false), (150, 380, true)];

RgbaImage _portrait() {
  final rnd = math.Random(5);
  final im = img.Image(width: 400, height: 500, numChannels: 4);
  for (final p in im) {
    final n = rnd.nextInt(16) - 8; // fine texture
    int r, g, b;
    if (_in(p.x, p.y, 155, 220, 22, 9) || _in(p.x, p.y, 245, 220, 22, 9)) {
      (r, g, b) = (110, 80, 60);
    } else if (_in(p.x, p.y, 155, 195, 26, 5) ||
        _in(p.x, p.y, 245, 195, 26, 5)) {
      (r, g, b) = (50, 35, 30);
    } else if (_in(p.x, p.y, 200, 330, 38, 14)) {
      (r, g, b) = (175, 95, 90);
    } else if (_in(p.x, p.y, _cx, _cy, _rx, _ry + 20)) {
      (r, g, b) = (215 + n, 172 + n, 148 + n);
      for (final (sx, sy, dark) in _spots) {
        if (_in(p.x, p.y, sx.toDouble(), sy.toDouble(), 5, 5)) {
          (r, g, b) = dark ? (175 + n, 130 + n, 110 + n) : (225 + n, 135 + n, 125 + n);
        }
      }
    } else {
      (r, g, b) = (90 + n, 140 + n, 200 + n);
    }
    p
      ..r = r
      ..g = g
      ..b = b
      ..a = 255;
  }
  return RgbaImage.decode(img.encodePng(im), fullSize: true);
}

(int, int, int) _px(RgbaImage im, int x, int y) {
  final i = (y * im.width + x) * 4;
  return (im.data[i], im.data[i + 1], im.data[i + 2]);
}

double _variance(RgbaImage im, int x0, int y0, int size) {
  final v = <int>[];
  for (var y = y0; y < y0 + size; y++) {
    for (var x = x0; x < x0 + size; x++) {
      v.add(im.data[(y * im.width + x) * 4 + 1]);
    }
  }
  final mean = v.reduce((a, b) => a + b) / v.length;
  return v.map((e) => (e - mean) * (e - mean)).reduce((a, b) => a + b) /
      v.length;
}

void main() {
  test('spots fade, texture stays, background untouched', () {
    final before = _portrait();
    final after = _portrait();
    applySkinCleanup(after, [_face], 1);

    // Dark spot: much closer to the surrounding skin.
    final (_, gBefore, _) = _px(before, 130, 280);
    final (_, gAfter, _) = _px(after, 130, 280);
    expect((172 - gAfter).abs(), lessThan((172 - gBefore).abs() * 0.6));

    // Red spot: less red.
    double redness(RgbaImage im) {
      final (r, g, _) = _px(im, 260, 300);
      return (r - g).toDouble();
    }

    expect(redness(after), lessThan(redness(before) - 10));

    // Pores (fine noise) on clean skin are kept: not blurred away.
    expect(_variance(after, 220, 250, 20),
        greaterThan(_variance(before, 220, 250, 20) * 0.6));

    // Background exactly the same.
    for (final (x, y) in [(10, 10), (390, 490), (30, 250)]) {
      expect(_px(after, x, y), _px(before, x, y));
    }
    // Brows unchanged.
    expect(_px(after, 155, 195), _px(before, 155, 195));
  });

  test('zero strength changes nothing', () {
    final a = _portrait();
    applySkinCleanup(a, [_face], 0);
    expect(a.data, _portrait().data);
  });

  test('no face: photo left as it is', () async {
    SkinCleanup.detector = (_) async => const [];
    addTearDown(() => SkinCleanup.detector = (_) async => const []);
    expect(await SkinCleanup.apply(_portrait().encodeJpg(), 0.7), isNull);
  });
}
