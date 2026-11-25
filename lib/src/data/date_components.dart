import '../coordinates.dart';

/// Gregorian date of a nominal solar cycle at the requested longitude.
/// Usually the target civil date; use [DateComponents.fromLocalNoon] when
/// political timezones can put the civil date on the other side of the date line.
/// Supported years: 1..9999. This is not an instant.
final class DateComponents {
  final int year, month, day;
  DateComponents(this.year, this.month, this.day) {
    if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1 || day > 31) {
      throw ArgumentError('Invalid Gregorian date: $year-$month-$day');
    }
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw ArgumentError('Invalid Gregorian date: $year-$month-$day');
    }
  }

  /// Reads the date fields as supplied. Convert to the target zone first.
  factory DateComponents.from(DateTime date) =>
      DateComponents(date.year, date.month, date.day);

  /// Maps an actual instant of target-local civil noon to the solar date.
  ///
  /// Use the location's IANA timezone to construct local noon first. This
  /// handles civil timezones whose date differs from the nominal solar date
  /// (e.g. Samoa or Kiritimati) without adding a timezone database dependency.
  /// Keep the requested civil date separately in the host application's UI.
  factory DateComponents.fromLocalNoon(DateTime localNoon, Coordinates coordinates) {
    final longitudeOffset = Duration(milliseconds: (coordinates.longitude * 240000).round());
    return DateComponents.from(localNoon.toUtc().add(longitudeOffset));
  }

  DateTime toUtcMidnight() => DateTime.utc(year, month, day);

  DateComponents addDays(int days) =>
      DateComponents.from(toUtcMidnight().add(Duration(days: days)));

  @override
  bool operator ==(Object other) => other is DateComponents &&
      year == other.year && month == other.month && day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}
