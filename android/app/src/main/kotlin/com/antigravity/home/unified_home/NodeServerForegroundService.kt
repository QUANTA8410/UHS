package com.antigravity.home.unified_home

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class NodeServerForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "unified_home_node_hub"
        const val NOTIFICATION_ID = 8765
        var isServiceRunning = false
        var isWakeLockHeld = false
        var isWifiLockHeld = false
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Unified Smart Home Hub")
            .setContentText("24/7 Always-On Embedded Node Server running on port 8765")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        isServiceRunning = true

        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "UnifiedHome::24x7NodeWakeLock"
            ).apply {
                setReferenceCounted(false)
                acquire() // Indefinite 24/7 keep-alive without 24-hr timeout
            }
            isWakeLockHeld = wakeLock?.isHeld == true
        } catch (_: Exception) {}

        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val wifiMode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                WifiManager.WIFI_MODE_FULL_LOW_LATENCY
            } else {
                @Suppress("DEPRECATION")
                WifiManager.WIFI_MODE_FULL_HIGH_PERF
            }
            wifiLock = wifiManager.createWifiLock(wifiMode, "UnifiedHome::24x7NodeWifiLock").apply {
                setReferenceCounted(false)
                acquire()
            }
            isWifiLockHeld = wifiLock?.isHeld == true
        } catch (_: Exception) {}
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
        isWakeLockHeld = false

        try {
            if (wifiLock?.isHeld == true) {
                wifiLock?.release()
            }
        } catch (_: Exception) {}
        isWifiLockHeld = false

        isServiceRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Unified Home Hub 24/7 Server",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the embedded HTTP & WebSocket server alive 24/7"
            }
            manager.createNotificationChannel(channel)
        }
    }
}
