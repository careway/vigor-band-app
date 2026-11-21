package com.careway.vigor_app

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Escribe UNA sesion de sueno con todas sus fases en Health Connect (el plugin `health` solo escribe una sesion por fase,
 * lo que deja decenas de sesiones solapadas). Mismo clientRecordId que la sesion sin fases: con version mayor la sustituye.
 * Usa el permiso WRITE_SLEEP ya concedido; no pide nada nuevo. Devuelve un codigo corto sin datos personales.
 */
object SleepStageWriter {
    fun write(ctx: Context, id: String, version: Long, startMs: Long, endMs: Long, rawStages: List<List<Long>>, done: (String) -> Unit) {
        val stages = SleepStagesRules.sanitize(startMs, endMs, rawStages)
        if (stages.isEmpty()) { done("NO_STAGES"); return }
        CoroutineScope(Dispatchers.IO).launch {
            val code = try {
                if (HealthConnectClient.getSdkStatus(ctx) != HealthConnectClient.SDK_AVAILABLE) "UNAVAILABLE"
                else {
                    val client = HealthConnectClient.getOrCreate(ctx)
                    val granted = client.permissionController.getGrantedPermissions()
                    if (HealthPermission.getWritePermission(SleepSessionRecord::class) !in granted) "NO_PERMISSION"
                    else {
                        val meta = Metadata.autoRecorded(Device(type = Device.TYPE_WATCH), clientRecordId = id, clientRecordVersion = version)
                        val rec = SleepSessionRecord(
                            startTime = Instant.ofEpochMilli(startMs), startZoneOffset = null,
                            endTime = Instant.ofEpochMilli(endMs), endZoneOffset = null,
                            title = null, notes = null,
                            stages = stages.map { SleepSessionRecord.Stage(Instant.ofEpochMilli(it.first), Instant.ofEpochMilli(it.second), it.third) },
                            metadata = meta)
                        client.insertRecords(listOf(rec)); "OK"
                    }
                }
            } catch (e: Throwable) { "ERROR:" + (e.javaClass.simpleName.take(40)) }
            done(code)
        }
    }
}
