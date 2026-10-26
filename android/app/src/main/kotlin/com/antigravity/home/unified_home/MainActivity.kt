package com.antigravity.home.unified_home

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val NOTIFICATION_CHANNEL = "com.antigravity.home/notifications"
    private val NOTIFICATION_CHANNEL_ALT = "com.antigravity.home.unified_home/notifications"
    private val OTA_CHANNEL = "com.antigravity.home.unified_home/ota"
    private val MASTER_OS_CHANNEL = "com.antigravity.home.unified_home/master_os"
    private val LIVE_CHANNEL_ID = "unified_home_live_appliance"
    private val ALERT_CHANNEL_ID = "unified_home_appliance_alerts"
    private var masterMethodChannel: MethodChannel? = null
    private var initialDeepLink: String? = null
    private var nodeWakeLock: PowerManager.WakeLock? = null
    private var nodeWifiLock: WifiManager.WifiLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannels()

        // 1. Zero-Dependency Native Notification & Audible Chime Alert Bridge
        val notificationHandler = MethodChannel.MethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (ActivityCompat.checkSelfPermission(
                                this,
                                Manifest.permission.POST_NOTIFICATIONS
                            ) != PackageManager.PERMISSION_GRANTED
                        ) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                1001
                            )
                        }
                    }
                    result.success(true)
                }
                "requestLocationPermission" -> {
                    val perms = mutableListOf(
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                    )
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        perms.add(Manifest.permission.NEARBY_WIFI_DEVICES)
                    }
                    val missing = perms.filter {
                        ActivityCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
                    }
                    if (missing.isNotEmpty()) {
                        ActivityCompat.requestPermissions(this, missing.toTypedArray(), 1003)
                    }
                    result.success(true)
                }
                "hasLocationPermission" -> {
                    val hasFine = ActivityCompat.checkSelfPermission(
                        this,
                        Manifest.permission.ACCESS_FINE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                    val hasCoarse = ActivityCompat.checkSelfPermission(
                        this,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(hasFine || hasCoarse)
                }
                "triggerApplianceAlert" -> {
                    val title = call.argument<String>("title") ?: "🧺 Appliance Alert"
                    val body = call.argument<String>("body") ?: "Cycle completed!"
                    val withChime = call.argument<Boolean>("withChime") ?: true
                    val withVibration = call.argument<Boolean>("withVibration") ?: true
                    val notificationId = call.argument<Int>("notificationId") ?: 1002

                    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

                    val builder = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
                        .setSmallIcon(android.R.drawable.ic_dialog_info)
                        .setContentTitle(title)
                        .setContentText(body)
                        .setPriority(NotificationCompat.PRIORITY_HIGH)
                        .setAutoCancel(true)

                    // On pre-Oreo devices, channel-based audio/vibration does not exist,
                    // so apply directly to NotificationCompat.Builder. On Android O+, ALERT_CHANNEL_ID
                    // natively plays chime and vibrates without duplicate manual playback.
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                        if (withChime) {
                            builder.setSound(soundUri)
                        }
                        if (withVibration) {
                            builder.setVibrate(longArrayOf(0, 300, 200, 300))
                        }
                    }

                    manager.notify(notificationId, builder.build())
                    result.success(true)
                }
                "enableNodeKeepAlive" -> {
                    try {
                        val serviceIntent = Intent(this, NodeServerForegroundService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }

                        if (nodeWakeLock == null) {
                            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                            nodeWakeLock = powerManager.newWakeLock(
                                PowerManager.PARTIAL_WAKE_LOCK,
                                "UnifiedHome::NodeWakeLock"
                            ).apply {
                                setReferenceCounted(false)
                            }
                        }
                        if (nodeWakeLock?.isHeld != true) {
                            nodeWakeLock?.acquire() // Indefinite 24/7 keep-alive without 24-hr timeout
                        }

                        if (nodeWifiLock == null) {
                            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                            val wifiMode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                WifiManager.WIFI_MODE_FULL_LOW_LATENCY
                            } else {
                                @Suppress("DEPRECATION")
                                WifiManager.WIFI_MODE_FULL_HIGH_PERF
                            }
                            nodeWifiLock = wifiManager.createWifiLock(wifiMode, "UnifiedHome::NodeWifiLock").apply {
                                setReferenceCounted(false)
                            }
                        }
                        if (nodeWifiLock?.isHeld != true) {
                            nodeWifiLock?.acquire()
                        }

                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(intent)
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("KEEP_ALIVE_ERROR", e.localizedMessage, e.message)
                    }
                }
                "disableNodeKeepAlive" -> {
                    try {
                        val serviceIntent = Intent(this, NodeServerForegroundService::class.java)
                        stopService(serviceIntent)
                    } catch (_: Exception) {}

                    try {
                        if (nodeWakeLock?.isHeld == true) {
                            nodeWakeLock?.release()
                        }
                    } catch (_: Exception) {}

                    try {
                        if (nodeWifiLock?.isHeld == true) {
                            nodeWifiLock?.release()
                        }
                    } catch (_: Exception) {}

                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(true)
                }
                "getNodeKeepAliveStatus" -> {
                    val isWake = NodeServerForegroundService.isWakeLockHeld || nodeWakeLock?.isHeld == true
                    val isWifi = NodeServerForegroundService.isWifiLockHeld || nodeWifiLock?.isHeld == true
                    var isBatteryIgnored = false
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                        isBatteryIgnored = powerManager.isIgnoringBatteryOptimizations(packageName)
                    }
                    result.success(
                        mapOf(
                            "wakeLock" to isWake,
                            "wifiLock" to isWifi,
                            "batteryOptimizationIgnored" to isBatteryIgnored,
                            "isForegroundServiceRunning" to NodeServerForegroundService.isServiceRunning
                        )
                    )
                }
                "launchExternalApp" -> {
                    val pkg = call.argument<String>("packageName") ?: ""
                    val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                    if (launchIntent != null) {
                        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(launchIntent)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "launchFirstInstalledApp" -> {
                    val packages = call.argument<List<String>>("packages") ?: listOf()
                    var launched = false
                    for (pkg in packages) {
                        val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                        if (launchIntent != null) {
                            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(launchIntent)
                            launched = true
                            break
                        }
                    }
                    result.success(launched)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
            .setMethodCallHandler(notificationHandler)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL_ALT)
            .setMethodCallHandler(notificationHandler)

        // 2. OTA Update Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OTA_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath")
                if (filePath == null) {
                    result.error("INVALID_PATH", "File path is null", null)
                    return@setMethodCallHandler
                }
                val file = File(filePath)
                if (!file.exists()) {
                    result.error("FILE_NOT_FOUND", "APK file does not exist at $filePath", null)
                    return@setMethodCallHandler
                }

                try {
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                        val uri = FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            file
                        )
                        setDataAndType(uri, "application/vnd.android.package-archive")
                    }
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("INSTALL_ERROR", e.localizedMessage, e.message)
                }
            } else {
                result.notImplemented()
            }
        }

        // 3. Master OS Channel (Live Notifications & Deep-Link forwarding)
        masterMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MASTER_OS_CHANNEL)
        masterMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialDeepLink" -> {
                    val link = initialDeepLink
                    initialDeepLink = null // Consume once
                    result.success(link)
                }
                "updateLiveNotification" -> {
                    val title = call.argument<String>("title") ?: "Appliance Active"
                    val subtitle = call.argument<String>("subtitle") ?: "Running..."
                    val progress = call.argument<Int>("progress") ?: 50
                    showOngoingNotification(title, subtitle, progress)
                    result.success(true)
                }
                "dismissLiveNotification" -> {
                    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    manager.cancel(9001)
                    result.success(true)
                }
                "requestLocationPermission" -> {
                    val perms = mutableListOf(
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                    )
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        perms.add(Manifest.permission.NEARBY_WIFI_DEVICES)
                    }
                    val missing = perms.filter {
                        ActivityCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
                    }
                    if (missing.isNotEmpty()) {
                        ActivityCompat.requestPermissions(this, missing.toTypedArray(), 1003)
                    }
                    result.success(true)
                }
                "hasLocationPermission" -> {
                    val hasFine = ActivityCompat.checkSelfPermission(
                        this,
                        Manifest.permission.ACCESS_FINE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                    val hasCoarse = ActivityCompat.checkSelfPermission(
                        this,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(hasFine || hasCoarse)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIncomingIntent(intent)
    }

    private fun handleIncomingIntent(intent: Intent?) {
        val data = intent?.dataString
        if (!data.isNullOrEmpty()) {
            initialDeepLink = data
            masterMethodChannel?.invokeMethod("onDeepLink", data)
        }
    }

    private fun showOngoingNotification(title: String, subtitle: String, progress: Int) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val builder = NotificationCompat.Builder(this, LIVE_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(100, progress, false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
        manager.notify(9001, builder.build())
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Live progress channel (Low importance for ongoing persistent state)
            val liveChannel = NotificationChannel(
                LIVE_CHANNEL_ID,
                "Live Appliance Progress",
                NotificationManager.IMPORTANCE_LOW
            )
            manager.createNotificationChannel(liveChannel)

            // High importance alert channel with audible chime and vibration
            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            val alertChannel = NotificationChannel(
                ALERT_CHANNEL_ID,
                "Appliance & Automation Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Audible chimes and heads-up alerts when smart appliances finish cycles"
                enableLights(true)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 200, 300)
                setSound(soundUri, audioAttributes)
            }
            manager.createNotificationChannel(alertChannel)
        }
    }

    override fun onDestroy() {
        try {
            if (nodeWakeLock?.isHeld == true) {
                nodeWakeLock?.release()
            }
        } catch (_: Exception) {}
        try {
            if (nodeWifiLock?.isHeld == true) {
                nodeWifiLock?.release()
            }
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
