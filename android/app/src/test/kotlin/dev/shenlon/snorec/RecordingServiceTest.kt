package dev.shenlon.snorec

import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowPowerManager

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class RecordingServiceTest {
    @Test
    fun processRestartDoesNotClaimToBeRecording() {
        val controller = Robolectric.buildService(RecordingService::class.java).create()
        val service = controller.get()
        assertEquals(Service.START_NOT_STICKY, service.onStartCommand(null, 0, 1))
        val manager = service.getSystemService(NotificationManager::class.java)
        assertTrue(manager.activeNotifications.isEmpty())
        controller.destroy()
    }

    @Test
    fun foregroundSessionHoldsCpuLockAndReleasesItOnDestroy() {
        val controller = Robolectric.buildService(RecordingService::class.java).create()
        val service = controller.get()
        val intent = Intent(service, RecordingService::class.java)
            .setAction(RecordingService.ACTION_START)
        assertEquals(Service.START_NOT_STICKY, service.onStartCommand(intent, 0, 1))
        val wakeLock = ShadowPowerManager.getLatestWakeLock()
        assertNotNull(wakeLock)
        assertTrue(wakeLock.isHeld)
        val manager = service.getSystemService(NotificationManager::class.java)
        assertEquals(1, manager.activeNotifications.size)
        controller.destroy()
        assertFalse(wakeLock.isHeld)
        assertTrue(manager.activeNotifications.isEmpty())
        RecordingService.updateNotification("Listening", "Must not reappear")
        assertTrue(manager.activeNotifications.isEmpty())
    }

    @Test
    fun alarmPostsReminderWithoutLaunchingAnActivity() {
        val app = RuntimeEnvironment.getApplication()
        val time = System.currentTimeMillis()
        app.getSharedPreferences("snorec_auto_start", Context.MODE_PRIVATE)
            .edit().putLong("scheduled_at_epoch_ms", time).commit()
        AutoStartReceiver().onReceive(app, Intent(AutoStartReceiver.ACTION_FIRE))
        val prefs = app.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        assertTrue(prefs.getBoolean("flutter.snorec_pending_auto_start", false))
        assertEquals(time, prefs.getLong("flutter.snorec_pending_auto_start_at", 0))
        assertNull(org.robolectric.Shadows.shadowOf(app).nextStartedActivity)
        val manager = app.getSystemService(NotificationManager::class.java)
        assertTrue(manager.activeNotifications.any { it.id == AutoStartReceiver.NOTIFICATION_ID })
    }
}
