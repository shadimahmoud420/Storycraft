import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:storycraft/data/filters.dart';
import 'package:storycraft/screens/camera_screen.dart';
import 'package:storycraft/services/image_processing.dart';

void main() {
  test('new looks exist', () {
    for (final f in [PhotoFilter.glow, PhotoFilter.food, PhotoFilter.nature]) {
      expect(PhotoFilters.matrixOf(f), hasLength(20));
      expect(PhotoFilters.blended(f, 0), PhotoFilters.identity);
    }
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

  test('applyLook keeps the full camera resolution', () async {
    final im = img.Image(width: 1600, height: 2844); // > 2400 long edge
    final out = await ImageProcessing.applyLook(
      img.encodeJpg(im),
      PhotoFilters.blended(PhotoFilter.food, 0.8),
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
