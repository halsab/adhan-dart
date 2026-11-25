package com.batoulapps.adhan2

import com.batoulapps.adhan2.data.DateComponents
import com.batoulapps.adhan2.model.Rounding
import com.batoulapps.adhan2.model.Shafaq
import kotlinx.serialization.json.*
import java.io.File
import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals

// Compiled by the pinned Kotlin repository's own Gradle JVM test task.
class KotlinParityTest {
    @Test
    fun compareDart() {
        val input = requireNotNull(System.getenv("ADHAN_DART_CROSS_PORT"))
        val rows = Json.parseToJsonElement(File(input).readText()).jsonArray
        fun normalized(s: String) = s.replace("_", "").lowercase()
        val failures = mutableListOf<String>()
        val maxima = LongArray(8)
        var count = 0
        for (value in rows) {
            val r = value.jsonObject
            fun str(key: String) = r.getValue(key).jsonPrimitive.content
            fun number(key: String) = r.getValue(key).jsonPrimitive.double
            fun int(key: String) = r.getValue(key).jsonPrimitive.int
            if (!r.getValue("kotlin").jsonPrimitive.boolean) continue
            val method = CalculationMethod.entries.first { normalized(it.name) == str("method") }
            val p = method.parameters.copy(
                madhab = if (str("madhab") == "hanafi") Madhab.HANAFI else Madhab.SHAFI,
                rounding = Rounding.NONE,
                highLatitudeRule = HighLatitudeRule.MIDDLE_OF_THE_NIGHT,
                shafaq = Shafaq.GENERAL,
                fajrAngle = number("fajrAngle"), ishaAngle = number("ishaAngle")
            )
            val coordinates = Coordinates(number("lat"), number("lon"))
            val date = DateComponents(int("year"), int("month"), int("day"))
            val label = "${date.year}-${date.month}-${date.day} ${str("lat")},${str("lon")} ${method.name}/${p.madhab}"
            fun fail(message: String) { failures.add("$label: $message") }
            count++
            val angle = abs(Qibla(coordinates).direction - number("qibla"))
            if (minOf(angle, abs(360 - angle)) > 1e-6) fail("Qibla mismatch")
            val expected = r.getValue("times")
            val result = try { PrayerTimes(coordinates, date, p) } catch (_: IllegalStateException) { null }
            if ((result == null) != (expected == JsonNull)) {
                fail("schedule validity mismatch")
                continue
            }
            if (result == null) continue
            val actual = listOf(result.fajr, result.sunrise, result.dhuhr, result.asr, result.maghrib, result.isha)
            // Kotlin still uses the old one-step solar-angle solver and 0h UT
            // Asr declination. Published upstream measurements show differences
            // up to ~73s in Asr; comparison is deliberately limited to |lat|<=40.
            for (i in actual.indices) {
                val error = abs(actual[i].toEpochMilliseconds() - expected.jsonArray[i].jsonPrimitive.long)
                maxima[i] = maxOf(maxima[i], error)
                val tolerance = if (i == 3) 90000L else 20000L
                if (error > tolerance) fail("event $i delta ${error}ms")
            }
            val expectedNight = r.getValue("night")
            if (expectedNight != JsonNull) {
                val night = SunnahTimes(result)
                val times = listOf(night.middleOfTheNight, night.lastThirdOfTheNight)
                for (i in times.indices) {
                    val error = abs(times[i].toEpochMilliseconds() - expectedNight.jsonArray[i].jsonPrimitive.long)
                    maxima[6+i] = maxOf(maxima[6+i], error)
                    if (error > 20000L) fail("night $i delta ${error}ms")
                }
            }
        }
        println("Kotlin: $count cases; max event deltas (ms): ${maxima.joinToString()}; ${failures.size} mismatches")
        assertEquals(0, failures.size, failures.take(40).joinToString("\n"))
        check(count > 1000) { "Comparison unexpectedly empty" }
    }
}
