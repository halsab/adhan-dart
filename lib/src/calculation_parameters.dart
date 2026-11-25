import 'calculation_method.dart';
import 'calculation_options.dart';
import 'coordinates.dart';
import 'high_latitude_rule.dart';
import 'madhab.dart';
import 'prayer_adjustments.dart';

/// Immutable calculation configuration. All angles are positive degrees below
/// the horizon; offsets and fixed intervals are minutes.
final class CalculationParameters {
  final CalculationMethod method;
  final double fajrAngle, ishaAngle, maghribAngle;
  final int ishaInterval;
  final Madhab madhab;
  final HighLatitudeRule highLatitudeRule;
  final PrayerAdjustments adjustments, methodAdjustments;
  final Rounding rounding;
  final Shafaq shafaq;
  final PolarCircleResolution polarCircleResolution;
  final ElevationFromHorizon elevationFromHorizon;

  CalculationParameters({
    this.method = CalculationMethod.other,
    this.fajrAngle = 0,
    this.ishaAngle = 0,
    this.maghribAngle = 0,
    this.ishaInterval = 0,
    this.madhab = Madhab.shafi,
    this.highLatitudeRule = HighLatitudeRule.middle_of_the_night,
    this.adjustments = const PrayerAdjustments(),
    this.methodAdjustments = const PrayerAdjustments(),
    this.rounding = Rounding.nearest,
    this.shafaq = Shafaq.general,
    this.polarCircleResolution = PolarCircleResolution.aqrabBalad,
    this.elevationFromHorizon = const ElevationFromHorizon(),
  }) {
    for (final angle in [fajrAngle, ishaAngle, maghribAngle]) {
      if (!angle.isFinite || angle < 0 || angle > 90) {
        throw ArgumentError.value(angle, 'angle', 'Expected 0..90 degrees');
      }
    }
    if (ishaInterval < 0 || ishaInterval >= 1440) {
      throw ArgumentError.value(ishaInterval, 'ishaInterval', 'Expected 0..1439 minutes');
    }
    if (!elevationFromHorizon.sunrise.isFinite ||
        !elevationFromHorizon.sunset.isFinite) {
      throw ArgumentError('Horizon elevation must be finite');
    }
  }

  CalculationParameters copyWith({
    CalculationMethod? method,
    double? fajrAngle, double? ishaAngle, double? maghribAngle,
    int? ishaInterval,
    Madhab? madhab,
    HighLatitudeRule? highLatitudeRule,
    PrayerAdjustments? adjustments, PrayerAdjustments? methodAdjustments,
    Rounding? rounding,
    Shafaq? shafaq,
    PolarCircleResolution? polarCircleResolution,
    ElevationFromHorizon? elevationFromHorizon,
  }) => CalculationParameters(
    method: method ?? this.method,
    fajrAngle: fajrAngle ?? this.fajrAngle,
    ishaAngle: ishaAngle ?? this.ishaAngle,
    maghribAngle: maghribAngle ?? this.maghribAngle,
    ishaInterval: ishaInterval ?? this.ishaInterval,
    madhab: madhab ?? this.madhab,
    highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
    adjustments: adjustments ?? this.adjustments,
    methodAdjustments: methodAdjustments ?? this.methodAdjustments,
    rounding: rounding ?? this.rounding,
    shafaq: shafaq ?? this.shafaq,
    polarCircleResolution: polarCircleResolution ?? this.polarCircleResolution,
    elevationFromHorizon: elevationFromHorizon ?? this.elevationFromHorizon,
  );

  CalculationParameters withMethodAdjustments(PrayerAdjustments adjustments) =>
      copyWith(methodAdjustments: adjustments);

  ({double fajr, double isha}) nightPortions([Coordinates? coordinates]) {
    final rule = highLatitudeRule == HighLatitudeRule.automatic
        ? HighLatitudeRule.recommendedFor(
            coordinates ?? (throw ArgumentError('Coordinates required for automatic rule')))
        : highLatitudeRule;
    return switch (rule) {
      HighLatitudeRule.middle_of_the_night => (fajr: 0.5, isha: 0.5),
      HighLatitudeRule.seventh_of_the_night => (fajr: 1 / 7, isha: 1 / 7),
      HighLatitudeRule.twilight_angle => (fajr: fajrAngle / 60, isha: ishaAngle / 60),
      HighLatitudeRule.automatic => throw StateError('Unresolved automatic rule'),
    };
  }
}
