import 'package:adhan/adhan.dart';
import 'package:test/test.dart';

void main() {
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
