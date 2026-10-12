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

    // No Arab event on Oct 11: that day's other events are offered
    // rather than another day's.
    final (a, aLabel) =
        DailyStoryGenerator.pickHistory(day, scope: HistoryScope.arab);
    expect(aLabel, 'حدث في مثل هذا اليوم');
    expect(a.source, contains('١١ أكتوبر'));

    // Arab includes Palestine, which comes first on the same day.
    final (oct29, away) = DailyStoryGenerator.historyChoices(
        DateTime(2026, 10, 29), HistoryScope.arab);
    expect(away, 0);
    expect([for (final e in oct29) e.scope],
        [HistoryScope.palestine, HistoryScope.arab]);

    // "Another text" only moves through the same day's events.
    for (var i = 0; i < 6; i++) {
      final (t, l) = DailyStoryGenerator.pickHistory(
          DateTime(2026, 10, 29), scope: HistoryScope.arab, shift: i);
      expect(t.source, contains('٢٩ أكتوبر'));
      expect(l, 'حدث في مثل هذا اليوم');
    }
  });

  test('a day without events falls back to the nearest, labelled so', () {
    final covered = {for (final e in historyEvents) (e.month, e.day)};
    var d = DateTime(2024, 1, 1);
    while (covered.contains((d.month, d.day))) {
      d = d.add(const Duration(days: 1));
    }
    final (list, away) = DailyStoryGenerator.historyChoices(d);
    expect(list, isNotEmpty);
    expect(away, greaterThan(0));
    expect(DailyStoryGenerator.pickHistory(d).$2, isNot('حدث في مثل هذا اليوم'));
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
