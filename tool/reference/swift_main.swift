import Foundation

// Compiled alongside the exact pinned Adhan Swift Sources in CI.
struct Scenario: Decodable {
    let lat: Double, lon: Double
    let year: Int, month: Int, day: Int
    let method: String, madhab: String, rule: String, polar: String, shafaq: String
    let east: Double, west: Double, fajrAngle: Double, ishaAngle: Double
    let times: [Int64]?, night: [Int64]?
    let qibla: Double
    let calculationLatitude: Double?, calculationDate: String?
    let nextFajr: Int64?
}
func normalized(_ s: String) -> String { s.replacingOccurrences(of: "_", with: "").lowercased() }
func ordered(_ t: PrayerTimes) -> [Date]? {
    let times = [t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha]
    return zip(times, times.dropFirst()).allSatisfy { $0.0 < $0.1 } ? times : nil
}
let rows = try JSONDecoder().decode([Scenario].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
var failures = 0
var comparisons = 0
var maxError: Double = 0
var failuresByKind: [String: Int] = [:]
var largeFailures = 0
for row in rows {
    let coordinates = Coordinates(latitude: row.lat, longitude: row.lon)
    let date = DateComponents(year: row.year, month: row.month, day: row.day)
    var params = CalculationMethod.allCases.first { normalized($0.rawValue) == row.method }!.params
    params.madhab = row.madhab == "hanafi" ? .hanafi : .shafi
    params.highLatitudeRule = HighLatitudeRule.allCases.first { normalized($0.rawValue) == row.rule }!
    params.polarCircleResolution = PolarCircleResolution.allCases.first { normalized($0.rawValue) == row.polar }!
    params.shafaq = Shafaq(rawValue: row.shafaq)!
    params.rounding = .none
    params.elevationFromHorizon = ElevationFromHorizon(sunrise: row.east, sunset: row.west)
    params.fajrAngle = row.fajrAngle
    params.ishaAngle = row.ishaAngle
    func fail(_ message: String, kind: String = "other", large: Bool = true) {
        failures += 1
        failuresByKind[kind, default: 0] += 1
        if large { largeFailures += 1 }
        if failures <= 10 || (large && largeFailures <= 40) { print("\(row.year)-\(row.month)-\(row.day) \(row.lat),\(row.lon) \(row.method)/\(row.madhab)/\(row.polar): \(message)") }
    }
    func compare(_ actual: [Date], _ expected: [Int64], _ name: String) {
        for (index, pair) in zip(actual, expected).enumerated() {
            let delta = abs(pair.0.timeIntervalSince1970 * 1000 - Double(pair.1))
            comparisons += 1
            maxError = max(maxError, delta)
            // Swift .none reconstructs Date from integer-second components;
            // its night milestones are then also floored. A 1 s endpoint
            // difference plus at most 1 s final truncation bounds this effect.
            let limit: Double = name == "night" ? 2000 : 1000
            if delta > limit {
                fail("\(name)[\(index)] delta \(delta)ms, Swift=\(pair.0), Dart=\(Date(timeIntervalSince1970: Double(pair.1)/1000)), Dart geometry=\(String(describing: row.calculationLatitude)),\(String(describing: row.calculationDate))", kind: name, large: delta > 2000)
            }
        }
    }
    let direction = Qibla(coordinates: coordinates).direction
    let angle = abs(direction - row.qibla)
    if min(angle, abs(360-angle)) > 1e-6 { fail("Qibla mismatch") }
    let prayer = PrayerTimes(coordinates: coordinates, date: date, calculationParameters: params)
    let actual = prayer.flatMap(ordered)
    if (actual == nil) != (row.times == nil) { fail("schedule validity mismatch"); continue }
    guard let expected = row.times, let prayer, let actual else { continue }
    compare(actual, expected, "prayer")
    var actualNight: [Date]? = nil
    let cal = Calendar.gregorianUTC
    if let today = cal.date(from: date),
       let nextDate = cal.date(byAdding: .day, value: 1, to: today),
       let next = PrayerTimes(coordinates: coordinates, date: cal.dateComponents([.year, .month, .day], from: nextDate), calculationParameters: params),
       ordered(next) != nil, next.fajr > prayer.isha,
       next.fajr.timeIntervalSince(prayer.maghrib) < 86400,
       let night = SunnahTimes(from: prayer),
       night.middleOfTheNight > prayer.maghrib,
       night.lastThirdOfTheNight > night.middleOfTheNight,
       next.fajr > night.lastThirdOfTheNight {
        actualNight = [night.middleOfTheNight, night.lastThirdOfTheNight]
        if let expectedNext = row.nextFajr {
            let nextDelta = abs(next.fajr.timeIntervalSince1970 * 1000 - Double(expectedNext))
            if nextDelta > 1000 {
                fail("next Fajr delta \(nextDelta)ms, Swift=\(next.fajr), Dart=\(Date(timeIntervalSince1970: Double(expectedNext)/1000))", kind: "nextFajr", large: nextDelta > 2000)
            }
        }
    }
    if (actualNight == nil) != (row.night == nil) { fail("night validity mismatch") }
    if let actualNight, let expectedNight = row.night { compare(actualNight, expectedNight, "night") }
}
print("Failure categories: \(failuresByKind)")
print("Swift: \(rows.count) scenarios, \(comparisons) instant comparisons, max error \(maxError) ms, \(failures) mismatches")
if failures > 0 { exit(1) }
