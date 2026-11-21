package com.careway.vigor_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SleepStagesRulesTest {
    private val s = 1_000_000L; private val e = 1_000_000L + 600_000L
    @Test fun valid_stages_pass_through_sorted() {
        val r = SleepStagesRules.sanitize(s, e, listOf(listOf(s + 120_000, s + 240_000, 5L), listOf(s, s + 120_000, 4L)))
        assertEquals(listOf(Triple(s, s + 120_000, 4), Triple(s + 120_000, s + 240_000, 5)), r)
    }
    @Test fun clips_to_session_and_drops_unknown_zero_and_overlap() {
        val r = SleepStagesRules.sanitize(s, e, listOf(
            listOf(s - 60_000, s + 60_000, 4L),        // se recorta al inicio
            listOf(s + 30_000, s + 90_000, 5L),        // solapa: se recorta tras la anterior
            listOf(s + 90_000, s + 90_000, 6L),        // duracion cero
            listOf(s + 100_000, s + 200_000, 2L),      // tipo desconocido (2 = durmiendo)
            listOf(e - 30_000, e + 90_000, 1L)))       // se recorta al final
        assertEquals(listOf(Triple(s, s + 60_000, 4), Triple(s + 60_000, s + 90_000, 5), Triple(e - 30_000, e, 1)), r)
    }
    @Test fun empty_when_nothing_valid_or_bad_session() {
        assertTrue(SleepStagesRules.sanitize(s, e, listOf(listOf(s, s + 1000, 9L))).isEmpty())
        assertTrue(SleepStagesRules.sanitize(e, s, listOf(listOf(s, e, 4L))).isEmpty())
        assertTrue(SleepStagesRules.sanitize(s, e, listOf(listOf(s))).isEmpty())
    }
    @Test fun caps_number_of_stages() {
        val raw = (0 until 3000).map { listOf(s + it * 100L, s + it * 100L + 100, if (it % 2 == 0) 4L else 5L) }
        assertEquals(SleepStagesRules.MAX_STAGES, SleepStagesRules.sanitize(s, s + 400_000, raw).size)
    }
}
