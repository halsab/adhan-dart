"""Independently calculate solar geometry from JPL DE440s using Skyfield.

No Adhan formula for solar coordinates or event iteration is reused.
Use apparent *geocentric* RA/declination of the Sun and apparent Greenwich
sidereal time. This matches the model's convention of no extra topocentric
solar parallax or atmospheric refraction (the rise/set target already includes
standard refraction and solar radius). Both Asr shadow ratios use declination
at meridian transit. The independent root solver is bisection in UTC hours.
"""
import json
import math
import sys
from collections import defaultdict

from skyfield.api import load


def wrap(angle):
    return (angle + 180) % 360 - 180


def bisect(fn, low, high):
    a, b = fn(low), fn(high)
    if a == 0:
        return low
    if b == 0:
        return high
    if a * b > 0:
        return None
    # 36 iterations: far below the accuracy of either solar model.
    for _ in range(36):
        mid = (low + high) / 2
        c = fn(mid)
        if a * c <= 0:
            high, b = mid, c
        else:
            low, a = mid, c
    return (low + high) / 2


rows = json.load(open(sys.argv[1], encoding="utf-8"))
ts = load.timescale(builtin=True)
# Skyfield downloads the named JPL ephemeris from JPL's official server.
eph = load("de440s.bsp")
earth, sun = eph["earth"], eph["sun"]
errors = defaultdict(list)
failures = []
unreachable = 0

for row in rows:
    lat, lon = row["latitude"], row["longitude"]
    phi = math.radians(lat)
    year, month, day = row["year"], row["month"], row["day"]
    label = f"{year}-{month:02d}-{day:02d} ({lat}, {lon})"

    def solar_state(hours):
        time = ts.utc(year, month, day, 0, 0, hours * 3600)
        ra, dec, _ = earth.at(time).observe(sun).apparent().radec(epoch="date")
        hour_angle = wrap(time.gast * 15 + lon - ra.hours * 15)
        return hour_angle, dec.degrees

    def altitude(hours):
        hour_angle, dec = solar_state(hours)
        h, delta = math.radians(hour_angle), math.radians(dec)
        return math.degrees(math.asin(max(-1, min(1,
            math.sin(phi) * math.sin(delta)
            + math.cos(phi) * math.cos(delta) * math.cos(h)))))

    mean_noon = 12 - lon / 15
    transit = bisect(lambda h: solar_state(h)[0], mean_noon - 1, mean_noon + 1)
    if transit is None:
        raise RuntimeError(f"{label}: failed to bracket independent transit")
    previous_lower = bisect(lambda h: wrap(solar_state(h)[0] - 180),
                            transit - 13, transit - 11)
    next_lower = bisect(lambda h: wrap(solar_state(h)[0] - 180),
                        transit + 11, transit + 13)
    if previous_lower is None or next_lower is None:
        raise RuntimeError(f"{label}: failed to bracket lower culmination")

    def angle_time(angle, evening):
        lower = next_lower if evening else previous_lower
        if not altitude(transit) > angle > altitude(lower):
            return None
        return bisect(lambda h: altitude(h) - angle, min(lower, transit), max(lower, transit))

    _, noon_declination = solar_state(transit)

    def asr(shadow):
        # The noon shadow is defined at transit, not at 0h UTC or at Asr.
        target = math.degrees(math.atan(1 / (shadow + math.tan(
            math.radians(abs(lat - noon_declination))))))
        if target <= 16 / 60 or altitude(transit) < target:
            return None
        return angle_time(target, True)

    expected = {
        "transit": transit,
        "sunrise": angle_time(-50 / 60 - 0.035333 * math.sqrt(max(0, row["east"])), False),
        "sunset": angle_time(-50 / 60 - 0.035333 * math.sqrt(max(0, row["west"])), True),
        "fajr18": angle_time(-18, False),
        "isha17": angle_time(-17, True),
        "isha18": angle_time(-18, True),
        "asr1": asr(1),
        "asr2": asr(2),
    }
    if row["west"] != 0:
        print(f"Polar-boundary oracle {label}: sunrise={expected['sunrise']}, sunset={expected['sunset']}")
    for name, target in expected.items():
        actual = row["hours"][name]
        if (target is None) != (actual is None):
            failures.append(f"{label}: {name} reachability mismatch: Dart={actual}, JPL={target}")
            continue
        if target is None:
            unreachable += 1
            continue
        error = abs(actual - target) * 3600
        errors[name].append(error)
        # High-latitude near-grazing events are numerically more sensitive.
        tolerance = 30 if abs(lat) >= 55 else 10
        if error > tolerance:
            failures.append(f"{label}: {name} differs by {error:.3f}s (limit {tolerance}s)")

print(f"JPL DE440s: {len(rows)} solar days; {unreachable} matching unreachable events")
for name, values in errors.items():
    rms = math.sqrt(sum(x*x for x in values) / len(values))
    print(f"{name}: {len(values)} events, RMS={rms:.3f}s, max={max(values):.3f}s")
for failure in failures[:40]:
    print(failure, file=sys.stderr)
print(f"{len(failures)} mismatches")
sys.exit(bool(failures))
