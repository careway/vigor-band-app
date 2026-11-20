package com.careway.vigor_app

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class JsonStoreTest {
    @get:Rule val tmp = TemporaryFolder()
    private val DAY = 86_400_000L
    private fun ms(y: Int, m: Int, d: Int) = java.util.Calendar.getInstance().apply { clear(); set(y, m - 1, d) }.timeInMillis
    private fun dir() = File(tmp.root, "vigor")

    @Test fun putFlushAndReload() {
        val s = JsonStore(dir()); s.put("origin5", "2026-03-05 10:00", JSONObject().put("stepValue", 12))
        assertTrue(s.flush("origin5"))
        val again = JsonStore(dir()); val a = JSONArray(again.all("origin5"))
        assertEquals(1, a.length()); assertEquals(12, a.getJSONObject(0).getInt("stepValue")); assertEquals("2026-03-05 10:00", a.getJSONObject(0).getString("_key"))
    }

    @Test fun resyncDoesNotDuplicate() {
        val s = JsonStore(dir()); repeat(3) { s.put("hrv", "2026-03-05 10:00", JSONObject().put("v", it)) }
        assertEquals(1, JSONArray(s.all("hrv")).length())
    }

    @Test fun corruptFileIsRenamedNotOverwritten() {
        dir().mkdirs(); File(dir(), "spo2.json").writeText("{not json")
        val s = JsonStore(dir(), now = { 1234L })
        assertEquals("[]", s.all("spo2"))
        assertTrue(File(dir(), "spo2.corrupt-1234").exists()); assertFalse(File(dir(), "spo2.json").exists())
        assertEquals("{not json", File(dir(), "spo2.corrupt-1234").readText())
    }

    @Test fun oldCorruptFilesArePurgedButRecentAndFutureOnesKept() {
        dir().mkdirs(); val now = 100 * DAY
        File(dir(), "a.corrupt-${now - 31 * DAY}").writeText("x"); File(dir(), "b.corrupt-${now - 5 * DAY}").writeText("x")
        File(dir(), "c.corrupt-${now + 9 * DAY}").writeText("x"); File(dir(), "d.corrupt-xyz").writeText("x")
        JsonStore(dir(), now = { now })
        assertFalse(File(dir(), "a.corrupt-${now - 31 * DAY}").exists()); assertTrue(File(dir(), "b.corrupt-${now - 5 * DAY}").exists())
        assertTrue(File(dir(), "c.corrupt-${now + 9 * DAY}").exists()); assertTrue(File(dir(), "d.corrupt-xyz").exists())
    }

    @Test fun retention60DaysFromClock() {
        val now = ms(2026, 3, 31); val s = JsonStore(dir(), now = { now })
        s.put("origin5", "2026-03-30 10:00", JSONObject()); s.put("origin5", "2026-01-29 10:00", JSONObject()); s.put("origin5", "2026-01-28 10:00", JSONObject())
        val removed = s.prune("origin5")
        val keys = JSONArray(s.all("origin5")).let { a -> (0 until a.length()).map { a.getJSONObject(it).getString("_key") } }
        assertEquals(1, removed); assertTrue("2026-01-28 10:00" !in keys); assertTrue("2026-01-29 10:00" in keys)
    }

    @Test fun aheadClockDoesNotDeleteValidData() {
        // reloj 1 ano adelantado: la referencia es el dato mas reciente, no el reloj
        val s = JsonStore(dir(), now = { ms(2027, 3, 31) })
        s.put("hrv", "2026-03-30 10:00", JSONObject()); s.put("hrv", "2026-03-01 10:00", JSONObject())
        assertEquals(0, s.prune("hrv")); assertEquals(2, JSONArray(s.all("hrv")).length())
    }

    @Test fun maxEntriesKeepsNewest() {
        val s = JsonStore(dir()); for (i in 1..505) s.put("sports", "2026-03-05 %04d".format(i), JSONObject())
        assertEquals(5, s.prune("sports")); val a = JSONArray(s.all("sports")); assertEquals(500, a.length())
        val keys = (0 until a.length()).map { a.getJSONObject(it).getString("_key") }
        assertFalse("2026-03-05 0001" in keys); assertTrue("2026-03-05 0505" in keys)
    }

    @Test fun keysWithoutDateAreNeverPruned() {
        val s = JsonStore(dir(), now = { ms(2026, 3, 31) }); s.put("live", "live", JSONObject()); s.put("live", "2025-01-01 00:00", JSONObject()); s.put("live", "2026-03-30 00:00", JSONObject())
        assertEquals(1, s.prune("live")); assertEquals(2, JSONArray(s.all("live")).length()) // cae la antigua; "live" (sin fecha) se conserva
    }

    @Test fun ioErrorDoesNotOverwriteGoodFile() {
        // un directorio con el nombre del fichero provoca error de E/S al leer: flush se niega a escribir
        dir().mkdirs(); File(dir(), "half.json").mkdirs()
        val s = JsonStore(dir()); assertFalse(s.flush("half")); assertTrue(File(dir(), "half.json").isDirectory)
    }

    @Test fun exportCopiesOnlyJsonAndWipeDeletesEverything() {
        val s = JsonStore(dir()); s.put("origin5", "2026-03-05 10:00", JSONObject().put("a", 1)); s.put("sleep", "2026-03-05", JSONObject())
        File(dir(), "x.corrupt-5").writeText("c"); File(dir(), "y.tmp").writeText("t")
        val out = File(tmp.root, "ext/export"); val names = s.exportTo(out)
        assertEquals(listOf("origin5.json", "sleep.json"), names); assertEquals(setOf("origin5.json", "sleep.json"), out.list()!!.toSet())
        assertEquals(1, JSONObject(File(out, "origin5.json").readText()).length())
        val n = s.wipe(); assertTrue(n >= 4); assertEquals(0, dir().listFiles()!!.size); assertEquals("[]", s.all("origin5"))
        assertTrue(File(out, "origin5.json").exists()) // wipe solo borra el almacen; la carpeta de exportacion la borra MainActivity
    }

    @Test fun h1WipeAfterSerializedFlushDoesNotResurrectFile() {
        val s = JsonStore(dir()); s.put("origin5", "2026-03-05 10:00", JSONObject().put("a", 1)); assertTrue(s.flush("origin5"))
        s.put("origin5", "2026-03-05 10:05", JSONObject().put("a", 2))
        s.beforeWrite = { s.wipe() } // el flush ya serializo; el wipe llega antes de la escritura
        assertFalse(s.flush("origin5"))
        s.beforeWrite = null
        assertFalse(File(dir(), "origin5.json").exists()); assertEquals("[]", s.all("origin5"))
        assertFalse(s.wiping)
        s.put("origin5", "k", JSONObject()); assertTrue(s.flush("origin5")) // tras el wipe se puede volver a escribir
    }

    @Test fun h1WipeRefusedWhenCallerSaysBusyAndWipingBlocksFlush() {
        val s = JsonStore(dir()); s.put("hrv", "2026-03-05 10:00", JSONObject()); assertTrue(s.flush("hrv"))
        assertNull(s.tryWipe { false }); assertTrue(File(dir(), "hrv.json").exists())
        assertEquals(1, s.tryWipe { s.put("hrv", "2026-03-06 10:00", JSONObject()); true }) // durante el canStart aun no hay wiping
        assertFalse(s.wiping);
    }

    @Test fun h4ExportRegeneratesFolder() {
        val s = JsonStore(dir()); s.put("sleep", "2026-03-05", JSONObject()); val out = File(tmp.root, "export"); out.mkdirs(); File(out, "viejo.json").writeText("x")
        assertEquals(listOf("sleep.json"), s.exportTo(out)); assertEquals(setOf("sleep.json"), out.list()!!.toSet())
    }

    @Test fun h7UnknownKindIsRejected() {
        val s = JsonStore(dir())
        for (k in listOf("../x", "a/b", "", "origin5/../hrv", "desconocido")) {
            assertThrows(IllegalArgumentException::class.java) { s.all(k) }
            assertFalse(s.flush(k))
        }
        for (k in JsonStore.KINDS) assertEquals("[]", s.all(k))
    }
}
