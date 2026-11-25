import 'package:adhan/adhan.dart';
import 'package:test/test.dart';

void main() {
  test('night portions and symmetric recommendation', () {
    final parameters = CalculationParameters(fajrAngle: 10, ishaAngle: 15);
    expect(parameters.nightPortions(), (fajr: 0.5, isha: 0.5));
    expect(parameters.copyWith(highLatitudeRule: HighLatitudeRule.seventh_of_the_night)
        .nightPortions().fajr, closeTo(1/7, 1e-12));
    final angle = parameters.copyWith(highLatitudeRule: HighLatitudeRule.twilight_angle)
        .nightPortions();
    expect(angle.fajr, closeTo(10/60, 1e-12));
    expect(angle.isha, closeTo(15/60, 1e-12));
    final automatic = parameters.copyWith(highLatitudeRule: HighLatitudeRule.automatic);
    for (final lat in [-49.0, 49.0]) {
      expect(automatic.nightPortions(Coordinates(lat, 0)).isha, closeTo(1/7, 1e-12));
    }
    expect(automatic.nightPortions(Coordinates(48, 0)).isha, 0.5);
  });

  test('copyWith does not mutate parameters or preset offsets', () {
    final original = CalculationMethod.karachi.getParameters();
    final changed = original.copyWith(madhab: Madhab.hanafi,
        adjustments: original.adjustments.copyWith(fajr: 5));
    expect(original.madhab, Madhab.shafi);
    expect(original.adjustments.fajr, 0);
    expect(changed.madhab, Madhab.hanafi);
    expect(changed.adjustments.fajr, 5);
    expect(changed.methodAdjustments.dhuhr, 1);
    expect(changed.method, original.method);
  });

  test('rejects malformed settings', () {
    expect(() => CalculationParameters(fajrAngle: double.nan), throwsArgumentError);
    expect(() => CalculationParameters(ishaAngle: -1), throwsArgumentError);
    expect(() => CalculationParameters(maghribAngle: 91), throwsArgumentError);
    expect(() => CalculationParameters(ishaInterval: -1), throwsArgumentError);
    expect(() => CalculationParameters(
        elevationFromHorizon: const ElevationFromHorizon(double.infinity)), throwsArgumentError);
  });
}
