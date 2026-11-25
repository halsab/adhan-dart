import 'dart:math';

import '../coordinates.dart';
import 'astronomical.dart';
import 'calendrical_helper.dart';
import 'math.dart';
import 'shadow_length.dart';
import 'solar_coordinates.dart';

/// Solar events in fractional UTC hours, relative to the requested date.
/// Nonexistent events are represented internally by NaN.
class SolarTime {
  final Coordinates _observer;
  late final SolarCoordinates _solar, _prevSolar, _nextSolar;
  late final double _approximateTransit;
  late final double transit, sunrise, sunset;

  SolarTime(DateTime date, this._observer,
      {double sunriseElevation = 0, double sunsetElevation = 0}) {
    final jd = CalendricalHelper.julianDay(date.year, date.month, date.day);
    _prevSolar = SolarCoordinates(jd - 1);
    _solar = SolarCoordinates(jd);
    _nextSolar = SolarCoordinates(jd + 1);
    _approximateTransit = Astronomical.approximateTransit(
        _observer.longitude, _solar.apparentSiderealTime, _solar.rightAscension);
    transit = Astronomical.correctedTransit(
        _approximateTransit, _observer.longitude, _solar.apparentSiderealTime,
        _solar.rightAscension, _prevSolar.rightAscension, _nextSolar.rightAscension);
    const altitude = -50 / 60;
    sunrise = hourAngle(altitude - 0.035333 * sqrt(sunriseElevation), false);
    sunset = hourAngle(altitude - 0.035333 * sqrt(sunsetElevation), true);
  }

  double hourAngle(double angle, bool afterTransit) =>
      Astronomical.correctedHourAngle(
          _approximateTransit, angle, _observer, afterTransit,
          _solar.apparentSiderealTime, _solar.rightAscension,
          _prevSolar.rightAscension, _nextSolar.rightAscension,
          _solar.declination, _prevSolar.declination, _nextSolar.declination);

  double afternoon(ShadowLength shadowLength) {
    // Noon shadow uses declination interpolated to solar transit, not 0h UT.
    final noonDeclination = Astronomical.interpolate(_solar.declination,
        _prevSolar.declination, _nextSolar.declination, transit / 24);
    final tangent = (_observer.latitude - noonDeclination).abs();
    final inverse = shadowLength.getShadowLength() + tan(radians(tangent));
    final angle = degrees(atan(1 / inverse));
    const solarAngularDiameter = 32 / 60;
    if (angle <= solarAngularDiameter / 2) return double.nan;
    final maxAltitude = Astronomical.altitudeOfCelestialBody(
        _observer.latitude, noonDeclination, 0);
    if (maxAltitude < angle) return double.nan;
    final result = hourAngle(angle, true);
    return result > transit ? result : double.nan;
  }
}
