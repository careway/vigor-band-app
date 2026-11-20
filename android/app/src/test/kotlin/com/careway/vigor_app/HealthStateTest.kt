package com.careway.vigor_app

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

/** DEV_007: libro de lo enviado a Health Connect/Salud en el JsonStore. */
class HealthStateTest {
    @get:Rule val tmp = TemporaryFolder()
    private fun dir() = File(tmp.root, "vigor")

    @Test fun emptyThenSaveAndReload() {
        val s = JsonStore(dir()); assertNull(s.healthState())
        assertTrue(s.saveHealthState("""{"v":1,"wm":{"steps":5}}"""))
        val again = JsonStore(dir()); val st = again.healthState()!!
        assertTrue(st.contains("\"v\":1")); assertTrue(st.contains("\"steps\":5"))
    }

    @Test fun overwritesInsteadOfDuplicating() {
        val s = JsonStore(dir()); s.saveHealthState("""{"v":1,"n":1}"""); s.saveHealthState("""{"v":1,"n":2}""")
        assertEquals(1, org.json.JSONArray(s.all("health")).length()); assertTrue(s.healthState()!!.contains("\"n\":2"))
    }

    @Test fun invalidJsonIsRejectedAndKeepsPrevious() {
        val s = JsonStore(dir()); s.saveHealthState("""{"v":1}""")
        assertFalse(s.saveHealthState("no es json")); assertTrue(s.healthState()!!.contains("\"v\":1"))
    }

    @Test fun wipeRemovesLedger() {
        val s = JsonStore(dir()); s.saveHealthState("""{"v":1}"""); s.wipe()
        assertNull(s.healthState())
    }
}
