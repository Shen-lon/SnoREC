import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_services.dart';
import 'screens/home_screen.dart';
import 'services/audio_playback_service.dart';
import 'services/audio_recorder_service.dart';
import 'services/auto_start_service.dart';
import 'services/classifier_service.dart';
import 'services/fgs_bridge.dart';
import 'services/session_log_service.dart';
import 'services/settings_service.dart';
import 'services/silero_vad_service.dart';
import 'services/storage_service.dart';
import 'utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Manrope',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  FgsBridge.initialize();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final settings = SettingsService();
  final storage = StorageService();
  final silero = SileroVadService();
  final classifier = ClassifierService(silero: silero);
  final sessionLog = SessionLogService();
  final recorder = AudioRecorderService(storage, classifier, sessionLog);
  final playback = AudioPlaybackService();
  final autoStart = AutoStartService();

  // Warm up both inference models so the first clip doesn't stall.
  unawaited(classifier.init());
  unawaited(silero.init());

  // Pending starts are handled by HomeScreen only once the UI is resumed.
  // Microphone foreground services cannot be started from a cold background
  // engine on modern Android.

  // Make sure the next alarm is armed for users who already had
  // auto-schedule on before this version. New installs will (re)arm
  // when they enable the toggle.
  if (!recorder.isRunning) {
    final s = await settings.load();
    if (s.autoSchedule) {
      unawaited(autoStart.scheduleNext(s));
    }
  }

  runApp(
    SnoRECApp(
      settings: settings,
      storage: storage,
      classifier: classifier,
      recorder: recorder,
      playback: playback,
      sessionLog: sessionLog,
    ),
  );
}

class SnoRECApp extends StatelessWidget {
  final SettingsService settings;
  final StorageService storage;
  final ClassifierService classifier;
  final AudioRecorderService recorder;
  final AudioPlaybackService playback;
  final SessionLogService sessionLog;

  const SnoRECApp({
    super.key,
    required this.settings,
    required this.storage,
    required this.classifier,
    required this.recorder,
    required this.playback,
    required this.sessionLog,
  });

  @override
  Widget build(BuildContext context) {
    return AppServices(
      settings: settings,
      storage: storage,
      classifier: classifier,
      recorder: recorder,
      playback: playback,
      sessionLog: sessionLog,
      child: MaterialApp(
        title: 'SnoREC',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
