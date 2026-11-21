package com.careway.vigor_app

import android.content.Context
import android.os.Handler
import android.os.Looper
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * La libreria Bluetooth de la pulsera (inuker) exige crearse en el HILO PRINCIPAL: BandClient crea sus escuchas al inicializarse
 * (initializer estatico) y, desde un trabajo de WorkManager (otro hilo), fallaba con IllegalStateException y el trabajo terminaba en FAILURE.
 * Este objeto NO toca BandClient en el hilo del llamador: lo inicializa en el principal y espera. Usarlo siempre en trabajos en segundo plano.
 */
object BandBoot {
    /** true si BandClient quedo inicializado. Bloquea al llamador hasta [timeoutSec] (solo hilos de fondo o el principal). */
    fun ensure(ctx: Context, timeoutSec: Long = 15): Boolean {
        val app = ctx.applicationContext
        if (Looper.myLooper() == Looper.getMainLooper()) return try { BandClient.init(app); true } catch (_: Throwable) { false }
        val latch = CountDownLatch(1); val ok = AtomicBoolean(false)
        Handler(Looper.getMainLooper()).post { try { BandClient.init(app); ok.set(true) } catch (_: Throwable) { ok.set(false) } finally { latch.countDown() } }
        return try { latch.await(timeoutSec, TimeUnit.SECONDS) && ok.get() } catch (_: InterruptedException) { Thread.currentThread().interrupt(); false }
    }
}
