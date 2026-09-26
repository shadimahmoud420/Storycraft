import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storycraft/data/palettes.dart';
import 'package:storycraft/models/story_background.dart';
import 'package:storycraft/state/editor_controller.dart';
import 'package:storycraft/widgets/color_picker.dart';

void main() {
  testWidgets('ColorRow reports the tapped color', (tester) async {
    Color? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ColorRow(selected: null, onChanged: (c) => picked = c),
      ),
    ));
    // Index 0 is the custom-color button; index 1 is the first palette color.
    await tester.tap(find.byType(GestureDetector).at(1));
    expect(picked, Palettes.classic.first);
  });

  test('EditorController adds, duplicates and removes text', () {
    final c = EditorController(const StoryBackground.solid(Colors.white));
    final layer = c.addText('مرحبا');
    expect(layer.font.arabic, isTrue);
    expect(layer.color, Colors.black); // readable on white
    c.duplicateLayer(layer.id);
    expect(c.layers, hasLength(2));
    c.removeLayer(c.selectedId!);
    expect(c.layers, hasLength(1));
    expect(c.hasChanges, isTrue);
  });
}
