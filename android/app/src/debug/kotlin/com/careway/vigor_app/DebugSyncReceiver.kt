package com.careway.vigor_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

/** Solo depuracion: `adb shell am broadcast -n com.careway.vigor_app/.DebugSyncReceiver` encola un SyncWorker inmediato. */
class DebugSyncReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent?) {
        when (i?.getStringExtra("probe")) {
            "events" -> { EventProbe.register(); return }
            "camera" -> { EventProbe.cameraMode(); return }
            // Solo depuracion: simula un informe en vivo de la pulsera para ver la isla y la pantalla de entreno (solo en memoria; no se guarda nada).
            "fakeworkout" -> { val type = i.getIntExtra("type", 1); val dur = i.getIntExtra("dur", 754)
                BandClient.emit(mapOf("type" to "sportLive", "data" to mapOf("sportType" to type, "sportDuration" to dur, "heartRate" to 148, "distance" to 2310, "pace" to 325, "speed" to 11100, "calories" to 160000, "gpsSignal" to 2, "runState" to "RUNNING"))); return }
            // Solo depuracion: sondea que modos acepta la pulsera. Ej.: --es modes OUTDOOR_WALK,SWIM  |  --es modes all
            "modes" -> { val raw = i.getStringExtra("modes") ?: ""; val names = if (raw == "all") com.veepoo.protocol.model.enums.ESportType.values().map { it.name }.filter { it != "NONE" } else raw.split(",").map { it.trim() }.filter { it.isNotEmpty() }
                DebugTools.probeModes(names); return }
            "endworkout" -> { BandClient.emit(mapOf("type" to "sport", "msg" to "Actividad detenida")); return }
        }
        WorkManager.getInstance(c).enqueue(OneTimeWorkRequestBuilder<SyncWorker>().build())
    }
}
