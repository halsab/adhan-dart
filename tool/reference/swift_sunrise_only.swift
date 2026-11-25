import Foundation

// Test-only adapter for the pinned Swift source. Its failable SolarTime
// initializer requires both sunrise and sunset. The *following* day is
// needed only for its sunrise; rejecting a valid sunrise when that day's
// sunset is absent changes Aqrab Yaum candidate selection near polar day.
// Reuse Swift's own astronomical routines, not Dart-generated values.
extension SolarTime {
    static func sunriseOnly(date: DateComponents, coordinates: Coordinates,
                            elevationFromHorizon: ElevationFromHorizon) -> DateComponents? {
        var date = date
        date.hour = 0
        date.minute = 0
        let jd = Astronomical.julianDay(dateComponents: date)
        let previous = SolarCoordinates(julianDay: jd - 1)
        let solar = SolarCoordinates(julianDay: jd)
        let next = SolarCoordinates(julianDay: jd + 1)
        let m0 = Astronomical.approximateTransit(
            longitude: coordinates.longitudeAngle,
            siderealTime: solar.apparentSiderealTime,
            rightAscension: solar.rightAscension)
        let angle = Angle(-50.0 / 60.0) - Astronomical.elevationCorrection(elevationFromHorizon.sunrise)
        let hours = Astronomical.correctedHourAngle(
            approximateTransit: m0, angle: angle, coordinates: coordinates,
            afterTransit: false, siderealTime: solar.apparentSiderealTime,
            rightAscension: solar.rightAscension, previousRightAscension: previous.rightAscension,
            nextRightAscension: next.rightAscension, declination: solar.declination,
            previousDeclination: previous.declination, nextDeclination: next.declination)
        return date.settingHour(hours)
    }
}
