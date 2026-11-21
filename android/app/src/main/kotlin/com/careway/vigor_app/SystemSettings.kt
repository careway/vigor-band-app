package com.careway.vigor_app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings

/**
 * Ajustes del sistema que NO se piden como un permiso normal (no hay ventana de «permitir»), pero SI se pueden consultar y se puede
 * llevar al usuario directo a su pantalla: instalar apps desconocidas, excepcion de optimizacion de bateria e inicio automatico de MIUI.
 * Vigor nunca los concede por su cuenta: solo consulta su estado y abre la pantalla donde el usuario decide.
 */
object SystemSettings {
    /** Operacion de AppOps de MIUI para «Inicio automatico» (no es publica; se consulta por reflexion y, si falla, el estado es desconocido). */
    const val MIUI_AUTOSTART_OP = 10008

    fun canInstallApps(ctx: Context): Boolean = Build.VERSION.SDK_INT < 26 || ctx.packageManager.canRequestPackageInstalls()

    fun batteryUnrestricted(ctx: Context): Boolean = try {
        (ctx.getSystemService(Context.POWER_SERVICE) as PowerManager).isIgnoringBatteryOptimizations(ctx.packageName)
    } catch (_: Throwable) { false }

    /** true permitido, false no permitido, null desconocido o no aplicable (no es Xiaomi / la reflexion no funciona en esta version). */
    fun autostart(ctx: Context): Boolean? {
        if (!MiuiAutostart.isXiaomiBrand(Build.MANUFACTURER)) return null
        return try {
            val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val m = AppOpsManager::class.java.getMethod("checkOpNoThrow", Int::class.javaPrimitiveType, Int::class.javaPrimitiveType, String::class.java)
            MiuiAutostart.interpret(m.invoke(ops, MIUI_AUTOSTART_OP, Process.myUid(), ctx.packageName) as? Int)
        } catch (_: Throwable) { null }
    }

    fun status(ctx: Context): Map<String, Any?> = mapOf(
        "installApps" to canInstallApps(ctx), "batteryUnrestricted" to batteryUnrestricted(ctx),
        "autostart" to autostart(ctx), "xiaomi" to MiuiAutostart.supported(ctx))

    private fun start(ctx: Context, i: Intent): Boolean = try { ctx.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); true } catch (_: Throwable) { false }
    private fun appDetails(ctx: Context) = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + ctx.packageName))

    /** Abre la pantalla de [which] (installApps | battery | autostart | details). Devuelve cual abrio: "direct", "list", "details" o "none". */
    fun open(ctx: Context, which: String): String = when (which) {
        "installApps" ->
            if (start(ctx, Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + ctx.packageName)))) "direct"
            else if (start(ctx, appDetails(ctx))) "details" else "none"
        "battery" ->
            // Ventana directa «¿permitir que Vigor se ejecute sin restricciones?»; si el sistema no la ofrece, la lista de optimizacion; y si no, la ficha de la app.
            if (start(ctx, Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:" + ctx.packageName)))) "direct"
            else if (start(ctx, Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))) "list"
            else if (start(ctx, appDetails(ctx))) "details" else "none"
        "autostart" -> when (MiuiAutostart.open(ctx)) { "autostart" -> "direct"; "details" -> "details"; else -> "none" }
        "details" -> if (start(ctx, appDetails(ctx))) "details" else "none"
        else -> "none"
    }
}
