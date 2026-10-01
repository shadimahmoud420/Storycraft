import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:storycraft/data/filters.dart';
import 'package:storycraft/screens/camera_screen.dart';
import 'package:storycraft/services/image_processing.dart';

double _variance(RgbaImage im, int x0, int y0, int size) {
  final values = <int>[];
  for (var y = y0; y < y0 + size; y++) {
    for (var x = x0; x < x0 + size; x++) {
      values.add(im.data[(y * im.width + x) * 4]);
    }
  }
  final mean = values.reduce((a, b) => a + b) / values.length;
  return values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
      values.length;
}

void main() {
  test('new looks exist and only Glow adds the soft blur', () {
    for (final f in [PhotoFilter.glow, PhotoFilter.food, PhotoFilter.nature]) {
      expect(PhotoFilters.matrixOf(f), hasLength(20));
      expect(PhotoFilters.blended(f, 0), PhotoFilters.identity);
    }
    expect(PhotoFilters.glowOf(PhotoFilter.glow, 0.7), 0.7);
    expect(PhotoFilters.glowOf(PhotoFilter.food, 0.7), 0);
  });

  test('food boosts warm colors, nature boosts greens', () {
    int apply(List<double> m, int row, List<int> rgb) =>
        (m[row * 5] * rgb[0] + m[row * 5 + 1] * rgb[1] + m[row * 5 + 2] * rgb[2] + m[row * 5 + 4]).round();
    final food = PhotoFilters.blended(PhotoFilter.food, 1);
    final tomato = [200, 80, 50];
    expect(apply(food, 0, tomato) - apply(food, 1, tomato),
        greaterThan(tomato[0] - tomato[1])); // redder
    final nature = PhotoFilters.blended(PhotoFilter.nature, 1);
    final leaf = [70, 140, 60];
    expect(apply(nature, 1, leaf) - apply(nature, 0, leaf),
        greaterThan(leaf[1] - leaf[0])); // greener
  });

  test('glow smooths flat skin-like areas but keeps edges sharp', () {
    // Left half: noisy "skin"; right half: dark; a hard edge between them.
    final rnd = math.Random(1);
    final im = img.Image(width: 400, height: 300, numChannels: 4);
    for (final p in im) {
      if (p.x < 200) {
        final v = 190 + rnd.nextInt(24) - 12;
        p..r = v..g = v - 30..b = v - 50..a = 255;
      } else {
        p..r = 30..g = 30..b = 30..a = 255;
      }
    }
    final rgba = RgbaImage.decode(img.encodePng(im), fullSize: true);
    final noiseBefore = _variance(rgba, 40, 100, 60);
    applyGlow(rgba, 1);
    expect(_variance(rgba, 40, 100, 60), lessThan(noiseBefore * 0.6));
    // Across the edge the contrast is still strong.
    final left = rgba.data[(150 * 400 + 194) * 4];
    final right = rgba.data[(150 * 400 + 206) * 4];
    expect(left - right, greaterThan(120));
  });

  test('applyLook keeps the full camera resolution', () async {
    final im = img.Image(width: 1600, height: 2844); // > 2400 long edge
    final out = await ImageProcessing.applyLook(
      img.encodeJpg(im),
      PhotoFilters.blended(PhotoFilter.food, 0.8),
      0,
    );
    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, 1600);
    expect(decoded.height, 2844);
  });

  testWidgets('camera screen without a camera shows a friendly message',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      supportedLocales: [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: CameraScreen(),
    ));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Glow'), findsOneWidget);
    expect(find.text('طعام'), findsOneWidget);
  });

  testWidgets('filtered view renders every look', (tester) async {
    for (final f in cameraFilters) {
      await tester.pumpWidget(MaterialApp(
        home: filteredView(f, 0.8,
            const SizedBox(width: 90, height: 160, child: ColoredBox(color: Colors.orange))),
      ));
      expect(tester.takeException(), isNull);
    }
  });
}
