package com.careway.vigor_app

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class PureTest {
    @get:Rule val tmp = TemporaryFolder()

    @Test fun maskMacShowsOnlyLastTwoBytes() {
        assertEquals("••:••:••:••:EE:FF", Mac.mask("AA:BB:CC:DD:EE:FF")); assertEquals("", Mac.mask(null)); assertEquals("", Mac.mask("AB:C"))
        assertFalse(Mac.mask("AA:BB:CC:DD:EE:FF").contains("AA:BB"))
    }

    private fun file(bytes: ByteArray) = tmp.newFile().apply { writeBytes(bytes) }
    private fun padded(head: String, n: Int = 2000) = (head + "x".repeat(n)).toByteArray(Charsets.ISO_8859_1)

    @Test fun looksValidRejectsSmallMissingAndErrorPages() {
        assertFalse(AgpsRules.looksValid(File(tmp.root, "no.pgl")))
        assertFalse(AgpsRules.looksValid(file(ByteArray(999) { 7 })))
        assertTrue(AgpsRules.looksValid(file(ByteArray(1000) { 7 })))
        for (h in listOf("<html>", "  <?xml", "{\"error\":1}", "[1,2]", "Error 404", "  ERROR", "xx Not Found")) assertFalse(h, AgpsRules.looksValid(file(padded(h))))
        assertTrue(AgpsRules.looksValid(file(ByteArray(3000) { (it % 250 + 1).toByte() }.also { it[0] = 0x55 })))
    }

    @Test fun backoffAndRetryDecisions() {
        assertTrue(AgpsRules.inBackoff(100, 101)); assertFalse(AgpsRules.inBackoff(101, 101)); assertFalse(AgpsRules.inBackoff(5, 0))
        assertEquals(1000L + 24 * 3600_000L, AgpsRules.nextTryAfterUnsupported(1000))
        assertTrue(AgpsRules.shouldRetry(0)); assertTrue(AgpsRules.shouldRetry(2)); assertFalse(AgpsRules.shouldRetry(3)); assertFalse(AgpsRules.shouldRetry(10))
        val h = 3600_000L
        assertTrue(AgpsRules.isFresh(true, 19 * h, 0)); assertFalse(AgpsRules.isFresh(true, 20 * h, 0)); assertFalse(AgpsRules.isFresh(false, 1, 0))
    }

    private val granted = HashSet<String>()
    private fun q() = PermissionQueue<String> { it in granted }
    private val SCAN = "SCAN"; private val CONN = "CONN"

    @Test fun singleRequestGranted() {
        val q = q(); assertEquals(listOf(CONN), q.add("a", listOf(CONN)))
        granted.add(CONN); val r = q.onResult(); assertEquals(listOf("a" to true), r.resolved); assertNull(r.next)
    }

    @Test fun k3ConcurrentRequestsWithDifferentPermissionsBothResolve() {
        granted.clear(); val q = q()
        assertEquals(listOf(CONN), q.add("connect", listOf(CONN)))
        assertNull(q.add("scan", listOf(SCAN, CONN))) // la segunda espera: ya hay una peticion en curso
        granted.add(CONN)
        val r1 = q.onResult()
        assertEquals(listOf("connect" to true), r1.resolved); assertEquals(listOf(SCAN), r1.next) // BLUETOOTH_SCAN se pide en la ronda siguiente
        granted.add(SCAN); val r2 = q.onResult(); assertEquals(listOf("scan" to true), r2.resolved); assertNull(r2.next)
    }

    @Test fun deniedPermissionResolvesFalseAndDoesNotLoopForever() {
        granted.clear(); val q = q()
        q.add("connect", listOf(CONN)); q.add("scan", listOf(SCAN, CONN))
        val r1 = q.onResult() // CONN denegado
        assertEquals(listOf("connect" to false), r1.resolved); assertEquals(listOf(SCAN), r1.next)
        val r2 = q.onResult() // SCAN denegado; CONN ya se pregunto
        assertEquals(listOf("scan" to false), r2.resolved); assertNull(r2.next)
    }

    @Test fun emptyResultArrayIsNotGranted() {
        granted.clear(); val q = q(); q.add("a", listOf(CONN)); val r = q.onResult()
        assertEquals(listOf("a" to false), r.resolved)
    }

    @Test fun addAfterRoundFinishedStartsNewRequest() {
        granted.clear(); val q = q(); q.add("a", listOf(CONN)); q.onResult()
        assertEquals(listOf(CONN), q.add("b", listOf(CONN)))
        assertNull(q.add("c", listOf(CONN))); granted.add(CONN)
        assertEquals(setOf("b" to true, "c" to true), q.onResult().resolved.toSet())
    }

    @Test fun alreadyGrantedAddReturnsNullAndLeavesNothingWaiting() {
        granted.add(CONN); val q = q(); assertNull(q.add("a", listOf(CONN)))
        assertEquals(emptyList<Pair<String, Boolean>>(), q.onResult().resolved)
    }

    @Test fun h3TimeoutResolvesEverythingAndFreesQueue() {
        granted.clear(); val q = q()
        q.add("a", listOf(CONN)); q.add("b", listOf(SCAN, CONN)); val g = q.generation
        granted.add(CONN)
        val r = q.expire(g)
        assertEquals(setOf("a" to true, "b" to false), r.resolved.toSet()); assertNull(r.next)
        assertEquals(listOf(SCAN), q.add("c", listOf(SCAN))) // la cola vuelve a aceptar peticiones
    }

    @Test fun h3StaleTimerDoesNotTouchNewRound() {
        granted.clear(); val q = q()
        q.add("a", listOf(CONN)); val old = q.generation; q.onResult()
        q.add("b", listOf(SCAN))
        assertTrue(q.expire(old).resolved.isEmpty())
        granted.add(SCAN); assertEquals(listOf("b" to true), q.onResult().resolved)
    }

    @Test fun h3RaceWhereNothingIsMissingStillResolves() {
        granted.clear(); granted.add(CONN); val q = q()
        assertNull(q.add("a", listOf(CONN)))
        assertEquals(listOf("a" to true), q.drainLate()); assertTrue(q.drainLate().isEmpty())
    }

    @Test fun h3LateSystemResponseAfterTimeoutIsHarmless() {
        granted.clear(); val q = q(); q.add("a", listOf(CONN)); q.expire(q.generation)
        val r = q.onResult(); assertTrue(r.resolved.isEmpty()); assertNull(r.next)
    }
}

class AutoMeasureRulesTest {
    @org.junit.Test fun intervals() {
        org.junit.Assert.assertEquals(30, AutoMeasureRules.safeInterval(30, 10))
        org.junit.Assert.assertNull(AutoMeasureRules.safeInterval(25, 10))
        org.junit.Assert.assertNull(AutoMeasureRules.safeInterval(5, 10))
        org.junit.Assert.assertNull(AutoMeasureRules.safeInterval(300, 10))
        org.junit.Assert.assertNull(AutoMeasureRules.safeInterval(10, 0))
    }
}
