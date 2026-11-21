package com.careway.vigor_app

import android.Manifest
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.gson.Gson
import com.inuker.bluetooth.library.Code
import com.veepoo.protocol.VPOperateManager
import com.inuker.bluetooth.library.Constants
import com.veepoo.protocol.listener.base.IABleConnectStatusListener
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.listener.base.IConnectResponse
import com.veepoo.protocol.listener.base.INotifyResponse
import com.veepoo.protocol.listener.data.IOriginData3Listener
import com.veepoo.protocol.listener.data.ISleepDataListener
import com.veepoo.protocol.listener.data.ICustomSettingDataListener
import com.veepoo.protocol.listener.data.IDeviceFuctionDataListener
import com.veepoo.protocol.listener.data.IFindDevicelistener
import com.veepoo.protocol.listener.data.IHeartDataListener
import com.veepoo.protocol.model.datas.HeartData
import com.veepoo.protocol.listener.data.IPwdDataListener
import com.veepoo.protocol.listener.data.ISocialMsgDataListener
import com.veepoo.protocol.listener.data.ISportModelOriginListener
import com.veepoo.protocol.listener.data.ISportModelStateListener
import com.veepoo.protocol.model.datas.DeviceFunctionPackage1
import com.veepoo.protocol.model.datas.DeviceFunctionPackage2
import com.veepoo.protocol.model.datas.DeviceFunctionPackage3
import com.veepoo.protocol.model.datas.DeviceFunctionPackage4
import com.veepoo.protocol.model.datas.DeviceFunctionPackage5
import com.veepoo.protocol.model.datas.FunctionDeviceSupportData
import com.veepoo.protocol.model.datas.FunctionSocailMsgData
import com.veepoo.protocol.model.datas.HRVOriginData
import com.veepoo.protocol.model.datas.OriginData3
import com.veepoo.protocol.model.datas.Spo2hOriginData
import com.veepoo.protocol.model.datas.OriginHalfHourData
import com.veepoo.protocol.model.datas.PwdData
import com.veepoo.protocol.model.datas.SleepData
import com.veepoo.protocol.model.datas.SportModelGPSWatchOriginHeadData
import com.veepoo.protocol.model.datas.SportModelOriginHeadData
import com.veepoo.protocol.model.datas.SportModelOriginItemData
import com.veepoo.protocol.model.datas.SportModelStateData
import com.veepoo.protocol.model.enums.EPwdStatus
import com.veepoo.protocol.model.enums.ESportType
import com.veepoo.protocol.model.enums.EAutoMeasureType
import com.veepoo.protocol.model.datas.AutoMeasureData
import com.veepoo.protocol.listener.data.IAutoMeasureSettingDataListener
import com.veepoo.protocol.shareprence.VpSpGetUtil
import com.veepoo.protocol.model.settings.CustomSettingData
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/** Único punto de acceso al SDK de Veepoo. Lo usan la app (MainActivity) y el trabajo de fondo (AgpsWorker). Todo el SDK se toca en el hilo principal. */
object BandClient {
    private const val TAG = "VIGORLOG"
    private val main = Handler(Looper.getMainLooper())
    private val gson = Gson()
    private val noop = IBleWriteResponse { }
    /** fsync fuera del hilo principal: un unico hilo de E/S para vaciar el almacen. */
    private val ioFlush = java.util.concurrent.Executors.newSingleThreadExecutor()
    val ioExec: java.util.concurrent.ExecutorService get() = ioFlush
    private fun flushAsync(kinds: List<String>, then: () -> Unit) { ioFlush.execute { try { kinds.forEach { store.flush(it) } } catch (_: Throwable) {}; then() } }
    @Volatile private var inited = false
    lateinit var app: Context; private set
    lateinit var store: JsonStore; private set
    private val mgr get() = VPOperateManager.getInstance()

    @Volatile var connected = false
    @Volatile var connecting = false
    @Volatile var battery = -1
    @Volatile var watchday = 3
    @Volatile private var syncing = false
    val isSyncing: Boolean get() = syncing
    private var syncGen = 0
    private var autoSync = true
    private var weConnectedHeadless = false
    private var connectTimeout: Runnable? = null
    private var connectStartedAt = 0L
    /** Solo depuracion: ultimos paquetes de funciones del dispositivo (para ver p. ej. precisionSleep). */
    private val fnPkgs = java.util.concurrent.ConcurrentHashMap<String, JSONObject>()
    fun functionValue(name: String): Any? { for (j in fnPkgs.values) if (j.has(name)) return j.opt(name); return null }
    private var statusMac: String? = null
    private var readyCbs = mutableListOf<(Boolean) -> Unit>()
    @Volatile var listener: ((Map<String, Any?>) -> Unit)? = null

    @Synchronized fun init(ctx: Context) {
        if (inited) return
        app = ctx.applicationContext
        mgr.init(app)
        store = JsonStore(File(app.filesDir, "vigor"))
        inited = true
    }

    /** Solo las compilaciones depurables escriben en logcat (privacidad). */
    val debuggable: Boolean get() = inited && (app.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    /** Muestra solo los 2 últimos bytes de una MAC. */
    fun maskMac(m: String?): String = Mac.mask(m)

    /** Mensaje corto: a logcat solo en debug; al registro técnico de la app siempre (sin datos de salud). */
    fun log(s: String) { if (debuggable) Log.i(TAG, s); emit(mapOf("type" to "log", "msg" to s)) }
    private fun onMain(r: () -> Unit) { if (Looper.myLooper() == Looper.getMainLooper()) r() else main.post(r) }
    fun emit(m: Map<String, Any?>) { main.post { listener?.invoke(m) } }
    private fun state(v: String) = emit(mapOf("type" to "state", "value" to v))
    private fun toJson(o: Any): JSONObject = JSONObject(gson.toJson(o))
    private fun tkey(t: JSONObject?): String = if (t == null) "" else
        "%04d-%02d-%02d %02d:%02d".format(t.optInt("year"), t.optInt("month"), t.optInt("day"), t.optInt("hour"), t.optInt("minute"))

    // ---------------- conexión ----------------
    private val statusListener = object : IABleConnectStatusListener() {
        override fun onConnectStatusChanged(mac: String?, status: Int) {
            onMain {
                if (debuggable) Log.i(TAG, "estado BLE ${maskMac(mac)} status=$status")
                // N4: solo vale el evento de la MAC vigente, y un DISCONNECTED durante el arranque del intento (primeros 3 s) no lo aborta:
                // el timeout de 45 s o connectState lo cubren. Si ya estaba conectada, se trata como caida real.
                val mine = mac == null || statusMac == null || mac.equals(statusMac, ignoreCase = true)
                val fresh = connecting && !connected && System.currentTimeMillis() - connectStartedAt < 3000
                if (mine && !fresh && status == Constants.STATUS_DISCONNECTED && (connected || connecting)) { log("Conexion perdida"); failConnect() }
            }
        }
    }

    private fun hasConnectPermission() = Build.VERSION.SDK_INT < 31 ||
        app.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    private fun cancelConnectTimeout() { connectTimeout?.let { main.removeCallbacks(it) }; connectTimeout = null }

    /** [headless]=true solo lo usa runSessionBlocking; cualquier conexion pedida por la app reclama la sesion. */
    fun connect(mac: String, pwd: String, auto: Boolean = true, headless: Boolean = false, ready: ((Boolean) -> Unit)? = null) {
        main.post {
            if (!headless) weConnectedHeadless = false
            if (connected) { ready?.invoke(true); return@post }
            ready?.let { readyCbs.add(it) }
            if (connecting) { if (!headless) autoSync = true; return@post }
            if (!hasConnectPermission()) { log("Falta el permiso BLUETOOTH_CONNECT"); state("disconnected"); val cbs = readyCbs; readyCbs = mutableListOf(); cbs.forEach { it(false) }; return@post }
            connecting = true; connectStartedAt = System.currentTimeMillis(); autoSync = auto; if (headless) weConnectedHeadless = true; state("connecting")
            cancelConnectTimeout()
            val to = Runnable { if (connecting && !connected) { log("Tiempo de conexion agotado"); try { mgr.disconnectWatch(noop) } catch (_: Throwable) {}; failConnect() } }
            connectTimeout = to; main.postDelayed(to, 45000)
            try {
                if (statusMac != mac) {
                    statusMac?.let { try { mgr.unregisterConnectStatusListener(it, statusListener) } catch (_: Throwable) {} }
                    mgr.registerConnectStatusListener(mac, statusListener); statusMac = mac
                }
                mgr.connectDevice(mac, IConnectResponse { code, _, _ ->
                    onMain { log("connectState code=$code"); if (code != Code.REQUEST_SUCCESS) failConnect() }
                }, INotifyResponse { st ->
                    onMain { if (st != Code.REQUEST_SUCCESS) log("notifyState=$st") else confirmPwd(pwd) }
                })
            } catch (e: Throwable) { log("Error al conectar: ${e.javaClass.simpleName}"); failConnect() }
        }
    }

    private fun failConnect() {
        cancelConnectTimeout()
        val was = connected || connecting
        connected = false; connecting = false; weConnectedHeadless = false
        heartOn = false; main.removeCallbacks(heartStop)
        if (syncing) { syncGen++; syncing = false; emit(mapOf("type" to "sync", "value" to "end")) }
        state("disconnected")
        if (was) { val cbs = readyCbs; readyCbs = mutableListOf(); cbs.forEach { it(false) } }
    }

    fun disconnect() { main.post { try { mgr.disconnectWatch(noop) } catch (_: Throwable) {}; failConnect() } }

    private fun onVerified() {
        if (connected) return
        cancelConnectTimeout()
        connected = true; connecting = false
        state("connected")
        val cbs = readyCbs; readyCbs = mutableListOf(); cbs.forEach { it(true) }
        if (autoSync) main.postDelayed({ syncAll { Agps.onConnected() } }, 1500)
    }

    private fun confirmPwd(pwd: String) {
        mgr.confirmDevicePwd(noop,
            object : IPwdDataListener {
                override fun onPwdDataChange(d: PwdData) = onMain {
                    log("Contrasena: ${d.getmStatus()}")
                    if (d.getmStatus() == EPwdStatus.CHECK_FAIL) disconnect() else onVerified()
                }
                override fun onConnectionConfirmTimeout() = onMain { log("Confirmacion en la pulsera agotada"); disconnect() }
            },
            object : IDeviceFuctionDataListener {
                override fun onFunctionSupportDataChange(d: FunctionDeviceSupportData?) = onMain {
                    d?.let { val j = toJson(it); val w = maxOf(j.optInt("watchday"), j.optInt("watchDay")); if (w in 1..30) watchday = w }; log("Funciones recibidas (dias de datos: $watchday)"); onVerified()
                }
                override fun onDeviceFunctionPackage1Report(d: DeviceFunctionPackage1?) { if (debuggable) { d?.let { fnPkgs["pkg1"] = toJson(it) }; log("Pkg1 recibido") } }
                override fun onDeviceFunctionPackage2Report(d: DeviceFunctionPackage2?) { if (debuggable) { d?.let { fnPkgs["pkg2"] = toJson(it) }; log("Pkg2 recibido") } }
                override fun onDeviceFunctionPackage3Report(d: DeviceFunctionPackage3?) { if (debuggable) { d?.let { fnPkgs["pkg3"] = toJson(it) }; log("Pkg3 recibido") } }
                override fun onDeviceFunctionPackage4Report(d: DeviceFunctionPackage4?) { if (debuggable) { d?.let { fnPkgs["pkg4"] = toJson(it) }; log("Pkg4 recibido") } }
                override fun onDeviceFunctionPackage5Report(d: DeviceFunctionPackage5?) { if (debuggable) { d?.let { fnPkgs["pkg5"] = toJson(it) }; log("Pkg5 recibido") } }
            },
            object : ISocialMsgDataListener {
                override fun onSocialMsgSupportDataChange(p0: FunctionSocailMsgData?) {}
                override fun onSocialMsgSupportDataChange2(p0: FunctionSocailMsgData?) {}
            },
            object : ICustomSettingDataListener { override fun OnSettingDataChange(c: CustomSettingData?) {} },
            pwd, false)
    }

    enum class Session { DONE, TIMEOUT, NO_SESSION }

    /**
     * Ejecuta [body] cuando hay sesion (reusa la abierta o conecta por MAC guardada). Bloquea al llamador (solo hilos de fondo).
     * Si vence [timeoutSec] se aborta; la sesion solo se cierra si la abrio este metodo y la app no la ha reclamado.
     */
    fun runSessionBlocking(timeoutSec: Long, body: (done: () -> Unit) -> Unit): Session {
        val latch = CountDownLatch(1)
        val finished = AtomicBoolean(false); val noSession = AtomicBoolean(false)
        val mac = app.getSharedPreferences("vigor", Context.MODE_PRIVATE).getString("mac", null)
        // weConnectedHeadless solo lo activa connect(headless=true) cuando ESTA llamada abre la conexion; la app lo anula al reclamar la sesion.
        fun release() = main.post {
            if (weConnectedHeadless && !syncing && connected) { try { mgr.disconnectWatch(noop) } catch (_: Throwable) {}; failConnect() }
            weConnectedHeadless = false
        }
        main.post {
            val had = connected
            val go = go@{
                if (finished.get()) return@go // N3: ya vencio el timeout o se interrumpio
                if (!had && !connected) { noSession.set(true); latch.countDown() }
                else {
                    try {
                        body {
                            if (finished.compareAndSet(false, true)) { if (!had) release(); latch.countDown() }
                        }
                    } catch (e: Throwable) { log("Error en tarea de fondo: ${e.javaClass.simpleName}"); if (finished.compareAndSet(false, true)) { if (!had) release(); latch.countDown() } }
                }
            }
            if (had) go() else if (mac == null) { noSession.set(true); latch.countDown() }
            else connect(mac, "0000", auto = false, headless = true) { ok -> if (ok) main.postDelayed({ go() }, 2500) else { noSession.set(true); latch.countDown() } }
        }
        val ok = try { latch.await(timeoutSec, TimeUnit.SECONDS) } catch (e: InterruptedException) {
            // N1: WorkManager cancela el trabajo: liberar la sesion abierta por este metodo y restaurar el estado.
            finished.set(true); release(); Thread.currentThread().interrupt(); return Session.TIMEOUT
        }
        if (!ok) { finished.set(true); release(); return Session.TIMEOUT }
        return if (noSession.get()) Session.NO_SESSION else Session.DONE
    }

    // ---------------- lecturas ----------------
    /** Etapas de la sincronizacion en curso que vencieron su tiempo (una sincronizacion con tiempos agotados no cuenta como "correcta"). */
    @Volatile private var stageTimeouts = 0
    private fun stage(name: String, timeoutMs: Long = 90000, body: (finish: () -> Unit) -> Unit, next: () -> Unit) {
        var done = false
        lateinit var to: Runnable
        val fin: () -> Unit = { main.post { if (!done) { done = true; main.removeCallbacks(to); next() } } }
        to = Runnable { log("timeout en $name"); stageTimeouts++; fin() }
        main.postDelayed(to, timeoutMs)
        try { body(fin) } catch (e: Throwable) { log("error en $name: ${e.message}"); fin() }
    }

    fun readBatteryThen(cb: () -> Unit) {
        stage("bateria", 15000, { fin ->
            mgr.readBattery(noop) { b ->
                battery = b.batteryPercent
                emit(mapOf("type" to "battery", "percent" to b.batteryPercent, "charging" to (b.powerModel == 1)))
                fin()
            }
        }, cb)
    }

    /** [keepHeadless]=true solo lo usa SyncWorker: la sesion abierta por el trabajo debe poder cerrarse al terminar. */
    fun syncAll(keepHeadless: Boolean = false, done: (() -> Unit)? = null) {
        main.post {
            if (!connected || syncing) { done?.invoke(); return@post }
            stopHeartNow() // la sincronizacion y la medicion de pulso no se solapan
            // H1: comprobar 'wiping' y marcar 'syncing' bajo el mismo cerrojo que usa tryWipe.
            val blocked = synchronized(store) { if (store.wiping) true else { syncing = true; false } }
            if (blocked) { done?.invoke(); return@post }
            if (!keepHeadless) weConnectedHeadless = false // el usuario (o la app) usa la sesion: el trabajo de fondo no debe cerrarla
            syncing = true; stageTimeouts = 0; val gen = ++syncGen; emit(mapOf("type" to "sync", "value" to "start"))
            val alive = { gen == syncGen && connected }
            val end: () -> Unit = {
                if (gen == syncGen) {
                    // Correcta = la conexion aguanto hasta el final y ninguna etapa vencio su tiempo. Solo entonces cuenta como "ultima sincronizacion".
                    val ok = connected && stageTimeouts == 0
                    val at = System.currentTimeMillis()
                    if (ok) SyncPrefs.markSynced(app, at, appOpen = listener != null)
                    syncing = false; emit(mapOf("type" to "sync", "value" to "end", "ok" to ok, "at" to at))
                }
                done?.invoke(); Unit
            }
            readBatteryThen {
                if (!alive()) { done?.invoke(); return@readBatteryThen }
                stage("pasos", 15000, { fin ->
                    mgr.readSportStep(noop) { d ->
                        store.put("live", "today", toJson(d).put("at", System.currentTimeMillis())); flushAsync(listOf("live")) { fin() }
                    }
                }) {
                    if (!alive()) { done?.invoke(); return@stage }
                    stage("salud", 180000, { fin -> readHealth(fin) }) {
                        if (!alive()) { done?.invoke(); return@stage }
                        stage("deportes", 180000, { fin -> readSports(fin) }, end)
                    }
                }
            }
        }
    }

    private fun keyOf(j: JSONObject): String {
        val t = j.optJSONObject("mTime") ?: j.optJSONObject("time") ?: j.optJSONObject("startTime")
        if (t != null) return tkey(t)
        return (j.optString("date") + "_" + j.optString("time") + "_" + j.optInt("packageNumber")).ifBlank { j.toString().hashCode().toString() }
    }

    private fun storeList(kind: String, list: List<Any>?) {
        list?.forEach { val j = toJson(it); store.put(kind, keyOf(j), j) }
    }

    private fun readHealth(fin: () -> Unit) {
        // 1) sueno
        mgr.readSleepData(noop, object : ISleepDataListener {
            override fun onSleepDataChange(day: String?, d: SleepData?) {
                d?.let { val j = toJson(it); store.put("sleep", j.optString("Date", j.optString("date", day ?: "")), j) }
            }
            override fun onSleepProgress(p: Float) {}
            override fun onSleepProgressDetail(day: String?, n: Int) {}
            override fun onReadSleepComplete() { flushAsync(listOf("sleep")) { main.post { readOrigin(fin) } } } // M5: la etapa siguiente salta al hilo principal
        }, watchday)
    }

    private fun readOrigin(fin: () -> Unit) {
        // 2) datos de 5 min (pulso, pasos), HRV y SpO2 (protocolo 5 -> OriginData3)
        mgr.readOriginData(noop, object : IOriginData3Listener {
            override fun onOriginFiveMinuteListDataChange(l: MutableList<OriginData3>?) { storeList("origin5", l) }
            override fun onOriginHalfHourDataChange(h: OriginHalfHourData?) { h?.let { val j = toJson(it); store.put("half", j.optString("date"), j) } }
            override fun onOriginHRVOriginListDataChange(l: MutableList<HRVOriginData>?) { storeList("hrv", l) }
            override fun onOriginSpo2OriginListDataChange(l: MutableList<Spo2hOriginData>?) { storeList("spo2", l) }
            override fun onReadOriginProgressDetail(day: Int, date: String?, all: Int, cur: Int) {}
            override fun onReadOriginProgress(p: Float) { emit(mapOf("type" to "syncProgress", "value" to p.toDouble())) }
            override fun onReadTimeout(p0: Int) { log("timeout lectura origen: $p0"); stageTimeouts++; flushAsync(listOf("origin5", "half", "hrv", "spo2")) { fin() } }
            override fun onReadOriginComplete() { flushAsync(listOf("origin5", "half", "hrv", "spo2")) { fin() } }
        }, watchday)
    }

    private var lastHeadKey = "unknown"
    private val seenItems = HashSet<String>()

    private fun readSports(fin: () -> Unit) {
        seenItems.clear(); lastHeadKey = "unknown" // M6: por lectura
        mgr.readSportModelOrigin(noop, object : ISportModelOriginListener {
            override fun onReadOriginProgress(p: Float) {}
            override fun onReadOriginProgressDetail(day: Int, date: String?, all: Int, cur: Int) {}
            override fun onHeadChangeListListener(h: SportModelOriginHeadData?) {
                h?.let { val j = toJson(it); lastHeadKey = tkey(j.optJSONObject("startTime")); store.put("sports", lastHeadKey, j) }
            }
            override fun onGPSWatchSportModeHeadChange(h: SportModelGPSWatchOriginHeadData?) {
                h?.let { val j = toJson(it); lastHeadKey = tkey(j.optJSONObject("startTime")); store.put("sports", lastHeadKey, j) }
            }
            override fun onItemChangeListListener(items: MutableList<SportModelOriginItemData>?) {
                if (items == null) return
                store.putItems("sportItems", lastHeadKey, JSONArray(gson.toJson(items)), reset = seenItems.add(lastHeadKey))
            }
            override fun onReadOriginComplete() { flushAsync(listOf("sports", "sportItems")) { fin() } }
        })
    }

    // ---------------- deporte / buscar ----------------
    private val stateListener = object : ISportModelStateListener {
        override fun onSportModelStateChange(d: SportModelStateData) {
            emit(mapOf("type" to "sport", "msg" to "Estado: operacion=${d.oprateStauts} dispositivo=${d.deviceStauts} tipo=${d.sportModeType}"))
        }
        override fun onSportStopped() { emit(mapOf("type" to "sport", "msg" to "Actividad detenida")) }
    }
    fun startSport(type: String) = main.post {
        // Sin sustituto silencioso: un nombre desconocido no debe arrancar otro deporte (p. ej. correr).
        val t = sportTypeOf(type)
        if (t == null) { emit(mapOf("type" to "sport", "msg" to "Modo no reconocido por la SDK: $type")) }
        else { emit(mapOf("type" to "sport", "msg" to "Orden de inicio enviada: $type (la pulsera decide si lo admite)")); mgr.startMultSportModel(noop, stateListener, t) }
    }
    /** Nombre de la enum ESportType -> valor; NONE y desconocidos -> null. */
    internal fun sportTypeOf(name: String): ESportType? = try { ESportType.valueOf(name).takeIf { it != ESportType.NONE } } catch (e: Exception) { null }

    // ---- Cadencia de la medición automática (SDK: readAutoMeasureSettingData / setAutoMeasureSettingData; sin probar con la pulsera) ----
    private var autoItems: List<AutoMeasureData> = emptyList()
    private fun autoJson(d: AutoMeasureData) = mapOf("type" to d.funType.value, "name" to d.funType.name, "on" to d.isSwitchOpen, "stepUnit" to d.stepUnit,
        "slotModify" to d.isSlotModify, "intervalModify" to d.isIntervalModify, "interval" to d.measureInterval,
        "supStart" to d.supportStartMinute, "supEnd" to d.supportEndMinute, "start" to d.currentStartMinute, "end" to d.currentEndMinute)
    private val autoListener = object : IAutoMeasureSettingDataListener {
        override fun onSettingDataChange(list: List<AutoMeasureData>) {
            autoItems = list.toList()
            emit(mapOf("type" to "autoMeasure", "items" to list.map { autoJson(it) }))
        }
        override fun onSettingDataChangeFail() { emit(mapOf("type" to "autoMeasureResult", "ok" to false)) }
        override fun onSettingDataChangeSuccess() { emit(mapOf("type" to "autoMeasureResult", "ok" to true)) }
    }
    fun autoMeasureSupported(): Boolean = inited && try { VpSpGetUtil.getVpSpVariInstance(app).isSupportAutoMeasure } catch (e: Throwable) { false }
    fun readAutoMeasure() = main.post {
        if (!autoMeasureSupported()) emit(mapOf("type" to "autoMeasure", "unsupported" to true))
        else try { mgr.readAutoMeasureSettingData(noop, autoListener) } catch (e: Throwable) { log("autoMeasure: " + e.javaClass.simpleName) }
    }
    /** Cambia interruptor e intervalo de UN tipo. Parte del objeto leído antes; el intervalo se valida con AutoMeasureRules (solo si la pulsera permite modificarlo). */
    fun setAutoMeasure(typeValue: Int, on: Boolean, interval: Int?) = main.post {
        val d = autoItems.firstOrNull { it.funType.value == typeValue }
        if (d == null) { emit(mapOf("type" to "autoMeasureResult", "ok" to false, "msg" to "Lee primero los ajustes de la pulsera")); return@post }
        d.isSwitchOpen = on
        if (interval != null && d.isIntervalModify) {
            val v = AutoMeasureRules.safeInterval(interval, d.stepUnit)
            if (v == null) { emit(mapOf("type" to "autoMeasureResult", "ok" to false, "msg" to "Intervalo no válido")); return@post }
            d.measureInterval = v
        }
        try { mgr.setAutoMeasureSettingData(noop, d, autoListener) } catch (e: Throwable) { emit(mapOf("type" to "autoMeasureResult", "ok" to false)) }
    }
    // ---- Medicion puntual de pulso (SDK startDetectHeart / stopDetectHeart). Siempre con tope de tiempo: nunca queda midiendo (bateria). ----
    private var heartOn = false
    private val heartStop = Runnable { stopHeartNow(); emit(mapOf("type" to "heart", "status" to "TIMEOUT", "value" to 0)) }
    private val heartListener = IHeartDataListener { d: HeartData? ->
        if (heartOn && d != null) emit(mapOf("type" to "heart", "status" to (d.heartStatus?.name ?: ""), "value" to (if (HeartRules.valid(d.data)) d.data else 0)))
    }
    fun startHeart() = main.post {
        if (!connected || syncing) { emit(mapOf("type" to "heart", "status" to "STATE_HEART_BUSY", "value" to 0)); return@post }
        try {
            heartOn = true; main.removeCallbacks(heartStop); main.postDelayed(heartStop, HeartRules.MAX_MS)
            mgr.startDetectHeart(noop, heartListener)
        } catch (e: Throwable) { log("startDetectHeart: " + e.javaClass.simpleName); heartOn = false; main.removeCallbacks(heartStop) }
    }
    private fun stopHeartNow() {
        main.removeCallbacks(heartStop)
        if (!heartOn) return
        heartOn = false
        try { mgr.stopDetectHeart(noop) } catch (e: Throwable) { log("stopDetectHeart: " + e.javaClass.simpleName) }
    }
    fun stopHeart() = main.post { stopHeartNow() }
    fun stopSport() = main.post { mgr.stopSportModel(noop, stateListener) }
    fun sportState() = main.post { mgr.readSportModelState(noop, stateListener) }
    fun findBand() = main.post {
        mgr.startFindDeviceByPhone(noop, object : IFindDevicelistener {
            override fun unSupportFindDeviceByPhone() { emit(mapOf("type" to "sport", "msg" to "Buscar pulsera no soportado")) }
            override fun findedDevice() { emit(mapOf("type" to "sport", "msg" to "Pulsera encontrada")) }
            override fun unFindDevice() { emit(mapOf("type" to "sport", "msg" to "Busqueda agotada")) }
            override fun findingDevice() { emit(mapOf("type" to "sport", "msg" to "La pulsera vibra...")) }
        })
    }
}
