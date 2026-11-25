import 'dart:math' as math;
import 'package:adhan/adhan.dart';
import 'package:adhan/src/internal/astronomical.dart';
import 'package:adhan/src/internal/calendrical_helper.dart';
import 'package:adhan/src/internal/solar_coordinates.dart';
import 'package:adhan/src/internal/solar_time.dart';
import 'package:test/test.dart';

void main() {
  test('Meeus worked solar-coordinate example, 1992-10-13', () {
    final jd = CalendricalHelper.julianDay(1992, 10, 13);
    expect(jd, 2448908.5);
    final solar = SolarCoordinates(jd);
    final t = CalendricalHelper.julianCentury(jd);
    expect(t, closeTo(-0.072183436, 1e-9));
    expect(Astronomical.meanSolarLongitude(t), closeTo(201.8072, 0.0001));
    expect(solar.declination, closeTo(-7.78507, 0.0001));
    expect(solar.rightAscension, closeTo(198.38083, 0.0001));
    expect(CalendricalHelper.julianDay(2015, 7, 12, hours: 4.25),
        closeTo(2457215.67708333, 0.00001));
    expect(CalendricalHelper.julianDayByDate(DateTime.utc(2015, 7, 12, 4, 15)),
        closeTo(2457215.67708333, 0.00001));
  });

  test('Meeus transit and rise example, chapter 15', () {
    const longitude = -71.0833;
    const theta = 177.74208;
    const a1 = 40.68021, a2 = 41.73129, a3 = 42.78204;
    final m0 = Astronomical.approximateTransit(longitude, theta, a2);
    expect(m0, closeTo(0.81965, 0.0001));
    expect(Astronomical.correctedTransit(m0, longitude, theta, a2, a1, a3) / 24,
        closeTo(0.8198, 0.0001));
    final rise = Astronomical.correctedHourAngle(m0, -0.5667,
        Coordinates(42.3333, longitude), false, theta, a2, a1, a3,
        18.44092, 18.04761, 18.82742) / 24;
    expect(rise, closeTo(0.51766, 0.0001));
  });

  test('DE440 reference near lower culmination from upstream PR #243', () {
    final cases = [
      (Coordinates(61.2181, -149.9003), DateTime.utc(2024, 8, 25), false, 10.56005),
      (Coordinates(55.8642, -4.2518), DateTime.utc(2028, 8, 9), true, 23.59859),
    ];
    for (final (coords, date, evening, reference) in cases) {
      final solar = SolarTime(date, coords);
      expect((solar.hourAngle(-18, evening) - reference).abs() * 3600,
          lessThan(10));
    }
  });

  test('next-day sunset is not a dependency of the current night length', () {
    final c = Coordinates(78.2232, 15.6469);
    final today = DateComponents(2025, 4, 16);
    final tomorrow = SolarTime(today.addDays(1).toUtcMidnight(), c,
        sunsetElevation: 100);
    expect(tomorrow.sunrise.isFinite, isTrue);
    expect(tomorrow.sunset.isNaN, isTrue);
    final p = CalculationMethod.muslim_world_league.getParameters().copyWith(
        rounding: Rounding.none,
        highLatitudeRule: HighLatitudeRule.twilight_angle,
        elevationFromHorizon: const ElevationFromHorizon.separate(sunrise: 0, sunset: 100),
        polarCircleResolution: PolarCircleResolution.unresolved);
    expect(PrayerTimes.tryCalculate(c, today, p), isNotNull);
    final substituted = PrayerTimes(c, DateComponents(2025, 4, 26),
        p.copyWith(polarCircleResolution: PolarCircleResolution.aqrabYaum));
    expect(substituted.calculationDate, today);
  });

  test('unreachable solar altitude remains unresolved', () {
    final solar = SolarTime(DateTime.utc(2015, 7, 12), Coordinates(35.78333, -78.65));
    expect(solar.hourAngle(-36, true).isNaN, isTrue);
    final polar = SolarTime(DateTime.utc(2026, 6, 21), Coordinates(78.2232, 15.6469));
    expect(polar.sunrise.isNaN, isTrue);
    expect(polar.sunset.isNaN, isTrue);
  });

  test('solar transit stays continuous across right-ascension and date-line crossings', () {
    final coordinates = Coordinates(42.74674252600066, 177.2401196144623);
    var previous = SolarTime(DateTime.utc(2025, 11, 1), coordinates);
    for (var i = 1; i <= 365; i++) {
      final current = SolarTime(DateTime.utc(2025, 11, 1 + i), coordinates);
      expect((current.transit - previous.transit).abs(), lessThan(1 / 60));
      expect((current.sunrise - previous.sunrise).abs(), lessThan(2 / 60));
      expect((current.sunset - previous.sunset).abs(), lessThan(2 / 60));
      previous = current;
    }
  });

  test('elevation correction reproduces Odeh worked example', () {
    const parallax = 0.0024;
    final zenith = 90 + 50/60 + 0.035333 * math.sqrt(1000) - parallax;
    expect(zenith, closeTo(91.948, 0.001));
  });
}
