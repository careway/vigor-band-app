package com.careway.vigor_app

/** Logica pura (sin Android) de los permisos de ejecucion que Vigor explica y pide al arrancar; probada con JUnit en la JVM. */
object StartupPermissions {
    enum class Group(val wire: String) { BLUETOOTH("bluetooth"), LOCATION("location") }

    const val SCAN = "android.permission.BLUETOOTH_SCAN"
    const val CONNECT = "android.permission.BLUETOOTH_CONNECT"
    const val FINE_LOCATION = "android.permission.ACCESS_FINE_LOCATION"

    /** Android 12 o posterior: Bluetooth (buscar y conectar). Android 11 o anterior: la ubicacion que exige el escaneo BLE. */
    fun required(sdk: Int): Map<Group, List<String>> =
        if (sdk >= 31) mapOf(Group.BLUETOOTH to listOf(SCAN, CONNECT)) else mapOf(Group.LOCATION to listOf(FINE_LOCATION))

    fun missing(sdk: Int, isGranted: (String) -> Boolean): List<Group> =
        required(sdk).filter { (_, perms) -> perms.any { !isGranted(it) } }.keys.toList()

    /**
     * El sistema ya no mostrara su dialogo: se pidio antes y, para cada permiso que falta, Android no ofrece explicacion
     * (denegado con "no volver a preguntar"). Entonces solo se puede ir a los ajustes de la app.
     */
    fun blocked(sdk: Int, asked: Boolean, isGranted: (String) -> Boolean, showRationale: (String) -> Boolean): Boolean {
        if (!asked) return false
        val missingPerms = required(sdk).values.flatten().filter { !isGranted(it) }
        return missingPerms.isNotEmpty() && missingPerms.none { showRationale(it) }
    }
}
