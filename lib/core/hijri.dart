import 'hijri_table.g.dart';

/// A date in the Hijri calendar (Umm al-Qura), computed on the device.
class HijriDate {
  const HijriDate(this.year, this.month, this.day);

  final int year;
  final int month; // 1…12
  final int day; // 1…30

  static const monthNamesAr = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];
  static const monthNamesEn = [
    'Muharram', 'Safar', 'Rabi al-Awwal', 'Rabi al-Akhir', 'Jumada al-Ula',
    'Jumada al-Akhirah', 'Rajab', "Sha'ban", 'Ramadan', 'Shawwal',
    "Dhu al-Qa'dah", 'Dhu al-Hijjah',
  ];

  String get monthNameAr => monthNamesAr[month - 1];
  String get monthNameEn => monthNamesEn[month - 1];

  /// Converts a Gregorian date. [offsetDays] lets people match their local
  /// moon sighting (usually -1, 0 or +1).
  factory HijriDate.fromDate(DateTime date, {int offsetDays = 0}) {
    final day = _epochDay(date) + offsetDays;
    const starts = ummAlQuraMonthStarts;
    if (day >= starts.first && day < starts.last) {
      // Binary search for the month containing [day].
      var lo = 0, hi = starts.length - 2;
      while (lo < hi) {
        final mid = (lo + hi + 1) ~/ 2;
        if (starts[mid] <= day) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      return HijriDate(ummAlQuraFirstYear + lo ~/ 12, lo % 12 + 1,
          day - starts[lo] + 1);
    }
    return _tabular(day);
  }

  /// First Gregorian day of a Hijri month (table range only).
  static DateTime? monthStart(int year, int month, {int offsetDays = 0}) {
    final i = (year - ummAlQuraFirstYear) * 12 + month - 1;
    if (i < 0 || i >= ummAlQuraMonthStarts.length) return null;
    final d = DateTime.fromMillisecondsSinceEpoch(
        ummAlQuraMonthStarts[i] * 86400000,
        isUtc: true);
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: offsetDays));
  }

  /// Days since 1970-01-01 for the calendar day of [d] (time ignored).
  static int _epochDay(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  /// Arithmetic (tabular) Islamic calendar, used outside the table range.
  static HijriDate _tabular(int epochDay) {
    final jd = epochDay + 2440588; // Julian day number
    final l0 = jd - 1948440 + 10632;
    final n = (l0 - 1) ~/ 10631;
    final l1 = l0 - 10631 * n + 354;
    final j = ((10985 - l1) ~/ 5316) * ((50 * l1) ~/ 17719) +
        (l1 ~/ 5670) * ((43 * l1) ~/ 15238);
    final l2 = l1 -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final m = (24 * l2) ~/ 709;
    final d = l2 - (709 * m) ~/ 24;
    final y = 30 * n + j - 30;
    return HijriDate(y, m, d);
  }

  @override
  bool operator ==(Object other) =>
      other is HijriDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '$year-$month-$day';
}
