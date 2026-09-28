import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:storycraft/data/art.dart';
import 'package:storycraft/data/fonts.dart';
import 'package:storycraft/data/quotes.dart';
import 'package:storycraft/data/templates.dart';
import 'package:storycraft/models/story_background.dart';
import 'package:storycraft/models/story_layer.dart';
import 'package:storycraft/state/editor_controller.dart';
import 'package:storycraft/widgets/story_view.dart';

void main() {
  group('undo / redo', () {
    test('restores layers and background step by step', () {
      final c = EditorController(const StoryBackground.solid(Colors.white));
      final a = c.addText('Hello');
      c.updateLayer(a.id, (l) => l.color = Colors.red);
      c.setBackground(const StoryBackground.solid(Colors.black));

      c.undo();
      expect(c.background.color, Colors.white);
      c.undo();
      expect(c.layers.single.color, isNot(Colors.red));
      c.undo();
      expect(c.layers, isEmpty);
      expect(c.canUndo, isFalse);

      c.redo();
      c.redo();
      expect(c.layers.single.color, Colors.red);
      c.redo();
      expect(c.background.color, Colors.black);
      expect(c.canRedo, isFalse);
    });

    test('a new change clears the redo stack', () {
      final c = EditorController(const StoryBackground.solid(Colors.white));
      c.addText('one');
      c.undo();
      c.addEmoji('🔥');
      expect(c.canRedo, isFalse);
      expect(c.layers.single.kind, LayerKind.emoji);
    });
  });

  test('new layers are placed where they do not cover existing ones', () {
    final c = EditorController(const StoryBackground.solid(Colors.white));
    final a = c.addText('first');
    final b = c.addText('second');
    final e = c.addEmoji('⭐');
    expect(a.position, isNot(b.position));
    expect((a.position.dy - b.position.dy).abs(), greaterThanOrEqualTo(56));
    expect((e.position.dy - b.position.dy).abs(), greaterThanOrEqualTo(56));
  });

  test('dim cycles 0 → 20% → 40% → 60% → 0 on photos only', () {
    final solid = EditorController(const StoryBackground.solid(Colors.white));
    solid.cycleDim();
    expect(solid.background.dim, 0);

    final photo = EditorController(StoryBackground.image(Uint8List(4)));
    final seen = <int>[];
    for (var i = 0; i < 4; i++) {
      photo.cycleDim();
      seen.add((photo.background.dim * 100).round());
    }
    expect(seen, [20, 40, 60, 0]);
  });

  test('photo pan/zoom is clamped, undoable and reset by fit toggle', () {
    final c = EditorController(StoryBackground.image(Uint8List(4)));
    c.checkpoint();
    c.transformImage(const Offset(30, -20), 9);
    expect(c.background.imageScale, 5); // clamped
    c.undo();
    expect(c.background.imageScale, 1);
    c.transformImage(const Offset(30, -20), 2);
    c.toggleImageFit();
    expect(c.background.imageOffset, Offset.zero);
    expect(c.background.imageScale, 1);
  });

  group('draft serialization', () {
    test('layers survive a JSON round trip', () {
      final layer = StoryLayer(
        id: 'x',
        kind: LayerKind.shape,
        shape: ShapeKind.circleFrame,
        color: const Color(0xFF123456),
        size: 150,
        position: const Offset(10, 20),
        scale: 1.5,
        rotation: 0.3,
        highlight: TextHighlight.blur,
        font: StoryFonts.byFamily('Amiri'),
      );
      final back = StoryLayer.fromJson(
        jsonDecode(jsonEncode(layer.toJson())) as Map<String, dynamic>,
      );
      expect(back.kind, LayerKind.shape);
      expect(back.shape, ShapeKind.circleFrame);
      expect(back.color, const Color(0xFF123456));
      expect(back.position, const Offset(10, 20));
      expect(back.scale, 1.5);
      expect(back.highlight, TextHighlight.blur);
      expect(back.font.family, 'Amiri');
    });

    test('gradient background survives a JSON round trip', () {
      const bg = StoryBackground.gradient(
        [Color(0xFF000000), Color(0xFFFFFFFF)],
        angle: 45,
      );
      final back = StoryBackground.fromJson(
        jsonDecode(jsonEncode(bg.toJson())) as Map<String, dynamic>,
      );
      expect(back.kind, BackgroundKind.gradient);
      expect(back.gradientColors, bg.gradientColors);
      expect(back.gradientAngle, 45);
    });
  });

  test('templates load with unique ids and only known fonts', () {
    for (final t in storyTemplates) {
      final c = EditorController(t.background, layers: t.buildLayers());
      final ids = c.layers.map((l) => l.id).toSet();
      expect(ids.length, c.layers.length);
      for (final l in c.layers.where((l) => l.isText)) {
        expect(StoryFonts.all, contains(l.font), reason: l.font.family);
      }
      for (final l in c.layers.where((l) => l.kind == LayerKind.art)) {
        expect(File(StoryArt.asset(l.text)).existsSync(), isTrue,
            reason: l.text);
      }
    }
    for (final c in TemplateCategory.values) {
      expect(storyTemplates.where((t) => t.category == c), isNotEmpty);
    }
  });

  test('every sticker illustration is bundled', () {
    for (final name in StoryArt.all) {
      expect(File(StoryArt.asset(name)).existsSync(), isTrue, reason: name);
    }
  });

  test('wide art spans the top instead of the center', () {
    final c = EditorController(const StoryBackground.solid(Colors.white));
    final g = c.addArt('lantern_garland');
    expect(g.size, 360);
    expect(g.position, const Offset(180, 150));
    expect(c.addArt('crescent').size, 150);
  });

  test('every quote category has content', () {
    for (final c in QuoteCategory.values) {
      expect(quotes[c], isNotEmpty);
    }
  });

  testWidgets('bundled fonts render offline and templates preview',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Wrap(
          children: [
            for (final t in storyTemplates)
              SizedBox(
                width: 60,
                child: StoryPreview(
                  background: t.background,
                  layers: t.buildLayers(),
                ),
              ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(StoryPreview), findsNWidgets(storyTemplates.length));
  });
}
