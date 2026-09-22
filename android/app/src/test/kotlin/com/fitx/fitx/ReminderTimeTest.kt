package com.fitx.fitx

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.ZoneId
import java.time.ZonedDateTime

class ReminderTimeTest {
    @Test
    fun futureTimeStaysTodayInIndia() {
        val now = ZonedDateTime.of(2026, 9, 13, 6, 30, 0, 0, ZoneId.of("Asia/Kolkata"))
        val next = ReminderTime.next(7, 0, now)
        assertEquals("2026-09-13T07:00+05:30[Asia/Kolkata]", next.toString())
    }

    @Test
    fun equalTimeRollsToTomorrow() {
        val now = ZonedDateTime.of(2026, 9, 13, 7, 0, 0, 0, ZoneId.of("Asia/Kolkata"))
        assertEquals(14, ReminderTime.next(7, 0, now).dayOfMonth)
    }

    @Test
    fun springGapMovesToFirstValidWallTime() {
        val now = ZonedDateTime.of(2026, 3, 8, 1, 0, 0, 0, ZoneId.of("America/New_York"))
        val next = ReminderTime.next(2, 30, now)
        assertEquals("2026-03-08T03:30-04:00[America/New_York]", next.toString())
    }

    @Test
    fun autumnOverlapUsesFirstOccurrence() {
        val now = ZonedDateTime.of(2026, 11, 1, 0, 30, 0, 0, ZoneId.of("America/New_York"))
        val next = ReminderTime.next(1, 30, now)
        assertEquals("2026-11-01T01:30-04:00[America/New_York]", next.toString())
    }

    @Test
    fun travelUsesTheCurrentDeviceZone() {
        val londonNow = ZonedDateTime.of(2026, 9, 13, 6, 0, 0, 0, ZoneId.of("Europe/London"))
        assertEquals("Europe/London", ReminderTime.next(7, 0, londonNow).zone.id)
    }
}
