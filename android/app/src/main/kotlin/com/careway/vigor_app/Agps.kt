package com.careway.vigor_app

import android.content.Context
import android.util.Log
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.veepoo.protocol.listener.data.IUIBaseInfoFormAGPSListener
import com.veepoo.protocol.listener.data.IUiUpdateListener
import com.veepoo.protocol.listener.oad.OnDownLoadListener
import com.veepoo.protocol.model.datas.UIDataAGPS
import com.veepoo.protocol.model.enums.EUIFromType
import com.veepoo.protocol.model.enums.EUiUpdateError
import com.veepoo.protocol.util.UiServerHttpUtil
import com.veepoo.protocol.util.UiUpdateUtil
import java.io.File
import java.io.FileInputStream
import java.util.Locale
import java.util.TimeZone
import androidx.work.ListenableWorker
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import android.os.Handler
import android.os.Looper

/**
 * Efemerides GPS en segundo plano y en silencio (sin UI ni notificaciones):
 *  1) cada ~6 h un trabajo comprueba si hay descarga pendiente del dia; si hace falta, descarga el fichero y lo guarda;
 *  2) con el fichero guardado "pendiente", cuando la pulsera esta a mano (sesion abierta o conexion por MAC guardada)
 *     lo transfiere y marca la tarea como hecha.
 */
object Agps {
    private const val TAG = "VIGORLOG"
    private const val TRANSFER_TIMEOUT_MS = 200_000L
    /** Hilo unico para descargas lanzadas desde la app (nada de hilos sueltos). */
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var transferring = false
    enum class Transfer { OK, UNSUPPORTED, LOW_BATTERY, FAILED }
    private fun dbg(s: String) { if (BandClient.debuggable) Log.i(TAG, s) }
    private fun prefs() = BandClient.app.getSharedPreferences("agps", Context.MODE_PRIVATE)
    fun file() = File(File(BandClient.app.filesDir, "agps"), "vp_agps.pgl")
    val pending get() = prefs().getBoolean("pending", false)

    fun status(): Map<String, Any?> = mapOf(
        "downloadedAt" to prefs().getLong("downloadedAt", 0),
        "transferredAt" to prefs().getLong("transferredAt", 0),
        "pending" to pending,
        "lastError" to (prefs().getString("lastError", "") ?: ""), // se borra al descargar/transferir con exito o al borrar datos
        "nextTryAt" to prefs().getLong("nextTryAt", 0))

    /** true si un fallo permanente (p. ej. la pulsera no lo soporta) pide esperar antes de reintentar. */
    fun inBackoff() = AgpsRules.inBackoff(System.currentTimeMillis(), prefs().getLong("nextTryAt", 0))

    private fun isChina() = Locale.getDefault().country == "CN" || TimeZone.getDefault().id == "Asia/Shanghai"

    fun schedule(ctx: Context) {
        val req = PeriodicWorkRequestBuilder<AgpsWorker>(6, TimeUnit.HOURS)
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()).build()
        WorkManager.getInstance(ctx).enqueueUniquePeriodicWork("agps", ExistingPeriodicWorkPolicy.KEEP, req)
    }

    /** El fichero descargado debe tener un tamano minimo y no ser una pagina de error (HTML/XML/JSON de texto). */
    internal fun looksValid(f: File): Boolean = AgpsRules.looksValid(f)

    /** Bloqueante y con cerrojo (una descarga a la vez): solo hilos de fondo. Devuelve true si hay un fichero valido (nuevo o reciente). */
    @Synchronized fun downloadIfDue(): Boolean {
        val p = prefs(); val f = file()
        if (AgpsRules.isFresh(looksValid(f), System.currentTimeMillis(), p.getLong("downloadedAt", 0))) return true
        f.parentFile?.mkdirs()
        // N6: .tmp huerfanos de descargas anteriores (el SDK puede recrearlos tras un timeout). Con @Synchronized no hay otra descarga en curso.
        f.parentFile?.listFiles { x -> x.name.startsWith("vp_agps.") && x.name.endsWith(".tmp") }?.forEach { it.delete() }
        val tmp = File(f.parentFile, "vp_agps.${System.currentTimeMillis()}.tmp"); tmp.delete()
        val latch = CountDownLatch(1)
        try {
            UiServerHttpUtil().downLoadAGpsFile(isChina(), tmp.absolutePath, object : OnDownLoadListener {
                override fun onProgress(progress: Float) {}
                override fun onFinish() { latch.countDown() }
            })
        } catch (e: Throwable) { tmp.delete(); p.edit().putString("lastError", "descarga: ${e.javaClass.simpleName}").apply(); return false }
        val finished = latch.await(120, TimeUnit.SECONDS)
        if (!finished) { tmp.delete(); try { tmp.deleteOnExit() } catch (_: Throwable) {}; p.edit().putString("lastError", "descarga: tiempo agotado").apply(); return false }
        if (!looksValid(tmp)) { tmp.delete(); p.edit().putString("lastError", "descarga invalida o vacia").apply(); return false }
        if (!tmp.renameTo(f)) { tmp.delete(); p.edit().putString("lastError", "no se pudo guardar la descarga").apply(); return false }
        p.edit().putLong("downloadedAt", System.currentTimeMillis()).putBoolean("pending", true).putString("lastError", "").apply()
        dbg("Efemerides descargadas (${f.length()} bytes)")
        return true
    }

    /** En hilo principal, de una en una, con timeout propio. [done] se llama exactamente una vez. */
    fun transfer(done: (Transfer) -> Unit) {
        val f = file()
        if (!looksValid(f)) { done(Transfer.FAILED); return }
        if (transferring) { done(Transfer.FAILED); return }
        transferring = true
        val fin = AtomicBoolean(false)
        var stream: FileInputStream? = null
        lateinit var to: Runnable
        val finish: (Transfer, String?) -> Unit = { r, why ->
            if (fin.compareAndSet(false, true)) {
                main.removeCallbacks(to); transferring = false
                try { stream?.close() } catch (_: Exception) {}
                when (r) {
                    Transfer.OK -> markTransferred()
                    Transfer.UNSUPPORTED -> prefs().edit().putString("lastError", why ?: "la pulsera no admite efemerides").putLong("nextTryAt", AgpsRules.nextTryAfterUnsupported(System.currentTimeMillis())).apply()
                    else -> if (why != null) prefs().edit().putString("lastError", why).apply()
                }
                done(r)
            }
        }
        to = Runnable { finish(Transfer.FAILED, "transferencia: tiempo agotado") }
        main.postDelayed(to, TRANSFER_TIMEOUT_MS)
        BandClient.readBatteryThen {
            if (fin.get()) return@readBatteryThen
            if (BandClient.battery in 0..29) { dbg("Efemerides: bateria baja, se pospone"); finish(Transfer.LOW_BATTERY, "bateria baja"); return@readBatteryThen }
            val u = UiUpdateUtil.getInstance()
            try { u.init(BandClient.app) } catch (e: Throwable) { dbg("UiUpdateUtil.init: ${e.javaClass.simpleName}") }
            val ok = try { u.isSupportChangeCustomAGPS() } catch (e: Throwable) { false }
            if (!ok) { dbg("Efemerides: la pulsera no lo soporta"); finish(Transfer.UNSUPPORTED, "la pulsera no admite efemerides (se reintenta en 24 h)"); return@readBatteryThen }
            try {
                u.getAGPSWacthUiInfo(object : IUIBaseInfoFormAGPSListener {
                    override fun onBaseUiInfoFormAgps(info: UIDataAGPS) {
                        main.post {
                            if (fin.get()) return@post
                            dbg("AGPS pulsera: info recibida")
                            try {
                                u.setAGPSTimeStamp(0)
                                stream = FileInputStream(f)
                                u.startSetUiStream(EUIFromType.A_GPS, stream, object : IUiUpdateListener {
                                    override fun onUiUpdateStart() {}
                                    override fun onStartClearCache(sumCount: Int) {}
                                    override fun onClearCacheProgress(currentCount: Int, sumCount: Int, progress: Int) {}
                                    override fun onFinishClearCache() {}
                                    override fun onUiUpdateProgress(currentBlock: Int, sumBlock: Int, progress: Int) {}
                                    override fun onUiUpdateSuccess() { main.post { dbg("Efemerides transferidas"); finish(Transfer.OK, null) } }
                                    override fun onUiUpdateFail(e: EUiUpdateError?) { main.post { finish(Transfer.FAILED, "transferencia: $e") } }
                                })
                            } catch (e: Throwable) { finish(Transfer.FAILED, "transferencia: ${e.javaClass.simpleName}") }
                        }
                    }
                })
            } catch (e: Throwable) { finish(Transfer.FAILED, "transferencia: ${e.javaClass.simpleName}") }
        }
    }

    private fun markTransferred() { prefs().edit().putBoolean("pending", false).putLong("transferredAt", System.currentTimeMillis()).putLong("nextTryAt", 0).putString("lastError", "").apply() }

    /** Llamado tras sincronizar cuando la app tiene sesion: descarga (hilo de fondo) y SOLO si termino bien transfiere. */
    fun onConnected() {
        if (!pending || inBackoff()) return
        io.execute {
            val ok = downloadIfDue()
            main.post {
                BandClient.emit(emptyMap())
                if (ok && pending && BandClient.connected) transfer { BandClient.emit(emptyMap()) }
            }
        }
    }

    /** Llamado por el trabajo periodico: devuelve el Result adecuado. */
    fun workerRun(attempt: Int): ListenableWorker.Result {
        BandClient.init(BandClient.app)
        val retryOrDone = { if (AgpsRules.shouldRetry(attempt)) ListenableWorker.Result.retry() else ListenableWorker.Result.success() }
        if (inBackoff()) return ListenableWorker.Result.success()
        if (!downloadIfDue()) return retryOrDone()
        if (!pending) return ListenableWorker.Result.success()
        val res = java.util.concurrent.atomic.AtomicReference(Transfer.FAILED)
        val s = BandClient.runSessionBlocking(300) { done -> transfer { r -> res.set(r); done() } }
        return when (s) {
            BandClient.Session.NO_SESSION, BandClient.Session.TIMEOUT -> retryOrDone()
            BandClient.Session.DONE -> when (res.get()) {
                Transfer.OK, Transfer.UNSUPPORTED, Transfer.LOW_BATTERY -> ListenableWorker.Result.success()
                Transfer.FAILED -> retryOrDone()
            }
        }
    }
}

class AgpsWorker(ctx: Context, p: WorkerParameters) : Worker(ctx, p) {
    override fun doWork(): Result {
        if (!BandBoot.ensure(applicationContext)) return Result.success() // sin cliente Bluetooth (hilo principal) no hay nada que hacer: reintenta el siguiente periodo
        return try { Agps.workerRun(runAttemptCount) } catch (e: Throwable) { if (BandClient.debuggable) Log.w("VIGORLOG", "AgpsWorker: ${e.javaClass.simpleName}"); if (AgpsRules.shouldRetry(runAttemptCount)) Result.retry() else Result.failure() }
    }
}
