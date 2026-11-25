/// Conversion of fractional solar hours to UTC calendar events.
class TimeComponents {
  final int hours, minutes, seconds;
  const TimeComponents(this.hours, this.minutes, this.seconds);

  static TimeComponents? fromDouble(double value) {
    if (!value.isFinite) return null;
    final hours = value.floor();
    final minutes = ((value - hours) * 60).floor();
    final seconds = ((value - (hours + minutes / 60)) * 3600).floor();
    return TimeComponents(hours, minutes, seconds);
  }

  DateTime dateComponents(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day, hours, minutes, seconds);
}
