package com.careway.vigor_app

import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Build
import android.os.ParcelUuid
import java.util.UUID

/**
 * Publica el pulso de la actividad en curso como sensor Bluetooth de pulso estandar (servicio 0x180D), para que otras apps (Strava, etc.) lo lean
 * como si fuera una banda de pecho. Solo mientras dura una actividad y solo si el usuario lo activo. Sin probar con otra app ni con la pulsera.
 */
@SuppressLint("MissingPermission")
object HeartRateBroadcaster {
    private val SERVICE = UUID.fromString("0000180d-0000-1000-8000-00805f9b34fb")
    private val MEASURE = UUID.fromString("00002a37-0000-1000-8000-00805f9b34fb")
    private val LOCATION = UUID.fromString("00002a38-0000-1000-8000-00805f9b34fb")
    private val CCCD = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    private var server: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var measure: BluetoothGattCharacteristic? = null
    private val subscribed = HashSet<BluetoothDevice>()
    private var last: ByteArray? = null
    @Volatile var active = false; private set
    @Volatile var lastError: String? = null; private set

    private val advCb = object : AdvertiseCallback() {
        override fun onStartFailure(errorCode: Int) { lastError = "ADV_$errorCode"; stop() }
    }
    private val gattCb = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(d: BluetoothDevice, status: Int, newState: Int) { if (newState != BluetoothProfile.STATE_CONNECTED) synchronized(subscribed) { subscribed.remove(d) } }
        override fun onDescriptorWriteRequest(d: BluetoothDevice, id: Int, c: BluetoothGattDescriptor, prep: Boolean, resp: Boolean, off: Int, v: ByteArray?) {
            if (c.uuid == CCCD) synchronized(subscribed) { if (v != null && v.isNotEmpty() && v[0].toInt() != 0) subscribed.add(d) else subscribed.remove(d) }
            if (resp) server?.sendResponse(d, id, BluetoothGatt.GATT_SUCCESS, off, v)
        }
        override fun onDescriptorReadRequest(d: BluetoothDevice, id: Int, off: Int, c: BluetoothGattDescriptor) {
            server?.sendResponse(d, id, BluetoothGatt.GATT_SUCCESS, off, if (d in subscribed) byteArrayOf(1, 0) else byteArrayOf(0, 0))
        }
        override fun onCharacteristicReadRequest(d: BluetoothDevice, id: Int, off: Int, c: BluetoothGattCharacteristic) {
            val v = if (c.uuid == LOCATION) HeartRateWire.WRIST else (last ?: byteArrayOf(0, 0))
            server?.sendResponse(d, id, BluetoothGatt.GATT_SUCCESS, off, v)
        }
    }

    fun start(ctx: Context): Boolean {
        if (active) return true
        lastError = null
        if (Build.VERSION.SDK_INT >= 31 && ctx.checkSelfPermission(android.Manifest.permission.BLUETOOTH_ADVERTISE) != android.content.pm.PackageManager.PERMISSION_GRANTED) { lastError = "NO_PERMISSION"; return false }
        return try {
            val mgr = ctx.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            val adapter = mgr.adapter ?: run { lastError = "NO_BT"; return false }
            val adv = adapter.bluetoothLeAdvertiser ?: run { lastError = "NO_ADVERTISER"; return false }
            val srv = mgr.openGattServer(ctx, gattCb) ?: run { lastError = "NO_GATT"; return false }
            val svc = BluetoothGattService(SERVICE, BluetoothGattService.SERVICE_TYPE_PRIMARY)
            val m = BluetoothGattCharacteristic(MEASURE, BluetoothGattCharacteristic.PROPERTY_NOTIFY, 0)
            m.addDescriptor(BluetoothGattDescriptor(CCCD, BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE))
            svc.addCharacteristic(m)
            svc.addCharacteristic(BluetoothGattCharacteristic(LOCATION, BluetoothGattCharacteristic.PROPERTY_READ, BluetoothGattCharacteristic.PERMISSION_READ))
            srv.addService(svc)
            val settings = AdvertiseSettings.Builder().setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY).setConnectable(true).setTimeout(0).build()
            val data = AdvertiseData.Builder().setIncludeDeviceName(false).addServiceUuid(ParcelUuid(SERVICE)).build()
            val scanResp = AdvertiseData.Builder().setIncludeDeviceName(true).build()
            adv.startAdvertising(settings, data, scanResp, advCb)
            server = srv; advertiser = adv; measure = m; active = true; true
        } catch (e: Throwable) { lastError = "ERROR:" + e.javaClass.simpleName.take(30); stop(); false }
    }

    fun publish(bpm: Int) {
        val v = HeartRateWire.encode(bpm) ?: return
        last = v
        val s = server ?: return; val m = measure ?: return
        val targets = synchronized(subscribed) { subscribed.toList() }
        for (d in targets) try {
            if (Build.VERSION.SDK_INT >= 33) s.notifyCharacteristicChanged(d, m, false, v)
            else { @Suppress("DEPRECATION") m.value = v; @Suppress("DEPRECATION") s.notifyCharacteristicChanged(d, m, false) }
        } catch (_: Throwable) {}
    }

    fun stop() {
        try { advertiser?.stopAdvertising(advCb) } catch (_: Throwable) {}
        try { server?.close() } catch (_: Throwable) {}
        synchronized(subscribed) { subscribed.clear() }
        server = null; advertiser = null; measure = null; last = null; active = false
    }
}
