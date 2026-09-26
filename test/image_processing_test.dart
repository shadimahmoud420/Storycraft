import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:storycraft/services/image_processing.dart';

RgbaImage _solid(int w, int h, int r, int g, int b) {
  final data = Uint8List(w * h * 4);
  for (var i = 0; i < data.length; i += 4) {
    data[i] = r;
    data[i + 1] = g;
    data[i + 2] = b;
    data[i + 3] = 255;
  }
  return RgbaImage(w, h, data);
}

void main() {
  test('boxBlur keeps a flat image unchanged', () {
    final image = _solid(20, 10, 120, 60, 200);
    final out = boxBlur(image.data, 20, 10, 3);
    expect(out, image.data);
  });

  test('auto tone stretches a dull, low-contrast image', () {
    // Horizontal ramp squeezed into 100..150 with a blue cast.
    const w = 256, h = 4;
    final data = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final v = 100 + x * 50 ~/ 255;
        final i = (y * w + x) * 4;
        data[i] = v;
        data[i + 1] = v;
        data[i + 2] = (v + 40).clamp(0, 255);
        data[i + 3] = 255;
      }
    }
    final image = RgbaImage(w, h, data);
    applyAutoTone(image, strength: 1, targetExposure: false);

    int minOf(int c) => [for (var i = c; i < data.length; i += 4) data[i]]
        .reduce((a, b) => a < b ? a : b);
    int maxOf(int c) => [for (var i = c; i < data.length; i += 4) data[i]]
        .reduce((a, b) => a > b ? a : b);
    for (var c = 0; c < 3; c++) {
      expect(minOf(c), lessThan(10));
      expect(maxOf(c), greaterThan(245));
    }
  });

  test('vibrance leaves greys untouched', () {
    final image = _solid(4, 4, 128, 128, 128);
    applyVibrance(image, 0.5);
    expect(image.data.take(3), [128, 128, 128]);
  });

  test('enhance upscales small photos and returns a valid JPEG', () async {
    final src = img.Image(width: 400, height: 300);
    img.fill(src, color: img.ColorRgb8(90, 120, 150));
    final jpg = img.encodeJpg(src);

    final out = await ImageProcessing.enhance(Uint8List.fromList(jpg));
    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, 800); // 2x cap
    expect(decoded.height, 600);
  });

  test('natural colors returns an image of the same size', () async {
    final src = img.Image(width: 300, height: 500);
    img.fill(src, color: img.ColorRgb8(200, 180, 120));
    final out = await ImageProcessing.naturalColors(
      Uint8List.fromList(img.encodePng(src)),
    );
    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, 300);
    expect(decoded.height, 500);
  });
}
