package com.careway.vigor_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

/** Solo depuracion: `adb shell am broadcast -n com.careway.vigor_app/.DebugSyncReceiver` encola un SyncWorker inmediato. */
class DebugSyncReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent?) {
        WorkManager.getInstance(c).enqueue(OneTimeWorkRequestBuilder<SyncWorker>().build())
    }
}
