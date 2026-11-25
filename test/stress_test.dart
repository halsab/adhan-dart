@TestOn('vm')
library;

import 'package:adhan/adhan.dart';
import 'package:test/test.dart';

void main() {
  test('global solar schedule sweep: 499,685 date/location combinations', () {
    final params = CalculationMethod.muslim_world_league.getParameters()
        .copyWith(polarCircleResolution: PolarCircleResolution.unresolved);
    final failures = <String>[];
    var count = 0;
    for (var lat = -90; lat <= 90; lat += 5) {
      for (var lon = -180; lon <= 180; lon += 10) {
        final coordinates = Coordinates(lat.toDouble(), lon.toDouble());
        for (var day = 0; day < 365; day++) {
          final date = DateComponents.from(DateTime.utc(2025, 1, 1 + day));
          final p = PrayerTimes.tryCalculate(coordinates, date, params);
          count++;
          if (p == null) {
            if (lat.abs() <= 66.55) failures.add('$lat,$lon $date unavailable');
            continue;
          }
          final times = [p.fajr, p.sunrise, p.dhuhr, p.asr, p.maghrib, p.isha];
          for (var i = 1; i < times.length; i++) {
            if (!times[i].isAfter(times[i-1])) failures.add('$lat,$lon $date out of order');
          }
        }
      }
    }
    expect(count, 499685);
    expect(failures, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
