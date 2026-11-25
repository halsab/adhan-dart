extension AdhanDateTimeExtensions on DateTime {
  /// Civil day of year, independent of DST and the instant's timezone offset.
  int get dayOfYear => DateTime.utc(year, month, day)
      .difference(DateTime.utc(year)).inDays + 1;
}
