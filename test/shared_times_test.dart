@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

String normalized(String value) => value.replaceAll('_', '').toLowerCase();

void main() {
  tzdata.initializeTimeZones();
  final directory = Directory('test/data/prayer-times');
  for (final file in directory.listSync().whereType<File>()) {
    if (!file.path.endsWith('.json') || file.path.contains('Generated-Using-V1')) continue;
    test('published fixture: ${file.path}', () {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final settings = data['params'] as Map<String, dynamic>;
      final method = CalculationMethod.values.firstWhere(
          (m) => normalized(m.name) == normalized(settings['method'] as String));
      final madhab = Madhab.values.byName((settings['madhab'] as String).toLowerCase());
      final rule = HighLatitudeRule.values.firstWhere(
          (r) => normalized(r.name) == normalized(settings['highLatitudeRule'] as String));
      final params = method.getParameters().copyWith(madhab: madhab, highLatitudeRule: rule);
      final coordinates = Coordinates((settings['latitude'] as num).toDouble(),
          (settings['longitude'] as num).toDouble());
      final zone = tz.getLocation(settings['timezone'] as String);
      final variance = (data['variance'] as num?) ?? 0;
      for (final value in data['times'] as List<dynamic>) {
        final row = value as Map<String, dynamic>;
        final date = DateComponents.from(DateTime.parse(row['date'] as String));
        final p = PrayerTimes(coordinates, date, params);
        for (final event in [Prayer.fajr, Prayer.sunrise, Prayer.dhuhr,
            Prayer.asr, Prayer.maghrib, Prayer.isha]) {
          final clock = DateFormat('h:mm a', 'en_US').parse(row[event.name] as String);
          final expected = tz.TZDateTime(zone, date.year, date.month, date.day,
              clock.hour, clock.minute);
          final difference = p.timeForPrayer(event)!.difference(expected).inSeconds.abs();
          expect(difference, lessThanOrEqualTo(variance * 60),
              reason: '$date ${event.name}, ${p.timeForPrayer(event)}, expected $expected');
        }
      }
    });
  }
}
