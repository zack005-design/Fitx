package com.fitx.fitx

import java.time.ZonedDateTime

/** Reminders follow the phone's wall clock, including travel and DST. */
object ReminderTime {
    fun next(hour: Int, minute: Int, now: ZonedDateTime): ZonedDateTime {
        require(hour in 0..23 && minute in 0..59)
        var date = now.toLocalDate()
        var next = date.atTime(hour, minute).atZone(now.zone)
        if (!next.isAfter(now)) {
            date = date.plusDays(1)
            next = date.atTime(hour, minute).atZone(now.zone)
        }
        // java.time shifts nonexistent spring times forward by the DST gap,
        // and uses the first occurrence of an overlapping autumn time.
        return next
    }
}
