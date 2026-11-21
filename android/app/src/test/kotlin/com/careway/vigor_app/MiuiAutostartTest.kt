package com.careway.vigor_app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MiuiAutostartTest {
    @Test fun detects_xiaomi_family_case_insensitive() {
        assertTrue(MiuiAutostart.isXiaomiBrand("Xiaomi")); assertTrue(MiuiAutostart.isXiaomiBrand("REDMI")); assertTrue(MiuiAutostart.isXiaomiBrand("poco"))
    }
    @Test fun other_brands_and_null_are_not_xiaomi() {
        assertFalse(MiuiAutostart.isXiaomiBrand("samsung")); assertFalse(MiuiAutostart.isXiaomiBrand("")); assertFalse(MiuiAutostart.isXiaomiBrand(null))
    }
    @Test fun appops_mode_is_interpreted() {
        assertTrue(MiuiAutostart.interpret(0) == true)
        assertTrue(MiuiAutostart.interpret(1) == false); assertTrue(MiuiAutostart.interpret(2) == false)
        assertTrue(MiuiAutostart.interpret(3) == null); assertTrue(MiuiAutostart.interpret(null) == null)
    }
}
