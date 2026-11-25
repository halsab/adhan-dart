/// Validated geographic coordinates in degrees.
final class Coordinates {
  final double latitude;
  final double longitude;

  Coordinates(this.latitude, this.longitude) {
    if (!latitude.isFinite || latitude.abs() > 90) {
      throw ArgumentError.value(latitude, 'latitude', 'Expected -90..90');
    }
    if (!longitude.isFinite || longitude.abs() > 180) {
      throw ArgumentError.value(longitude, 'longitude', 'Expected -180..180');
    }
  }

  @override
  bool operator ==(Object other) => other is Coordinates &&
      latitude == other.latitude && longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
