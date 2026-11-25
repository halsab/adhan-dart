import 'dart:convert';
import 'dart:io';
import 'package:adhan/adhan.dart';

String normalize(String value) => value.replaceAll('_', '').toLowerCase();
T select<T extends Enum>(List<T> values, Object? name) =>
    values.firstWhere((value) => normalize(value.name) == name);

void main(List<String> args) {
  final data = jsonDecode(File(args.single).readAsStringSync()) as List<dynamic>;
  var failures = 0;
  var checked = 0;
  for (final value in data) {
    final row = value as Map<String, dynamic>;
    final method = select(CalculationMethod.values, row['method']);
    final elevation = row['elevation'] as Map<String, dynamic>;
    final params = method.getParameters().copyWith(
      madhab: select(Madhab.values, row['madhab']),
      rounding: select(Rounding.values, row['rounding']),
      highLatitudeRule: select(HighLatitudeRule.values, row['highLatitudeRule']),
      polarCircleResolution: select(PolarCircleResolution.values, row['polar']),
      shafaq: select(Shafaq.values, row['shafaq']),
      fajrAngle: (row['fajrAngle'] as num).toDouble(),
      ishaAngle: (row['ishaAngle'] as num).toDouble(),
      elevationFromHorizon: ElevationFromHorizon.separate(
          sunrise: (elevation['sunrise'] as num).toDouble(),
          sunset: (elevation['sunset'] as num).toDouble()),
    );
    final coordinates = Coordinates((row['lat'] as num).toDouble(),
        (row['lon'] as num).toDouble());
    final date = DateComponents.from(DateTime.parse(row['date'] as String));
    final label = '$date ${row['lat']},${row['lon']} ${method.name} '
        '${params.madhab.name}/${params.highLatitudeRule.name}/${params.polarCircleResolution.name}';
    void fail(String problem) {
      failures++;
      if (failures <= 40) stderr.writeln('$label: $problem');
    }
    final qibla = Qibla(coordinates).direction;
    final expectedQibla = (row['qibla'] as num).toDouble();
    final qiblaDifference = (qibla - expectedQibla).abs();
    if (qiblaDifference > 1e-6 && (360 - qiblaDifference).abs() > 1e-6) {
      fail('Qibla mismatch: $qibla vs $expectedQibla');
    }
    final result = PrayerTimes.tryCalculate(coordinates, date, params);
    final expected = row['times'] as Map<String, dynamic>?;
    if ((result == null) != (expected == null)) {
      fail('validity mismatch');
      continue;
    }
    if (result == null || expected == null) continue;
    final actual = {'fajr': result.fajr, 'sunrise': result.sunrise,
      'dhuhr': result.dhuhr, 'asr': result.asr, 'sunset': result.sunset,
      'maghrib': result.maghrib, 'isha': result.isha};
    // Compare rounded schedules exactly; investigate any one-minute boundary
    // mismatch instead of hiding it. Unrounded results tolerate one second.
    final tolerance = params.rounding == Rounding.none ? 1000 : 0;
    for (final entry in actual.entries) {
      final delta = (entry.value.millisecondsSinceEpoch - (expected[entry.key] as num)).abs();
      if (delta > tolerance) fail('${entry.key} differs by ${delta}ms');
      checked++;
    }
    final night = row['sunnah'] as Map<String, dynamic>?;
    final calculatedNight = SunnahTimes.tryCalculate(result);
    if (night != null && calculatedNight != null) {
      final middleDelta = (calculatedNight.middleOfTheNight.millisecondsSinceEpoch -
          (night['middle'] as num)).abs();
      final lastDelta = (calculatedNight.lastThirdOfTheNight.millisecondsSinceEpoch -
          (night['lastThird'] as num)).abs();
      if (middleDelta > tolerance || lastDelta > tolerance) fail('night milestone mismatch');
    } else if ((night == null) != (calculatedNight == null)) {
      final nextDate = date.addDays(1);
      final next = PrayerTimes.tryCalculate(coordinates, nextDate, params);
      fail('night milestone validity mismatch: reference=$night, '
          'actual=${calculatedNight?.middleOfTheNight}, '
          'todayMaghrib=${result.maghrib}, todayIsha=${result.isha}, '
          'nextFajr=${next?.fajr}, nextResolution=${next?.appliedPolarResolution}');
    }
  }
  stdout.writeln('${data.length} scenarios, $checked event comparisons, $failures mismatches');
  if (failures != 0) exitCode = 1;
}
