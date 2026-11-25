import 'package:adhan/adhan.dart';
import 'package:test/test.dart';

void main() {
  test('Qibla reference bearings (true north)', () {
    expect(Qibla(Coordinates(38.9072, -77.0369)).direction, closeTo(56.560, 0.001));
    expect(Qibla(Coordinates(40.7128, -74.0059)).direction, closeTo(58.481, 0.001));
    expect(Qibla(Coordinates(37.7749, -122.4194)).direction, closeTo(18.843, 0.001));
    expect(Qibla(Coordinates(61.2181, -149.9003)).direction, closeTo(350.883, 0.001));
  });
}
