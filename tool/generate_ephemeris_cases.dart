// Raw solar geometry only: no preset offsets, fallback, or minute rounding.
import 'dart:convert';
import 'dart:io';

import 'package:adhan/adhan.dart';
import 'package:adhan/src/internal/shadow_length.dart';
import 'package:adhan/src/internal/solar_time.dart';

void main(List<String> args) {
  final locations = [
    Coordinates(0, 0), Coordinates(21.4225, 39.8262),
    Coordinates(35.775, -78.6336), Coordinates(52.2297, 21.0122),
    Coordinates(1.3708, 103.8015), Coordinates(-34.6037, -58.3816),
    Coordinates(-36.8485, 174.7633), Coordinates(0, 179.9),
    Coordinates(0, -179.9), Coordinates(61.2181, -149.9003),
    Coordinates(55.8642, -4.2518), Coordinates(-53.16, -70.91),
    Coordinates(78.2232, 15.6469), Coordinates(-78, 15),
  ];
  final dates = [
    DateTime.utc(2024, 2, 29), DateTime.utc(2024, 3, 20),
    DateTime.utc(2026, 6, 21), DateTime.utc(2026, 9, 22),
    DateTime.utc(2026, 12, 21), DateTime.utc(2030, 12, 31),
  ];
  final rows = <Map<String, Object?>>[];
  void add(Coordinates coords, DateTime date, {double east = 0, double west = 0}) {
    final solar = SolarTime(date, coords, sunriseElevation: east, sunsetElevation: west);
    final values = {
      'transit': solar.transit,
      'sunrise': solar.sunrise,
      'sunset': solar.sunset,
      'fajr18': solar.hourAngle(-18, false),
      'isha17': solar.hourAngle(-17, true),
      'isha18': solar.hourAngle(-18, true),
      'asr1': solar.afternoon(ShadowLength.single),
      'asr2': solar.afternoon(ShadowLength.double),
    };
    rows.add({
      'latitude': coords.latitude, 'longitude': coords.longitude,
      'year': date.year, 'month': date.month, 'day': date.day,
      'east': east, 'west': west,
      'hours': values.map((key, value) => MapEntry(key, value.isFinite ? value : null)),
    });
  }
  for (final coords in locations) {
    for (final date in dates) {
      add(coords, date);
    }
  }
  // Near-lower-culmination cases originally identified using JPL DE440.
  add(Coordinates(61.2181, -149.9003), DateTime.utc(2024, 8, 25));
  add(Coordinates(55.8642, -4.2518), DateTime.utc(2028, 8, 9));
  // Aqrab Yaum boundary: the following sunrise exists even though its
  // sunset is absent. The following sunset is not required to compute night.
  add(Coordinates(78.2232, 15.6469), DateTime.utc(2025, 4, 16), west: 100);
  add(Coordinates(78.2232, 15.6469), DateTime.utc(2025, 4, 17), west: 100);
  File(args.single).writeAsStringSync(jsonEncode(rows));
  stdout.writeln('Generated ${rows.length} raw solar geometry scenarios');
}
