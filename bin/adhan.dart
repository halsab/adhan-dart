import 'dart:io';
import 'package:adhan/adhan.dart';

/// The caller supplies the civil date for the target location, not device now.
void main(List<String> args) {
  if (args.length != 3) {
    stderr.writeln('Usage: dart run adhan <latitude> <longitude> <YYYY-MM-DD>');
    exitCode = 64;
    return;
  }
  try {
    final coordinates = Coordinates(double.parse(args[0]), double.parse(args[1]));
    final dateParts = args[2].split('-');
    if (dateParts.length != 3) throw const FormatException('Expected YYYY-MM-DD');
    final date = DateComponents(int.parse(dateParts[0]), int.parse(dateParts[1]),
        int.parse(dateParts[2]));
    final times = PrayerTimes(coordinates, date,
        CalculationMethod.karachi.getParameters().copyWith(madhab: Madhab.hanafi));
    for (final event in PrayerSchedule(times).events) {
      stdout.writeln('${event.kind.name}: ${event.time.toIso8601String()}');
    }
    stdout.writeln('Qibla: ${Qibla(coordinates).direction}° true north');
    if (times.isApproximate) stdout.writeln('Uses approximated times');
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
