package com.careway.vigor_app

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings

/**
 * Xiaomi/MIUI impide arrancar una app cerrada desde WorkManager si no tiene el permiso «Inicio automatico»
 * (registro del sistema: "MIUI ... Reject service ... SystemJobService"). Abre esa pantalla; si no existe, la ficha de la app.
 * No concede nada por su cuenta: solo lleva al usuario a donde lo decide.
 */
object MiuiAutostart {
    private val BRANDS = setOf("xiaomi", "redmi", "poco")
    private fun component() = ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")

    /** Modo de AppOps → permitido? MODE_ALLOWED (0) sí; MODE_IGNORED (1) y MODE_ERRORED (2) no; cualquier otro valor o nulo: desconocido. */
    fun interpret(mode: Int?): Boolean? = when (mode) { 0 -> true; 1, 2 -> false; else -> null }

    fun isXiaomiBrand(manufacturer: String?): Boolean = (manufacturer ?: "").lowercase() in BRANDS

    fun supported(ctx: Context): Boolean {
        if (!isXiaomiBrand(Build.MANUFACTURER)) return false
        return try { ctx.packageManager.resolveActivity(Intent().setComponent(component()), 0) != null } catch (_: Throwable) { false }
    }

    /** "autostart" si abrio la pantalla de inicio automatico, "details" si abrio la ficha de la app, "none" si no pudo. */
    fun open(ctx: Context): String {
        try { if (supported(ctx)) { ctx.startActivity(Intent().setComponent(component()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); return "autostart" } } catch (_: Throwable) {}
        return try {
            ctx.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + ctx.packageName)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); "details"
        } catch (_: Throwable) { "none" }
    }
}
