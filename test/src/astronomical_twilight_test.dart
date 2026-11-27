import 'package:adhan/adhan.dart';
import 'package:adhan/src/data/time_components.dart';
import 'package:adhan/src/internal/solar_time.dart';
import 'package:test/test.dart';

DateTime? angleCrossing(
    Coordinates coordinates, DateComponents date, double angle, bool evening) {
  final midnight = date.toUtcMidnight();
  final solar = SolarTime(midnight, coordinates);
  return TimeComponents.fromDouble(solar.hourAngle(-angle, evening))
      ?.dateComponents(midnight);
}

void main() {
  final coordinates = Coordinates(36.3, 30.1);
  final equinox = DateComponents(2024, 3, 20);
  final base = CalculationParameters(
    fajrAngle: 18,
    ishaAngle: 17,
    rounding: Rounding.none,
    polarCircleResolution: PolarCircleResolution.unresolved,
  );
  final london = Coordinates(51.507194, -0.116711);
  final summer = DateComponents(2026, 6, 21);

  test('reachable crossings are independent UTC instants', () {
    final times = PrayerTimes(coordinates, equinox, base);
    expect(times.astronomicalFajr, isNotNull);
    expect(times.astronomicalIsha, isNotNull);
    expect(times.astronomicalFajr!.isUtc, isTrue);
    expect(times.astronomicalIsha!.isUtc, isTrue);
    expect(times.astronomicalFajr, angleCrossing(coordinates, equinox, 18, false));
    expect(times.astronomicalIsha, angleCrossing(coordinates, equinox, 17, true));
    expect(times.astronomicalFajr, times.fajr);
    expect(times.astronomicalIsha, times.isha);
    expect(times.fajrSource, PrayerTimeSource.astronomical);
    expect(times.ishaSource, PrayerTimeSource.astronomical);
    expect(times.isApproximate, isFalse);
  });

  test('night portions retain both reachable crossings before clamping', () {
    final unrestricted = base.copyWith(fajrAngle: 12, ishaAngle: 12);
    final direct = PrayerTimes(london, summer, unrestricted);
    final limited = PrayerTimes(london, summer, unrestricted.copyWith(
        highLatitudeRule: HighLatitudeRule.seventh_of_the_night));
    expect(direct.fajrSource, PrayerTimeSource.astronomical);
    expect(direct.ishaSource, PrayerTimeSource.astronomical);
    expect(limited.fajrSource, PrayerTimeSource.nightPortion);
    expect(limited.ishaSource, PrayerTimeSource.nightPortion);
    expect(limited.astronomicalFajr, direct.fajr);
    expect(limited.astronomicalIsha, direct.isha);
    expect(limited.astronomicalFajr!.isBefore(limited.fajr), isTrue);
    expect(limited.astronomicalIsha!.isAfter(limited.isha), isTrue);
    expect(limited.isApproximate, isTrue);
  });

  test('each unreachable angle is null independently of the other', () {
    for (final (fajrAngle, ishaAngle) in [(18.0, 12.0), (12.0, 18.0), (18.0, 18.0)]) {
      final times = PrayerTimes(london, summer,
          base.copyWith(fajrAngle: fajrAngle, ishaAngle: ishaAngle));
      expect(times.astronomicalFajr, angleCrossing(london, summer, fajrAngle, false));
      expect(times.astronomicalIsha, angleCrossing(london, summer, ishaAngle, true));
      expect(times.astronomicalFajr == null, fajrAngle == 18);
      expect(times.astronomicalIsha == null, ishaAngle == 18);
      expect(times.fajrSource, fajrAngle == 18
          ? PrayerTimeSource.nightPortion : PrayerTimeSource.astronomical);
      expect(times.ishaSource, ishaAngle == 18
          ? PrayerTimeSource.nightPortion : PrayerTimeSource.astronomical);
      expect(times.fajr.isBefore(times.sunrise), isTrue);
      expect(times.isha.isAfter(times.maghrib), isTrue);
      expect(times.isApproximate, isTrue);
    }
  });

  test('seasonal and northern special substitutions preserve raw crossings', () {
    final northern = Coordinates(56, 10);
    final seasonal = CalculationMethod.moon_sighting_committee.getParameters()
        .copyWith(rounding: Rounding.none,
            polarCircleResolution: PolarCircleResolution.unresolved);
    final times = PrayerTimes(northern, equinox, seasonal);
    expect(times.astronomicalFajr, isNotNull);
    expect(times.astronomicalIsha, isNotNull);
    expect(times.astronomicalFajr,
        angleCrossing(northern, equinox, seasonal.fajrAngle, false));
    expect(times.astronomicalIsha,
        angleCrossing(northern, equinox, seasonal.ishaAngle, true));
    expect(times.fajrSource, isNot(PrayerTimeSource.astronomical));
    expect(times.ishaSource, isNot(PrayerTimeSource.astronomical));
    expect(times.fajr, isNot(times.astronomicalFajr));
    expect(times.isha, isNot(times.astronomicalIsha));
    expect(times.isApproximate, isTrue);
  });

  test('user and method adjustments and rounding affect final times only', () {
    final raw = PrayerTimes(coordinates, equinox, base);
    final adjusted = PrayerTimes(coordinates, equinox, base.copyWith(
        adjustments: const PrayerAdjustments(fajr: 3, isha: 4),
        methodAdjustments: const PrayerAdjustments(fajr: 2, isha: -2)));
    final rounded = PrayerTimes(coordinates, equinox, base.copyWith(
        adjustments: const PrayerAdjustments(fajr: 3, isha: 4),
        methodAdjustments: const PrayerAdjustments(fajr: 2, isha: -2),
        rounding: Rounding.up));
    expect(adjusted.fajr, raw.fajr.add(const Duration(minutes: 5)));
    expect(adjusted.isha, raw.isha.add(const Duration(minutes: 2)));
    DateTime ceilMinute(DateTime time) => DateTime.fromMillisecondsSinceEpoch(
        (time.millisecondsSinceEpoch / 60000).ceil() * 60000, isUtc: true);
    expect(rounded.fajr, ceilMinute(adjusted.fajr));
    expect(rounded.isha, ceilMinute(adjusted.isha));
    expect(rounded.fajr, isNot(raw.fajr));
    expect(rounded.isha, isNot(raw.isha));
    for (final times in [adjusted, rounded]) {
      expect(times.astronomicalFajr, raw.astronomicalFajr);
      expect(times.astronomicalIsha, raw.astronomicalIsha);
      expect(times.fajrSource, raw.fajrSource);
      expect(times.ishaSource, raw.ishaSource);
      expect(times.isApproximate, raw.isApproximate);
    }
  });

  test('fixed Isha interval retains configured reachable or unreachable angle', () {
    final direct = PrayerTimes(coordinates, equinox, base);
    final fixed = PrayerTimes(coordinates, equinox, base.copyWith(ishaInterval: 90));
    expect(fixed.isha, fixed.sunset.add(const Duration(minutes: 90)));
    expect(fixed.ishaSource, PrayerTimeSource.fixedInterval);
    expect(fixed.astronomicalIsha, direct.astronomicalIsha);
    expect(fixed.isha, isNot(fixed.astronomicalIsha));
    expect(fixed.astronomicalFajr, direct.astronomicalFajr);
    expect(fixed.isApproximate, isFalse);

    final unreachable = PrayerTimes(london, summer,
        base.copyWith(fajrAngle: 12, ishaAngle: 18, ishaInterval: 90));
    expect(unreachable.astronomicalFajr, isNotNull);
    expect(unreachable.astronomicalIsha, isNull);
    expect(unreachable.isha, unreachable.sunset.add(const Duration(minutes: 90)));
    expect(unreachable.ishaSource, PrayerTimeSource.fixedInterval);
    expect(unreachable.isApproximate, isFalse);

    final zeroAngle = PrayerTimes(coordinates, equinox,
        base.copyWith(ishaAngle: 0, ishaInterval: 90));
    expect(zeroAngle.astronomicalIsha, isNotNull);
    expect(zeroAngle.astronomicalIsha,
        angleCrossing(coordinates, equinox, 0, true));
    expect(zeroAngle.ishaSource, PrayerTimeSource.fixedInterval);
  });

  test('Aqrab Balad uses the substituted coordinates', () {
    final polar = Coordinates(78.2232, 15.6469);
    final winter = DateComponents(2026, 12, 21);
    final p = base.copyWith(fajrAngle: 6, ishaAngle: 6);
    final times = PrayerTimes(polar, winter,
        p.copyWith(polarCircleResolution: PolarCircleResolution.aqrabBalad));
    expect(times.appliedPolarResolution, PolarCircleResolution.aqrabBalad);
    expect(times.calculationCoordinates, isNot(polar));
    final direct = PrayerTimes(times.calculationCoordinates, winter, p);
    expect(direct.astronomicalFajr, isNotNull);
    expect(direct.astronomicalIsha, isNotNull);
    expect(times.astronomicalFajr, direct.astronomicalFajr);
    expect(times.astronomicalIsha, direct.astronomicalIsha);
    expect(times.isApproximate, isTrue);
  });

  test('Aqrab Yaum shifts both crossings and preserves independent nulls', () {
    final polar = Coordinates(78.2232, 15.6469);
    final winter = DateComponents(2026, 12, 21);
    for (final (fajrAngle, ishaAngle) in [(6.0, 6.0), (90.0, 6.0), (6.0, 90.0)]) {
      final p = base.copyWith(fajrAngle: fajrAngle, ishaAngle: ishaAngle);
      final times = PrayerTimes(polar, winter,
          p.copyWith(polarCircleResolution: PolarCircleResolution.aqrabYaum));
      expect(times.appliedPolarResolution, PolarCircleResolution.aqrabYaum);
      expect(times.calculationCoordinates, polar);
      expect(times.calculationDate, isNot(winter));
      expect(times.isApproximate, isTrue);
      final direct = PrayerTimes(polar, times.calculationDate, p);
      final shift = winter.toUtcMidnight().difference(times.calculationDate.toUtcMidnight());
      expect(direct.astronomicalFajr == null, fajrAngle == 90);
      expect(direct.astronomicalIsha == null, ishaAngle == 90);
      expect(times.astronomicalFajr, direct.astronomicalFajr?.add(shift));
      expect(times.astronomicalIsha, direct.astronomicalIsha?.add(shift));
      expect(times.fajr, direct.fajr.add(shift));
      expect(times.isha, direct.isha.add(shift));
      expect(times.fajrSource, direct.fajrSource);
      expect(times.ishaSource, direct.ishaSource);
    }
  });
}
