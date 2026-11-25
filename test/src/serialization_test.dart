import 'dart:convert';
import 'package:adhan/adhan.dart';
import 'package:test/test.dart';

void main() {
  test('settings round-trip with explicit schema version and immutable offsets', () {
    final original = CalculationMethod.tehran.getParameters().copyWith(
        madhab: Madhab.hanafi, rounding: Rounding.none,
        highLatitudeRule: HighLatitudeRule.automatic,
        shafaq: Shafaq.abyad, polarCircleResolution: PolarCircleResolution.aqrabYaum,
        adjustments: const PrayerAdjustments(fajr: -3, isha: 2),
        elevationFromHorizon: const ElevationFromHorizon.separate(sunrise: 450, sunset: 0));
    final data = jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>;
    final restored = CalculationParametersSerialization.fromJson(data);
    expect(restored.toJson(), original.toJson());
    final coordinates = Coordinates(52.2297, 21.0122);
    final date = DateComponents(2026, 3, 20);
    expect(PrayerTimes(coordinates, date, restored).fajr,
        PrayerTimes(coordinates, date, original).fajr);
    data['schemaVersion'] = 2;
    expect(() => CalculationParametersSerialization.fromJson(data), throwsFormatException);
  });
}
