import '../core/date_text.dart';
import '../core/hijri.dart';
import '../services/app_settings.dart';
import 'daily_texts.dart';

/// What makes a given day special: a title (Friday, Eid…), a small tag
/// (voluntary fast, white days, Ramadan countdown…) and suitable texts.
class DayInfo {
  const DayInfo({
    required this.date,
    required this.hijri,
    this.title,
    this.tag,
    this.texts,
    this.textLabel,
  });

  final DateTime date;
  final HijriDate hijri;

  /// Headline such as "جمعة مباركة" or "عيد فطر سعيد".
  final String? title;

  /// Small badge such as "صيام تطوّع" or "باقي ٥ أيام على رمضان".
  final String? tag;

  /// Texts that fit the day better than the regular rotation.
  final List<DailyText>? texts;
  final String? textLabel;

  /// Greeting for the time of day.
  static String greeting(DateTime now) {
    if (now.hour >= 4 && now.hour < 12) return 'صباح الخير';
    if (now.hour >= 17 || now.hour < 4) return 'مساء الخير';
    return 'يومك سعيد';
  }

  factory DayInfo.of(DateTime date) {
    final offset = AppSettings.instance.value.hijriOffset;
    final h = HijriDate.fromDate(date, offsetDays: offset);
    String? title, tag, label;
    List<DailyText>? texts;
    final ramadan = h.month == 9;
    final dhulHijjah = h.month == 12;

    if (ramadan) {
      title = 'رمضان كريم';
      tag = 'اليوم ${DateText.digits(h.day)} من رمضان';
      texts = DailyTexts.ramadan;
      label = 'دعاء رمضان';
    } else if (h.month == 10 && h.day <= 3) {
      title = 'عيد فطر سعيد';
      texts = DailyTexts.eid;
      label = 'تهنئة العيد';
    } else if (dhulHijjah && h.day == 9) {
      title = 'يوم عرفة';
      tag = 'صيام يوم عرفة';
      texts = DailyTexts.arafah;
      label = 'خير الدعاء دعاء يوم عرفة';
    } else if (dhulHijjah && h.day >= 10 && h.day <= 13) {
      title = 'عيد أضحى مبارك';
      if (h.day > 10) tag = 'أيام التشريق';
      texts = DailyTexts.eid;
      label = 'تهنئة العيد';
    } else if (h.month == 1 && h.day == 1) {
      title = 'سنة هجرية مباركة';
      texts = DailyTexts.newHijriYear;
      label = 'عام هجري جديد';
    } else if (date.weekday == DateTime.friday) {
      title = 'جمعة مباركة';
      texts = DailyTexts.friday;
      label = 'جمعة مباركة';
    }

    if (tag == null && !ramadan && !(dhulHijjah && h.day >= 10 && h.day <= 13)) {
      if (dhulHijjah && h.day <= 8) {
        tag = 'العشر من ذي الحجة';
      } else if (h.month == 1 && (h.day == 9 || h.day == 10)) {
        tag = h.day == 9 ? 'صيام تاسوعاء' : 'صيام عاشوراء';
      } else if (h.month == 8) {
        final start = HijriDate.monthStart(h.year, 9, offsetDays: offset);
        if (start != null) {
          final left = DateTime(start.year, start.month, start.day)
              .difference(DateTime(date.year, date.month, date.day))
              .inDays;
          if (left > 0 && left <= 15) {
            tag = switch (left) {
              1 => 'غدًا أول أيام رمضان',
              2 => 'باقي يومان على رمضان',
              _ => 'باقي ${DateText.digits(left)} ${left <= 10 ? 'أيام' : 'يومًا'} على رمضان',
            };
          }
        }
      }
      if (tag == null && h.day >= 13 && h.day <= 15 && !(h.month == 10 && h.day < 4)) {
        tag = 'الأيام البيض';
      } else if (tag == null &&
          (date.weekday == DateTime.monday || date.weekday == DateTime.thursday) &&
          !(h.month == 10 && h.day == 1)) {
        tag = 'صيام تطوّع';
      }
    }

    return DayInfo(
      date: date,
      hijri: h,
      title: title,
      tag: tag,
      texts: texts,
      textLabel: label,
    );
  }
}
