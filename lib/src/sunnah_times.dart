import 'calculation_options.dart';
import 'data/calendar_util.dart';
import 'prayer_times.dart';

/// Night milestones computed from today's Maghrib and tomorrow's Fajr.
/// A valid daytime schedule does not guarantee a valid following night.
final class SunnahTimes {
  final DateTime middleOfTheNight, lastThirdOfTheNight, fajrTomorrow;
  final PrayerTimes nextDayPrayerTimes;

  SunnahTimes._(this.middleOfTheNight, this.lastThirdOfTheNight,
      this.fajrTomorrow, this.nextDayPrayerTimes);

  factory SunnahTimes(PrayerTimes today) {
    final tomorrow = PrayerTimes(today.coordinates,
        today.dateComponents.addDays(1), today.calculationParameters);
    final night = tomorrow.fajr.difference(today.maghrib);
    if (night <= Duration.zero || night >= const Duration(days: 1)) {
      throw const PrayerTimeCalculationException(
          CalculationFailure.invalidNight, 'Invalid Maghrib-to-Fajr interval');
    }
    DateTime milestone(double portion) => CalendarUtil.roundedMinute(
        today.maghrib.add(Duration(milliseconds:
            (night.inMilliseconds * portion).truncate())),
        today.calculationParameters.rounding);
    final middle = milestone(0.5);
    final lastThird = milestone(2 / 3);
    if (!middle.isAfter(today.maghrib) || !lastThird.isAfter(middle) ||
        !tomorrow.fajr.isAfter(lastThird)) {
      throw const PrayerTimeCalculationException(
          CalculationFailure.invalidNight, 'Night milestones are out of order');
    }
    return SunnahTimes._(middle, lastThird, tomorrow.fajr, tomorrow);
  }

  static SunnahTimes? tryCalculate(PrayerTimes today) {
    try {
      return SunnahTimes(today);
    } on PrayerTimeCalculationException {
      return null;
    }
  }
}
