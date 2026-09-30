import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storycraft/core/config.dart';
import 'package:storycraft/core/date_text.dart';
import 'package:storycraft/core/hijri.dart';
import 'package:storycraft/data/daily_texts.dart';
import 'package:storycraft/data/occasions.dart';
import 'package:storycraft/models/story_layer.dart';
import 'package:storycraft/screens/daily_screen.dart';
import 'package:storycraft/services/daily_story.dart';
import 'package:storycraft/widgets/story_view.dart';

void main() {
  group('Hijri (Umm al-Qura)', () {
    test('known dates', () {
      expect(HijriDate.fromDate(DateTime(2026, 9, 30)), const HijriDate(1448, 4, 19));
      expect(HijriDate.fromDate(DateTime(2025, 3, 1)), const HijriDate(1446, 9, 1));
      expect(HijriDate.fromDate(DateTime(2024, 7, 7)), const HijriDate(1446, 1, 1));
    });

    test('offset shifts the day', () {
      expect(HijriDate.fromDate(DateTime(2026, 9, 30), offsetDays: 1),
          const HijriDate(1448, 4, 20));
    });

    test('falls back to the tabular calendar outside the table', () {
      final h = HijriDate.fromDate(DateTime(2090, 1, 1));
      expect(h.year, greaterThan(1480));
      expect(h.month, inInclusiveRange(1, 12));
      expect(h.day, inInclusiveRange(1, 30));
    });

    test('month start round-trips', () {
      final start = HijriDate.monthStart(1448, 9)!;
      expect(HijriDate.fromDate(start), const HijriDate(1448, 9, 1));
    });
  });

  test('date placeholders', () {
    final d = DateTime(2026, 9, 30);
    expect(DateText.resolve('{weekday} · {greg}', d), 'الأربعاء · ٣٠ سبتمبر ٢٠٢٦');
    expect(DateText.resolve('{hijri}', d), '١٩ ربيع الآخر ١٤٤٨ هـ');
    expect(DateText.resolve('{day} {month} {year}', d), '٣٠ سبتمبر ٢٠٢٦');
    expect(DateText.resolve('بدون تاريخ', d), 'بدون تاريخ');
  });

  group('occasions', () {
    test('Friday, voluntary fasts and white days', () {
      expect(DayInfo.of(DateTime(2026, 10, 2)).title, 'جمعة مباركة');
      expect(DayInfo.of(DateTime(2026, 10, 1)).tag, 'صيام تطوّع'); // Thursday
      expect(DayInfo.of(DateTime(2026, 9, 30)).tag, isNull); // Wednesday
      // 13 Jumada al-Ula 1448 is a white day.
      final white = HijriDate.monthStart(1448, 5)!.add(const Duration(days: 12));
      expect(DayInfo.of(white).tag, 'الأيام البيض');
    });

    test('Ramadan day count and countdown', () {
      final first = HijriDate.monthStart(1448, 9)!;
      final day5 = first.add(const Duration(days: 4));
      expect(DayInfo.of(day5).title, 'رمضان كريم');
      expect(DayInfo.of(day5).tag, 'اليوم ٥ من رمضان');
      final before = first.subtract(const Duration(days: 5));
      expect(DayInfo.of(before).tag, 'باقي ٥ أيام على رمضان');
      expect(DayInfo.of(first.subtract(const Duration(days: 1))).tag,
          'غدًا أول أيام رمضان');
    });

    test('Eid and Arafah', () {
      expect(DayInfo.of(HijriDate.monthStart(1448, 10)!).title, 'عيد فطر سعيد');
      final dh = HijriDate.monthStart(1448, 12)!;
      expect(DayInfo.of(dh.add(const Duration(days: 8))).title, 'يوم عرفة');
      expect(DayInfo.of(dh.add(const Duration(days: 9))).title, 'عيد أضحى مبارك');
    });
  });

  group('texts', () {
    test('no duplicates inside a category', () {
      for (final c in DailyCategory.values) {
        final texts = DailyTexts.of(c).map((t) => t.text).toList();
        expect(texts.toSet().length, texts.length, reason: c.name);
      }
    });

    test('a year of automatic texts barely repeats', () {
      final start = DateTime(2027, 1, 1);
      final seen = <String>{};
      var regular = 0;
      for (var i = 0; i < 365; i++) {
        final d = start.add(Duration(days: i));
        final info = DayInfo.of(d);
        if (info.texts != null) continue;
        regular++;
        seen.add(DailyStoryGenerator.pickText(d, info).$1.text);
      }
      expect(seen.length / regular, greaterThan(0.85));
      expect(regular, greaterThan(250));
    });
  });

  group('generator', () {
    test('every day of a year fits the canvas and the safe zone', () {
      final start = DateTime(2026, 9, 1);
      for (var i = 0; i < 365; i++) {
        final d = start.add(Duration(days: i));
        for (final variant in [0, 1, 2]) {
          final story = DailyStoryGenerator.build(d,
              variant: variant, now: DateTime(2026, 1, 1, 9));
          expect(story.layers, isNotEmpty);
          for (final l in story.layers) {
            expect(l.position.dx, inInclusiveRange(0, AppConfig.canvasWidth));
            expect(l.position.dy, inInclusiveRange(0, AppConfig.canvasHeight));
          }
          expect(story.layers.where((l) => l.kind == LayerKind.watermark),
              hasLength(1));
        }
      }
    });

    test('neighbouring days and variants look different', () {
      String signature(DailyStory s) =>
          '${s.background.gradientColors}|${s.layers.map((l) => '${l.kind.name}${l.ornament.name}').join()}';
      final d = DateTime(2026, 10, 1);
      final a = DailyStoryGenerator.build(d);
      final b = DailyStoryGenerator.build(d.add(const Duration(days: 1)));
      final c = DailyStoryGenerator.build(d, variant: 1);
      expect(signature(a), isNot(signature(b)));
      expect(signature(a), isNot(signature(c)));
      // Deterministic: the same inputs give the same design.
      expect(signature(DailyStoryGenerator.build(d)), signature(a));
    });

    test('dates are live placeholders and the watermark can be skipped', () {
      final s = DailyStoryGenerator.build(DateTime(2026, 10, 1), watermark: false);
      expect(s.layers.any((l) => l.template != null), isTrue);
      expect(s.layers.where((l) => l.kind == LayerKind.watermark), isEmpty);
    });

    test('new layer fields survive JSON', () {
      final l = StoryLayer(
        id: 'x',
        kind: LayerKind.ornament,
        ornament: OrnamentKind.frame,
        height: 400,
        seed: 9,
        locked: true,
        template: '{greg}',
      );
      final back = StoryLayer.fromJson(l.toJson());
      expect(back.ornament, OrnamentKind.frame);
      expect(back.height, 400);
      expect(back.seed, 9);
      expect(back.locked, isTrue);
      expect(back.template, '{greg}');
    });
  });

  testWidgets('every layout renders without errors', (tester) async {
    for (var i = 0; i < 10; i++) {
      final story = DailyStoryGenerator.build(DateTime(2026, 10, 1 + i));
      await tester.pumpWidget(MaterialApp(
        home: StoryClock(
          date: story.date,
          child: SizedBox(
            width: 360,
            height: 640,
            child: Stack(children: [
              for (final l in story.layers)
                PositionedLayer(layer: l, child: StoryLayerVisual(layer: l)),
            ]),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('daily screen: another design / text, browse days',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      supportedLocales: [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: DailyScreen(),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.palette_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.shuffle_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.keyboard_arrow_left_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.today_rounded), findsOneWidget); // back to today
    expect(tester.takeException(), isNull);
  });
}
