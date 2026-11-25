import 'package:adhan/adhan.dart';
import 'package:test/test.dart';

void main() {
  test('all method presets retain their identity and published parameters', () {
    final expected = <CalculationMethod, (double, double, int)>{
      CalculationMethod.muslim_world_league: (18, 17, 0),
      CalculationMethod.egyptian: (19.5, 17.5, 0),
      CalculationMethod.karachi: (18, 18, 0),
      CalculationMethod.umm_al_qura: (18.5, 0, 90),
      CalculationMethod.dubai: (18.2, 18.2, 0),
      CalculationMethod.moon_sighting_committee: (18, 18, 0),
      CalculationMethod.north_america: (15, 15, 0),
      CalculationMethod.kuwait: (18, 17.5, 0),
      CalculationMethod.qatar: (18, 0, 90),
      CalculationMethod.singapore: (20, 18, 0),
      CalculationMethod.turkey: (18, 17, 0),
      CalculationMethod.tehran: (17.7, 14, 0),
      CalculationMethod.other: (0, 0, 0),
    };
    expect(expected.length, CalculationMethod.values.length);
    for (final entry in expected.entries) {
      final p = entry.key.getParameters();
      expect(p.method, entry.key);
      expect((p.fajrAngle, p.ishaAngle, p.ishaInterval), entry.value);
      expect(p.polarCircleResolution, PolarCircleResolution.aqrabBalad);
    }
    expect(CalculationMethod.singapore.getParameters().rounding, Rounding.up);
    expect(CalculationMethod.tehran.getParameters().maghribAngle, 4.5);
    final dubai = CalculationMethod.dubai.getParameters().methodAdjustments;
    expect((dubai.sunrise, dubai.dhuhr, dubai.asr, dubai.maghrib), (-3, 3, 3, 3));
  });
}
