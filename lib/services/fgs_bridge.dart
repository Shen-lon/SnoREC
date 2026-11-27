import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin wrapper over the native Android foreground service. On non-Android
/// platforms all calls no-op, so the recorder logic can stay platform-agnostic.
class FgsBridge {
  static const _channel = MethodChannel('snorec/fgs');
  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static final _events = StreamController<String>.broadcast();
  static Stream<String> get events => _events.stream;

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      _events.add(call.method);
    });
  }

  static Future<void> start() async {
    if (!_isAndroid) return;
    // Starting the microphone without the service would silently fail later
    // when Android backgrounds us. Wait for native foreground readiness.
    await _channel.invokeMethod('start');
  }

  static Future<void> stop() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }

  static Future<void> update({
    required String title,
    required String content,
  }) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('update', {
        'title': title,
        'content': content,
      });
    } catch (_) {}
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!_isAndroid) return true;
    try {
      final v = await _channel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> backgroundStatus() async {
    if (!_isAndroid) return const {};
    try {
      return await _channel.invokeMapMethod<String, dynamic>(
            'backgroundStatus',
          ) ??
          const {};
    } catch (_) {
      return const {};
    }
  }

  static Future<void> openAppSettings() async {
    if (!_isAndroid) return;
    await _channel.invokeMethod('openAppSettings');
  }

  /// Schedule a one-shot AlarmManager broadcast to wake the app at
  /// [fireAt]. Returns true if the OS accepted the schedule.
  static Future<bool> scheduleAutoStart(DateTime fireAt) async {
    if (!_isAndroid) return false;
    try {
      final v = await _channel.invokeMethod<bool>('scheduleAutoStart', {
        'epochMs': fireAt.millisecondsSinceEpoch,
      });
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancelAutoStart() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('cancelAutoStart');
    } catch (_) {}
  }

  /// Currently-armed alarm time, or null if nothing is scheduled.
  static Future<DateTime?> autoStartScheduledAt() async {
    if (!_isAndroid) return null;
    try {
      final v = await _channel.invokeMethod<int>('autoStartScheduledAt');
      if (v == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(v);
    } catch (_) {
      return null;
    }
  }

  /// On API 31+, exact alarms require user grant unless USE_EXACT_ALARM
  /// applies. False here means we should send the user to settings.
  static Future<bool> canScheduleExact() async {
    if (!_isAndroid) return true;
    try {
      final v = await _channel.invokeMethod<bool>('canScheduleExact');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openExactAlarmSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('openExactAlarmSettings');
    } catch (_) {}
  }

  /// Returns the alarm time once. The caller must reject expired sessions.
  static Future<DateTime?> consumePendingAutoStart() async {
    if (!_isAndroid) return null;
    try {
      final v = await _channel.invokeMethod<int>('consumePendingAutoStart');
      return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
    } catch (_) {
      return null;
    }
  }
}
