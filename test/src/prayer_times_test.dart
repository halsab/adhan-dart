import 'package:adhan/adhan.dart';
import 'package:test/test.dart';

List<DateTime> ordered(PrayerTimes p) =>
    [p.fajr, p.sunrise, p.dhuhr, p.asr, p.maghrib, p.isha];

void expectOrdered(PrayerTimes p) {
  final times = ordered(p);
  expect(times.every((t) => t.isUtc), isTrue);
  for (var i = 1; i < times.length; i++) {
    expect(times[i].isAfter(times[i - 1]), isTrue,
        reason: '${p.dateComponents}: ${times[i - 1]} >= ${times[i]}');
  }
}

void main() {
  final coords = Coordinates(35.775, -78.6336);
  final date = DateComponents(2015, 7, 12);
  final params = CalculationMethod.north_america.getParameters();
  test('UTC values from current Adhan JS test case', () {
    final p = PrayerTimes(coords, date, params.copyWith(madhab: Madhab.hanafi));
    expectOrdered(p);
    expect(ordered(p), [
      DateTime.utc(2015, 7, 12, 8, 42), DateTime.utc(2015, 7, 12, 10, 8),
      DateTime.utc(2015, 7, 12, 17, 21), DateTime.utc(2015, 7, 12, 22, 22),
      DateTime.utc(2015, 7, 13, 0, 32), DateTime.utc(2015, 7, 13, 1, 57),
    ]);
    expect(p.currentPrayer(p.fajr.subtract(const Duration(seconds: 1))), Prayer.none);
    expect(p.currentPrayer(p.fajr), Prayer.fajr);
    expect(p.nextPrayer(p.fajr), Prayer.sunrise);
    expect(p.nextPrayer(p.isha), Prayer.none);
    expect(p.timeForPrayer(Prayer.none), isNull);
    expect(p.timeForPrayer(Prayer.asr), p.asr);
    expect(PrayerTimes.today(coords, params, localNow: DateTime.utc(2015, 7, 12, 23))
        .dateComponents, date);
  });

  test('Hanafi Asr occurs after Shafi Asr; offsets applied once', () {
    final shafi = PrayerTimes(coords, date, params);
    final hanafi = PrayerTimes(coords, date, params.copyWith(madhab: Madhab.hanafi));
    expect(hanafi.asr.isAfter(shafi.asr), isTrue);
    final offset = PrayerTimes(coords, date,
        params.copyWith(adjustments: const PrayerAdjustments(fajr: 4, asr: -2)));
    expect(offset.fajr.difference(shafi.fajr), const Duration(minutes: 4));
    expect(offset.asr.difference(shafi.asr), const Duration(minutes: -2));
  });

  test('no polar substitution for invalid user adjustments', () {
    expect(() => PrayerTimes(coords, date, params.copyWith(
        adjustments: const PrayerAdjustments(fajr: 300))),
        throwsA(isA<PrayerTimeCalculationException>().having(
            (e) => e.reason, 'reason', CalculationFailure.invalidAdjustments)));
  });

  test('date line UTC instants keep the intended solar day', () {
    for (final lon in [-179.9, 179.9]) {
      final p = PrayerTimes(Coordinates(0, lon), DateComponents(2026, 3, 20),
          CalculationMethod.muslim_world_league.getParameters());
      expectOrdered(p);
      final solarNoon = p.dhuhr.add(Duration(minutes: (lon * 4).round()));
      expect(solarNoon.day, 20);
      expect(solarNoon.hour, inInclusiveRange(11, 12));
    }
  });

  test('polar fallback is bounded, explicit, and retains provenance', () {
    final polar = Coordinates(78.2232, 15.6469);
    final summer = DateComponents(2026, 6, 21);
    final unresolved = params.copyWith(polarCircleResolution: PolarCircleResolution.unresolved);
    expect(PrayerTimes.tryCalculate(polar, summer, unresolved), isNull);
    final nearestLocation = PrayerTimes(polar, summer, params);
    expectOrdered(nearestLocation);
    expect(nearestLocation.appliedPolarResolution, PolarCircleResolution.aqrabBalad);
    expect(nearestLocation.calculationCoordinates.latitude, lessThan(polar.latitude));
    expect(nearestLocation.calculationCoordinates.longitude, polar.longitude);
    expect(nearestLocation.calculationDate, summer);
    expect(nearestLocation.isApproximate, isTrue);
    final nearestDate = PrayerTimes(polar, summer,
        params.copyWith(polarCircleResolution: PolarCircleResolution.aqrabYaum));
    expectOrdered(nearestDate);
    expect(nearestDate.calculationCoordinates, polar);
    expect(nearestDate.calculationDate, isNot(summer));
    expect(nearestDate.dateComponents, summer);
    expect(nearestDate.appliedPolarResolution, PolarCircleResolution.aqrabYaum);
    final south = PrayerTimes(Coordinates(-78, 15), DateComponents(2026, 12, 21), params);
    expect(south.calculationCoordinates.latitude, inInclusiveRange(-78, 0));
    expectOrdered(south);
  });

  test('impossible interval terminates even near equator', () {
    final invalid = params.copyWith(ishaInterval: 1);
    for (final latitude in [-0.3, 0.0, 0.3, 70.0]) {
      expect(PrayerTimes.tryCalculate(Coordinates(latitude, 10), date, invalid), isNull);
    }
    expect(PrayerTimes.tryCalculate(Coordinates(70, 10), date,
        invalid.copyWith(polarCircleResolution: PolarCircleResolution.aqrabYaum)), isNull);
  });

  test('Shafaq controls seasonal evening twilight; source is exposed', () {
    final location = Coordinates(51.507194, -0.116711);
    final summer = DateComponents(2026, 6, 21);
    final method = CalculationMethod.moon_sighting_committee.getParameters();
    final red = PrayerTimes(location, summer, method.copyWith(shafaq: Shafaq.ahmer));
    final white = PrayerTimes(location, summer, method.copyWith(shafaq: Shafaq.abyad));
    expect(red.ishaSource, PrayerTimeSource.seasonalTwilight);
    expect(white.ishaSource, PrayerTimeSource.seasonalTwilight);
    expect(white.isha.isAfter(red.isha), isTrue);
  });

  test('elevation adjusts horizon events, not direct twilight or Asr', () {
    final location = Coordinates(36.3, 30.1);
    final equinox = DateComponents(2024, 3, 20);
    final method = CalculationMethod.muslim_world_league.getParameters()
        .copyWith(rounding: Rounding.none);
    final normal = PrayerTimes(location, equinox, method);
    final elevated = PrayerTimes(location, equinox, method.copyWith(
        elevationFromHorizon: const ElevationFromHorizon(450)));
    expect(normal.sunrise.difference(elevated.sunrise).inSeconds, inInclusiveRange(180, 240));
    expect(elevated.sunset.difference(normal.sunset).inSeconds, inInclusiveRange(180, 240));
    expect(elevated.fajr, normal.fajr);
    expect(elevated.asr, normal.asr);
    expect(elevated.isha, normal.isha);
    final eastOnly = PrayerTimes(location, equinox, method.copyWith(
        elevationFromHorizon: const ElevationFromHorizon.separate(sunrise: 450, sunset: 0)));
    expect(eastOnly.sunrise, elevated.sunrise);
    expect(eastOnly.sunset, normal.sunset);
    final negative = PrayerTimes(location, equinox, method.copyWith(
        elevationFromHorizon: const ElevationFromHorizon(-100)));
    expect(ordered(negative), ordered(normal));
    final tehran = PrayerTimes(location, equinox,
        CalculationMethod.tehran.getParameters().copyWith(rounding: Rounding.none));
    expect(tehran.maghrib.isAfter(tehran.sunset), isTrue);
  });

  test('season day and leap year boundaries', () {
    expect(PrayerTimes.daysSinceSolstice(1, 2016, 1), 11);
    expect(PrayerTimes.daysSinceSolstice(366, 2016, 1), 10);
    expect(PrayerTimes.daysSinceSolstice(356, 2016, 1), 0);
    expect(PrayerTimes.daysSinceSolstice(173, 2016, -1), 0);
    expect(PrayerTimes.daysSinceSolstice(172, 2015, -1), 0);
  });
}
