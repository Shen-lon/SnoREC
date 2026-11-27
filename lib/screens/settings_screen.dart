import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_services.dart';
import '../models/app_settings.dart';
import '../services/auto_start_service.dart';
import '../services/fgs_bridge.dart';
import '../utils/categories.dart';
import '../utils/theme.dart';
import '../widgets/brand.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  AppSettings? _settings;
  bool _batteryExempt = false;
  Map<String, dynamic> _background = const {};
  String _versionLabel = '';
  int _versionTaps = 0;
  DateTime? _lastVersionTap;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final svc = AppServices.of(context);
    final s = await svc.settings.load();
    final b = await FgsBridge.isIgnoringBatteryOptimizations();
    final background = await FgsBridge.backgroundStatus();
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _settings = s;
        _batteryExempt = b;
        _background = background;
        _versionLabel = 'SnoREC · v${info.version}';
      });
    }
  }

  Future<void> _save(AppSettings s) async {
    setState(() => _settings = s);
    final svc = AppServices.of(context);
    await svc.settings.save(s);
    // Apply immediately so changes take effect mid-session.
    svc.recorder.updateSettings(s);
    // Reschedule the next AlarmManager firing whenever the schedule
    // settings change. AutoStartService handles the autoSchedule=false
    // case by cancelling.
    final fireAt = await AutoStartService().scheduleNext(s);
    if (s.autoSchedule && fireAt == null && mounted) {
      // Almost always means Android 12 hasn't granted the exact-alarm
      // permission yet. Send the user to the system screen.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Exact alarms not allowed yet. Enable in system settings.',
          ),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => AutoStartService().openExactAlarmSettings(),
          ),
        ),
      );
    }
  }

  void _onVersionTap() {
    final now = DateTime.now();
    if (_lastVersionTap != null &&
        now.difference(_lastVersionTap!) > const Duration(seconds: 2)) {
      _versionTaps = 0;
    }
    _lastVersionTap = now;
    _versionTaps++;

    final s = _settings;
    if (s == null) return;

    if (!s.developerMode && _versionTaps >= 10) {
      _versionTaps = 0;
      _save(s.copyWith(developerMode: true));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Developer mode enabled')));
    } else if (s.developerMode && _versionTaps >= 10) {
      _versionTaps = 0;
      _save(s.copyWith(developerMode: false));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Developer mode disabled')));
    }
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) {
    return showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(context).copyWith(
          timePickerTheme: TimePickerThemeData(
            backgroundColor: AppColors.surface,
            hourMinuteColor: AppColors.surfaceAlt,
            dayPeriodColor: AppColors.surfaceAlt,
            dialBackgroundColor: AppColors.surfaceAlt,
          ),
        ),
        child: child!,
      ),
    );
  }

  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  Future<void> _reanalyzeAll() async {
    final svc = AppServices.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final all = await svc.storage.loadAll();
    if (!mounted) return;
    if (all.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No recordings to re-analyze')),
      );
      return;
    }

    final progress = ValueNotifier<int>(0);
    final total = all.length;
    bool cancelled = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Re-analyzing'),
        content: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (_, v, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$v / $total',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: total == 0 ? 0 : v / total,
                backgroundColor: AppColors.surfaceAlt,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelled = true;
              Navigator.of(context).pop();
            },
            child: const Text('Stop'),
          ),
        ],
      ),
    );

    for (var i = 0; i < all.length; i++) {
      if (cancelled) break;
      final r = all[i];
      try {
        final result = await svc.classifier.classifyWavFile(r.filePath);
        if (result != null) {
          final updated = r.copyWith(
            category: result.primary.category,
            categoryLabel: result.primary.label,
            categoryConfidence: result.primary.confidence,
            tags: result.tags.map((t) => t.category).toList(),
            windowCategories: result.windowCategories,
            windowCategoriesSecondary: result.windowCategoriesSecondary,
          );
          final trimmed = await svc.storage.trimToActiveRange(updated);
          await svc.storage.update(trimmed);
        }
      } catch (_) {}
      progress.value = i + 1;
    }

    if (mounted && !cancelled) Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          cancelled
              ? 'Re-analysis stopped at ${progress.value} / $total'
              : 'Re-analyzed $total recordings',
        ),
      ),
    );
  }

  Future<void> _clearClassifications() async {
    final svc = AppServices.of(context);
    final all = await svc.storage.loadAll();
    if (all.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No recordings to clear')));
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear all classifications?'),
        content: Text(
          'Resets category, tags and waveform colouring on all '
          '${all.length} clips. Recordings themselves are not deleted. '
          'You can re-run classification afterwards.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final wiped = all
        .map(
          (r) => r.copyWith(
            category: SoundCategory.unknown,
            categoryLabel: 'Other',
            categoryConfidence: 0,
            tags: const [],
            windowCategories: const [],
            windowCategoriesSecondary: const [],
          ),
        )
        .toList();
    await svc.storage.replaceAll(wiped);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cleared classifications on ${wiped.length} clips'),
      ),
    );
  }

  /// Pack every recording plus the JSON index into a single ZIP in the
  /// app's cache dir, then hand it to the system share sheet so the user
  /// can route it to any destination — Files → save to folder, Drive,
  /// email, etc. Streams to disk so big libraries don't blow up memory.
  Future<void> _exportRecordingsZip() async {
    final svc = AppServices.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final all = await svc.storage.loadAll();
    if (!mounted) return;
    if (all.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No recordings to export')),
      );
      return;
    }

    final progress = ValueNotifier<int>(0);
    final total = all.length;
    var cancelled = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Exporting'),
        content: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (_, v, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$v / $total',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: total == 0 ? 0 : v / total,
                backgroundColor: AppColors.surfaceAlt,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelled = true;
              Navigator.of(context).pop();
            },
            child: const Text('Stop'),
          ),
        ],
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final zipPath = p.join(tempDir.path, 'snorec-export-$stamp.zip');
    final zipFile = File(zipPath);
    if (await zipFile.exists()) {
      try {
        await zipFile.delete();
      } catch (_) {}
    }

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    var added = 0;
    try {
      for (var i = 0; i < all.length; i++) {
        if (cancelled) break;
        final r = all[i];
        final wav = File(r.filePath);
        if (await wav.exists()) {
          try {
            await encoder.addFile(wav, 'recordings/${p.basename(r.filePath)}');
            added++;
          } catch (_) {}
        }
        progress.value = i + 1;
      }
      // Include the JSON index so a restore could rebuild everything.
      final indexFile = await svc.storage.indexFile();
      if (await indexFile.exists()) {
        try {
          await encoder.addFile(indexFile, 'index.json');
        } catch (_) {}
      }
    } finally {
      await encoder.close();
    }

    if (mounted && !cancelled) navigator.pop();

    if (cancelled) {
      try {
        await zipFile.delete();
      } catch (_) {}
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Export cancelled at ${progress.value} / $total'),
        ),
      );
      return;
    }

    final sizeBytes = await zipFile.length();
    final sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Archive ready — $added clips, $sizeMb MB')),
    );

    try {
      await Share.shareXFiles(
        [XFile(zipPath, mimeType: 'application/zip')],
        subject: 'SnoREC recordings — $stamp',
        text: '$added clips, $sizeMb MB',
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Could not share: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    if (s == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        const ScreenHeading(
          title: 'Make it yours.',
          subtitle: 'A few settings for a better night.',
        ),
        _sectionTitle('Schedule'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Nightly schedule'),
                subtitle: const Text(
                  'Bedtime reminder and automatic stop. Tap the reminder to start when the app is closed.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                value: s.autoSchedule,
                onChanged: (v) => _save(s.copyWith(autoSchedule: v)),
              ),
              const Divider(height: 1),
              ListTile(
                enabled: s.autoSchedule,
                title: const Text('Bedtime reminder'),
                trailing: Text(
                  _fmt(s.startTime),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () async {
                  final t = await _pickTime(s.startTime);
                  if (t != null) _save(s.copyWith(startTime: t));
                },
              ),
              const Divider(height: 1),
              ListTile(
                enabled: s.autoSchedule,
                title: const Text('End session at'),
                trailing: Text(
                  _fmt(s.endTime),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () async {
                  final t = await _pickTime(s.endTime);
                  if (t != null) _save(s.copyWith(endTime: t));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Recording'),
        Card(
          child: Column(
            children: [
              _slider(
                title: 'Time to fall asleep',
                value: s.ignoreFirstMinutes.toDouble(),
                min: 0,
                max: 60,
                divisions: 60,
                valueLabel: '${s.ignoreFirstMinutes} min',
                onChanged: (v) =>
                    _save(s.copyWith(ignoreFirstMinutes: v.round())),
                help: 'Wait this long after starting before capturing anything',
              ),
              const Divider(height: 1),
              _slider(
                title: 'Sensitivity',
                value: s.sensitivity,
                min: 0,
                max: 1,
                divisions: 10,
                valueLabel: '${(s.sensitivity * 100).round()}%',
                onChanged: (v) => _save(s.copyWith(sensitivity: v)),
                help: 'Higher captures quieter sounds',
              ),
              const Divider(height: 1),
              _slider(
                title: 'Before each sound',
                value: s.preRollSeconds.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                valueLabel: '${s.preRollSeconds}s',
                onChanged: (v) => _save(s.copyWith(preRollSeconds: v.round())),
                help: 'Keep the beginning of a sound, before it gets loud',
              ),
              const Divider(height: 1),
              _slider(
                title: 'After each sound',
                value: s.postRollSeconds.toDouble(),
                min: 5,
                max: 180,
                divisions: 35,
                valueLabel: '${s.postRollSeconds}s',
                onChanged: (v) => _save(s.copyWith(postRollSeconds: v.round())),
                help: 'How long to keep recording after the last loud sound',
              ),
              const Divider(height: 1),
              _slider(
                title: 'Max clip length',
                value: s.maxSegmentSeconds.toDouble(),
                min: 10,
                max: 300,
                divisions: 29,
                valueLabel: '${s.maxSegmentSeconds}s',
                onChanged: (v) =>
                    _save(s.copyWith(maxSegmentSeconds: v.round())),
                help: 'Stop capturing after this many seconds',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Background'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  _batteryExempt ? Icons.check_circle : Icons.battery_alert,
                  color: _batteryExempt ? AppColors.teal : AppColors.orange,
                ),
                title: const Text('Battery optimization'),
                subtitle: Text(
                  _batteryExempt
                      ? 'Android battery optimization exemption granted. Phone-specific restrictions may still apply.'
                      : 'Android may interrupt recording. Tap to request a battery optimization exemption.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                trailing: _batteryExempt
                    ? null
                    : const Icon(
                        Icons.chevron_right,
                        color: AppColors.textMuted,
                      ),
                onTap: _batteryExempt
                    ? null
                    : () async {
                        await FgsBridge.requestIgnoreBatteryOptimizations();
                      },
              ),
              if (_background['powerSaveMode'] == true ||
                  _background['backgroundRestricted'] == true)
                const ListTile(
                  leading: Icon(Icons.warning_amber, color: AppColors.orange),
                  title: Text('Background recording may be restricted'),
                  subtitle: Text(
                    'Turn off Power saving and allow background activity for SnoREC before recording.',
                  ),
                ),
              ListTile(
                leading: const Icon(
                  Icons.settings_applications,
                  color: AppColors.primary,
                ),
                title: const Text('Phone background settings'),
                subtitle: Text(
                  '${_background['manufacturer'] ?? ''}'.toLowerCase().contains(
                        'honor',
                      )
                      ? 'HONOR: search Settings for App launch. Set SnoREC to Manage manually and enable Run in background. Lock it in Recent apps. Menu names vary by MagicOS version.'
                      : 'Allow background activity for SnoREC in your phone settings. You can turn the screen off after starting a recording.',
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () async {
                  try {
                    await FgsBridge.openAppSettings();
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Open Android Settings and select SnoREC.',
                        ),
                      ),
                    );
                  }
                },
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Start while SnoREC is open, then lock the screen. Force stop, powering off, or manufacturer cleanup can still end a session. A bedtime reminder requires a tap when the app is in the background.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        if (s.developerMode) ...[
          const SizedBox(height: 20),
          _sectionTitle('Developer'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.refresh, color: AppColors.primary),
                  title: const Text('Re-analyze all recordings'),
                  subtitle: const Text(
                    'Re-run classification on every saved clip',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                  ),
                  onTap: _reanalyzeAll,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.cleaning_services_outlined,
                    color: AppColors.red,
                  ),
                  title: const Text('Clear all classifications'),
                  subtitle: const Text(
                    'Reset every clip to Other and strip waveform colouring',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                  ),
                  onTap: _clearClassifications,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.archive_outlined,
                    color: AppColors.accent,
                  ),
                  title: const Text('Export recordings as ZIP'),
                  subtitle: const Text(
                    'Bundle every clip and the index, then save to a folder '
                    'of your choice',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                  ),
                  onTap: _exportRecordingsZip,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onVersionTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                _versionLabel.isEmpty ? 'SnoREC' : _versionLabel,
                style: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: AppColors.textMuted,
      ),
    ),
  );

  Widget _slider({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueLabel,
    required ValueChanged<double> onChanged,
    required String help,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                valueLabel,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              thumbColor: AppColors.accent,
              inactiveTrackColor: AppColors.surfaceAlt,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          Text(
            help,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
