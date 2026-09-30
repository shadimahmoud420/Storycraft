import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storycraft/data/quotes.dart';
import 'package:storycraft/models/story_background.dart';
import 'package:storycraft/models/story_layer.dart';
import 'package:storycraft/state/editor_controller.dart';
import 'package:storycraft/widgets/ornament_painter.dart';
import 'package:storycraft/widgets/story_canvas.dart';
import 'package:storycraft/widgets/story_view.dart';

Future<void> _pumpCanvas(WidgetTester tester, EditorController c) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: StoryCanvas(
        controller: c,
        boundaryKey: GlobalKey(),
        onEditLayer: (_) {},
      ),
    ),
  ));
  await tester.pump(); // measure layers
  await tester.pump(); // move the mark
}

void main() {
  testWidgets('the app mark moves to an empty spot', (tester) async {
    final c = EditorController(const StoryBackground.solid(Colors.black));
    // A wide text sitting exactly on the default spot (84% of the height).
    c.addLayer(
      StoryLayer(id: 't', text: 'نص كبير يغطي أسفل التصميم', fontSize: 30)
        ..position = const Offset(180, 640 * 0.84),
      keepPosition: true,
    );
    c.select(null);
    await _pumpCanvas(tester, c);

    final mark = tester.getRect(find.byType(WatermarkBadge));
    final text = tester.getRect(find.byType(StoryLayerVisual).first);
    expect(mark.overlaps(text), isFalse);
  });

  testWidgets('with nothing in the way it stays above the reply bar',
      (tester) async {
    final c = EditorController(const StoryBackground.solid(Colors.white));
    c.addText('فوق');
    c.updateLayer(c.layers.single.id,
        (l) => l.position = const Offset(180, 120), record: false);
    c.select(null);
    await _pumpCanvas(tester, c);
    final mark = tester.getRect(find.byType(WatermarkBadge));
    final canvas = tester.getRect(find.byType(StoryCanvas));
    // Centered horizontally, in the lower part of the story.
    expect((mark.center.dx - canvas.center.dx).abs(), lessThan(2));
    expect(mark.center.dy, greaterThan(canvas.top + canvas.height * 0.75));
  });

  test('quotes button offers the full library', () {
    for (final c in QuoteCategory.values) {
      expect(quotes[c], isNotEmpty, reason: c.name);
    }
    expect(quotes[QuoteCategory.sayings]!.first, contains('\nابن القيم'));
    expect(quotes[QuoteCategory.motivation]!.length, greaterThan(90));
  });
}
