package com.careway.vigor_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GpsAssistRulesTest {
    @Test fun status_depends_on_permission_and_age() {
        assertEquals(GpsAssistRules.Status.CLOSED, GpsAssistRules.status(false, 1000))
        assertEquals(GpsAssistRules.Status.CLOSED, GpsAssistRules.status(true, null))
        assertEquals(GpsAssistRules.Status.NORMAL, GpsAssistRules.status(true, 60_000))
        assertEquals(GpsAssistRules.Status.WEAK, GpsAssistRules.status(true, 30 * 60_000L))
        assertEquals(GpsAssistRules.Status.CLOSED, GpsAssistRules.status(true, 7 * 3600_000L))
        assertEquals(GpsAssistRules.Status.CLOSED, GpsAssistRules.status(true, -5))
    }
    @Test fun replies_are_rate_limited() { assertFalse(GpsAssistRules.shouldReply(10_000, 8_000)); assertTrue(GpsAssistRules.shouldReply(10_000, 5_000)); assertTrue(GpsAssistRules.shouldReply(1, 0).not()) }
    @Test fun time_zone_in_hours() { assertEquals(1.toShort(), GpsAssistRules.timeZoneHours(3_600_000)); assertEquals(2.toShort(), GpsAssistRules.timeZoneHours(7_200_000)); assertEquals((-5).toShort(), GpsAssistRules.timeZoneHours(-18_000_000)) }
    @Test fun coordinates_validation() {
        assertTrue(GpsAssistRules.validCoords(40.0, -3.0)); assertFalse(GpsAssistRules.validCoords(0.0, 0.0)); assertFalse(GpsAssistRules.validCoords(91.0, 0.0))
        assertFalse(GpsAssistRules.validCoords(Double.NaN, 1.0)); assertFalse(GpsAssistRules.validCoords(10.0, 181.0))
    }
}
