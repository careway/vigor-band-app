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

/** DEV_008: tumbas de borrado individual. */
class TombstoneTest {
    @get:Rule val tmp = TemporaryFolder()
    private fun dir() = File(tmp.root, "vigor")
    private fun o(v: Int) = org.json.JSONObject().put("v", v)

    @Test fun deletedSleepDoesNotResurrectAfterResync() {
        val s = JsonStore(dir()); s.put("sleep", "2026-11-20", o(1)); s.flush("sleep")
        assertEquals(1, s.deleteRecords("sleep", listOf("2026-11-20")))
        s.put("sleep", "2026-11-20", o(2)) // la pulsera lo vuelve a entregar
        assertEquals("[]", s.all("sleep"))
        val again = JsonStore(dir()); assertEquals("[]", again.all("sleep")); again.put("sleep", "2026-11-20", o(3)); assertEquals("[]", again.all("sleep"))
        s.put("sleep", "2026-11-21", o(1)); assertEquals(1, org.json.JSONArray(s.all("sleep")).length())
    }

    @Test fun deleteSessionRemovesItemsAndBlocksResync() {
        val s = JsonStore(dir()); s.put("sports", "2026-11-19 18:00", o(1)); s.putItems("sportItems", "2026-11-19 18:00", org.json.JSONArray().put(1), true); s.put("sports", "2026-11-19 19:00", o(1))
        s.deleteRecords("session", listOf("2026-11-19 18:00"))
        s.put("sports", "2026-11-19 18:00", o(2)); s.putItems("sportItems", "2026-11-19 18:00", org.json.JSONArray().put(1), true)
        assertEquals(1, org.json.JSONArray(s.all("sports")).length()); assertEquals("[]", s.all("sportItems"))
    }

    @Test fun deleteDayRemovesDenseKindsAndBlocksPrefix() {
        val s = JsonStore(dir()); for (k in listOf("origin5", "hrv", "spo2")) { s.put(k, "2026-11-18 10:00", o(1)); s.put(k, "2026-11-19 10:00", o(1)) }
        assertEquals(3, s.deleteRecords("day", listOf("2026-11-18")))
        s.put("hrv", "2026-11-18 11:00", o(2))
        for (k in listOf("origin5", "hrv", "spo2")) assertEquals(1, org.json.JSONArray(s.all(k)).length())
    }

    @Test fun tombstonesExpireAfterRetentionAndWipeClears() {
        var t = 1_000_000_000_000L; val s = JsonStore(dir(), { t })
        s.put("sleep", "2026-11-20", o(1)); s.deleteRecords("sleep", listOf("2026-11-20"))
        t += (JsonStore.TOMB_KEEP_DAYS + 1) * 86_400_000L; s.flush("tomb")
        s.put("sleep", "2026-11-20", o(2)); assertEquals(1, org.json.JSONArray(s.all("sleep")).length()) // caducada
        s.deleteRecords("sleep", listOf("2026-11-20")); s.wipe()
        s.put("sleep", "2026-11-20", o(3)); assertEquals(1, org.json.JSONArray(s.all("sleep")).length()) // el borrado total limpia tumbas
    }

    @Test fun unknownTypeRejected() { assertThrows(IllegalArgumentException::class.java) { JsonStore(dir()).deleteRecords("x", listOf("a")) } }
}
