import 'package:adhan/adhan.dart';

void main() {
  final coordinates = Coordinates(52.2297, 21.0122);
  final date = DateComponents(2026, 6, 21);
  final parameters = CalculationMethod.muslim_world_league.getParameters()
      .copyWith(madhab: Madhab.hanafi,
          highLatitudeRule: HighLatitudeRule.automatic);
  final times = PrayerTimes(coordinates, date, parameters);
  for (final event in PrayerSchedule(times).events) {
    print('${event.kind.name}: ${event.time.toIso8601String()}');
  }
  print('Approximation: ${times.isApproximate}');
  print('Qibla: ${Qibla(coordinates).direction}');
}
