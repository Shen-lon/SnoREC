import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import 'audio_recorder_service.dart';
import 'fgs_bridge.dart';
import 'settings_service.dart';

/// Schedules bedtime reminders and consumes them only while the app is visible.
/// Android does not permit an alarm to silently start a background microphone.
class AutoStartService {
  static DateTime nextOccurrence(TimeOfDay t, {DateTime? from}) {
    final now = from ?? DateTime.now();
    var fire = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    if (!fire.isAfter(now)) {
      fire = DateTime(now.year, now.month, now.day + 1, t.hour, t.minute);
    }
    return fire;
  }

  static DateTime resolveEnd(TimeOfDay end, {DateTime? from}) {
    final now = from ?? DateTime.now();
    var stop = DateTime(now.year, now.month, now.day, end.hour, end.minute);
    if (!stop.isAfter(now)) {
      stop = DateTime(now.year, now.month, now.day + 1, end.hour, end.minute);
    }
    return stop;
  }

  /// Schedule (or reschedule) the next auto-start firing. Returns the
  /// fire time on success, null if the OS rejected the request.
  Future<DateTime?> scheduleNext(AppSettings s) async {
    if (!s.autoSchedule) {
      await FgsBridge.cancelAutoStart();
      return null;
    }
    final fireAt = nextOccurrence(s.startTime);
    final ok = await FgsBridge.scheduleAutoStart(fireAt);
    return ok ? fireAt : null;
  }

  Future<void> cancel() => FgsBridge.cancelAutoStart();

  Future<DateTime?> currentScheduledAt() => FgsBridge.autoStartScheduledAt();

  Future<bool> canScheduleExact() => FgsBridge.canScheduleExact();

  Future<void> openExactAlarmSettings() => FgsBridge.openExactAlarmSettings();

  static DateTime? pendingSessionEnd(
    AppSettings settings,
    DateTime firedAt, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    if (!settings.autoSchedule || firedAt.isAfter(current)) return null;
    final end = resolveEnd(settings.endTime, from: firedAt);
    return current.isBefore(end) ? end : null;
  }

  /// If the alarm fired before the app was open (or while it was), pick
  /// up the flag and start recording with the user's saved settings.
  Future<void> handleColdLaunch({
    required SettingsService settingsService,
    required AudioRecorderService recorder,
  }) async {
    final pending = await FgsBridge.consumePendingAutoStart();
    if (pending == null) return;
    final s = await settingsService.load();
    final endsAt = pendingSessionEnd(s, pending);
    if (endsAt == null || recorder.isRunning) return;
    try {
      await recorder.start(settings: s, endsAt: endsAt);
      // Re-arm for tomorrow so the user doesn't have to do anything.
      await scheduleNext(s);
    } catch (e, st) {
      debugPrint('auto-start cold launch failed: $e\n$st');
    }
  }
}
