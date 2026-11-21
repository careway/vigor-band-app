package com.careway.vigor_app

import org.junit.Assert.*
import org.junit.Test

class SyncRulesTest {
    @Test fun intervaloValidoOPredeterminado() {
        assertEquals(15, SyncRules.safeInterval(15)); assertEquals(60, SyncRules.safeInterval(60))
        assertEquals(30, SyncRules.safeInterval(5)); assertEquals(30, SyncRules.safeInterval(null)); assertEquals(30, SyncRules.safeInterval(1440))
    }
    @Test fun puertasEnOrden() {
        assertEquals(SyncRules.Gate.DISABLED, SyncRules.gate(false, false, false))
        assertEquals(SyncRules.Gate.NO_PERMISSION, SyncRules.gate(true, false, true))
        assertEquals(SyncRules.Gate.NO_MAC, SyncRules.gate(true, true, false))
        assertEquals(SyncRules.Gate.RUN, SyncRules.gate(true, true, true))
    }
    @Test fun pantallaApagadaNoHaceNada() {
        assertEquals(SyncRules.Gate.SCREEN_OFF, SyncRules.gate(true, true, true, screenOnly = true, interactive = false))
        assertEquals(SyncRules.Gate.RUN, SyncRules.gate(true, true, true, screenOnly = true, interactive = true))
        assertEquals(SyncRules.Gate.RUN, SyncRules.gate(true, true, true, screenOnly = false, interactive = false))
        assertEquals(SyncRules.Gate.DISABLED, SyncRules.gate(false, true, true, true, true))
        assertFalse(SyncRules.mayContinue(true, false)); assertTrue(SyncRules.mayContinue(true, true)); assertTrue(SyncRules.mayContinue(false, false))
    }
    @Test fun recienteSaltaLaPasada() {
        val now = 10_000_000_000L
        assertTrue(SyncRules.recentEnough(now, now - 5 * 60_000L, 30))
        assertFalse(SyncRules.recentEnough(now, now - 20 * 60_000L, 30))
        assertFalse(SyncRules.recentEnough(now, 0, 30)) // nunca sincronizada
        assertFalse(SyncRules.recentEnough(now, now + 1000, 30)) // reloj cambiado: no se fia
    }
    @Test fun exportacionSoloSiTodoLoPermite() {
        assertTrue(SyncRules.exportNeeded(true, true, false, true))
        assertFalse(SyncRules.exportNeeded(false, true, false, true)) // interruptor general de Health Connect apagado: NUNCA
        assertFalse(SyncRules.exportNeeded(true, false, false, true)) // nada nuevo
        assertFalse(SyncRules.exportNeeded(true, true, true, true)) // app abierta: la exporta ella
        assertFalse(SyncRules.exportNeeded(true, true, false, false)) // interruptor interno apagado
    }
    @Test fun sinReintentosAutomaticos() { assertFalse(SyncRules.RETRY); assertTrue(SyncRules.SYNC_TIMEOUT_SEC <= 300) }
    @Test fun etiquetaSinDatosPersonales() { assertEquals("DONE+SYNC+HC_OK", SyncRules.label("DONE", true, "OK")); assertEquals("NO_SESSION", SyncRules.label("NO_SESSION", false, null)) }
}
