import 'calculation_method.dart';
import 'calculation_options.dart';
import 'calculation_parameters.dart';
import 'high_latitude_rule.dart';
import 'madhab.dart';
import 'prayer_adjustments.dart';

/// Versioned persistence of calculation settings. Does not serialize dates,
/// local timezones, or computed times as if they were configuration.
extension CalculationParametersSerialization on CalculationParameters {
  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'method': method.name,
    'fajrAngle': fajrAngle,
    'ishaAngle': ishaAngle,
    'maghribAngle': maghribAngle,
    'ishaInterval': ishaInterval,
    'madhab': madhab.name,
    'highLatitudeRule': highLatitudeRule.name,
    'adjustments': _encodeOffsets(adjustments),
    'methodAdjustments': _encodeOffsets(methodAdjustments),
    'rounding': rounding.name,
    'shafaq': shafaq.name,
    'polarCircleResolution': polarCircleResolution.name,
    'elevationFromHorizon': {
      'sunrise': elevationFromHorizon.sunrise,
      'sunset': elevationFromHorizon.sunset,
    },
  };

  static CalculationParameters fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported calculation parameter schema');
    }
    final elevation = _object(json, 'elevationFromHorizon');
    return CalculationParameters(
      method: CalculationMethod.values.byName(_string(json, 'method')),
      fajrAngle: _number(json, 'fajrAngle'),
      ishaAngle: _number(json, 'ishaAngle'),
      maghribAngle: _number(json, 'maghribAngle'),
      ishaInterval: _integer(json, 'ishaInterval'),
      madhab: Madhab.values.byName(_string(json, 'madhab')),
      highLatitudeRule: HighLatitudeRule.values.byName(_string(json, 'highLatitudeRule')),
      adjustments: _decodeOffsets(_object(json, 'adjustments')),
      methodAdjustments: _decodeOffsets(_object(json, 'methodAdjustments')),
      rounding: Rounding.values.byName(_string(json, 'rounding')),
      shafaq: Shafaq.values.byName(_string(json, 'shafaq')),
      polarCircleResolution: PolarCircleResolution.values.byName(
          _string(json, 'polarCircleResolution')),
      elevationFromHorizon: ElevationFromHorizon.separate(
          sunrise: _number(elevation, 'sunrise'), sunset: _number(elevation, 'sunset')),
    );
  }
}

Map<String, int> _encodeOffsets(PrayerAdjustments p) => {
  'fajr': p.fajr, 'sunrise': p.sunrise, 'dhuhr': p.dhuhr,
  'asr': p.asr, 'maghrib': p.maghrib, 'isha': p.isha,
};

PrayerAdjustments _decodeOffsets(Map<String, Object?> json) => PrayerAdjustments(
    fajr: _integer(json, 'fajr'), sunrise: _integer(json, 'sunrise'),
    dhuhr: _integer(json, 'dhuhr'), asr: _integer(json, 'asr'),
    maghrib: _integer(json, 'maghrib'), isha: _integer(json, 'isha'));

Map<String, Object?> _object(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is Map<String, Object?>) return value;
  throw FormatException('Expected object: $key');
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected string: $key');
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected integer: $key');
}

double _number(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('Expected finite number: $key');
}
