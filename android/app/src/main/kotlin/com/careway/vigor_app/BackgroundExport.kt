package com.careway.vigor_app

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * Exportacion a Health Connect sin interfaz: un FlutterEngine propio ejecuta `vigorBackgroundExport` (lib/background_export.dart), que usa
 * el mismo HealthSync de la app (libro, lotes, marca de agua e interruptor general). Su canal "vigor/methods" es SOLO el de este motor
 * y atiende unicamente lo necesario; el de MainActivity no se toca.
 */
object BackgroundExport {
    private val running = AtomicBoolean(false)
    private val main = Handler(Looper.getMainLooper())

    /** Bloquea el hilo llamador (solo de fondo). Devuelve OK, PARTIAL, NO_PERMISSION, OFF, BUSY, TIMEOUT, ENGINE_FAIL, ERROR... */
    fun runBlocking(ctx: Context, timeoutSec: Long): String {
        if (!running.compareAndSet(false, true)) return "BUSY"
        val latch = CountDownLatch(1); val code = AtomicReference("TIMEOUT"); val engine = AtomicReference<FlutterEngine?>(null)
        main.post {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(ctx); loader.ensureInitializationComplete(ctx, null)
                val e = FlutterEngine(ctx); engine.set(e)
                val bm = e.dartExecutor.binaryMessenger
                MethodChannel(bm, "vigor/bg").setMethodCallHandler { call, res ->
                    if (call.method == "done") { code.set(call.argument<String>("code") ?: "ERROR"); res.success(null); latch.countDown() } else res.notImplemented()
                }
                MethodChannel(bm, "vigor/methods").setMethodCallHandler { call, res -> try { handle(ctx, call, res) } catch (t: Throwable) { res.error("BG", t.javaClass.simpleName, null) } }
                e.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "package:vigor_app/background_export.dart", "vigorBackgroundExport"))
            } catch (t: Throwable) { code.set("ENGINE_FAIL"); latch.countDown() }
        }
        try { if (!latch.await(timeoutSec, TimeUnit.SECONDS)) code.set("TIMEOUT") } catch (e: InterruptedException) { code.set("INTERRUPTED"); Thread.currentThread().interrupt() }
        val gone = CountDownLatch(1)
        main.post { try { engine.get()?.destroy() } catch (_: Throwable) {}; running.set(false); gone.countDown() }
        try { gone.await(5, TimeUnit.SECONDS) } catch (_: InterruptedException) {}
        return code.get()
    }

    private fun reply(res: MethodChannel.Result, v: Any?) { main.post { try { res.success(v) } catch (_: Throwable) {} } }

    /** Lista cerrada de llamadas que necesita HealthSync + VigorRepo.reload. Todo lo demas: notImplemented. */
    private fun handle(ctx: Context, call: MethodCall, res: MethodChannel.Result) {
        val store = BandClient.store
        when (call.method) {
            "getPrefs" -> res.success(ctx.getSharedPreferences("vigor_prefs", Context.MODE_PRIVATE).all)
            "setPref" -> { ctx.getSharedPreferences("vigor_prefs", Context.MODE_PRIVATE).edit().putInt(call.argument<String>("key")!!, call.argument<Int>("value")!!).apply(); res.success(null) }
            "getData" -> { val kind = call.argument<String>("kind")!!; BandClient.ioExec.execute { val out = try { store.all(kind) } catch (e: Throwable) { null }; main.post { if (out != null) res.success(out) else res.error("STORE", "lectura fallida", null) } } }
            "healthLoad" -> BandClient.ioExec.execute { val out = try { store.healthState() } catch (e: Throwable) { null }; reply(res, out) }
            "healthSave" -> { val t = call.argument<String>("json"); BandClient.ioExec.execute { val ok = try { store.saveHealthState(t ?: "") } catch (e: Throwable) { false }; reply(res, ok) } }
            "clearExportDirty" -> { SyncPrefs.clearDirty(ctx); res.success(null) }
            "writeSleepStages" -> {
                val id = call.argument<String>("id") ?: ""; val ver = (call.argument<Number>("version") ?: 1).toLong()
                val st = (call.argument<Number>("start") ?: 0).toLong(); val en = (call.argument<Number>("end") ?: 0).toLong()
                val raw = (call.argument<List<List<Number>>>("stages") ?: emptyList()).map { r -> r.map { it.toLong() } }
                SleepStageWriter.write(ctx, id, ver, st, en, raw) { c -> reply(res, c) }
            }
            "writeHealthBatch" -> {
                val type = call.argument<String>("type") ?: ""; val raw = (call.argument<List<List<Any>>>("items") ?: emptyList())
                HealthBatchWriter.write(ctx, type, raw) { out -> reply(res, out) }
            }
            "openHealthSettings" -> res.success(false)
            else -> res.notImplemented()
        }
    }
}
