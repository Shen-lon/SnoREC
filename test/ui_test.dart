import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snorec/main.dart';
import 'package:snorec/models/app_settings.dart';
import 'package:snorec/models/recording.dart';
import 'package:snorec/services/audio_playback_service.dart';
import 'package:snorec/services/audio_recorder_service.dart';
import 'package:snorec/services/classifier_service.dart';
import 'package:snorec/services/session_log_service.dart';
import 'package:snorec/services/settings_service.dart';
import 'package:snorec/services/storage_service.dart';
import 'package:snorec/utils/categories.dart';
import 'package:snorec/utils/theme.dart';
import 'package:snorec/widgets/recorder_panel.dart';

class _Storage extends Fake implements StorageService {
  _Storage(this.items);
  final List<Recording> items;
  @override
  Future<List<Recording>> loadAll() async => List.of(items);
}

class _Recorder extends Fake implements AudioRecorderService {
  _Recorder([this.current = SessionStatus.idle]);
  SessionStatus current;
  @override
  SessionStatus get status => current;
  @override
  Stream<SessionStatus> get status$ => const Stream.empty();
  @override
  bool get isRunning => current.phase != RecorderPhase.idle;
  @override
  void addSegmentListener(SegmentCallback cb) {}
  @override
  void removeSegmentListener(SegmentCallback cb) {}
  @override
  void updateSettings(AppSettings settings) {}
}

class _Classifier extends Fake implements ClassifierService {}

class _Playback extends Fake implements AudioPlaybackService {
  final changes = StreamController<PlaybackState>.broadcast();
  PlaybackState current = PlaybackState.idle;
  int toggles = 0;
  @override
  PlaybackState get state => current;
  @override
  Stream<PlaybackState> get state$ => changes.stream;
  @override
  Future<void> toggle(String session, String path) async {
    toggles++;
    current = PlaybackState(activeSession: session, playing: !current.playing);
    changes.add(current);
  }
}

final _samples = List.generate(
  7,
  (i) => Recording(
    id: 'sample-$i',
    filePath: '/sample-$i.wav',
    startedAt: DateTime(2026, 11, i < 4 ? 27 : 26, 1 + i % 4, 12 + i * 3),
    durationMs: 16000 + i * 5000,
    peakDb: -20,
    avgDb: -36,
    category: i.isEven ? SoundCategory.speech : SoundCategory.snoring,
    categoryLabel: i.isEven ? 'Talking' : 'Snoring',
    categoryConfidence: 0.8,
    waveform: List.generate(
      100,
      (n) => 0.12 + 0.7 * math.sin(n * 0.4).abs() * math.sin(n * 0.13).abs(),
    ),
  ),
);

const _captureKey = ValueKey('capture');
const _export = bool.fromEnvironment('UPDATE_SCREENSHOTS');

Future<void> _screenshot(WidgetTester tester, String name) async {
  if (!_export) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<_Playback> _app(
  WidgetTester tester, {
  required Size size,
  bool populated = false,
  double scale = 1,
  SessionStatus status = SessionStatus.idle,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({});
  PackageInfo.setMockInitialValues(
    appName: 'SnoREC',
    packageName: 'dev.shenlon.snorec',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('snorec/fgs'),
        (call) async => switch (call.method) {
          'isIgnoringBatteryOptimizations' => true,
          'backgroundStatus' => {'manufacturer': 'HONOR'},
          _ => null,
        },
      );
  final playback = _Playback();
  addTearDown(playback.changes.close);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: SnoRECApp(
        settings: SettingsService(),
        storage: _Storage(populated ? _samples : []),
        classifier: _Classifier(),
        recorder: _Recorder(status),
        playback: playback,
        sessionLog: SessionLogService(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return playback;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Manrope');
    for (final weight in [400, 500, 600, 700, 800]) {
      loader.addFont(rootBundle.load('assets/fonts/Manrope-$weight.ttf'));
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final spec in [
    (const Size(390, 844), 1.0),
    (const Size(320, 720), 1.7),
    (const Size(840, 900), 1.0),
  ]) {
    testWidgets(
      'navigation and layouts at ${spec.$1.width}px with text ${spec.$2}',
      (tester) async {
        await _app(tester, size: spec.$1, scale: spec.$2);
        expect(find.text('SnoREC'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _screenshot(
          tester,
          spec.$1.width >= 720
              ? 'foldable'
              : spec.$2 > 1
              ? 'large-text'
              : 'tonight',
        );
        await tester.tap(find.text('Library').last);
        await tester.pumpAndSettle();
        expect(find.text('Nothing recorded. Yet.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (spec.$1.width == 390) await _screenshot(tester, 'library-empty');
        await tester.tap(find.text('Settings').last);
        await tester.pumpAndSettle();
        expect(find.text('Make it yours.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (spec.$1.width == 390) await _screenshot(tester, 'settings');
        // Stop time cannot be edited while the schedule is disabled.
        final endTile = tester.widget<ListTile>(
          find.widgetWithText(ListTile, 'End session at'),
        );
        expect(endTile.enabled, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('library opens clips, switches views, and plays and pauses', (
    tester,
  ) async {
    final playback = await _app(
      tester,
      size: const Size(390, 844),
      populated: true,
    );
    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();
    await _screenshot(tester, 'library');
    await tester.tap(find.text('Thursday'));
    await tester.pumpAndSettle();
    expect(find.text('Night of Nov 26'), findsOneWidget);
    await _screenshot(tester, 'clips');
    await tester.tap(find.byTooltip('Play clip').first);
    await tester.pumpAndSettle();
    expect(playback.toggles, 1);
    expect(find.byTooltip('Pause clip'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause clip'));
    await tester.pumpAndSettle();
    expect(playback.toggles, 2);
    await tester.tap(find.text('By time'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Play clip'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('active session exposes end control and actual status', (
    tester,
  ) async {
    await _app(
      tester,
      size: const Size(390, 844),
      status: SessionStatus.idle.copyWith(
        phase: RecorderPhase.capturing,
        segmentsCaptured: 8,
        lastAmplitudeDb: -28,
        sessionStartedAt: DateTime.now().subtract(
          const Duration(hours: 2, minutes: 14),
        ),
      ),
    );
    expect(find.text('RECORDING A CLIP'), findsOneWidget);
    expect(find.text('End session'), findsOneWidget);
    await _screenshot(tester, 'recording');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('record action is accessible and disabled during transitions', (
    tester,
  ) async {
    var toggles = 0;
    Future<void> panel(bool busy) => tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecorderPanel(
              status: SessionStatus.idle,
              settings: const AppSettings(),
              onToggle: () => toggles++,
              onOpenSettings: () {},
              levels: const [],
              busy: busy,
            ),
          ),
        ),
      ),
    );
    await panel(false);
    await tester.ensureVisible(find.byKey(const ValueKey('record-toggle')));
    await tester.tap(find.byKey(const ValueKey('record-toggle')));
    expect(toggles, 1);
    await panel(true);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('record-toggle')))
          .onPressed,
      isNull,
    );
  });
}
