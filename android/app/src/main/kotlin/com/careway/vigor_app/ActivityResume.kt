package com.careway.vigor_app

/** Logica pura (probada con JUnit): ¿hay que retomar el seguimiento de una actividad que la pulsera ya tiene en curso al (re)conectar? */
object ActivityResume {
    /** Solo si la pulsera dice «ocupada» (hay una actividad en marcha) y el tipo es valido. «Abierta antes» es ambiguo y no se retoma. */
    fun shouldResume(deviceState: String, typeValue: Int) = deviceState == "DEVICE_BUSY" && typeValue > 0
}
