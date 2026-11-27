package dev.shenlon.snorec

import android.app.ActivityManager
import android.app.NotificationManager
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.ResultReceiver
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Application-scoped bridge: recording keeps working without an Activity. */
class RecordingBridge(context: Context, messenger: BinaryMessenger) : ContextWrapper(context) {
    private val channel = MethodChannel(messenger, "snorec/fgs")

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> startRecordingService(result)
                    "stop" -> {
                        RecordingService.stop(this)
                        result.success(null)
                    }
                    "update" -> {
                        RecordingService.updateNotification(
                            call.argument<String>("title"), call.argument<String>("content"))
                        result.success(null)
                    }
                    "isIgnoringBatteryOptimizations" -> result.success(isBatteryExempt())
                    "backgroundStatus" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        val am = getSystemService(ACTIVITY_SERVICE) as ActivityManager
                        result.success(mapOf(
                            "manufacturer" to Build.MANUFACTURER,
                            "batteryExempt" to isBatteryExempt(),
                            "powerSaveMode" to pm.isPowerSaveMode,
                            "backgroundRestricted" to
                                (Build.VERSION.SDK_INT >= 28 && am.isBackgroundRestricted)))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        if (Build.VERSION.SDK_INT >= 23 && !isBatteryExempt()) {
                            openSettings(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                        }
                        result.success(null)
                    }
                    "openAppSettings" -> {
                        openSettings(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        result.success(null)
                    }
                    "scheduleAutoStart" -> {
                        val at = call.argument<Number>("epochMs")?.toLong()
                        if (at == null) result.error("ARG", "epochMs required", null)
                        else result.success(AutoStartScheduler.schedule(this, at))
                    }
                    "cancelAutoStart" -> {
                        AutoStartScheduler.cancel(this)
                        clearPendingStart()
                        result.success(null)
                    }
                    "autoStartScheduledAt" -> result.success(
                        AutoStartScheduler.scheduledAt(this).takeIf { it != 0L })
                    "canScheduleExact" -> result.success(AutoStartScheduler.canScheduleExact(this))
                    "openExactAlarmSettings" -> {
                        if (Build.VERSION.SDK_INT >= 31) {
                            openSettings(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                        }
                        result.success(null)
                    }
                    "consumePendingAutoStart" -> {
                        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                        val at = prefs.getLong("flutter.snorec_pending_auto_start_at", 0L)
                        val pending = prefs.getBoolean("flutter.snorec_pending_auto_start", false)
                        clearPendingStart()
                        result.success(if (pending && at != 0L) at else null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("ANDROID", e.message ?: e.javaClass.simpleName, null)
            }
        }
    }

    private fun clearPendingStart() {
        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE).edit()
            .remove("flutter.snorec_pending_auto_start")
            .remove("flutter.snorec_pending_auto_start_at").apply()
        getSystemService(NotificationManager::class.java).cancel(AutoStartReceiver.NOTIFICATION_ID)
    }

    private fun startRecordingService(result: MethodChannel.Result) {
        val handler = Handler(Looper.getMainLooper())
        var replied = false
        val timeout = Runnable {
            if (!replied) {
                replied = true
                RecordingService.stop(this)
                result.error("FGS_TIMEOUT", "Android did not start the recording service. Reopen SnoREC and try again.", null)
            }
        }
        val receiver = object : ResultReceiver(handler) {
            override fun onReceiveResult(code: Int, data: Bundle?) {
                if (replied) return
                replied = true
                handler.removeCallbacks(timeout)
                if (code == 0) result.success(null)
                else result.error("FGS_START", data?.getString("error"), null)
            }
        }
        val intent = Intent(this, RecordingService::class.java).apply {
            action = RecordingService.ACTION_START
            putExtra(RecordingService.EXTRA_RESULT, receiver)
        }
        handler.postDelayed(timeout, 10000)
        try {
            ContextCompat.startForegroundService(this, intent)
        } catch (e: Exception) {
            replied = true
            handler.removeCallbacks(timeout)
            throw e
        }
    }

    private fun isBatteryExempt(): Boolean {
        if (Build.VERSION.SDK_INT < 23) return true
        return (getSystemService(POWER_SERVICE) as PowerManager)
            .isIgnoringBatteryOptimizations(packageName)
    }

    private fun openSettings(action: String) {
        val intent = Intent(action, Uri.parse("package:$packageName"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(intent)
        } catch (e: android.content.ActivityNotFoundException) {
            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }
}
