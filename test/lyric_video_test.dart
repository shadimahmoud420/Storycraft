import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storycraft/models/lyrics.dart';
import 'package:storycraft/screens/lyric_video_screen.dart';
import 'package:storycraft/services/lyric_video_exporter.dart';
import 'package:video_composer/video_composer.dart';

void main() {
  group('timings', () {
    test('unsynced lines are spread evenly', () {
      final lines = Lyrics.parse('أ\n\nب\nج\nد\n');
      expect(lines, hasLength(4));
      final t = Lyrics.timings(lines, 8000);
      expect([for (final x in t) x.startMs], [0, 2000, 4000, 6000]);
      expect(t.last.endMs, 8000);
    });

    test('synced lines are anchors, the rest fill the gaps', () {
      final lines = [
        LyricLine('1', 1000),
        LyricLine('2'),
        LyricLine('3', 5000),
        LyricLine('4'),
      ];
      final t = Lyrics.timings(lines, 9000);
      expect([for (final x in t) x.startMs], [1000, 3000, 5000, 7000]);
      // Before the first synced line nothing is shown.
      expect(Lyrics.activeAt(t, 500), isNull);
      expect(Lyrics.activeAt(t, 3500)!.index, 1);
    });

    test('frames are quantized and settle after the entrance', () {
      final t = Lyrics.timings([LyricLine('a'), LyricLine('b')], 4000);
      final a = Lyrics.frameAt(t, LyricEffect.fade, 1000)!;
      final b = Lyrics.frameAt(t, LyricEffect.fade, 1200)!;
      expect(a, b); // static between entrance and exit
      expect(Lyrics.frameAt(t, LyricEffect.fade, 100)!.appear,
          lessThan(LyricsFrame.steps));
      final k1 = Lyrics.frameAt(t, LyricEffect.karaoke, 500)!;
      final k2 = Lyrics.frameAt(t, LyricEffect.karaoke, 1500)!;
      expect(k2.progress, greaterThan(k1.progress));
      expect(Lyrics.frameAt(t, LyricEffect.fade, 2500)!.line, 1);
    });
  });

  test('output size is capped and even', () {
    expect(VideoComposer.outputSize(3840, 2160), (1920, 1080));
    expect(VideoComposer.outputSize(2160, 3840), (1080, 1920));
    expect(VideoComposer.outputSize(1080, 1920), (1080, 1920));
    expect(VideoComposer.outputSize(721, 1281), (722, 1282));
  });

  testWidgets('overlay frames: one PNG per distinct moment', (tester) async {
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('lyrics_test');
      addTearDown(() => dir.delete(recursive: true));
      for (final effect in LyricEffect.values) {
        final frames = await LyricVideoExporter.renderOverlay(
          dir: dir,
          width: 180,
          height: 320,
          lines: [LyricLine('يا ليل يا عين'), LyricLine('ما أجمل الليالي')],
          style: LyricsStyle(effect: effect),
          durationMs: 4000,
        );
        expect(frames, hasLength(120), reason: effect.name);
        final distinct = frames.toSet()..remove(-1);
        // Entrance-only effects hold still once shown (karaoke, write-on
        // and word by word keep moving through the line).
        if (const [LyricEffect.fade, LyricEffect.zoom, LyricEffect.slide]
            .contains(effect)) {
          expect(distinct.length, lessThan(frames.length ~/ 2),
              reason: effect.name);
        }
        for (final i in distinct) {
          expect(File('${dir.path}/f$i.png').existsSync(), isTrue);
        }
      }
    });
  });

  testWidgets('song video screen starts with picking a video', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      supportedLocales: [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: LyricVideoScreen(),
    ));
    expect(find.text('فيديو بأغنية'), findsOneWidget);
    expect(find.text('اختر فيديو'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
