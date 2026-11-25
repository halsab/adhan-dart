import 'package:adhan/adhan.dart';
import 'package:test/test.dart';

void main() {
  test('night milestones use the actual next-day Fajr and preserve UTC', () {
    final coordinates = Coordinates(35.775, -78.6336);
    final date = DateComponents(2015, 7, 12);
    final params = CalculationMethod.north_america.getParameters()
        .copyWith(rounding: Rounding.none);
    final today = PrayerTimes(coordinates, date, params);
    final tomorrow = PrayerTimes(coordinates, date.addDays(1), params);
    final night = SunnahTimes(today);
    final duration = tomorrow.fajr.difference(today.maghrib).inMilliseconds;
    expect(night.fajrTomorrow, tomorrow.fajr);
    expect(night.middleOfTheNight, today.maghrib.add(Duration(milliseconds: duration ~/ 2)));
    expect(night.lastThirdOfTheNight,
        today.maghrib.add(Duration(milliseconds: (duration * 2 / 3).truncate())));
    final timeline = PrayerSchedule(today);
    expect(timeline.events.last.kind, ScheduleEventKind.nextFajr);
    expect(timeline.events.last.time, tomorrow.fajr);
    expect(timeline.currentPrayer(night.lastThirdOfTheNight), Prayer.isha);
    expect(timeline.nextEvent(tomorrow.fajr), isNull);
    expect(() => timeline.events.clear(), throwsUnsupportedError);
  });
}
