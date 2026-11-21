package com.careway.vigor_app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import com.veepoo.protocol.VPOperateManager
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.listener.data.IAppReportGpsDataListener
import com.veepoo.protocol.model.datas.ReportGpsData
import com.veepoo.protocol.model.enums.EGpsStatus
import com.veepoo.protocol.model.settings.GpsLatLongSettingFromApp
import java.util.TimeZone

/**
 * Responde a la peticion de GPS de la pulsera. Segun el SDK (`settingRequestAppReportGpsDataListener`): «el dispositivo pide a la app que le mande
 * datos GPS»; la app contesta con `settingGpsLatLonfromApp` (estado, latitud, longitud, zona horaria y hora). Es una ayuda de posicion y hora aproximadas
 * que acelera el primer fijado. Se usa la ULTIMA posicion conocida del movil (sin encender la ubicacion en continuo) y solo mientras la pulsera lo pide
 * (durante una actividad con GPS). Sin permiso de ubicacion o sin posicion reciente se contesta «GPS_PERMISSION_CLOSE» (sin ayuda), sin datos inventados.
 */
object GpsAssist {
    private var last = 0L
    /** Ultimo resultado, solo para el registro de depuracion y el estado de la app (sin coordenadas). */
    @Volatile var lastStatus = "sin peticiones"

    fun register(ctx: Context) {
        try {
            VPOperateManager.getInstance().settingRequestAppReportGpsDataListener(object : IAppReportGpsDataListener {
                override fun onReportGpsDataDataChange(d: ReportGpsData) { handle(ctx, d.isReport) }
            })
        } catch (_: Throwable) {}
    }

    private fun hasPermission(ctx: Context) = ctx.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
        ctx.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    /** La posicion conocida mas reciente de cualquier proveedor, o null. No pide ninguna actualizacion nueva. */
    private fun lastKnown(ctx: Context): Location? {
        if (!hasPermission(ctx)) return null
        return try {
            val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            lm.getProviders(true).mapNotNull { try { lm.getLastKnownLocation(it) } catch (_: SecurityException) { null } }.maxByOrNull { it.time }
        } catch (_: Throwable) { null }
    }

    fun handle(ctx: Context, report: Boolean) {
        val now = System.currentTimeMillis()
        if (!GpsAssistRules.shouldReply(now, last)) return
        last = now
        val perm = hasPermission(ctx); val loc = lastKnown(ctx)?.takeIf { GpsAssistRules.validCoords(it.latitude, it.longitude) }
        val age = loc?.let { now - it.time }
        val st = GpsAssistRules.status(perm, age)
        val (lat, lon) = if (st == GpsAssistRules.Status.CLOSED || loc == null) 0.0 to 0.0 else loc.latitude to loc.longitude
        val e = when (st) { GpsAssistRules.Status.NORMAL -> EGpsStatus.SIGNAL_NORML; GpsAssistRules.Status.WEAK -> EGpsStatus.SIGNAL_WEAK; GpsAssistRules.Status.CLOSED -> EGpsStatus.GPS_PERMISSION_CLOSE }
        try {
            val tz = GpsAssistRules.timeZoneHours(TimeZone.getDefault().getOffset(now))
            VPOperateManager.getInstance().settingGpsLatLonfromApp(IBleWriteResponse { }, GpsLatLongSettingFromApp(report, e, lon, lat, tz, (now / 1000).toInt()))
            lastStatus = "respondido: $st"
        } catch (t: Throwable) { lastStatus = "error al responder: ${t.javaClass.simpleName}" }
        if (BandClient.debuggable) BandClient.log("gps-peticion de la pulsera (informar=$report) -> respuesta $st, permiso=$perm, edad de la posicion=${age?.let { it / 1000 }} s")
    }
}
