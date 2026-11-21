package com.careway.vigor_app

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.BodyTemperatureRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Length
import androidx.health.connect.client.units.Percentage
import androidx.health.connect.client.units.Temperature
import java.time.Instant
import kotlin.reflect.KClass
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Escribe muchos datos del mismo tipo con POCAS llamadas a Health Connect (hasta [HealthBatchRules.CHUNK] registros por insertRecords).
 * Los limites de cuota cuentan LLAMADAS, no registros; el plugin `health` hace una llamada por dato y agotaba la cuota.
 * Misma forma de registro que el plugin (mismos clientRecordId y version: un reenvio no duplica). Devuelve {code, written}:
 * written = datos consumidos desde el principio de la lista (escritos o descartados por invalidos), para retomar donde se corto.
 * code: OK | RATE_LIMIT | NO_PERMISSION | UNAVAILABLE | BAD_TYPE | ERROR:Clase (sin datos personales).
 */
object HealthBatchWriter {
    private fun cls(type: String): KClass<out Record>? = when (type) {
        "steps" -> StepsRecord::class; "distance" -> DistanceRecord::class; "activeEnergy" -> ActiveCaloriesBurnedRecord::class
        "heartRate" -> HeartRateRecord::class; "hrvRmssd" -> HeartRateVariabilityRmssdRecord::class; "restingHr" -> RestingHeartRateRecord::class
        "spo2" -> OxygenSaturationRecord::class; "bodyTemp" -> BodyTemperatureRecord::class; else -> null
    }

    private fun build(type: String, id: String, ver: Long, startMs: Long, endMs: Long, v: Double): Record {
        val meta = Metadata.autoRecorded(Device(type = Device.TYPE_WATCH), clientRecordId = id, clientRecordVersion = ver)
        val s = Instant.ofEpochMilli(startMs); val e = Instant.ofEpochMilli(endMs)
        return when (type) {
            "steps" -> StepsRecord(startTime = s, startZoneOffset = null, endTime = e, endZoneOffset = null, count = v.toLong(), metadata = meta)
            "distance" -> DistanceRecord(startTime = s, startZoneOffset = null, endTime = e, endZoneOffset = null, distance = Length.meters(v), metadata = meta)
            "activeEnergy" -> ActiveCaloriesBurnedRecord(startTime = s, startZoneOffset = null, endTime = e, endZoneOffset = null, energy = Energy.kilocalories(v), metadata = meta)
            "heartRate" -> HeartRateRecord(startTime = s, startZoneOffset = null, endTime = e, endZoneOffset = null, samples = listOf(HeartRateRecord.Sample(time = s, beatsPerMinute = v.toLong())), metadata = meta)
            "hrvRmssd" -> HeartRateVariabilityRmssdRecord(time = s, zoneOffset = null, heartRateVariabilityMillis = v, metadata = meta)
            "restingHr" -> RestingHeartRateRecord(time = s, zoneOffset = null, beatsPerMinute = v.toLong(), metadata = meta)
            "spo2" -> OxygenSaturationRecord(time = s, zoneOffset = null, percentage = Percentage(v), metadata = meta)
            else -> BodyTemperatureRecord(time = s, zoneOffset = null, temperature = Temperature.celsius(v), metadata = meta)
        }
    }

    /** items: [id, version, startMs, endMs, value] por dato. */
    fun write(ctx: Context, type: String, items: List<List<Any>>, done: (Map<String, Any>) -> Unit) {
        val klass = cls(type)
        if (klass == null) { done(mapOf("code" to "BAD_TYPE", "written" to 0)); return }
        CoroutineScope(Dispatchers.IO).launch {
            var consumed = 0
            val code = try {
                if (HealthConnectClient.getSdkStatus(ctx) != HealthConnectClient.SDK_AVAILABLE) "UNAVAILABLE"
                else {
                    val client = HealthConnectClient.getOrCreate(ctx)
                    if (HealthPermission.getWritePermission(klass) !in client.permissionController.getGrantedPermissions()) "NO_PERMISSION"
                    else {
                        for (chunk in items.chunked(HealthBatchRules.CHUNK)) {
                            val recs = ArrayList<Record>(chunk.size)
                            for (it in chunk) {
                                val id = it[0] as String; val ver = (it[1] as Number).toLong()
                                val a = (it[2] as Number).toLong(); val b = (it[3] as Number).toLong(); val v = (it[4] as Number).toDouble()
                                if (HealthBatchRules.valid(type, v, a, b)) recs.add(build(type, id, ver, a, b, v))
                            }
                            if (recs.isNotEmpty()) client.insertRecords(recs)
                            consumed += chunk.size
                        }
                        "OK"
                    }
                }
            } catch (e: Throwable) { if (HealthBatchRules.isRateLimit(e.message)) "RATE_LIMIT" else "ERROR:" + e.javaClass.simpleName.take(40) }
            done(mapOf("code" to code, "written" to consumed))
        }
    }
}
