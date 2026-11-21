package com.careway.vigor_app

/** Logica pura (sin Android) de la escritura por lotes en Health Connect; probada con JUnit en la JVM. */
object HealthBatchRules {
    /** Registros por llamada a insertRecords. Google permite 1000; se usa menos por el limite de memoria de inserciones en bloque. */
    const val CHUNK = 500

    /** Tipos con intervalo (inicio < fin obligatorio) frente a puntuales. Nombres = HType de Dart. */
    val INTERVAL = setOf("steps", "distance", "activeEnergy", "heartRate")
    val POINT = setOf("hrvRmssd", "restingHr", "spo2", "bodyTemp")

    /**
     * Valida un dato antes de construir el registro: Health Connect rechaza el LOTE ENTERO si un solo registro es invalido,
     * asi que los invalidos se descartan uno a uno (rangos de los registros de Health Connect).
     */
    fun valid(type: String, value: Double, startMs: Long, endMs: Long): Boolean {
        if (!value.isFinite()) return false
        if (type in INTERVAL && endMs <= startMs) return false
        return when (type) {
            "steps" -> value >= 1 && value <= 1_000_000
            "distance" -> value > 0 && value <= 1_000_000
            "activeEnergy" -> value >= 0 && value <= 1_000_000
            "heartRate", "restingHr" -> value >= 1 && value <= 300
            "spo2" -> value >= 0 && value <= 100
            "hrvRmssd" -> value >= 1 && value <= 200
            "bodyTemp" -> value >= 0 && value <= 100
            else -> false
        }
    }

    /** true si el mensaje de una excepcion indica cuota agotada (la excepcion no tiene una clase publica estable). */
    fun isRateLimit(msg: String?): Boolean {
        val m = (msg ?: "").lowercase()
        return m.contains("rate limit") || m.contains("quota")
    }
}
