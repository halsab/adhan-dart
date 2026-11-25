import 'dart:math' as math;

import 'calculation_method.dart';
import 'calculation_options.dart';
import 'calculation_parameters.dart';
import 'coordinates.dart';
import 'data/calendar_util.dart';
import 'data/date_components.dart';
import 'data/time_components.dart';
import 'internal/solar_time.dart';
import 'madhab.dart';
import 'prayer.dart';

/// One complete daily schedule. All times are absolute UTC instants.
/// A civil date belongs to the target location; timezone presentation is the
/// caller's responsibility. No device timezone is used during calculation.
final class PrayerTimes {
  final Coordinates coordinates;
  final DateComponents dateComponents;
  final CalculationParameters calculationParameters;

  /// The actual coordinates and civil date used for solar geometry.
  final Coordinates calculationCoordinates;
  final DateComponents calculationDate;
  final PolarCircleResolution? appliedPolarResolution;
  final _DayTimes _times;

  DateTime get fajr => _times.fajr;
  DateTime get sunrise => _times.sunrise;
  DateTime get dhuhr => _times.dhuhr;
  DateTime get asr => _times.asr;
  DateTime get sunset => _times.sunset;
  DateTime get maghrib => _times.maghrib;
  DateTime get isha => _times.isha;
  PrayerTimeSource get fajrSource => _times.fajrSource;
  PrayerTimeSource get ishaSource => _times.ishaSource;
  bool get usedPolarResolution => appliedPolarResolution != null;
  bool get isApproximate => usedPolarResolution ||
      fajrSource == PrayerTimeSource.nightPortion ||
      fajrSource == PrayerTimeSource.seasonalTwilight ||
      ishaSource == PrayerTimeSource.nightPortion ||
      ishaSource == PrayerTimeSource.seasonalTwilight;

  PrayerTimes._(this.coordinates, this.dateComponents,
      this.calculationParameters, this.calculationCoordinates,
      this.calculationDate, this.appliedPolarResolution, this._times);

  factory PrayerTimes(Coordinates coordinates, DateComponents date,
      CalculationParameters parameters) {
    var raw = _computeDay(coordinates, date.toUtcMidnight(), parameters);
    var usedCoordinates = coordinates;
    var usedDate = date;
    PolarCircleResolution? resolution;

    if (raw == null) {
      switch (parameters.polarCircleResolution) {
        case PolarCircleResolution.aqrabBalad:
          // At most 180 half-degree steps, never cross the equator.
          var latitude = coordinates.latitude;
          while (latitude != 0) {
            latitude = latitude.sign * math.max(0.0, latitude.abs() - 0.5);
            final candidate = Coordinates(latitude, coordinates.longitude);
            raw = _computeDay(candidate, date.toUtcMidnight(), parameters);
            if (raw != null) {
              usedCoordinates = candidate;
              resolution = PolarCircleResolution.aqrabBalad;
              break;
            }
          }
          break;
        case PolarCircleResolution.aqrabYaum:
          // Search +1, -1, +2, -2 ... up to 183 days in each direction.
          search:
          for (var days = 1; days <= 183; days++) {
            for (final direction in [1, -1]) {
              final offset = days * direction;
              final candidate = date.toUtcMidnight().add(Duration(days: offset));
              if (candidate.year < 1 || candidate.year > 9999) continue;
              final calculated = _computeDay(coordinates, candidate, parameters);
              if (calculated != null) {
                raw = calculated.shift(Duration(days: -offset));
                usedDate = DateComponents.from(candidate);
                resolution = PolarCircleResolution.aqrabYaum;
                break search;
              }
            }
          }
          break;
        case PolarCircleResolution.unresolved:
          break;
      }
    }

    if (raw == null) {
      throw const PrayerTimeCalculationException(
          CalculationFailure.unavailable, 'No complete astronomical schedule');
    }
    // Invalid user adjustments must not trigger a change of date or location.
    final result = raw.adjust(parameters);
    if (!_ordered(result.ordered, minimumGap: Duration.zero)) {
      throw const PrayerTimeCalculationException(
          CalculationFailure.invalidAdjustments,
          'Adjusted prayer times must be strictly increasing');
    }
    return PrayerTimes._(coordinates, date, parameters, usedCoordinates,
        usedDate, resolution, result);
  }

  /// Equivalent to the default UTC-only constructor.
  factory PrayerTimes.utc(Coordinates coordinates, DateComponents date,
      CalculationParameters parameters) => PrayerTimes(coordinates, date, parameters);

  /// Convenience constructor using explicitly supplied target-local date fields.
  factory PrayerTimes.today(Coordinates coordinates, CalculationParameters parameters,
      {required DateTime localNow}) =>
      PrayerTimes(coordinates, DateComponents.from(localNow), parameters);

  /// Returns null only on a calculation failure. Invalid input remains an error.
  static PrayerTimes? tryCalculate(Coordinates coordinates, DateComponents date,
      CalculationParameters parameters) {
    try {
      return PrayerTimes(coordinates, date, parameters);
    } on PrayerTimeCalculationException {
      return null;
    }
  }

  static const _prayers = [Prayer.fajr, Prayer.sunrise, Prayer.dhuhr,
    Prayer.asr, Prayer.maghrib, Prayer.isha];

  /// Latest elapsed event in this civil day's schedule, or none before Fajr.
  Prayer currentPrayer([DateTime? now]) {
    final instant = now ?? DateTime.now();
    for (final prayer in _prayers.reversed) {
      if (!instant.isBefore(timeForPrayer(prayer)!)) return prayer;
    }
    return Prayer.none;
  }

  /// Next event in this civil day's schedule, or none after Isha.
  Prayer nextPrayer([DateTime? now]) {
    final instant = now ?? DateTime.now();
    for (final prayer in _prayers) {
      if (instant.isBefore(timeForPrayer(prayer)!)) return prayer;
    }
    return Prayer.none;
  }

  Prayer currentPrayerByDateTime(DateTime time) => currentPrayer(time);
  Prayer nextPrayerByDateTime(DateTime time) => nextPrayer(time);

  DateTime? timeForPrayer(Prayer prayer) => switch (prayer) {
    Prayer.none => null,
    Prayer.fajr => fajr,
    Prayer.sunrise => sunrise,
    Prayer.dhuhr => dhuhr,
    Prayer.asr => asr,
    Prayer.maghrib => maghrib,
    Prayer.isha => isha,
  };

  static int daysSinceSolstice(int dayOfYear, int year, double latitude) {
    final leap = CalendarUtil.isLeapYear(year);
    final days = leap ? 366 : 365;
    return (dayOfYear + (latitude >= 0 ? 10 : -(leap ? 173 : 172))) % days;
  }
}

bool _ordered(List<DateTime> times,
    {Duration minimumGap = const Duration(minutes: 5)}) {
  for (var i = 1; i < times.length; i++) {
    final gap = times[i].difference(times[i - 1]);
    if (gap <= Duration.zero || gap < minimumGap) return false;
  }
  return true;
}

final class _DayTimes {
  final DateTime fajr, sunrise, dhuhr, asr, sunset, maghrib, isha;
  final PrayerTimeSource fajrSource, ishaSource;
  const _DayTimes(this.fajr, this.sunrise, this.dhuhr, this.asr,
      this.sunset, this.maghrib, this.isha, this.fajrSource, this.ishaSource);

  List<DateTime> get ordered => [fajr, sunrise, dhuhr, asr, maghrib, isha];

  _DayTimes shift(Duration offset) => _DayTimes(
      fajr.add(offset), sunrise.add(offset), dhuhr.add(offset), asr.add(offset),
      sunset.add(offset), maghrib.add(offset), isha.add(offset),
      fajrSource, ishaSource);

  _DayTimes adjust(CalculationParameters p) {
    final a = p.adjustments;
    final m = p.methodAdjustments;
    DateTime apply(DateTime time, int offset) =>
        CalendarUtil.roundedMinute(time.add(Duration(minutes: offset)), p.rounding);
    return _DayTimes(
        apply(fajr, a.fajr + m.fajr),
        apply(sunrise, a.sunrise + m.sunrise),
        apply(dhuhr, a.dhuhr + m.dhuhr),
        apply(asr, a.asr + m.asr),
        apply(sunset, 0),
        apply(maghrib, a.maghrib + m.maghrib),
        apply(isha, a.isha + m.isha),
        fajrSource, ishaSource);
  }
}

DateTime? _at(DateTime date, double hours) =>
    TimeComponents.fromDouble(hours)?.dateComponents(date);

DateTime _addSeconds(DateTime time, double seconds) =>
    time.add(Duration(milliseconds: (seconds * 1000).truncate()));

_DayTimes? _computeDay(Coordinates coordinates, DateTime date,
    CalculationParameters p) {
  final sunriseElevation = math.max(0.0, p.elevationFromHorizon.sunrise);
  final sunsetElevation = math.max(0.0, p.elevationFromHorizon.sunset);
  final tomorrow = date.add(const Duration(days: 1));
  final solar = SolarTime(date, coordinates, sunriseElevation: sunriseElevation,
      sunsetElevation: sunsetElevation);
  final nextSolar = SolarTime(tomorrow, coordinates, sunriseElevation: sunriseElevation,
      sunsetElevation: sunsetElevation);

  final sunrise = _at(date, solar.sunrise);
  final sunset = _at(date, solar.sunset);
  final dhuhr = _at(date, solar.transit);
  final asr = _at(date, solar.afternoon(p.madhab.getShadowLength()));
  final nextSunrise = _at(tomorrow, nextSolar.sunrise);
  if (sunrise == null || sunset == null || dhuhr == null ||
      asr == null || nextSunrise == null) return null;

  final night = nextSunrise.difference(sunset).inMilliseconds / 1000;
  if (night <= 0 || night >= 86400) return null;
  final portions = p.nightPortions(coordinates);
  final moonsighting = p.method == CalculationMethod.moon_sighting_committee;
  // Retain the upstream convention for the northern >=55° special case.
  final special = moonsighting && coordinates.latitude >= 55;
  final dayOfYear = date.difference(DateTime.utc(date.year)).inDays + 1;
  final dyy = PrayerTimes.daysSinceSolstice(dayOfYear, date.year, coordinates.latitude);
  final safeSource = moonsighting
      ? PrayerTimeSource.seasonalTwilight : PrayerTimeSource.nightPortion;

  var fajr = _at(date, solar.hourAngle(-p.fajrAngle, false));
  var fajrSource = PrayerTimeSource.astronomical;
  if (special) {
    fajr = _addSeconds(sunrise, -night / 7);
    fajrSource = PrayerTimeSource.nightPortion;
  }
  final safeFajr = moonsighting
      ? sunrise.subtract(Duration(seconds: (_seasonalMinutes(
          coordinates.latitude, dyy, morning: true, shafaq: p.shafaq) * 60).round()))
      : _addSeconds(sunrise, -portions.fajr * night);
  if (fajr == null || fajr.isBefore(safeFajr) || !_ordered([fajr, sunrise])) {
    fajr = safeFajr;
    fajrSource = safeSource;
  }

  DateTime? isha;
  var ishaSource = PrayerTimeSource.astronomical;
  if (p.ishaInterval > 0) {
    // Same fixed-interval convention as the reference: raw sunset, not offsets.
    isha = sunset.add(Duration(minutes: p.ishaInterval));
    ishaSource = PrayerTimeSource.fixedInterval;
  } else {
    isha = _at(date, solar.hourAngle(-p.ishaAngle, true));
    if (special) {
      isha = _addSeconds(sunset, night / 7);
      ishaSource = PrayerTimeSource.nightPortion;
    }
    final safeIsha = moonsighting
        ? sunset.add(Duration(seconds: (_seasonalMinutes(
            coordinates.latitude, dyy, morning: false, shafaq: p.shafaq) * 60).round()))
        : _addSeconds(sunset, portions.isha * night);
    if (isha == null || isha.isAfter(safeIsha) || !_ordered([sunset, isha])) {
      isha = safeIsha;
      ishaSource = safeSource;
    }
  }

  var maghrib = sunset;
  if (p.maghribAngle > 0) {
    final angleTime = _at(date, solar.hourAngle(-p.maghribAngle, true));
    if (angleTime != null && angleTime.isAfter(sunset) && angleTime.isBefore(isha)) {
      maghrib = angleTime;
    }
  }

  final result = _DayTimes(fajr, sunrise, dhuhr, asr, sunset, maghrib, isha,
      fajrSource, ishaSource);
  return _ordered(result.ordered) ? result : null;
}

/// Moonsighting Committee seasonal coefficients (Adhan JS / Swift).
double _seasonalMinutes(double latitude, int day,
    {required bool morning, required Shafaq shafaq}) {
  final x = latitude.abs() / 55;
  final (a, b, c, d) = morning
      ? (75 + 28.65 * x, 75 + 19.44 * x, 75 + 32.74 * x, 75 + 48.10 * x)
      : switch (shafaq) {
          Shafaq.general => (75 + 25.60 * x, 75 + 2.05 * x,
              75 - 9.21 * x, 75 + 6.14 * x),
          Shafaq.ahmer => (62 + 17.40 * x, 62 - 7.16 * x,
              62 + 5.12 * x, 62 + 19.44 * x),
          Shafaq.abyad => (75 + 25.60 * x, 75 + 7.16 * x,
              75 + 36.84 * x, 75 + 81.84 * x),
        };
  if (day < 91) return a + (b - a) / 91 * day;
  if (day < 137) return b + (c - b) / 46 * (day - 91);
  if (day < 183) return c + (d - c) / 46 * (day - 137);
  if (day < 229) return d + (c - d) / 46 * (day - 183);
  if (day < 275) return c + (b - c) / 46 * (day - 229);
  return b + (a - b) / 91 * (day - 275);
}
