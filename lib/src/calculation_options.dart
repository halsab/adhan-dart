/// Minute rounding applied only after calculation and adjustments.
enum Rounding { nearest, up, none }

/// Twilight convention for the Moonsighting Committee method.
enum Shafaq { general, ahmer, abyad }

/// Strategy for days where a complete astronomical schedule cannot be found.
enum PolarCircleResolution { aqrabBalad, aqrabYaum, unresolved }

/// Height in meters above the eastern and western horizons, NOT sea level.
/// Negative heights are treated as zero. Nonfinite values are invalid.
final class ElevationFromHorizon {
  final double sunrise;
  final double sunset;

  const ElevationFromHorizon([double meters = 0])
      : sunrise = meters, sunset = meters;

  const ElevationFromHorizon.separate({required this.sunrise, required this.sunset});
}

/// Origin of a prayer time before user adjustments and rounding.
enum PrayerTimeSource {
  astronomical,
  nightPortion,
  seasonalTwilight,
  fixedInterval,
  sunsetFallback,
}

/// A calculation failure, distinct from invalid caller input.
enum CalculationFailure { unavailable, invalidAdjustments, invalidNight }

final class PrayerTimeCalculationException implements Exception {
  final CalculationFailure reason;
  final String message;
  const PrayerTimeCalculationException(this.reason, this.message);

  @override
  String toString() => 'PrayerTimeCalculationException($reason): $message';
}
