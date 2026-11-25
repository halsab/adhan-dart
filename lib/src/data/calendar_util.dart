import '../calculation_options.dart';
import 'date_components.dart';

class CalendarUtil {
  static bool isLeapYear(int year) =>
      year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

  static DateTime roundedMinute(DateTime when, [Rounding rounding = Rounding.nearest]) {
    if (rounding == Rounding.none) return when;
    // Round whole seconds, preserving exact-minute ceilings and pre-epoch dates.
    final seconds = (when.millisecondsSinceEpoch / 1000).floor();
    final minutes = seconds / 60;
    final rounded = rounding == Rounding.up
        ? minutes.ceil() : (minutes + 0.5).floor();
    return DateTime.fromMillisecondsSinceEpoch(rounded * 60000, isUtc: when.isUtc);
  }

  static DateTime resolveTimeByDateComponents(DateComponents components) =>
      components.toUtcMidnight();

  static DateTime resolveTime(int year, int month, int day) =>
      DateComponents(year, month, day).toUtcMidnight();
}
