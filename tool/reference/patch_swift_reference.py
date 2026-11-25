"""Apply one explicit, test-only dependency correction to the pinned Swift port.

This script does not change any astronomical algorithm or output tolerances.
The baseline Swift build is executed first and reported separately. The
normalized reference build then requires strict parity. Refuse unknown source.
"""
from pathlib import Path
import sys

path = Path(sys.argv[1]) / "Sources" / "PrayerTimes.swift"
text = path.read_text()
replacements = {
    "let tomorrowSolarTime = SolarTime(date: tomorrow, coordinates: coordinates, elevationFromHorizon: elevation),":
        "let tomorrowSunriseComponents = SolarTime.sunriseOnly(date: tomorrow, coordinates: coordinates, elevationFromHorizon: elevation),",
    "let tomorrowSunrise = cal.date(from: tomorrowSolarTime.sunrise)":
        "let tomorrowSunrise = cal.date(from: tomorrowSunriseComponents)",
}
for old, new in replacements.items():
    if text.count(old) != 1:
        raise RuntimeError(f"Unexpected pinned Swift source: {old}")
    text = text.replace(old, new, 1)
path.write_text(text)
print("Applied only the following-day sunrise dependency correction")
