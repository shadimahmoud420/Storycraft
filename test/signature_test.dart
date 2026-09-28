import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storycraft/data/fonts.dart';
import 'package:storycraft/data/formats.dart';
import 'package:storycraft/models/story_background.dart';
import 'package:storycraft/models/story_layer.dart';
import 'package:storycraft/state/editor_controller.dart';
import 'package:storycraft/widgets/signature_view.dart';

StoryLayer _sig(String name, SignatureStyle style, {TextFill fill = TextFill.solid}) =>
    StoryLayer(
      id: 's',
      kind: LayerKind.signature,
      text: name,
      font: StoryFonts.byFamily(
          StoryFonts.hasArabic(name) ? 'Aref Ruqaa' : 'Great Vibes'),
      fontSize: 40,
      fill: fill,
      signatureStyle: style,
    );

void main() {
  test('signature style survives a JSON round trip', () {
    final l = _sig('شادي محمود', SignatureStyle.seal, fill: TextFill.gold);
    final b = StoryLayer.fromJson(
      jsonDecode(jsonEncode(l.toJson())) as Map<String, dynamic>,
    );
    expect(b.kind, LayerKind.signature);
    expect(b.signatureStyle, SignatureStyle.seal);
    expect(b.fill, TextFill.gold);
    expect(b.text, 'شادي محمود');
  });

  test('signatures land in the bottom corner on the reading-end side', () {
    final c = EditorController(const StoryBackground.solid(Colors.black));
    final ar = c.addSignature(_sig('شادي', SignatureStyle.swash));
    final en = c.addSignature(_sig('Shadi', SignatureStyle.swash));
    expect(ar.position.dx, lessThan(180)); // Arabic ends on the left
    expect(en.position.dx, greaterThan(180));
    // Stays above Instagram's bottom overlay (80% of the story height).
    expect(ar.position.dy, lessThan(StoryFormat.story.size.height * 0.8));
    c.undo();
    expect(c.layers, hasLength(1));
  });

  testWidgets('every signature style renders in Arabic and English',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Wrap(children: [
            for (final name in ['شادي محمود', 'Shadi Mahmoud'])
              for (final st in SignatureStyle.values)
                for (final fill in [TextFill.solid, TextFill.gold])
                  SignatureView(layer: _sig(name, st, fill: fill)),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SignatureView), findsNWidgets(SignatureStyle.values.length * 4));
  });
}
