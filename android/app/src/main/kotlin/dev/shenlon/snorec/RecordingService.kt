package dev.shenlon.snorec

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.PowerManager
import android.os.ResultReceiver
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Minimal microphone-type foreground service. Its only job is to keep the
 * process alive while SnoREC is listening; all recording logic stays in
 * the Flutter main isolate.
 *
 * Holds a PARTIAL_WAKE_LOCK for the duration of the session. Without it,
 * Doze-mode CPU throttling can pause the audio stream when the screen is
 * off — even though the foreground service keeps the process alive. The
 * wake lock keeps the CPU on; it does not keep the screen on.
 */
class RecordingService : Service() {

    companion object {
        const val ACTION_START = "dev.shenlon.snorec.START"
        const val EXTRA_RESULT = "result"
        private var activeService: RecordingService? = null

        fun stop(context: Context) {
            activeService?.intentionalStop = true
            context.stopService(Intent(context, RecordingService::class.java))
        }

        fun updateNotification(title: String?, content: String?) {
            val service = activeService ?: return
            title?.let { service.currentTitle = it }
            content?.let { service.currentContent = it }
            service.getSystemService(NotificationManager::class.java)
                ?.notify(NOTIFICATION_ID, service.buildNotification())
        }
        // v2 channel id: forces existing installs to pick up the
        // explicit silent + no-vibration + no-lights config below.
        // NotificationChannel settings are immutable once created, so
        // changing the ID is the supported way to roll out new defaults.
        private const val CHANNEL_ID = "snorec_recording_v2"
        private const val LEGACY_CHANNEL_ID = "snorec_recording"
        private const val CHANNEL_NAME = "SnoREC recording"
        private const val NOTIFICATION_ID = 1001
        private const val WAKE_LOCK_TAG = "snorec:recording"
        private const val DEFAULT_TITLE = "SnoREC is listening"
        private const val DEFAULT_CONTENT = "Keeps recording until you tap stop"
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var intentionalStop = false
    private var currentTitle: String = DEFAULT_TITLE
    private var currentContent: String = DEFAULT_CONTENT

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // A restarted service cannot recreate a lost Dart recording session.
        // Never show a false "listening" notification after process death.
        if (intent?.action != ACTION_START) {
            stopSelf()
            return START_NOT_STICKY
        }
        @Suppress("DEPRECATION")
        val receiver = intent.getParcelableExtra<ResultReceiver>(EXTRA_RESULT)
        try {
            intentionalStop = false
            ensureChannel()
            val notification = buildNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                startForeground(NOTIFICATION_ID, notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            acquireWakeLock()
            activeService = this
            receiver?.send(0, null)
        } catch (e: Exception) {
            releaseWakeLock()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            receiver?.send(1, Bundle().apply { putString("error", e.message) })
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        val interrupted = activeService === this && !intentionalStop
        if (activeService === this) activeService = null
        releaseWakeLock()
        stopForeground(STOP_FOREGROUND_REMOVE)
        if (interrupted) {
            FlutterEngineCache.getInstance().get(MainActivity.ENGINE_ID)?.let {
                MethodChannel(it.dartExecutor.binaryMessenger, "snorec/fgs")
                    .invokeMethod("serviceStopped", null)
            }
        }
        super.onDestroy()
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val lock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG)
        lock.setReferenceCounted(false)
        wakeLock = lock
        lock.acquire()
    }

    private fun releaseWakeLock() {
        val lock = wakeLock ?: return
        wakeLock = null
        try {
            if (lock.isHeld) lock.release()
        } catch (_: Throwable) {}
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        // Tidy up the v1 channel from prior installs. Safe no-op on fresh installs.
        if (manager.getNotificationChannel(LEGACY_CHANNEL_ID) != null) {
            try {
                manager.deleteNotificationChannel(LEGACY_CHANNEL_ID)
            } catch (_: Throwable) {}
        }
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        )
        channel.description = "Keeps SnoREC listening overnight"
        channel.setShowBadge(false)
        // Overnight-friendly: never vibrate, never make sound, never light
        // up the lockscreen. IMPORTANCE_LOW is silent on stock Android,
        // but several OEMs (Xiaomi, OPPO, older OnePlus) ignore the
        // implicit default and vibrate on first notify. Be explicit.
        channel.setSound(null, null)
        channel.enableVibration(false)
        channel.enableLights(false)
        channel.lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pi = if (launch != null) {
            PendingIntent.getActivity(
                this,
                0,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else null

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        builder
            .setContentTitle(currentTitle)
            .setContentText(currentContent)
            .setSmallIcon(R.drawable.ic_stat_snorec)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
        if (pi != null) builder.setContentIntent(pi)
        return builder.build()
    }
}
