// Test-only direct comparisons: the Swift and Kotlin programs calculate
// independently from these Dart-generated inputs and compare absolute instants.
import 'dart:convert';
import 'dart:io';

import 'package:adhan/adhan.dart';

String normalized(Enum e) => e.name.replaceAll('_', '').toLowerCase();

void main(List<String> args) {
  final locations = [
    Coordinates(0, 0), Coordinates(21.4225, 39.8262),
    Coordinates(35.775, -78.6336), Coordinates(36.3, 30.1),
    Coordinates(1.3708, 103.8015), Coordinates(-34.6037, -58.3816),
    Coordinates(-36.8485, 174.7633), Coordinates(0, -179.9),
    Coordinates(0, 179.9), Coordinates(52.2297, 21.0122),
    Coordinates(61.2181, -149.9003), Coordinates(-53.16, -70.91),
    Coordinates(78.2232, 15.6469), Coordinates(-78, 15),
  ];
  final dates = [
    DateComponents(2024, 2, 29), DateComponents(2024, 3, 20),
    DateComponents(2025, 4, 26), DateComponents(2026, 6, 21),
    DateComponents(2026, 9, 22), DateComponents(2026, 12, 21),
  ];
  final rows = <Map<String, Object?>>[];
  for (final location in locations) {
    for (final date in dates) {
      for (final method in CalculationMethod.values) {
        for (final madhab in Madhab.values) {
          for (var variant = 0; variant < 3; variant++) {
            final rule = [HighLatitudeRule.middle_of_the_night,
                HighLatitudeRule.seventh_of_the_night,
                HighLatitudeRule.twilight_angle][variant];
            final polar = [PolarCircleResolution.unresolved,
                PolarCircleResolution.aqrabBalad,
                PolarCircleResolution.aqrabYaum][variant];
            final shafaq = Shafaq.values[variant];
            final elevation = variant == 0 ? const ElevationFromHorizon()
                : variant == 1 ? const ElevationFromHorizon(450)
                : const ElevationFromHorizon.separate(sunrise: 0, sunset: 100);
            final p = method.getParameters().copyWith(
                madhab: madhab, rounding: Rounding.none, highLatitudeRule: rule,
                polarCircleResolution: polar, shafaq: shafaq,
                elevationFromHorizon: elevation,
                fajrAngle: method == CalculationMethod.other ? 16 : null,
                ishaAngle: method == CalculationMethod.other ? 16 : null);
            final times = PrayerTimes.tryCalculate(location, date, p);
            final night = times == null ? null : SunnahTimes.tryCalculate(times);
            rows.add({
              'lat': location.latitude, 'lon': location.longitude,
              'year': date.year, 'month': date.month, 'day': date.day,
              'method': normalized(method), 'madhab': madhab.name,
              'rule': normalized(rule), 'polar': normalized(polar),
              'shafaq': shafaq.name, 'east': elevation.sunrise, 'west': elevation.sunset,
              'fajrAngle': p.fajrAngle, 'ishaAngle': p.ishaAngle,
              // Kotlin uses the older solver and has no elevation/polar/Tehran
              // features; compare moderate latitudes with shared policies only.
              'kotlin': variant == 0 && location.latitude.abs() <= 40 &&
                  method != CalculationMethod.tehran,
              'times': times == null ? null :
                  [times.fajr, times.sunrise, times.dhuhr, times.asr,
                   times.maghrib, times.isha]
                  .map((t) => t.millisecondsSinceEpoch).toList(),
              'night': night == null ? null : [night.middleOfTheNight,
                  night.lastThirdOfTheNight].map((t) => t.millisecondsSinceEpoch).toList(),
              'qibla': Qibla(location).direction,
              'calculationLatitude': times?.calculationCoordinates.latitude,
              'calculationDate': times?.calculationDate.toString(),
              'nextFajr': night?.fajrTomorrow.millisecondsSinceEpoch,
            });
          }
        }
      }
    }
  }
  File(args.single).writeAsStringSync(jsonEncode(rows));
  stdout.writeln('Generated ${rows.length} direct cross-port cases');
}
