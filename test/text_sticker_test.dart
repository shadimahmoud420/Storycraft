import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storycraft/data/fonts.dart';
import 'package:storycraft/models/story_layer.dart';
import 'package:storycraft/screens/text_sticker_screen.dart';
import 'package:storycraft/widgets/story_view.dart';

void main() {
  testWidgets('sticker renders on a transparent background', (tester) async {
    final key = GlobalKey();
    await tester.runAsync(() async {
      final loader = FontLoader('Aref Ruqaa')
        ..addFont(rootBundle.load('assets/fonts/ArefRuqaa-400.ttf'));
      await loader.load();
    });
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: key,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: StoryLayerVisual(
              layer: StoryLayer(
                id: 't',
                text: 'في عيونك حيرة',
                font: StoryFonts.byFamily('Aref Ruqaa'),
                fontSize: 40,
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image =
          await boundary.toImage(pixelRatio: TextStickerScreen.pixelRatio);
      final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
      // High resolution, corners fully transparent, some opaque text.
      expect(image.width, greaterThan(600));
      expect(bytes[3], 0);
      expect(bytes[bytes.length - 1], 0);
      var opaque = 0;
      for (var i = 3; i < bytes.length; i += 4) {
        if (bytes[i] > 200) opaque++;
      }
      expect(opaque, greaterThan(1000));
      image.dispose();
    });
  });

  testWidgets('text sticker screen invites to write', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      supportedLocales: [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: TextStickerScreen(),
    ));
    expect(find.text('اضغط هنا لكتابة النص'), findsOneWidget);
    final copy = tester.widget<FilledButton>(find.ancestor(
        of: find.text('نسخ الملصق'), matching: find.byWidgetPredicate((w) => w is FilledButton)));
    expect(copy.onPressed, isNull); // nothing to copy yet
    expect(tester.takeException(), isNull);
  });
}
