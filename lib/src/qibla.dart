import 'coordinates.dart';
import 'internal/qibla_util.dart';

/// Great-circle initial bearing clockwise from true north, in degrees.
final class Qibla {
  static final Coordinates MAKKAH = Coordinates(21.4225241, 39.8261818);
  final double direction;

  Qibla(Coordinates coordinates)
      : direction = QiblaUtil.calculateQiblaDirection(coordinates);
}
