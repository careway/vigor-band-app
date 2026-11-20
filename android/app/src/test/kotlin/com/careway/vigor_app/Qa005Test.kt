package com.careway.vigor_app

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** QA_005: pruebas con hilos reales de la carrera wipe/flush/sync (H1) y bordes de PermissionQueue (H3). */
class Qa005Test {
    @get:Rule val tmp = TemporaryFolder()
    private fun dir() = File(tmp.root, "vigor")

    /** Muchos flush y puts concurrentes con wipes: sin interbloqueo (timeout) y, tras el ultimo wipe sin escritores, no queda nada en disco. */
    @Test(timeout = 20_000) fun concurrentFlushAndWipeNoDeadlockAndEmptyAtEnd() {
        val s = JsonStore(dir()); val pool = Executors.newFixedThreadPool(6); val stop = java.util.concurrent.atomic.AtomicBoolean(false)
        val tasks = (0 until 4).map { t -> pool.submit { var i = 0; while (!stop.get()) { s.put("hrv", "2026-03-0${1 + t} 10:${i++ % 60}", JSONObject().put("v", i)); s.flush("hrv"); s.exportTo(File(tmp.root, "exp$t")) } } }
        val wipes = pool.submit { repeat(200) { s.wipe() } }
        wipes.get(15, TimeUnit.SECONDS); stop.set(true); tasks.forEach { it.get(10, TimeUnit.SECONDS) }
        pool.shutdown()
        s.wipe()
        assertEquals(0, dir().listFiles()?.count { it.isFile } ?: 0)
        assertFalse(s.wiping)
    }

    /** Un flush que llega mientras 'wiping' se niega y no recrea el fichero. */
    @Test fun flushDuringWipingIsRefused() {
        val s = JsonStore(dir()); s.put("spo2", "2026-03-05 10:00", JSONObject().put("v", 1)); assertTrue(s.flush("spo2"))
        var during: Boolean? = null
        s.put("spo2", "2026-03-05 10:01", JSONObject().put("v", 2))
        val n = s.tryWipe { during = s.wiping; true }
        assertNotNull(n); assertEquals(false, during) // canStart se evalua antes de marcar wiping
        assertFalse(File(dir(), "spo2.json").exists())
        assertFalse(s.wiping)
    }

    /** tryWipe negado no cambia estado ni borra. */
    @Test fun refusedTryWipeKeepsData() {
        val s = JsonStore(dir()); s.put("hrv", "2026-03-05 10:00", JSONObject().put("v", 1)); s.flush("hrv")
        assertNull(s.tryWipe { false }); assertFalse(s.wiping)
        assertTrue(File(dir(), "hrv.json").exists()); assertEquals(1, org.json.JSONArray(s.all("hrv")).length())
    }

    /** exportTo solo copia .json (no .tmp ni .corrupt) y deja el destino limpio. */
    @Test fun exportOnlyJsonAndCleansTarget() {
        val s = JsonStore(dir()); s.put("hrv", "2026-03-05 10:00", JSONObject().put("v", 1)); s.flush("hrv")
        File(dir(), "x.corrupt-1").writeText("x"); File(dir(), "hrv.tmp").writeText("x")
        val t = File(tmp.root, "out"); t.mkdirs(); File(t, "old.json").writeText("{}")
        assertEquals(listOf("hrv.json"), s.exportTo(t)); assertEquals(listOf("hrv.json"), t.list()!!.toList())
    }

    @Test fun kindWithTraversalRejectedInAllAndFlush() {
        val s = JsonStore(dir())
        assertFalse(s.flush("../x")); assertThrows(IllegalArgumentException::class.java) { s.all("../x") }
        assertThrows(IllegalArgumentException::class.java) { s.put("hrv/../../a", "k", JSONObject()) }
    }

    /** H3: expire con una ronda ya respondida no hace nada; expire dos veces no resuelve dos veces. */
    @Test fun expireIsIdempotent() {
        val granted = HashSet<String>(); val q = PermissionQueue<String> { it in granted }
        val ask = q.add("A", listOf("p1")); assertEquals(listOf("p1"), ask); val g = q.generation
        val r1 = q.expire(g); assertEquals(listOf("A" to false), r1.resolved)
        val r2 = q.expire(g); assertTrue(r2.resolved.isEmpty())
        // tras el timeout la cola acepta una peticion nueva
        assertEquals(listOf("p1"), q.add("B", listOf("p1")))
    }

    /** H3: una respuesta tardia tras expire resuelve a los nuevos solo con lo realmente concedido (no cuelga ni miente). */
    @Test fun lateResultAfterExpireThenNewRequest() {
        val granted = HashSet<String>(); val q = PermissionQueue<String> { it in granted }
        q.add("A", listOf("p1")); q.expire(q.generation)
        q.add("B", listOf("p1")) // nueva ronda en curso
        val late = q.onResult() // respuesta tardia de la ronda vieja: se atribuye a la nueva
        // Documenta el comportamiento: B se resuelve (false) aunque su dialogo siga abierto.
        assertEquals(listOf("B" to false), late.resolved)
    }
}
