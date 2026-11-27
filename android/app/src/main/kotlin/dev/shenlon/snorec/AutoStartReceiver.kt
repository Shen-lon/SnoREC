package dev.shenlon.snorec

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

/** Exact alarms do not grant permission to open UI or use a background mic. */
class AutoStartReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_FIRE = "dev.shenlon.snorec.AUTO_START_FIRE"
        const val NOTIFICATION_ID = 1002
        private const val CHANNEL_ID = "snorec_schedule"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_FIRE) return
        // Retain the intended alarm time, rather than extending a delayed alarm
        // into a new recording window after the scheduled end.
        val scheduledAt = AutoStartScheduler.scheduledAt(context)
        if (scheduledAt == 0L) return
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putBoolean("flutter.snorec_pending_auto_start", true)
            .putLong("flutter.snorec_pending_auto_start_at", scheduledAt)
            .apply()
        AutoStartScheduler.clearScheduled(context)
        val next = Calendar.getInstance().apply {
            timeInMillis = scheduledAt
            do { add(Calendar.DATE, 1) } while (timeInMillis <= System.currentTimeMillis())
        }
        AutoStartScheduler.schedule(context, next.timeInMillis)

        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(CHANNEL_ID,
                "Bedtime reminders", NotificationManager.IMPORTANCE_DEFAULT))
        }
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launch != null) {
            val pending = PendingIntent.getActivity(context, NOTIFICATION_ID, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val builder = if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }
            try {
                manager.notify(NOTIFICATION_ID, builder
                    .setSmallIcon(R.drawable.ic_stat_snorec)
                    .setContentTitle("Time to start SnoREC")
                    .setContentText("Tap to begin tonight's recording")
                    .setContentIntent(pending).setAutoCancel(true).build())
            } catch (_: SecurityException) {
                // The pending time is still picked up on the next visible launch.
            }
        }
        // If already visible, Flutter can start immediately. Otherwise it waits
        // for a resumed Activity, preserving Android's microphone restrictions.
        FlutterEngineCache.getInstance().get(MainActivity.ENGINE_ID)?.let {
            MethodChannel(it.dartExecutor.binaryMessenger, "snorec/fgs")
                .invokeMethod("autoStartDue", null)
        }
    }
}
