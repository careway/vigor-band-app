package com.careway.vigor_app

/** Logica pura (sin Android) para las fases de una sesion de sueno de Health Connect; probada con JUnit en la JVM. */
object SleepStagesRules {
    /** Tipos de fase de Health Connect (SleepSessionRecord.STAGE_TYPE_*): 1 despierto, 4 ligero, 5 profundo, 6 REM. */
    val VALID_TYPES = setOf(1, 4, 5, 6)
    const val MAX_STAGES = 2000

    /**
     * Normaliza fases [inicioMs, finMs, tipo] para una sesion [startMs, endMs]: recorta a la sesion, descarta las de
     * duracion cero, de tipo desconocido o que se solapan con la anterior (ya ordenadas), y limita su numero.
     * Devuelve una lista vacia si no queda ninguna valida (entonces no se escribe la sesion con fases).
     */
    fun sanitize(startMs: Long, endMs: Long, raw: List<List<Long>>): List<Triple<Long, Long, Int>> {
        if (endMs <= startMs) return emptyList()
        val out = ArrayList<Triple<Long, Long, Int>>()
        var cursor = startMs
        for (r in raw.sortedBy { if (it.size >= 3) it[0] else Long.MAX_VALUE }) {
            if (r.size < 3) continue
            val type = r[2].toInt()
            if (type !in VALID_TYPES) continue
            val a = maxOf(r[0], startMs, cursor); val b = minOf(r[1], endMs)
            if (b <= a) continue
            out.add(Triple(a, b, type)); cursor = b
            if (out.size >= MAX_STAGES) break
        }
        return out
    }
}
