import 'package:flutter/widgets.dart';

import '../services/app_settings.dart';
import 'hijri.dart';

/// Arabic date formatting and live date placeholders for text layers.
///
/// A text layer with a template such as `{weekday} · {greg}` always shows
/// the current date, so a saved "story of the day" stays correct tomorrow.
class DateText {
  DateText._();

  static const weekdaysAr = [
    'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد',
  ];
  static const monthsAr = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس',
    'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  /// Western digits -> Arabic-Indic digits (٠١٢٣…).
  static String digits(Object value) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    return value.toString().replaceAllMapped(
        RegExp(r'[0-9]'), (m) => ar[m[0]!.codeUnitAt(0) - 48]);
  }

  static HijriDate hijriOf(DateTime date) => HijriDate.fromDate(date,
      offsetDays: AppSettings.instance.value.hijriOffset);

  static String weekday(DateTime d) => weekdaysAr[d.weekday - 1];
  static String month(DateTime d) => monthsAr[d.month - 1];
  static String greg(DateTime d) =>
      '${digits(d.day)} ${month(d)} ${digits(d.year)}';
  static String hijri(DateTime d) {
    final h = hijriOf(d);
    return '${digits(h.day)} ${h.monthNameAr} ${digits(h.year)} هـ';
  }

  static const tokens = {
    '{weekday}': 'weekday',
    '{day}': 'day',
    '{month}': 'month',
    '{year}': 'year',
    '{greg}': 'greg',
    '{hijri}': 'hijri',
    '{hday}': 'hday',
    '{hmonth}': 'hmonth',
    '{hyear}': 'hyear',
  };

  /// Replaces date placeholders in [template] with [date]'s values.
  static String resolve(String template, DateTime date) {
    if (!template.contains('{')) return template;
    final h = hijriOf(date);
    return template
        .replaceAll('{weekday}', weekday(date))
        .replaceAll('{day}', digits(date.day))
        .replaceAll('{month}', month(date))
        .replaceAll('{year}', digits(date.year))
        .replaceAll('{greg}', greg(date))
        .replaceAll('{hijri}', hijri(date))
        .replaceAll('{hday}', digits(h.day))
        .replaceAll('{hmonth}', h.monthNameAr)
        .replaceAll('{hyear}', digits(h.year));
  }
}

/// The date that live date layers show below this widget (defaults to
/// today). The daily screen uses it to preview other days.
class StoryClock extends InheritedWidget {
  const StoryClock({super.key, required this.date, required super.child});

  final DateTime date;

  static DateTime of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoryClock>()?.date ??
      DateTime.now();

  @override
  bool updateShouldNotify(StoryClock oldWidget) => oldWidget.date != date;
}
