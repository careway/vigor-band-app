package com.careway.vigor_app

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/** Ajustes y estado de la sincronizacion automatica (fichero propio "vigor_sync"; sin datos de salud ni MAC). */
object SyncPrefs {
    fun p(c: Context) = c.getSharedPreferences("vigor_sync", Context.MODE_PRIVATE)
    fun enabled(c: Context) = p(c).getBoolean("enabled", true)
    fun minutes(c: Context) = SyncRules.safeInterval(p(c).getInt("minutes", SyncRules.DEFAULT_MIN))
    fun screenOnly(c: Context) = p(c).getBoolean("screenOnly", true)
    /** Interruptor interno de la exportacion a Health Connect sin la app (activado de serie por decision del usuario). */
    fun bgExport(c: Context) = p(c).getBoolean("bgExport", true)
    fun lastOkAt(c: Context) = p(c).getLong("lastOkAt", 0)
    fun dirty(c: Context) = p(c).getBoolean("hcDirty", false)
    fun markSynced(c: Context, at: Long, appOpen: Boolean) { p(c).edit().putLong("lastOkAt", at).also { if (!appOpen) it.putBoolean("hcDirty", true) }.apply() }
    fun clearDirty(c: Context) { p(c).edit().putBoolean("hcDirty", false).apply() }
    fun record(c: Context, label: String) { p(c).edit().putLong("bgAt", System.currentTimeMillis()).putString("bgResult", label).apply() }
    fun wipe(c: Context) { p(c).edit().remove("lastOkAt").remove("hcDirty").remove("bgAt").remove("bgResult").apply() }
    fun info(c: Context): Map<String, Any?> = mapOf("enabled" to enabled(c), "minutes" to minutes(c), "screenOnly" to screenOnly(c), "bgExport" to bgExport(c),
        "lastOkAt" to lastOkAt(c), "dirty" to dirty(c), "bgAt" to p(c).getLong("bgAt", 0), "bgResult" to (p(c).getString("bgResult", "") ?: ""))
    fun hcOn(c: Context) = c.getSharedPreferences("vigor_prefs", Context.MODE_PRIVATE).getInt("hcOn", 0) == 1
}

object SyncScheduler {
    const val NAME = "vigor_sync"
    /** [replace]=true cuando el usuario cambia el intervalo; en el arranque se conserva el calendario existente. */
    fun apply(c: Context, replace: Boolean) {
        val wm = WorkManager.getInstance(c)
        if (!SyncPrefs.enabled(c)) { wm.cancelUniqueWork(NAME); return }
        val req = PeriodicWorkRequestBuilder<SyncWorker>(SyncPrefs.minutes(c).toLong(), TimeUnit.MINUTES)
            .setConstraints(Constraints.Builder().setRequiresBatteryNotLow(true).build()).build()
        wm.enqueueUniquePeriodicWork(NAME, if (replace) ExistingPeriodicWorkPolicy.UPDATE else ExistingPeriodicWorkPolicy.KEEP, req)
    }
}

/** Sincronizacion periodica con la app cerrada: pulsera -> movil y, si procede, movil -> Health Connect. Nunca pide reintento (ver SyncRules.RETRY). */
class SyncWorker(ctx: Context, p: WorkerParameters) : Worker(ctx, p) {
    private fun interactive(): Boolean = (applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive
    private fun hasPerm(): Boolean = Build.VERSION.SDK_INT < 31 || applicationContext.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    override fun doWork(): Result {
        val c = applicationContext
        val screenOnly = SyncPrefs.screenOnly(c)
        val mac = c.getSharedPreferences("vigor", Context.MODE_PRIVATE).getString("mac", null)
        val gate = SyncRules.gate(SyncPrefs.enabled(c), hasPerm(), mac != null, screenOnly, interactive())
        if (gate != SyncRules.Gate.RUN) { SyncPrefs.record(c, gate.name); return Result.success() } // sin cargar el SDK ni tocar Bluetooth
        val th = Thread.currentThread()
        val rcv = object : BroadcastReceiver() { override fun onReceive(x: Context?, i: Intent?) { if (screenOnly) th.interrupt() } }
        try { c.registerReceiver(rcv, IntentFilter(Intent.ACTION_SCREEN_OFF)) } catch (_: Throwable) {} // en ejecucion, no en el manifiesto
        var session = "SKIP"; var synced = false; var export: String? = null
        try {
            if (!BandBoot.ensure(c)) { session = "ERROR" } else {
            if (SyncRules.recentEnough(System.currentTimeMillis(), SyncPrefs.lastOkAt(c), SyncPrefs.minutes(c))) session = "RECENT"
            else {
                val before = SyncPrefs.lastOkAt(c)
                session = BandClient.runSessionBlocking(SyncRules.SYNC_TIMEOUT_SEC) { done -> BandClient.syncAll(keepHeadless = true) { done() } }.name
                synced = SyncPrefs.lastOkAt(c) != before
            }
            val appOpen = BandClient.listener != null
            if (SyncRules.mayContinue(screenOnly, interactive()) && SyncRules.exportNeeded(SyncPrefs.hcOn(c), SyncPrefs.dirty(c), appOpen, SyncPrefs.bgExport(c)))
                export = BackgroundExport.runBlocking(c, SyncRules.EXPORT_TIMEOUT_SEC)
            }
        } catch (e: Throwable) { session = "ERROR" }
        finally { try { c.unregisterReceiver(rcv) } catch (_: Throwable) {}; Thread.interrupted() }
        val label = SyncRules.label(session, synced, export)
        SyncPrefs.record(c, label)
        try { if (BandClient.debuggable) Log.i("VIGORLOG", "SyncWorker $label") } catch (_: Throwable) {} // BandClient puede no haberse inicializado
        return Result.success()
    }
}
