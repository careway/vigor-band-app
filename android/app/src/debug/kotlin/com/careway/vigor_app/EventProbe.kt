package com.careway.vigor_app

import android.util.Log
import com.google.gson.Gson
import com.veepoo.protocol.VPOperateManager
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.listener.data.ICameraDataListener
import com.veepoo.protocol.listener.data.IDeviceSportReportListener
import com.veepoo.protocol.listener.data.IFindPhonelistener
import com.veepoo.protocol.listener.data.IKnocknotifyListener
import com.veepoo.protocol.listener.data.IMusicControlListener
import com.veepoo.protocol.listener.data.IPhoneListener
import com.veepoo.protocol.listener.data.ISOSListener
import com.veepoo.protocol.listener.data.ISportModelStateListener
import com.veepoo.protocol.model.datas.SportControlDataInfo
import com.veepoo.protocol.model.datas.SportModelStateData
import com.veepoo.protocol.model.enums.ECameraStatus

/**
 * SOLO DEPURACION (carpeta src/debug, no existe en release): se registra en todos los eventos que la pulsera puede disparar y escribe una
 * linea "EVENTO ..." en logcat (tag VIGORLOG) por cada uno, para probar a mano que botones y gestos llegan. No guarda nada ni hace nada mas.
 */
object EventProbe {
    private const val TAG = "VIGORLOG"
    private var registered = false
    private fun ev(s: String) { Log.i(TAG, "EVENTO " + s) }

    fun register() {
        if (registered) return
        val m = VPOperateManager.getInstance()
        try {
            m.settingFindPhoneListener(object : IFindPhonelistener { override fun findPhone() = ev("buscar-movil (la pulsera pide que suene el movil)"); override fun deviceFindingCYPhone() = ev("buscar-movil-CY") })
            m.settingKnocknotifyListener(object : IKnocknotifyListener { override fun knocknotify(i: Int) = ev("golpecito valor=$i") })
            m.settingSOSListener(object : ISOSListener { override fun sos() = ev("SOS") })
            m.settingPhoneListener(object : IPhoneListener {
                override fun rejectPhone() = ev("llamada: rechazar"); override fun cliencePhone() = ev("llamada: silenciar"); override fun appAnswerCall() = ev("llamada: contestar") })
            m.settingMusicControlListener(object : IMusicControlListener {
                override fun nextMusic() = ev("musica: siguiente"); override fun previousMusic() = ev("musica: anterior"); override fun pauseAndPlayMusic() = ev("musica: pausa/reproducir")
                override fun pauseMusic() = ev("musica: pausa"); override fun playMusic() = ev("musica: reproducir"); override fun voiceUp() = ev("musica: volumen +"); override fun voiceDown() = ev("musica: volumen -")
                override fun oprateMusicSuccess() = ev("musica: operacion ok"); override fun oprateMusicFail() = ev("musica: operacion fallida") })
            m.setSportControlReportListener(object : IDeviceSportReportListener { override fun onSportControlDataChange(d: SportControlDataInfo) = ev("deporte-control " + Gson().toJson(d)) })
            m.setNewSportDataReportListener(object : ISportModelStateListener {
                override fun onSportModelStateChange(d: SportModelStateData) = ev("deporte-estado " + Gson().toJson(d)); override fun onSportStopped() = ev("deporte: parado") })
            m.setCameraListener(object : ICameraDataListener { override fun OnCameraDataChange(s: ECameraStatus) = ev("camara " + s.name) })
            registered = true; ev("sonda registrada (find, golpecito, SOS, llamada, musica, deporte, camara)")
        } catch (t: Throwable) { Log.w(TAG, "EventProbe: " + t.javaClass.simpleName + " " + t.message) }
    }

    /** Entra en el modo foto de la pulsera 90 s (el obturador solo se oye en ese modo) y sale solo. */
    fun cameraMode(seconds: Long = 90) {
        val m = VPOperateManager.getInstance(); val noop = IBleWriteResponse { }
        val l = ICameraDataListener { s -> ev("camara " + s.name) }
        ev("camara: entrando en modo foto $seconds s (pulsa el boton de disparo de la pulsera)")
        try { m.startCamera(noop, l) } catch (t: Throwable) { ev("camara: error " + t.javaClass.simpleName); return }
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({ try { m.stopCamera(noop, l); ev("camara: modo foto cerrado") } catch (_: Throwable) {} }, seconds * 1000)
    }
}
