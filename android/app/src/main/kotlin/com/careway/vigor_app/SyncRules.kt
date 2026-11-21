package com.careway.vigor_app

/** Logica pura (sin Android) de la sincronizacion automatica en segundo plano, para probarla con JUnit sin pulsera. */
object SyncRules {
    val INTERVALS = listOf(15, 30, 60)
    const val DEFAULT_MIN = 30
    /** Tiempo maximo de una pasada del trabajo (conexion + lectura). */
    const val SYNC_TIMEOUT_SEC = 240L
    /** Tiempo maximo de la exportacion a Health Connect sin interfaz. */
    const val EXPORT_TIMEOUT_SEC = 180L

    /** Minutos de intervalo validos (15 / 30 / 60); cualquier otro valor cae al predeterminado. WorkManager no admite menos de 15. */
    fun safeInterval(m: Int?): Int = if (m != null && m in INTERVALS) m else DEFAULT_MIN

    enum class Gate { RUN, DISABLED, SCREEN_OFF, NO_PERMISSION, NO_MAC }

    /** Orden de las puertas: interruptor del usuario, permiso de Bluetooth, pulsera guardada. Si no es RUN no se carga el SDK ni se toca Bluetooth. */
    fun gate(enabled: Boolean, hasConnectPermission: Boolean, hasMac: Boolean, screenOnly: Boolean = false, interactive: Boolean = true): Gate = when {
        !enabled -> Gate.DISABLED
        screenOnly && !interactive -> Gate.SCREEN_OFF
        !hasConnectPermission -> Gate.NO_PERMISSION
        !hasMac -> Gate.NO_MAC
        else -> Gate.RUN
    }

    /** Si la ultima sincronizacion buena es mas reciente que la mitad del intervalo, el trabajo no despierta la pulsera (la app abierta ya la mantiene al dia). */
    fun recentEnough(now: Long, lastOkAt: Long, intervalMin: Int): Boolean =
        lastOkAt > 0 && now >= lastOkAt && now - lastOkAt < safeInterval(intervalMin) * 60_000L / 2

    /** Exportar a Health Connect sin la app: solo con el interruptor general encendido, datos nuevos sin enviar, sin la app abierta y con el interruptor interno de este modo. */
    fun exportNeeded(hcOn: Boolean, dirty: Boolean, appOpen: Boolean, bgExportEnabled: Boolean): Boolean = hcOn && dirty && !appOpen && bgExportEnabled

    /** Antes de cada etapa larga: con «solo pantalla encendida» y la pantalla apagada se aborta limpiamente. */
    fun mayContinue(screenOnly: Boolean, interactive: Boolean): Boolean = !screenOnly || interactive

    /** Politica de reintentos: nunca Result.retry. Si la pulsera no esta o la pasada falla, la siguiente ocurre en el siguiente periodo (>= 15 min); asi no hay tormentas de reintentos. */
    const val RETRY = false

    /** Texto corto sin datos personales para el estado de la ultima pasada. */
    fun label(session: String, synced: Boolean, export: String?): String = listOfNotNull(session, if (synced) "SYNC" else null, export?.let { "HC_$it" }).joinToString("+")
}
