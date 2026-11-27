import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snorec/models/app_settings.dart';
import 'package:snorec/services/audio_recorder_service.dart';
import 'package:snorec/services/classifier_service.dart';
import 'package:snorec/services/fgs_bridge.dart';
import 'package:snorec/services/session_log_service.dart';
import 'package:snorec/services/storage_service.dart';

class TestMic extends Fake implements AudioRecorder {
  final stream = StreamController<Uint8List>.broadcast();
  int starts = 0;
  int stops = 0;
  Completer<void>? opening;

  @override
  Future<bool> hasPermission({bool request = true}) async => true;
  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    starts++;
    await opening?.future;
    return stream.stream;
  }

  @override
  Future<String?> stop() async {
    stops++;
    return null;
  }

  @override
  Future<void> dispose() => stream.close();
}

class FailingStorage extends StorageService {
  @override
  Future<String> newRecordingPath() async => throw FileSystemExceptionForTest();
}

class FileSystemExceptionForTest implements Exception {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('snorec/fgs');
  late TestMic mic;
  late SessionLogService log;
  late AudioRecorderService recorder;
  late List<String> calls;
  const settings = AppSettings(ignoreFirstMinutes: 0, minSegmentSeconds: 0);

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    FgsBridge.initialize();
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
    mic = TestMic();
    log = SessionLogService();
    recorder = AudioRecorderService(
      FailingStorage(),
      ClassifierService(),
      log,
      audioRecorder: mic,
    );
  });

  tearDown(() async {
    await recorder.stop();
    recorder.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('foreground rejection never opens the mic and is logged', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'start') {
            throw PlatformException(code: 'FGS_START', message: 'restricted');
          }
          return null;
        });
    await expectLater(
      recorder.start(settings: settings),
      throwsA(isA<PlatformException>()),
    );
    expect(mic.starts, 0);
    expect(recorder.isRunning, isFalse);
    expect(calls, contains('stop'));
    expect((await log.load())!.stopReason, SessionStopReason.startError);
  });

  test('rapid double start opens only one microphone stream', () async {
    await Future.wait([
      recorder.start(settings: settings),
      recorder.start(settings: settings),
    ]);
    expect(mic.starts, 1);
    expect(calls.where((call) => call == 'start'), hasLength(1));
  });

  test(
    'stop during startup waits and closes the newly opened microphone',
    () async {
      mic.opening = Completer<void>();
      final starting = recorder.start(settings: settings);
      final stopping = recorder.stop();
      mic.opening!.complete();
      await Future.wait([starting, stopping]);
      expect(recorder.isRunning, isFalse);
      expect(mic.starts, 1);
      expect(mic.stops, 1);
      expect((await log.load())!.endedCleanly, isTrue);
    },
  );

  test(
    'saving failure still releases foreground service and reports idle',
    () async {
      await recorder.start(settings: settings);
      mic.stream.add(Uint8List.fromList([255, 127, 255, 127]));
      await Future<void>.delayed(Duration.zero);
      await recorder.stop();
      expect(recorder.isRunning, isFalse);
      expect(recorder.status.phase, RecorderPhase.idle);
      expect(calls.last, 'stop');
      expect((await log.load())!.stopReason, SessionStopReason.storageError);
    },
  );

  test('expired end time never starts an unbounded session', () async {
    await expectLater(
      recorder.start(
        settings: settings,
        endsAt: DateTime.now().subtract(const Duration(seconds: 1)),
      ),
      throwsStateError,
    );
    expect(mic.starts, 0);
    expect(calls, isEmpty);
  });

  test('notification is refreshed for a second recording session', () async {
    await recorder.start(settings: settings);
    await recorder.stop();
    calls.clear();
    await recorder.start(settings: settings);
    expect(calls, contains('update'));
  });
}
