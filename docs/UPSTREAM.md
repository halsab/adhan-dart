# Upstream sources and verification contract

Status: implementation draft, not a validated release.

## Pinned reference revisions

| Repository | Commit | Role |
| --- | --- | --- |
| [adhan-dart](https://github.com/iamriajul/adhan-dart/tree/c4b6f0fd6d438963a0fff79fa9ac148224fef57c) | c4b6f0fd6d438963a0fff79fa9ac148224fef57c | Fork base and existing Meeus/Qibla implementation |
| [adhan-js](https://github.com/batoulapps/adhan-js/tree/d2993d56fac7d8a06abba4837347bd3fc9cbd188) | d2993d56fac7d8a06abba4837347bd3fc9cbd188 | Primary functional and numerical reference |
| [adhan-swift](https://github.com/batoulapps/adhan-swift/tree/96998baa08d697cbc7b471ebad3749f689550b74) | 96998baa08d697cbc7b471ebad3749f689550b74 | Typed models, calendar isolation, bounded polar search, corroborating algorithms |
| [adhan-kotlin](https://github.com/batoulapps/adhan-kotlin/tree/a39517d0aafb95addef28956d96e5823b3aea1cc) | a39517d0aafb95addef28956d96e5823b3aea1cc | Immutable parameters and opt-in automatic high-latitude policy |
| [salah](https://github.com/insha/salah/tree/adc8f592c434cdca9dedfeb9bf976f4745132473) | adc8f592c434cdca9dedfeb9bf976f4745132473 | Timeline convenience and settings serialization inspiration; not an accuracy reference |

All sources are MIT. Salah's GitHub version is the reviewed revision; its
new Codeberg repository has not been checked.

## Port map

- JS PR [#243](https://github.com/batoulapps/adhan-js/pull/243) / Swift
  [#109](https://github.com/batoulapps/adhan-swift/pull/109): corrected Asr
  noon declination and bracketed Newton/bisection solar-angle convergence.
- JS PR [#240](https://github.com/batoulapps/adhan-js/pull/240) / Swift
  [#108](https://github.com/batoulapps/adhan-swift/pull/108): independent
  horizon elevation corrections. Formula: Odeh, Calculating Prayer Times,
  section 4, equation 8; horizon angle adjustment 0.035333 * sqrt(height).
- JS/Swift polar fallback strategies; explicit failure, bounded searches,
  metadata for substituted geometry.
- Current JS/Swift Shafaq variants, preset offsets, maghrib angle, separate
  sunset, minute rounding and seasonal twilight coefficients.
- Kotlin immutable parameters and opt-in automatic high-latitude rule;
  absolute latitude is used for both hemispheres (as in JS/Swift recommendation).
- Salah's extended timeline idea, without treating Qiyam as an obligatory
  prayer or replacing missing Asr with transit.
- No platform-specific code, external runtime dependencies or Flutter SDK
  dependency.

## Deliberate behavioral decisions

1. Use UTC DateTime instants and a separately validated civil date. Never shift
   a UTC instant to fake another timezone. The host app owns timezone mapping.
2. Keep JS default high-latitude rule and northern Moonsighting Committee
   >=55° special case. Automatic symmetric selection is opt-in. A broader
   change to the Moonsighting Committee rule requires methodological evidence.
3. Treat +180 and -180 as signed solar-day boundaries; do not wrap the
   expected transit at -180 from 24h to 0h. Civil timezone mapping still belongs
   to the host. This exact meridian differs from the pinned JS reference.
4. Report substitutions explicitly and reject inverted final adjusted times,
   rather than falling back to another date/location for a bad adjustment.
5. Reject invalid night intervals, including next Fajr not after today's Isha.
6. Reject nonfinite/out-of-range coordinates and invalid Gregorian dates.
   Limit individual offsets to one day to avoid unbounded arithmetic.
7. API compatibility is not required for v3. Keep familiar preset names and
   package import, but prefer immutable data, typed failures and explicit date.

## Verification gates

- Static analyzer and all unit tests on stable Dart.
- Published prayer-time fixtures copied from pinned JS Shared/Times; use
  their original variance and source metadata. Older Dart fixtures generated
  by v1 are retained as historical material and intentionally not used as
  ground truth. Updated fixtures must not be altered solely to make the port pass.
- Astronomical worked examples and two DE440 near-culmination reference cases
  transcribed from the upstream tests; these are independent numerical
  reference values, not a newly executed ephemeris benchmark.
- Global stress sweep: 37 latitudes * 37 longitudes * 365 days = 499,685.
  Require valid schedules outside the polar circle on this sampling grid,
  and strictly increasing returned events everywhere.
- JS differential check: 15 locations * 7 dates * 13 methods * 2 madhabs *
  3 policy variants = 8,190 scenarios. Check validity, UTC instants, Qibla
  and valid night milestones; use at most 1 second difference for unrounded
  results and exact rounded values. Exact signed antimeridian endpoints have
  their own regression test. Do not expand tolerances to hide unexplained
  discrepancies.
- Run targeted unit tests in three host timezones, and on Chrome using
  dart2js and dart2wasm. Compile native executable, JS and Wasm examples.
- Direct Swift comparison: run the pinned Swift implementation on all 6,552
  unrounded combinations (14 locations, 6 dates, 13 methods, 2 madhabs,
  3 policy variants). Check valid/invalid schedules, night milestones and
  Qibla; use a one-second limit on absolute instants.
- Direct Kotlin comparison: restrict the same input matrix to the 1,296
  common-feature scenarios at |latitude| <=40°, no polar substitution,
  no elevation and no Tehran. The old solver and 0h-UT Asr declination
  differ by design; limit differences to 90 seconds for Asr and 20 seconds
  for other events and night milestones. These bounds reflect the older
  model's known numerical limitations, not a relaxation of JS/Swift parity.
- Independent JPL DE440s benchmark: 86 solar days, eight raw solar events
  each, both Asr shadow ratios, polar unreachable events and two
  near-culmination cases. Use Skyfield's apparent geocentric solar
  coordinates, matching the geometric conventions, and independent bisection.
  Limits: 10 seconds for |latitude| <55°, 30 seconds above; report actual
  maximum and RMS per event and fail on unexplained reachability differences.
- Before stable release, inspect all CI results and perform a follow-up audit.
  Record observed results and verify the native, JS and Wasm execution paths.
  Performance benchmarking is informative; it does not substitute for
  correctness checks.
- Stable release and VaqtPro integration are blocked until required
  verification is observed to pass. CI definitions and test code alone are
  not evidence of successful execution.
