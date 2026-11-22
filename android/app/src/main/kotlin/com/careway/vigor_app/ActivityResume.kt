package com.careway.vigor_app

/** Logica pura (probada con JUnit): ¿hay que retomar el seguimiento de una actividad que la pulsera ya tiene en curso al (re)conectar? */
object ActivityResume {
    /** Si la pulsera dice «ocupada» o «iniciada antes» (asi responde con una actividad en marcha) y el tipo es valido. Si ya no corre, el sondeo falla y se abandona solo. */
    fun shouldResume(deviceState: String, typeValue: Int) = (deviceState == "DEVICE_BUSY" || deviceState == "DEVICE_HAD_START_BEFORE") && typeValue > 0
}
