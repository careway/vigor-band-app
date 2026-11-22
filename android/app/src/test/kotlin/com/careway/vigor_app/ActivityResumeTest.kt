package com.careway.vigor_app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ActivityResumeTest {
    @Test fun resumes_only_when_busy_with_valid_type() {
        assertTrue(ActivityResume.shouldResume("DEVICE_BUSY", 2))
        assertFalse(ActivityResume.shouldResume("DEVICE_FREE", 2))
        assertTrue(ActivityResume.shouldResume("DEVICE_HAD_START_BEFORE", 2))
        assertFalse(ActivityResume.shouldResume("DEVICE_HAD_START_BEFORE", 0))
        assertFalse(ActivityResume.shouldResume("UNKNOW", 2))
        assertFalse(ActivityResume.shouldResume("DEVICE_BUSY", 0))
    }
}
