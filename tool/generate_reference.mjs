// Test-only use of the exact Adhan JS commit checked out by CI.
// No Node or JS dependency exists in the Dart package at runtime.
import { writeFileSync } from 'node:fs';
import { CalculationMethod, Coordinates, HighLatitudeRule, Madhab,
  PolarCircleResolution, PrayerTimes, Rounding, Shafaq, SunnahTimes, Qibla }
  from '../.reference/adhan-js/lib/esm/Adhan.js';

const locations = [
  [0, 0], [21.4225, 39.8262], [52.2297, 21.0122], [35.775, -78.6336],
  [61.2181, -149.9003], [51.507194, -0.116711], [1.3708, 103.8015],
  [-45.87, 170.5], [-53.16, -70.91], [78.2232, 15.6469],
  [-78, 15], [0, -179.9], [0, 179.9], [36.3, 30.1], [35.7153, 51.4043],
];
const dates = ['2024-02-29', '2024-03-20', '2025-04-26',
  '2026-06-21', '2026-09-22', '2026-12-21', '2026-12-31'];
const methods = ['MuslimWorldLeague', 'Egyptian', 'Karachi', 'UmmAlQura',
  'Dubai', 'MoonsightingCommittee', 'NorthAmerica', 'Kuwait',
  'Qatar', 'Singapore', 'Turkey', 'Tehran', 'Other'];
const events = ['fajr', 'sunrise', 'dhuhr', 'asr', 'sunset', 'maghrib', 'isha'];
const records = [];
const normalize = s => s.replaceAll('_', '').toLowerCase();
for (const [lat, lon] of locations) {
  for (const date of dates) {
    for (const method of methods) {
      for (const madhab of [Madhab.Shafi, Madhab.Hanafi]) {
        const p = CalculationMethod[method]();
        p.madhab = madhab;
        p.rounding = Rounding.None;
        p.polarCircleResolution = PolarCircleResolution.Unresolved;
        if (method === 'Other') { p.fajrAngle = 16; p.ishaAngle = 16; }
        const variants = [
          { rule: HighLatitudeRule.MiddleOfTheNight, polar: PolarCircleResolution.Unresolved,
            shafaq: Shafaq.General, rounding: Rounding.None, elevation: 0 },
          { rule: HighLatitudeRule.SeventhOfTheNight, polar: PolarCircleResolution.AqrabBalad,
            shafaq: Shafaq.Ahmer, rounding: Rounding.Nearest, elevation: 450 },
          { rule: HighLatitudeRule.TwilightAngle, polar: PolarCircleResolution.AqrabYaum,
            shafaq: Shafaq.Abyad, rounding: Rounding.Up, elevation: { sunrise: 0, sunset: 100 } },
        ];
        for (const v of variants) {
          p.highLatitudeRule = v.rule;
          p.polarCircleResolution = v.polar;
          p.shafaq = v.shafaq;
          p.rounding = v.rounding;
          p.elevationFromHorizon = v.elevation;
          const c = new Coordinates(lat, lon);
          const times = new PrayerTimes(c, new Date(date + 'T00:00:00Z'), p);
          const record = {
            lat, lon, date, method: normalize(method), madhab, highLatitudeRule: v.rule,
            polar: normalize(v.polar), shafaq: v.shafaq, rounding: v.rounding,
            elevation: typeof v.elevation === 'number'
              ? { sunrise: v.elevation, sunset: v.elevation } : v.elevation,
            fajrAngle: p.fajrAngle, ishaAngle: p.ishaAngle,
            qibla: Qibla(c), times: null, sunnah: null,
          };
          if (times.isValid) {
            // Dart intentionally rejects inverted final adjusted times.
            const order = ['fajr','sunrise','dhuhr','asr','maghrib','isha'];
            if (order.every((key, i) => i === 0 || times[key] > times[order[i-1]])) {
              record.times = Object.fromEntries(events.map(k => [k, +times[k]]));
              const n = new SunnahTimes(times);
              const nextDate = new Date(date + 'T00:00:00Z');
              nextDate.setUTCDate(nextDate.getUTCDate() + 1);
              const next = new PrayerTimes(c, nextDate, p);
              if (n.isValid && next.isValid && next.fajr > times.isha &&
                  next.fajr - times.maghrib < 86400000 &&
                  n.middleOfTheNight > times.maghrib &&
                  n.lastThirdOfTheNight > n.middleOfTheNight &&
                  next.fajr > n.lastThirdOfTheNight) {
                record.sunnah = { middle: +n.middleOfTheNight, lastThird: +n.lastThirdOfTheNight };
              }
            }
          }
          records.push(record);
        }
      }
    }
  }
}
writeFileSync(process.argv[2] || 'reference-results.json', JSON.stringify(records));
console.log('Generated ' + records.length + ' reference scenarios');
