package com.careway.vigor_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HealthBatchRulesTest {
    @Test fun valid_ranges_per_type() {
        assertTrue(HealthBatchRules.valid("steps", 120.0, 0, 300_000))
        assertFalse(HealthBatchRules.valid("steps", 0.0, 0, 300_000))
        assertFalse(HealthBatchRules.valid("heartRate", 301.0, 0, 60_000))
        assertTrue(HealthBatchRules.valid("heartRate", 55.0, 0, 60_000))
        assertTrue(HealthBatchRules.valid("spo2", 97.0, 5, 5))
        assertFalse(HealthBatchRules.valid("spo2", 101.0, 5, 5))
        assertFalse(HealthBatchRules.valid("hrvRmssd", 250.0, 5, 5))
        assertTrue(HealthBatchRules.valid("restingHr", 48.0, 5, 5))
        assertTrue(HealthBatchRules.valid("bodyTemp", 36.5, 5, 5))
        assertTrue(HealthBatchRules.valid("activeEnergy", 0.0, 0, 300_000))
    }
    @Test fun interval_types_need_end_after_start_point_types_do_not() {
        assertFalse(HealthBatchRules.valid("steps", 10.0, 1000, 1000))
        assertFalse(HealthBatchRules.valid("distance", 5.0, 2000, 1000))
        assertTrue(HealthBatchRules.valid("spo2", 97.0, 1000, 1000))
    }
    @Test fun rejects_nan_inf_and_unknown_types() {
        assertFalse(HealthBatchRules.valid("steps", Double.NaN, 0, 1000))
        assertFalse(HealthBatchRules.valid("heartRate", Double.POSITIVE_INFINITY, 0, 1000))
        assertFalse(HealthBatchRules.valid("glucose", 5.0, 0, 1000))
    }
    @Test fun detects_rate_limit_messages() {
        assertTrue(HealthBatchRules.isRateLimit("Request rejected. Rate limited request quota has been exceeded. Please wait"))
        assertTrue(HealthBatchRules.isRateLimit("API call quota exceeded"))
        assertFalse(HealthBatchRules.isRateLimit("permission denied"))
        assertFalse(HealthBatchRules.isRateLimit(null))
    }
    @Test fun chunk_is_within_google_limit() { assertTrue(HealthBatchRules.CHUNK in 1..1000) }
}
