import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:storycraft/data/surfaces.dart';
import 'package:storycraft/screens/product_studio_screen.dart';
import 'package:storycraft/widgets/product_scene.dart';

void main() {
  test('every surface has its asset', () {
    expect(studioSurfaces.length, greaterThanOrEqualTo(10));
    for (final s in studioSurfaces) {
      expect(File(s.asset).existsSync(), isTrue, reason: s.asset);
      expect(s.ar, isNotEmpty);
    }
  });

  test('light matching tints toward the scene, brightness lifts', () {
    final neutral = productLightMatrix(null, 1, 0);
    expect(neutral[0], 1);
    expect(neutral[6], 1);
    final warm = productLightMatrix(const Color(0xFFA27D5B), 1, 0);
    expect(warm[0], greaterThan(1)); // more red
    expect(warm[12], lessThan(1)); // less blue
    final bright = productLightMatrix(null, 0, 1);
    expect(bright[0], greaterThan(1));
    expect(bright[4], greaterThan(0));
  });

  testWidgets('scene renders lying and standing, glossy and studio',
      (tester) async {
    final product = img.encodePng(img.Image(width: 40, height: 60, numChannels: 4)
      ..clear(img.ColorRgba8(200, 50, 50, 255)));
    for (final standing in [false, true]) {
      for (final s in [studioSurfaces.first, studioSurfaces.last]) {
        await tester.pumpWidget(MaterialApp(
          home: Center(
            child: ProductScene(
              product: product,
              productAspect: 1.5,
              center: const Offset(180, 520),
              width: 200,
              look: ProductLook(standing: standing, blur: 0.3),
              surface: s,
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('studio starts by picking a product photo', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      supportedLocales: [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ProductStudioScreen(),
    ));
    expect(find.text('استوديو المنتجات'), findsOneWidget);
    expect(find.text('اختر صورة المنتج'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
