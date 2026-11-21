package com.careway.vigor_app

/**
 * Logica pura (sin Android) de la respuesta a la peticion de GPS de la pulsera; probada con JUnit en la JVM.
 * La pulsera pide (cada ~5 s durante una actividad con GPS) que la app le mande la posicion y la hora aproximadas del movil: acelera mucho el primer fijado.
 */
object GpsAssistRules {
    /** Una posicion conocida de hasta 6 h sirve de ayuda (basta una posicion aproximada: unas decenas de km). */
    const val MAX_AGE_MS = 6 * 3600_000L
    /** Hasta 10 min se considera «normal»; entre 10 min y 6 h, «debil» (posicion antigua pero util). */
    const val FRESH_MS = 10 * 60_000L
    /** Como maximo una respuesta cada 4 s (la pulsera pregunta cada ~5 s). */
    const val MIN_GAP_MS = 4000L

    enum class Status { NORMAL, WEAK, CLOSED }

    /** Sin permiso o sin posicion utilizable: «GPS_PERMISSION_CLOSE» (la pulsera sabe que no hay ayuda). */
    fun status(hasPermission: Boolean, ageMs: Long?): Status = when {
        !hasPermission || ageMs == null || ageMs < 0 || ageMs > MAX_AGE_MS -> Status.CLOSED
        ageMs <= FRESH_MS -> Status.NORMAL
        else -> Status.WEAK
    }

    fun shouldReply(nowMs: Long, lastMs: Long) = nowMs - lastMs >= MIN_GAP_MS

    /** Zona horaria en horas respecto a UTC (la unidad que espera la pulsera no esta documentada: se envian horas). */
    fun timeZoneHours(offsetMs: Int): Short = (offsetMs / 3_600_000).toShort()

    /** Latitud y longitud validas (no 0,0, no NaN, en rango). */
    fun validCoords(lat: Double, lon: Double) = lat.isFinite() && lon.isFinite() && lat in -90.0..90.0 && lon in -180.0..180.0 && !(lat == 0.0 && lon == 0.0)
}
