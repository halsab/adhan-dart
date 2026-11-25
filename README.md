# Adhan Dart

An offline prayer-time calculation library for Dart and Flutter. This fork is a
pure Dart port of the current Adhan algorithms, with no runtime package
dependencies, native bindings, network access, or device timezone dependency.

**Development version.** The 3.0.0-dev.1 branch is not a production release.
Passing CI, differential tests and review are required before tagging a stable
release. See [upstream and verification notes](docs/UPSTREAM.md).

## Usage

Requires Dart 3.10 or later. Add this repository as a Git dependency, pinning an
approved commit or release tag. Package imports remain `package:adhan/adhan.dart`.

```dart
import 'package:adhan/adhan.dart';

final coordinates = Coordinates(52.2297, 21.0122);
final date = DateComponents(2026, 6, 21); // civil date at target location
final parameters = CalculationMethod.muslim_world_league.getParameters()
    .copyWith(
      madhab: Madhab.hanafi,
      highLatitudeRule: HighLatitudeRule.automatic,
    );

final times = PrayerTimes(coordinates, date, parameters);
print(times.fajr.toIso8601String()); // absolute UTC instant
print(times.asr);
print(times.isApproximate);
print(Qibla(coordinates).direction); // true-north bearing

final night = SunnahTimes.tryCalculate(times);
final schedule = PrayerSchedule(times);
```

For ordinary locations use `DateComponents.from(targetLocalDateTime)` or explicit year/month/day.
For global calendar correctness, map the instant of civil noon in the target IANA
zone using `DateComponents.fromLocalNoon(localNoon, coordinates)`. This handles
political timezones across the International Date Line, including Samoa and
Kiritimati. Keep the requested civil date separately as the UI label.
**Never add a UTC offset to a prayer time and then treat it as an absolute
instant.** A device's local timezone can differ from the target location.
An app can use an IANA timezone database (for example, the Dart timezone
package) to obtain the civil date and format the UTC results. This library
intentionally does not contain timezone lookup or DST rules.

## Calculation options

| Setting | Behavior |
| --- | --- |
| `CalculationMethod` | MWL, Egyptian, Karachi, Umm al-Qura, Dubai, Moonsighting Committee, North America, Kuwait, Qatar, Singapore, Turkey (approximation), Tehran, Other/custom |
| `Madhab` | Shafi (single shadow) or Hanafi (double shadow) for Asr |
| `HighLatitudeRule` | Middle of night, seventh of night, twilight angle, or automatic (absolute latitude >48° selects seventh) |
| `PolarCircleResolution` | Aqrab Balad (default), Aqrab Yaum, or unresolved |
| `Shafaq` | General, Ahmer or Abyad for Moonsighting Committee |
| `Rounding` | Nearest minute, up to the next minute, none; Singapore defaults to up |
| `ElevationFromHorizon` | Height above the visible astronomical horizon in meters, separate east/west values supported |
| `PrayerAdjustments` | Independent signed minute adjustments, applied once after raw calculation |
| `maghribAngle` | Optional twilight angle; Tehran preset uses 4.5° |
| `ishaInterval` | Fixed interval after raw sunset; takes precedence over the Isha angle |

The default high-latitude rule matches Adhan JS (middle of night); automatic
selection is opt-in. The northern >=55° Moonsighting Committee special case
retains upstream behavior. These conventions are not a determination of the
religiously correct rule for every location. The caller selects suitable
parameters, and may apply local authority guidance. Ramadan adjustments (e.g.
the additional 30 minutes for Umm al-Qura Isha) must be configured explicitly.

Horizon elevation is **not GPS altitude above sea level**. Only provide
known height above the relevant horizon. For a city on a plateau the usual
value is zero. Negative values are treated as zero.

## Results and failures

- `PrayerTimes` contains Fajr, sunrise, Dhuhr, Asr, physical sunset, Maghrib,
  and Isha as UTC DateTime values.
- `fajrSource`, `ishaSource`, `maghribSource`, `calculationCoordinates`,
  `calculationDate`, and `appliedPolarResolution` describe calculation
  substitutions. `isApproximate` flags twilight/angle and polar substitutions.
- Aqrab Balad searches in half-degree steps toward the equator at the original
  longitude. Aqrab Yaum searches forward/backward by day, preferring forward on
  ties, up to 183 days each way, and relabels the result to the requested date.
- If the result cannot be computed, the constructor throws
  `PrayerTimeCalculationException` with a reason. `tryCalculate` returns null
  on calculation failures. Invalid inputs throw `ArgumentError`.
- Raw prayer events must be at least five minutes apart, matching upstream
  geometry checks. Final adjusted prayer events must be strictly increasing.
  Invalid adjustments never trigger polar substitution.
- Coordinates must be finite and in [-90,90] and [-180,180]; Gregorian dates
  must be valid with years 1–9999. This range is input validation, not a claim
  of ephemeris accuracy throughout that period.
- Angles must be finite and 0–90°, fixed interval 0–1439 minutes, per-event
  offsets -1440–1440 minutes per adjustment set.
- Night milestones are the midpoint and beginning of the last third of the
  Maghrib-to-next-Fajr interval. They can be unavailable independently of the
  day. Invalid or overlapping next-day intervals fail explicitly.
- `PrayerSchedule` adds sorted auxiliary events without treating them as
  obligatory prayers. `currentPrayer`/ `nextPrayer` on PrayerTimes are
  daily event helpers, not a ruling about prayer validity windows. Sunrise
  is a boundary/event, not a prayer. Schedule currentPrayer covers the
  requested schedule through its next-Fajr boundary only.
- `Qibla` is a great-circle initial bearing relative to true north, not a
  magnetic compass correction. At the Kaaba itself and its antipode no
  unique initial bearing exists; callers must handle that degenerate case.

## Persist settings

`parameters.toJson()` produces schema version 1. Restore using
`CalculationParametersSerialization.fromJson(map)`. All fields are explicit,
including preset and manual adjustments. Malformed or unsupported settings are
rejected rather than silently substituted.

## Migration from v2

This is a breaking release. Parameter and adjustment fields are immutable; use
`copyWith`. Dates and coordinates validate eagerly. Output is always UTC.
The old `utcOffset` option/factory was removed; `PrayerTimes.today` requires
explicit target-local date fields. The deprecated Flutter demo was replaced
with a standalone Dart example. Old generated-v1 timing files are retained as
historical artifacts, not accuracy oracles for changed algorithms.

## Verification

```sh
dart pub get
dart analyze
dart test
dart test -p chrome --compiler dart2js test/src
dart test -p chrome --compiler dart2wasm test/src
```

The GitHub Actions workflow additionally generates reference schedules from
the pinned Adhan JS commit and compares them with Dart, executes direct Swift
and Kotlin differential checks, and benchmarks raw solar geometry against JPL
DE440s. None of those tools or datasets is a runtime dependency.

## License

MIT. Copyright notices for the original Dart library and Batoul Apps are
preserved in [LICENSE](LICENSE). See [upstream notes](docs/UPSTREAM.md).
