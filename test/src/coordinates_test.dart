import 'package:adhan/adhan.dart';
import 'package:test/test.dart';

void main() {
  test('local-noon anchor handles political date-line timezones', () {
    final apia = Coordinates(-13.8333, -171.75);
    // 2026-06-21 12:00 in Samoa (UTC+13).
    final civilNoon = DateTime.utc(2026, 6, 20, 23);
    final date = DateComponents.fromLocalNoon(civilNoon, apia);
    expect(date, DateComponents(2026, 6, 20));
    final p = PrayerTimes(apia, date, CalculationMethod.muslim_world_league.getParameters());
    final localDhuhr = p.dhuhr.add(const Duration(hours: 13));
    expect(localDhuhr.day, 21);
    expect(localDhuhr.hour, inInclusiveRange(11, 13));
    final kiritimati = Coordinates(1.87, -157.4);
    // Local noon June 21 in UTC+14.
    expect(DateComponents.fromLocalNoon(DateTime.utc(2026, 6, 20, 22), kiritimati),
        DateComponents(2026, 6, 20));
    final warsaw = Coordinates(52.2297, 21.0122);
    expect(DateComponents.fromLocalNoon(DateTime.utc(2026, 6, 21, 10), warsaw),
        DateComponents(2026, 6, 21));
  });

  test('always validates geographic coordinates', () {
    for (final lat in [90.1, -90.1, double.nan, double.infinity]) {
      expect(() => Coordinates(lat, 0), throwsArgumentError);
    }
    for (final lon in [180.1, -180.1, double.nan, double.negativeInfinity]) {
      expect(() => Coordinates(0, lon), throwsArgumentError);
    }
    expect(Coordinates(-90, 180), Coordinates(-90, 180));
    expect(Coordinates(-90, 180).hashCode, Coordinates(-90, 180).hashCode);
  });

  test('civil date validates Gregorian fields and handles leap days', () {
    expect(() => DateComponents(2025, 2, 29), throwsArgumentError);
    expect(() => DateComponents(2026, 13, 1), throwsArgumentError);
    expect(() => DateComponents(0, 1, 1), throwsArgumentError);
    expect(DateComponents(2024, 2, 28).addDays(1), DateComponents(2024, 2, 29));
    expect(DateComponents(2024, 12, 31).addDays(1), DateComponents(2025, 1, 1));
    expect(DateComponents(2024, 1, 1).hashCode, DateComponents(2024, 1, 1).hashCode);
  });
}
