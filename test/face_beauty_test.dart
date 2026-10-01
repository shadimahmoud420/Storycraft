import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:storycraft/screens/beauty_screen.dart';
import 'package:storycraft/services/face_beauty.dart';
import 'package:storycraft/services/image_processing.dart';

// A synthetic 400x500 portrait: noisy skin oval, dark eyes and brows, red
// lips, dark nostrils, a dark fringe of hair and a noisy background.
const _cx = 200.0, _cy = 250.0, _rx = 120.0, _ry = 160.0;

List<Pt> _ellipse(double cx, double cy, double rx, double ry, [int n = 24]) => [
      for (var i = 0; i < n; i++)
        Pt(cx + rx * math.cos(2 * math.pi * i / n),
            cy + ry * math.sin(2 * math.pi * i / n)),
    ];

final _face = FaceLandmarks(
  // Jaw only (as on iOS); the forehead is derived from the brows.
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
  noseCrest: [const Pt(200, 225), const Pt(200, 260), const Pt(200, 285)],
);

bool _inEllipse(num x, num y, double cx, double cy, double rx, double ry) =>
    math.pow((x - cx) / rx, 2) + math.pow((y - cy) / ry, 2) <= 1;

RgbaImage _portrait() {
  final rnd = math.Random(3);
  final im = img.Image(width: 400, height: 500, numChannels: 4);
  for (final p in im) {
    final n = rnd.nextInt(30) - 15;
    int r, g, b;
    if (_inEllipse(p.x, p.y, 155, 220, 22, 9) ||
        _inEllipse(p.x, p.y, 245, 220, 22, 9)) {
      (r, g, b) = (120, 90, 70); // eyes
    } else if (_inEllipse(p.x, p.y, 155, 195, 26, 5) ||
        _inEllipse(p.x, p.y, 245, 195, 26, 5)) {
      (r, g, b) = (50, 35, 30); // brows
    } else if (_inEllipse(p.x, p.y, 200, 330, 38, 14)) {
      (r, g, b) = (170, 90, 90); // lips
    } else if ((p.x - 186).abs() < 4 && (p.y - 290).abs() < 4 ||
        (p.x - 214).abs() < 4 && (p.y - 290).abs() < 4) {
      (r, g, b) = (60, 40, 35); // nostrils
    } else if (_inEllipse(p.x, p.y, _cx, _cy, _rx, _ry + 20)) {
      if (p.y < 130) {
        (r, g, b) = (45 + n, 35 + n, 30 + n); // hair fringe
      } else {
        (r, g, b) = (215 + n, 170 + n, 145 + n); // skin
      }
    } else {
      (r, g, b) = (90 + n, 140 + n, 200 + n); // background
    }
    p
      ..r = r
      ..g = g
      ..b = b
      ..a = 255;
  }
  return RgbaImage.decode(img.encodePng(im), fullSize: true);
}

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

(int, int, int) _px(RgbaImage im, int x, int y) {
  final i = (y * im.width + x) * 4;
  return (im.data[i], im.data[i + 1], im.data[i + 2]);
}

double _mean(RgbaImage im, int x0, int y0, int w, int h, int c) {
  var sum = 0;
  for (var y = y0; y < y0 + h; y++) {
    for (var x = x0; x < x0 + w; x++) {
      sum += im.data[(y * im.width + x) * 4 + c];
    }
  }
  return sum / (w * h);
}

void main() {
  test('skin is smoothed; background and hair are untouched', () {
    final before = _portrait();
    final after = _portrait();
    applyBeauty(after, [_face], const BeautySettings(skin: 1));
    // Cheek: much smoother.
    expect(_variance(after, 120, 260, 24),
        lessThan(_variance(before, 120, 260, 24) * 0.4));
    // Background: bit for bit the same (no blur outside the face).
    for (final (x, y) in [(20, 20), (380, 480), (40, 250), (360, 120)]) {
      expect(_px(after, x, y), _px(before, x, y));
    }
    // Dark hair inside the face outline is not treated as skin.
    expect(_variance(after, 180, 105, 16),
        greaterThan(_variance(before, 180, 105, 16) * 0.6));
    // Eyes and brows keep their edges.
    expect(_px(after, 155, 195).$1, lessThan(90));
  });

  test('eyes brighten, lips gain color', () {
    final before = _portrait();
    final after = _portrait();
    applyBeauty(after, [_face], const BeautySettings(eyes: 1, lips: 1));
    expect(_mean(after, 145, 216, 20, 8, 0),
        greaterThan(_mean(before, 145, 216, 20, 8, 0) + 8));
    double sat(RgbaImage im) =>
        _mean(im, 185, 320, 30, 6, 0) - _mean(im, 185, 320, 30, 6, 1);
    expect(sat(after), greaterThan(sat(before) * 1.2));
  });

  test('nose slimming pulls the nostrils toward the center', () {
    final after = _portrait();
    applyBeauty(after, [_face], const BeautySettings(nose: 1));
    // Darkest column of the left nostril moved right (toward x = 200).
    int darkest(RgbaImage im) {
      var best = 0, bestV = 999;
      for (var x = 170; x < 200; x++) {
        final v = _px(im, x, 290).$1;
        if (v < bestV) {
          bestV = v;
          best = x;
        }
      }
      return best;
    }

    expect(darkest(after), greaterThan(darkest(_portrait())));
    // Far from the nose nothing moves.
    expect(_px(after, 60, 400), _px(_portrait(), 60, 400));
  });

  test('zero settings change nothing', () {
    final a = _portrait();
    applyBeauty(a, [_face], const BeautySettings());
    expect(a.data, _portrait().data);
  });

  test('landmarks parse from the plugin format', () {
    List<double> flat(List<Pt> l) => [for (final p in l) ...[p.x, p.y]];
    final face = FaceLandmarks.fromMap({
      'contour': flat(_face.contour),
      'leftEye': flat(_face.leftEye),
      'rightEye': flat(_face.rightEye),
      'outerLips': flat(_face.outerLips),
    })!;
    expect(face.leftEye, hasLength(24));
    expect(face.nose, isEmpty);
    expect(face.scaled(2).leftEye.first.x, _face.leftEye.first.x * 2);
    expect(FaceLandmarks.fromMap({'contour': [1, 2, 3, 4]}), isNull);
  });

  group('beauty screen', () {
    late Uint8List jpg;
    setUp(() => jpg = _portrait().encodeJpg());
    tearDown(() => FaceBeauty.detector = (b) async => []);

    Widget app(Widget home) => MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: home,
        );

    testWidgets('shows sliders and applies', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      FaceBeauty.detector = (b) async => [_face];
      BeautyResult? result;
      await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => BeautyScreen(imageBytes: jpg)),
            ),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      for (var i = 0; i < 10 && find.byType(RawImage).evaluate().isEmpty; i++) {
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 500)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(Slider), findsNWidgets(4));
      expect(find.text('تنقية البشرة'), findsOneWidget);
      expect(find.byType(RawImage), findsOneWidget);
      await tester.tap(find.text('تطبيق'));
      for (var i = 0; i < 8 && result == null; i++) {
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 500)));
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(result, isNotNull);
      expect(result!.settings, BeautySettings.natural);
      expect(img.decodeJpg(result!.bytes)!.width, 400);
      expect(tester.takeException(), isNull);
    });

    testWidgets('explains when there is no face', (tester) async {
      FaceBeauty.detector = (b) async => [];
      await tester.pumpWidget(app(BeautyScreen(imageBytes: jpg)));
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
      await tester.pump();
      expect(find.text('لم يتم العثور على وجه واضح في الصورة'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });
  });
}
