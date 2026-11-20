package com.careway.vigor_app

import android.os.Handler
import android.os.Looper
import com.veepoo.protocol.VPOperateManager
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.listener.data.IHrvDetectListener
import com.veepoo.protocol.listener.data.IMetDetectListener
import com.veepoo.protocol.listener.data.IPressureDetectListener
import com.veepoo.protocol.listener.data.ISleepDataListener
import com.veepoo.protocol.listener.data.ITemptureDetectDataListener
import com.veepoo.protocol.model.datas.SleepData
import com.veepoo.protocol.model.datas.TemptureDetectData
import com.veepoo.protocol.model.enums.HrvDetectState
import com.veepoo.protocol.model.enums.MetDetectState
import com.veepoo.protocol.model.enums.PressureDetectState
import com.veepoo.protocol.shareprence.VpSpGetUtil
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Herramientas SOLO de depuracion (E6/E7 de la ronda 3). Cada entrada comprueba BandClient.debuggable y no hace nada en release.
 * Sin UI publica: se invocan desde "Dispositivo > Avanzado (depuracion)", que Flutter solo muestra en compilaciones de depuracion.
 * Nada se escribe fuera del directorio privado de la app y nada incluye la MAC.
 */
object DebugTools {
    private val main = Handler(Looper.getMainLooper())
    private val noop = IBleWriteResponse { }
    private val mgr get() = VPOperateManager.getInstance()
    private fun log(s: String) = BandClient.log(s)
    fun dumpDir() = File(BandClient.app.filesDir, "debug")

    // ---------------- E7: sondeo de medicion rapida ----------------
    /** kind = pressure | met | temp | hrv. Un tiempo maximo, siempre llama a stop*, no permite lanzarse durante una sincronizacion. */
    fun probe(kind: String, timeoutMs: Long = 60_000) {
        if (!BandClient.debuggable) return
        main.post {
            if (!BandClient.connected) { log("sondeo $kind: sin conexion"); return@post }
            if (BandClient.isSyncing) { log("sondeo $kind: hay una sincronizacion en curso, se omite"); return@post }
            val t0 = System.currentTimeMillis(); val done = AtomicBoolean(false)
            lateinit var stop: () -> Unit
            val to = Runnable { if (done.compareAndSet(false, true)) { log("sondeo $kind: SIN RESPUESTA en ${timeoutMs / 1000} s"); stop() } }
            val finish: (String) -> Unit = { msg ->
                if (done.compareAndSet(false, true)) { main.removeCallbacks(to); log("sondeo $kind: $msg (${(System.currentTimeMillis() - t0) / 1000.0} s)"); stop() }
            }
            val say: (String) -> Unit = { m -> if (!done.get()) log("sondeo $kind: $m") }
            main.postDelayed(to, timeoutMs)
            try {
                when (kind) {
                    "pressure" -> {
                        stop = { try { mgr.stopDetectPressure(noop) } catch (_: Throwable) {} }
                        mgr.startDetectPressure(noop, object : IPressureDetectListener {
                            override fun onDetecting(progress: Int) = say("progreso $progress")
                            override fun onDetectSuccess(pressure: Int) = finish("valor $pressure")
                            override fun onDetectFailed(detectState: PressureDetectState) = finish("fallo ${detectState.des}")
                            override fun onDetectStop() = finish("detenido")
                        })
                    }
                    "met" -> {
                        stop = { try { mgr.stopDetectMet(noop) } catch (_: Throwable) {} }
                        mgr.startDetectMet(noop, object : IMetDetectListener {
                            override fun onMetDetect(progress: Int, met: Float) { if (progress >= 100) finish("valor $met") else say("progreso $progress valor $met") }
                            override fun onDetectFailed(detectState: MetDetectState) = finish("fallo ${detectState.des}")
                            override fun onDetectStop() = finish("detenido")
                        })
                    }
                    "temp" -> {
                        stop = { try { mgr.stopDetectTempture(noop, null) } catch (_: Throwable) {} }
                        mgr.startDetectTempture(noop, object : ITemptureDetectDataListener {
                            override fun onDataChange(d: TemptureDetectData?) {
                                if (d == null) return
                                if (d.progress >= 100 || d.tempture > 0f) finish("oprate=${d.oprate} estado=${d.deviceState} temp=${d.tempture} base=${d.temptureBase}")
                                else say("oprate=${d.oprate} estado=${d.deviceState} progreso=${d.progress}")
                            }
                        })
                    }
                    "hrv" -> {
                        stop = { try { mgr.stopDetectHrv(noop, null) } catch (_: Throwable) {} }
                        val sup = try { VpSpGetUtil.getVpSpVariInstance(BandClient.app).isSupportHrvAppDetect } catch (e: Throwable) { false }
                        if (!sup) { finish("no soportado por el dispositivo (isSupportHrvAppDetect=false)"); return@post }
                        mgr.startDetectHrv(noop, object : IHrvDetectListener {
                            override fun onHrvDetect(hrv: Int) = finish("valor $hrv ms")
                            override fun onDetectFailed(detectState: HrvDetectState) = finish("fallo $detectState")
                            override fun onDetectStop() = finish("detenido")
                        })
                    }
                    else -> { main.removeCallbacks(to); done.set(true); log("sondeo: tipo desconocido") }
                }
            } catch (e: Throwable) { finish("excepcion ${e.javaClass.simpleName}") }
        }
    }

    // ---------------- E6: volcado de sueno ----------------
    private val recKeys = listOf("mTime", "sleepStates", "sleepStatusQuantity", "gesture", "sportValue", "wear", "ppgs")

    /** Escribe `files/debug/sleep_dump_<ms>.json`. Se borra con [clearDumps]. */
    fun sleepDump() {
        if (!BandClient.debuggable) return
        main.post {
            if (!BandClient.connected || BandClient.isSyncing) { log("volcado de sueno: hace falta la pulsera conectada y sin sincronizar"); return@post }
            val out = JSONObject(); val calls = JSONArray(); out.put("readSleepData", calls)
            val days = listOf(-1, 0, 1, 2) // -1 = readSleepData (todo); 0..2 = una noche concreta
            fun next(i: Int) {
                if (i >= days.size) { finishDump(out); return }
                val d = days[i]; val done = AtomicBoolean(false)
                val entry = JSONObject().put("call", if (d < 0) "readSleepData" else "readSleepDataSingleDay($d)").put("items", JSONArray())
                lateinit var to: Runnable
                val end: (String) -> Unit = { why -> if (done.compareAndSet(false, true)) { main.removeCallbacks(to); entry.put("end", why); calls.put(entry); next(i + 1) } }
                to = Runnable { end("timeout") }
                main.postDelayed(to, 30_000)
                val l = object : ISleepDataListener {
                    override fun onSleepDataChange(day: String?, s: SleepData?) { try { entry.getJSONArray("items").put(JSONObject().put("day", day ?: "").put("data", s?.let { JSONObject(com.google.gson.Gson().toJson(it)) })) } catch (_: Throwable) {} }
                    override fun onSleepProgress(p: Float) {}
                    override fun onSleepProgressDetail(day: String?, n: Int) {}
                    override fun onReadSleepComplete() { main.post { end("complete") } }
                }
                try { if (d < 0) mgr.readSleepData(noop, l, BandClient.watchday) else mgr.readSleepDataSingleDay(noop, l, d, BandClient.watchday) }
                catch (e: Throwable) { end("excepcion ${e.javaClass.simpleName}") }
            }
            next(0)
        }
    }

    private fun finishDump(out: JSONObject) {
        out.put("precisionSleep", BandClient.functionValue("precisionSleep") ?: JSONObject.NULL)
        BandClient.ioExec.execute {
            try {
                val o5 = JSONArray(BandClient.store.all("origin5")); val sel = JSONArray()
                for (i in 0 until o5.length()) {
                    val r = o5.optJSONObject(i) ?: continue; val t = r.optJSONObject("mTime") ?: continue
                    val h = t.optInt("hour", -1); if (h in 11..20) continue // ventana 21:00-11:00
                    val c = JSONObject(); for (k in recKeys) if (r.has(k)) c.put(k, r.get(k)); sel.put(c)
                }
                out.put("origin5_21_11", sel)
                val hv = JSONArray(BandClient.store.all("hrv")); val hs = JSONArray()
                for (i in 0 until hv.length()) { val r = hv.optJSONObject(i) ?: continue; val t = r.optJSONObject("mTime") ?: continue; val h = t.optInt("hour", -1); if (h in 11..20) continue; hs.put(r) }
                out.put("hrv_21_11", hs)
                dumpDir().mkdirs()
                val f = File(dumpDir(), "sleep_dump_${System.currentTimeMillis()}.json")
                f.writeText(out.toString())
                log("volcado de sueno escrito: debug/${f.name} (${f.length()} bytes)")
            } catch (e: Throwable) { log("volcado de sueno fallido: ${e.javaClass.simpleName}") }
        }
    }

    fun clearDumps(): Int { var n = 0; dumpDir().listFiles()?.forEach { if (it.delete()) n++ }; return n }
}
