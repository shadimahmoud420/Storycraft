import 'package:flutter_test/flutter_test.dart';
import 'package:storycraft/data/daily_texts.dart';
import 'package:storycraft/data/history_events.dart';
import 'package:storycraft/services/daily_story.dart';

void main() {
  test('every event has a real date in the past', () {
    for (final e in historyEvents) {
      final d = DateTime(e.year, e.month, e.day);
      expect((d.month, d.day), (e.month, e.day), reason: e.text);
      expect(e.year, lessThanOrEqualTo(2026), reason: e.text);
    }
  });

  test('no restricted names or praise of violence', () {
    for (final e in historyEvents) {
      for (final term in historyBlockedTerms) {
        expect(e.text.contains(term), isFalse, reason: '${e.text} ($term)');
      }
    }
  });

  test('no duplicates; every scope is well covered', () {
    final keys = {for (final e in historyEvents) '${e.month}/${e.day}/${e.text}'};
    expect(keys.length, historyEvents.length);
    for (final scope in HistoryScope.values) {
      expect(historyEvents.where((e) => e.scope == scope).length,
          greaterThan(40), reason: scope.name);
    }
  });

  test('same-day events first, then the nearest, labelled honestly', () {
    final day = DateTime(2026, 10, 11);
    final (t, label) = DailyStoryGenerator.pickHistory(day);
    expect(label, 'حدث في مثل هذا اليوم');
    expect(t.text, contains('للطفلة'));
    expect(t.source, '— ١١ أكتوبر ٢٠١٢');

    // No Arab event on Oct 11: the nearest one (Oct 13) is used.
    final (a, aLabel) =
        DailyStoryGenerator.pickHistory(day, scope: HistoryScope.arab);
    expect(aLabel, 'حدث في مثل هذا الأسبوع');
    expect(a.text, contains('محفوظ'));

    // Arab includes Palestine, which comes first among equally near days.
    final oct29 = DailyStoryGenerator.historyFor(
        DateTime(2026, 10, 29), HistoryScope.arab);
    expect(oct29[0].$1.scope, HistoryScope.palestine);
    expect(oct29[1].$1.scope, HistoryScope.arab);
    expect(
        DailyStoryGenerator.historyFor(DateTime(2026, 10, 29),
            HistoryScope.world).every((x) => x.$1.scope == HistoryScope.world),
        isTrue);

    // "Another text" walks outwards through the year.
    final seen = {
      for (var i = 0; i < historyEvents.length; i++)
        DailyStoryGenerator.pickHistory(day, shift: i).$1.text,
    };
    expect(seen.length, historyEvents.toSet().map((e) => e.text).length);
  });

  test('every event fits every layout', () {
    final misfits = <String>[];
    final day = DateTime(2026, 10, 1); // a Thursday: tighter limit
    for (var shift = 0; shift < historyEvents.length; shift++) {
      for (var variant = 0; variant < 5; variant++) {
        final s = DailyStoryGenerator.build(day,
            category: DailyCategory.history,
            textShift: shift,
            variant: variant,
            now: DateTime(2026, 1, 1, 9));
        if (!s.fits) misfits.add('#$shift v$variant');
      }
    }
    expect(misfits, isEmpty);
  });
}
