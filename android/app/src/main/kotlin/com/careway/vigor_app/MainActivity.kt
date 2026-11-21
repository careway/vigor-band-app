package com.careway.vigor_app

import android.Manifest
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import com.inuker.bluetooth.library.search.SearchResult
import com.inuker.bluetooth.library.search.response.SearchResponse
import com.veepoo.protocol.VPOperateManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Adaptador Flutter <-> BandClient. Eventos: {type: scan|state|battery|sync|syncProgress|sport|log, ...} */
class MainActivity : FlutterFragmentActivity() {
    private var sink: EventChannel.EventSink? = null
    private val ioExec = java.util.concurrent.Executors.newSingleThreadExecutor()
    /** M7/K3: varias peticiones simultaneas; se lanzan en rondas y cada una se resuelve comprobando de verdad sus permisos (ver PermissionQueue). */
    private val permQueue = PermissionQueue<MethodChannel.Result> { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }
    private val uiHandler = android.os.Handler(android.os.Looper.getMainLooper())
    /** H3: pide permisos y arma un tiempo maximo; si el sistema no responde, las peticiones se resuelven con lo que haya. */
    private fun askPermissions(p: List<String>) {
        requestPermissions(p.toTypedArray(), 77)
        val g = permQueue.generation
        uiHandler.postDelayed({
            val round = permQueue.expire(g)
            round.resolved.forEach { (r, ok) -> try { r.success(ok) } catch (_: Throwable) {} }
        }, PermissionQueue.TIMEOUT_MS)
    }
    private val mgr get() = VPOperateManager.getInstance()
    private val prefs get() = getSharedPreferences("vigor", MODE_PRIVATE)

    override fun onRequestPermissionsResult(rc: Int, perms: Array<out String>, res: IntArray) {
        super.onRequestPermissionsResult(rc, perms, res)
        if (rc == 77) {
            // Un array vacio (peticion cancelada/interrumpida) NO cuenta como concedido: la cola comprueba cada permiso.
            val round = permQueue.onResult()
            round.resolved.forEach { (r, ok) -> try { r.success(ok) } catch (_: Throwable) {} }
            round.next?.let { askPermissions(it) }
        }
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        BandClient.init(applicationContext)
        Agps.schedule(applicationContext)
        try { SyncScheduler.apply(applicationContext, replace = false) } catch (_: Throwable) {}
        clearExport(null) // H2: no queda ninguna copia de una ejecucion anterior
        EventChannel(engine.dartExecutor.binaryMessenger, "vigor/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                private var mine: ((Map<String, Any?>) -> Unit)? = null
                override fun onListen(a: Any?, s: EventChannel.EventSink?) {
                    sink = s
                    // El lambda solo captura el sink (no la Activity) y se limpia en onCancel/onDestroy.
                    val l: (Map<String, Any?>) -> Unit = { m -> try { s?.success(m) } catch (_: Throwable) {} }
                    mine = l; BandClient.listener = l
                }
                // N7: un onCancel tardio de un oyente viejo no debe anular el oyente nuevo.
                override fun onCancel(a: Any?) { if (BandClient.listener === mine) { BandClient.listener = null; sink = null }; mine = null }
            })

        MethodChannel(engine.dartExecutor.binaryMessenger, "vigor/methods").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "requestPermissions" -> {
                        val scan = call.argument<Boolean>("scan") ?: true
                        val p = if (Build.VERSION.SDK_INT >= 31)
                            (if (scan) arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT) else arrayOf(Manifest.permission.BLUETOOTH_CONNECT))
                        else if (scan) arrayOf(Manifest.permission.ACCESS_FINE_LOCATION) else emptyArray()
                        val missing = p.filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
                        if (missing.isEmpty()) result.success(true)
                        else {
                            val ask = permQueue.add(result, p.toList()); if (ask != null) askPermissions(ask)
                            permQueue.drainLate().forEach { (r, ok) -> try { r.success(ok) } catch (_: Throwable) {} } // H3: nunca queda un Result colgado
                        }
                    }
                    "permissionStatus" -> {
                        val granted = { x: String -> checkSelfPermission(x) == PackageManager.PERMISSION_GRANTED }
                        val asked = getSharedPreferences("vigor_prefs", MODE_PRIVATE).getInt("permAsked", 0) == 1
                        result.success(mapOf(
                            "missing" to StartupPermissions.missing(Build.VERSION.SDK_INT, granted).map { it.wire },
                            "blocked" to StartupPermissions.blocked(Build.VERSION.SDK_INT, asked, granted) { x -> shouldShowRequestPermissionRationale(x) }))
                    }
                    "startScan" -> { startScan(); result.success(null) }
                    "stopScan" -> { mgr.stopScanDevice(); result.success(null) }
                    "connect" -> {
                        val mac = call.argument<String>("mac")!!
                        prefs.edit().putString("mac", mac).apply()
                        BandClient.connect(mac, call.argument<String>("pwd") ?: "0000"); result.success(null)
                    }
                    "disconnect" -> { BandClient.disconnect(); result.success(null) }
                    "savedMac" -> result.success(prefs.getString("mac", null))
                    "forgetMac" -> { prefs.edit().remove("mac").apply(); result.success(null) }
                    "sync" -> { BandClient.syncAll(); result.success(null) }
                    "getData" -> {
                        val kind = call.argument<String>("kind")!!
                        ioExec.execute {
                            val out = try { BandClient.store.all(kind) } catch (e: Throwable) { null }
                            runOnUiThread { try { if (out != null) result.success(out) else result.error("STORE", "lectura fallida", null) } catch (_: Throwable) {} }
                        }
                    }
                    "startSport" -> { BandClient.startSport(call.argument<String>("type") ?: ""); result.success(null) }
                    "readAutoMeasure" -> { BandClient.readAutoMeasure(); result.success(null) }
                    "setAutoMeasure" -> { BandClient.setAutoMeasure(call.argument<Int>("type") ?: -1, call.argument<Boolean>("on") ?: false, call.argument<Int>("interval")); result.success(null) }
                    "stopSport" -> { BandClient.stopSport(); result.success(null) }
                    "sportState" -> { BandClient.sportState(); result.success(null) }
                    "findBand" -> { BandClient.findBand(); result.success(null) }
                    "getPrefs" -> result.success(getSharedPreferences("vigor_prefs", MODE_PRIVATE).all)
                    "setPref" -> { getSharedPreferences("vigor_prefs", MODE_PRIVATE).edit().putInt(call.argument<String>("key")!!, call.argument<Int>("value")!!).apply(); result.success(null) }
                    "agpsStatus" -> result.success(Agps.status())
                    "debugEnabled" -> result.success(BandClient.debuggable)
                    "debugSleepDump" -> { DebugTools.sleepDump(); result.success(BandClient.debuggable) }
                    "debugProbe" -> { DebugTools.probe(call.argument<String>("kind") ?: ""); result.success(BandClient.debuggable) }
                    "debugClearDumps" -> result.success(if (BandClient.debuggable) DebugTools.clearDumps() else 0)
                    "exportData" -> exportData(result)
                    "wipeData" -> wipeData(result)
                    "clearExport" -> clearExport(result)
                    "deleteRecords" -> {
                        val type = call.argument<String>("type") ?: ""; val keys = call.argument<List<String>>("keys") ?: emptyList()
                        ioExec.execute {
                            val n = try { BandClient.store.deleteRecords(type, keys) } catch (e: Throwable) { -1 }
                            runOnUiThread { try { if (n >= 0) result.success(n) else result.error("STORE", "no se pudo borrar", null) } catch (_: Throwable) {} }
                        }
                    }
                    "writeSleepStages" -> {
                        val id = call.argument<String>("id") ?: ""; val ver = (call.argument<Number>("version") ?: 1).toLong()
                        val st = (call.argument<Number>("start") ?: 0).toLong(); val en = (call.argument<Number>("end") ?: 0).toLong()
                        val raw = (call.argument<List<List<Number>>>("stages") ?: emptyList()).map { r -> r.map { it.toLong() } }
                        SleepStageWriter.write(applicationContext, id, ver, st, en, raw) { code -> android.util.Log.i("VIGORLOG", "writeSleepStages " + code); runOnUiThread { try { result.success(code) } catch (_: Throwable) {} } }
                    }
                    "writeHealthBatch" -> {
                        val type = call.argument<String>("type") ?: ""
                        val raw = (call.argument<List<List<Any>>>("items") ?: emptyList())
                        HealthBatchWriter.write(applicationContext, type, raw) { out -> android.util.Log.i("VIGORLOG", "writeHealthBatch " + type + " " + out["code"] + " " + out["written"] + "/" + raw.size); runOnUiThread { try { result.success(out) } catch (_: Throwable) {} } }
                    }
                    "openHealthSettings" -> result.success(openHealthSettings())
                    "healthLoad" -> ioExec.execute {
                        val out = try { BandClient.store.healthState() } catch (e: Throwable) { null }
                        runOnUiThread { try { result.success(out) } catch (_: Throwable) {} }
                    }
                    "healthSave" -> {
                        val txt = call.argument<String>("json")
                        ioExec.execute {
                            val ok = try { BandClient.store.saveHealthState(txt ?: "") } catch (e: Throwable) { false }
                            runOnUiThread { try { result.success(ok) } catch (_: Throwable) {} }
                        }
                    }
                    "startHeart" -> { BandClient.startHeart(); result.success(null) }
                    "stopHeart" -> { BandClient.stopHeart(); result.success(null) }
                    "appVersion" -> {
                        val pi = packageManager.getPackageInfo(packageName, 0)
                        result.success(mapOf("code" to androidx.core.content.pm.PackageInfoCompat.getLongVersionCode(pi), "name" to (pi.versionName ?: "")))
                    }
                    "updateDir" -> result.success(updateDir().apply { mkdirs() }.absolutePath)
                    "cleanUpdates" -> { try { updateDir().deleteRecursively() } catch (_: Throwable) {}; result.success(null) }
                    "openUrl" -> {
                        val u = android.net.Uri.parse(call.argument<String>("url") ?: "")
                        if (u.scheme == "https" && u.host == "github.com") { startActivity(Intent(Intent.ACTION_VIEW, u).addCategory(Intent.CATEGORY_BROWSABLE)); result.success(true) } else result.success(false)
                    }
                    "installApk" -> result.success(installApk(call.argument<String>("name")))
                    "isConnected" -> result.success(BandClient.connected)
                    "syncInfo" -> result.success(SyncPrefs.info(applicationContext))
                    "setAutoSync" -> {
                        val e = SyncPrefs.p(applicationContext).edit()
                        call.argument<Boolean>("enabled")?.let { e.putBoolean("enabled", it) }
                        call.argument<Int>("minutes")?.let { e.putInt("minutes", SyncRules.safeInterval(it)) }
                        call.argument<Boolean>("screenOnly")?.let { e.putBoolean("screenOnly", it) }
                        call.argument<Boolean>("bgExport")?.let { e.putBoolean("bgExport", it) }
                        e.apply(); SyncScheduler.apply(applicationContext, replace = true); result.success(SyncPrefs.info(applicationContext))
                    }
                    "clearExportDirty" -> { SyncPrefs.clearDirty(applicationContext); result.success(null) }
                    "hasConnectPermission" -> result.success(Build.VERSION.SDK_INT < 31 || checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED)
                    "autostartSupported" -> result.success(MiuiAutostart.supported(this))
                    "openAutostartSettings" -> result.success(MiuiAutostart.open(this))
                    "openBatterySettings" -> result.success(try { startActivity(Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.parse("package:$packageName")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); true } catch (_: Throwable) { false })
                    else -> result.notImplemented()
                }
            } catch (e: Throwable) { result.error("SDK", e.message, null) }
        }
    }

    override fun onDestroy() {
        BandClient.listener = null; sink = null; uiHandler.removeCallbacksAndMessages(null); ioExec.shutdown()
        super.onDestroy()
    }

    override fun onStop() { BandClient.stopHeart(); super.onStop() } // la medicion de pulso nunca sigue en segundo plano

    /** Abre los ajustes de Health Connect (permisos y datos). Android 14+: pantalla del sistema; antes: la app Health Connect. false si no hay donde abrirlos. */
    private fun openHealthSettings(): Boolean {
        val intents = listOf(Intent("android.health.connect.action.HEALTH_HOME_SETTINGS"), Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS"))
        for (i in intents) {
            try { startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); return true } catch (_: Throwable) {}
        }
        return false
    }

    private fun updateDir() = java.io.File(cacheDir, "updates")

    /** Abre el instalador de paquetes del sistema con el APK descargado (FileProvider, lectura temporal). Devuelve "started" o "needsPermission". No instala nada por su cuenta. */
    private fun installApk(name: String?): String {
        if (!UpdateRules.safeName(name)) throw IllegalArgumentException("nombre no valido")
        val f = java.io.File(updateDir(), name!!)
        if (!f.isFile || f.canonicalFile.parentFile != updateDir().canonicalFile) throw IllegalArgumentException("archivo no valido")
        if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
            startActivity(Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, android.net.Uri.parse("package:$packageName")))
            return "needsPermission"
        }
        val info = packageManager.getPackageArchiveInfo(f.absolutePath, 0)
        val cur = androidx.core.content.pm.PackageInfoCompat.getLongVersionCode(packageManager.getPackageInfo(packageName, 0))
        val cand = if (info == null) 0L else androidx.core.content.pm.PackageInfoCompat.getLongVersionCode(info)
        if (!UpdateRules.acceptable(packageName, info?.packageName, cur, cand)) { f.delete(); throw IllegalArgumentException("el APK no es una version mas nueva de Vigor") }
        val uri = androidx.core.content.FileProvider.getUriForFile(this, "$packageName.fileprovider", f)
        startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK))
        return "started"
    }

    private fun exportDir() = java.io.File(filesDir, "export")

    /** H2: la copia vive en files/export (privada) y se entrega con el selector de compartir (FileProvider, permiso de lectura temporal). */
    private fun exportData(result: MethodChannel.Result) {
        ioExec.execute {
            val names: List<String>? = try { BandClient.store.exportTo(exportDir()) } catch (e: Throwable) { null }
            runOnUiThread {
                try {
                    if (names == null) { result.error("EXPORT", "no se pudo exportar", null); return@runOnUiThread }
                    if (names.isNotEmpty()) share(names)
                    result.success(mapOf("path" to "export", "files" to names))
                } catch (e: Throwable) { try { result.error("EXPORT", "no se pudo compartir", null) } catch (_: Throwable) {} }
            }
        }
    }

    private fun share(names: List<String>) {
        val uris = ArrayList(names.map { androidx.core.content.FileProvider.getUriForFile(this, "$packageName.fileprovider", java.io.File(exportDir(), it)) })
        val i = if (uris.size == 1) Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_STREAM, uris[0])
                else Intent(Intent.ACTION_SEND_MULTIPLE).putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
        i.type = "application/json"; i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        val clip = ClipData.newRawUri("vigor", uris[0]); uris.drop(1).forEach { clip.addItem(ClipData.Item(it)) }; i.clipData = clip
        startActivity(Intent.createChooser(i, "Guardar o enviar mis datos").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
    }

    /** H2: borra la copia privada (al abrir la pantalla, al arrancar y en 'Borrar todos'). */
    private fun clearExport(result: MethodChannel.Result?) {
        ioExec.execute {
            val ok = try { exportDir().deleteRecursively() } catch (e: Throwable) { false }
            if (result != null) runOnUiThread { try { if (ok) result.success(null) else result.error("EXPORT", "no se pudo borrar la copia", null) } catch (_: Throwable) {} }
        }
    }

    /** Privacidad: borra files/vigor, files/agps, files/debug y la copia de exportacion. No toca la MAC ni edad/meta. Se niega durante una sincronizacion (comprobado dentro del almacen, H1). */
    private fun wipeData(result: MethodChannel.Result) {
        ioExec.execute {
            var busy = false
            val out: Int? = try {
                val w = BandClient.store.tryWipe { !BandClient.isSyncing }
                if (w == null) { busy = true; null } else {
                    var n = w
                    for (d in listOf(java.io.File(filesDir, "agps"), java.io.File(filesDir, "debug"), exportDir(), getExternalFilesDir(null)?.let { java.io.File(it, "export") }).filterNotNull()) {
                        if (d.exists()) { n += d.walkBottomUp().count { it.isFile }; d.deleteRecursively() }
                    }
                    getSharedPreferences("agps", MODE_PRIVATE).edit().clear().apply()
                    SyncPrefs.wipe(applicationContext)
                    n
                }
            } catch (e: Throwable) { null }
            runOnUiThread { try { if (out != null) result.success(out) else if (busy) result.error("BUSY", "sincronizando", null) else result.error("WIPE", "no se pudo borrar", null) } catch (_: Throwable) {} }
        }
    }

    private fun startScan() {
        try {
            val ad = android.bluetooth.BluetoothAdapter.getDefaultAdapter()
            if (ad == null || !ad.isEnabled) { BandClient.emit(mapOf("type" to "log", "msg" to "Bluetooth apagado: actívalo para buscar la pulsera")); BandClient.emit(mapOf("type" to "state", "value" to "idle")); return }
            if (Build.VERSION.SDK_INT < 31) {
                val lm = getSystemService(LOCATION_SERVICE) as? android.location.LocationManager
                val on = lm != null && (Build.VERSION.SDK_INT < 28 || lm.isLocationEnabled)
                if (!on) { BandClient.emit(mapOf("type" to "log", "msg" to "Para buscar una pulsera nueva en Android 11 o anterior hay que activar la ubicación un momento")); BandClient.emit(mapOf("type" to "state", "value" to "idle")); return }
            }
        } catch (t: Throwable) { android.util.Log.e("VIGORLOG", "precheck scan", t) }
        try { startScanUnsafe() } catch (t: Throwable) {
            android.util.Log.e("VIGORLOG", "startScan", t)
            BandClient.emit(mapOf("type" to "log", "msg" to "No se pudo iniciar la búsqueda"))
            BandClient.emit(mapOf("type" to "state", "value" to "idle"))
        }
    }

    private fun startScanUnsafe() {
        mgr.startScanDevice(object : SearchResponse {
            override fun onSearchStarted() { BandClient.emit(mapOf("type" to "state", "value" to "scanning")) }
            override fun onDeviceFounded(d: SearchResult) {
                BandClient.emit(mapOf("type" to "scan", "name" to (d.name ?: ""), "mac" to d.address, "macMasked" to BandClient.maskMac(d.address), "rssi" to d.rssi))
            }
            override fun onSearchStopped() { BandClient.emit(mapOf("type" to "state", "value" to "idle")) }
            override fun onSearchCanceled() { BandClient.emit(mapOf("type" to "state", "value" to "idle")) }
        })
    }
}
