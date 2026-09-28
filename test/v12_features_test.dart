import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storycraft/data/filters.dart';
import 'package:storycraft/data/fonts.dart';
import 'package:storycraft/data/formats.dart';
import 'package:storycraft/models/story_background.dart';
import 'package:storycraft/models/story_layer.dart';
import 'package:storycraft/state/editor_controller.dart';
import 'package:storycraft/widgets/story_view.dart';
import 'package:storycraft/widgets/styled_text.dart';

void main() {
  test('every catalog font file is bundled and registered', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(StoryFonts.arabic.length, greaterThan(40));
    expect(StoryFonts.english.length, greaterThan(30));
    for (final f in StoryFonts.all) {
      expect(pubspec, contains('family: ${f.family}\n'), reason: f.family);
      final file = 'assets/fonts/${f.family.replaceAll(' ', '')}-400.ttf';
      expect(File(file).existsSync(), isTrue, reason: file);
    }
    for (final arabic in [true, false]) {
      expect(StoryFonts.categories(arabic: arabic), isNotEmpty);
    }
  });

  test('new text style fields survive a JSON round trip', () {
    final l = StoryLayer(
      id: 'a',
      text: 'ذهب',
      fill: TextFill.gold,
      color2: const Color(0xFF00FF00),
      strokeWidth: 3,
      strokeColor: const Color(0xFF112233),
      letterSpacing: 4,
      lineHeight: 1.8,
      curve: -0.5,
    );
    final b = StoryLayer.fromJson(
      jsonDecode(jsonEncode(l.toJson())) as Map<String, dynamic>,
    );
    expect(b.fill, TextFill.gold);
    expect(b.color2, const Color(0xFF00FF00));
    expect(b.strokeWidth, 3);
    expect(b.strokeColor, const Color(0xFF112233));
    expect(b.letterSpacing, 4);
    expect(b.lineHeight, 1.8);
    expect(b.curve, -0.5);
  });

  test('filters: zero intensity is the identity, full is the preset', () {
    for (final f in PhotoFilter.values) {
      final zero = PhotoFilters.blended(f, 0);
      final full = PhotoFilters.blended(f, 1);
      final m = PhotoFilters.matrixOf(f);
      for (var i = 0; i < 20; i++) {
        expect(zero[i], closeTo(PhotoFilters.identity[i], 1e-9));
        expect(full[i], closeTo(m[i], 1e-9));
      }
      expect(PhotoFilters.matrixOf(f), hasLength(20));
    }
    final bg = StoryBackground.image(Uint8List(4))
        .copyWith(filter: PhotoFilter.mono, filterIntensity: 0.5);
    final back = StoryBackground.fromJson(
      jsonDecode(jsonEncode(bg.toJson())) as Map<String, dynamic>,
      image: Uint8List(4),
    );
    expect(back.filter, PhotoFilter.mono);
    expect(back.filterIntensity, 0.5);
  });

  test('format change keeps layers in the same relative place, undoable', () {
    final c = EditorController(const StoryBackground.solid(Colors.white));
    final l = c.addText('hi');
    final before = l.position.dy / c.canvasSize.height;
    c.setFormat(StoryFormat.square);
    expect(c.canvasSize, const Size(360, 360));
    expect(c.layers.single.position.dy / 360, closeTo(before, 1e-9));
    c.undo();
    expect(c.format, StoryFormat.story);
    expect(c.canvasSize.height, 640);
  });

  testWidgets('styled and curved text render in every fill without errors',
      (tester) async {
    final layers = [
      for (final fill in TextFill.values)
        for (final curve in [0.0, 0.6, -0.6])
          StoryLayer(
            id: '$fill$curve',
            text: 'رمضان كريم',
            font: StoryFonts.byFamily('Aref Ruqaa'),
            fill: fill,
            curve: curve,
            strokeWidth: 2,
            shadow: true,
          ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Wrap(children: [
            for (final l in layers) StoryLayerVisual(layer: l),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(CurvedText), findsWidgets);
    expect(find.byType(ShaderMask), findsWidgets);
  });
}
