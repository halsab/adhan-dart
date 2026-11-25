import 'coordinates.dart';

/// Approximations for Fajr and Isha at high latitudes.
enum HighLatitudeRule {
  middle_of_the_night,
  seventh_of_the_night,
  twilight_angle,
  /// Choose the recommended rule using the calculation latitude.
  automatic;

  static HighLatitudeRule recommendedFor(Coordinates coordinates) =>
      coordinates.latitude.abs() > 48
          ? seventh_of_the_night
          : middle_of_the_night;
}
