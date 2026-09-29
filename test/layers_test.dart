import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storycraft/models/story_background.dart';
import 'package:storycraft/models/story_layer.dart';
import 'package:storycraft/state/editor_controller.dart';

void main() {
  EditorController make() {
    final c = EditorController(const StoryBackground.solid(Colors.black));
    c.addText('A');
    c.addText('B');
    c.addText('C');
    return c;
  }

  List<String> order(EditorController c) => [for (final l in c.layers) l.text];

  test('selecting keeps the stacking order', () {
    final c = make();
    c.select(c.layers.first.id);
    expect(order(c), ['A', 'B', 'C']);
  });

  test('forward, backward, front and back reorder; each is undoable', () {
    final c = make();
    final a = c.layers.first.id;
    c.bringForward(a);
    expect(order(c), ['B', 'A', 'C']);
    c.bringToFront(a);
    expect(order(c), ['B', 'C', 'A']);
    c.sendBackward(a);
    expect(order(c), ['B', 'A', 'C']);
    c.sendToBack(a);
    expect(order(c), ['A', 'B', 'C']);
    c.undo();
    expect(order(c), ['B', 'A', 'C']);
    c.sendToBack(a);
    c.sendToBack(a); // already at the bottom: no extra undo step
    c.undo();
    expect(order(c), ['B', 'A', 'C']);
  });

  test('hiding deselects and survives JSON', () {
    final c = make();
    final b = c.layers[1];
    c.select(b.id);
    c.toggleHidden(b.id);
    expect(c.selectedId, isNull);
    b.opacity = 0.4;
    final back = StoryLayer.fromJson(b.toJson());
    expect(back.hidden, isTrue);
    expect(back.opacity, closeTo(0.4, 1e-9));
    c.undo();
    expect(c.layers[1].hidden, isFalse);
  });
}
