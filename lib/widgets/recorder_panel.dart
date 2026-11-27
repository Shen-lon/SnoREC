import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/audio_recorder_service.dart';
import '../utils/theme.dart';
import 'brand.dart';

class RecorderPanel extends StatelessWidget {
  const RecorderPanel({
    super.key,
    required this.status,
    required this.settings,
    required this.onToggle,
    required this.onOpenSettings,
    required this.levels,
    this.busy = false,
    this.now,
  });
  final SessionStatus status;
  final AppSettings? settings;
  final VoidCallback onToggle;
  final VoidCallback onOpenSettings;
  final List<double> levels;
  final bool busy;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final running = status.phase != RecorderPhase.idle;
    final capturing = status.phase == RecorderPhase.capturing;
    final elapsed = status.sessionStartedAt == null
        ? Duration.zero
        : (now ?? DateTime.now()).difference(status.sessionStartedAt!);
    final seconds = elapsed.inSeconds.clamp(0, 9999999);
    final timer =
        '${(seconds ~/ 3600).toString().padLeft(2, '0')}:'
        '${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
    final stateText = capturing
        ? 'RECORDING A CLIP'
        : status.ignoreWindow
        ? 'SETTLING IN'
        : running
        ? 'LISTENING'
        : 'READY TO RECORD';
    final remaining = status.remainingIgnore ?? Duration.zero;
    final explanation = status.ignoreWindow
        ? 'Listening starts in ${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}'
        : running
        ? 'You can lock your screen now.'
        : 'Start a session, then put your phone nearby.';
    final stateColor = capturing
        ? AppColors.record
        : running
        ? AppColors.teal
        : AppColors.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreenHeading(
          title: 'Tonight.',
          subtitle: 'Sleep sounds, saved for the morning.',
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.line, width: 0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: stateColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      stateText,
                      style: TextStyle(
                        color: stateColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const Icon(Icons.mic_none_rounded, size: 19),
                ],
              ),
              const SizedBox(height: 30),
              Semantics(
                label: 'Session duration',
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    timer,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -2,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                explanation,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 28),
              ExcludeSemantics(
                child: SizedBox(
                  height: 64,
                  child: CustomPaint(
                    painter: SoundTracePainter(
                      levels: levels,
                      active: running && !status.ignoreWindow,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SectionLabel('Sound level'),
                  Text(
                    running &&
                            !status.ignoreWindow &&
                            status.lastAmplitudeDb > -95
                        ? '${status.lastAmplitudeDb.round()} dB'
                        : '—',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              const Divider(),
              const SizedBox(height: 19),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Reading(
                      label: 'CLIPS SAVED',
                      value: '${status.segmentsCaptured}',
                    ),
                  ),
                  Expanded(
                    child: _Reading(
                      label: running ? 'STOPS AT' : 'SETTLE-IN TIME',
                      value: running
                          ? (status.endsAt == null
                                ? 'Manual'
                                : TimeOfDay.fromDateTime(
                                    status.endsAt!,
                                  ).format(context))
                          : '${settings?.ignoreFirstMinutes ?? 0} min',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 23),
              FilledButton.icon(
                key: const ValueKey('record-toggle'),
                onPressed: busy || settings == null ? null : onToggle,
                style: running
                    ? FilledButton.styleFrom(
                        backgroundColor: AppColors.surfaceAlt,
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(color: AppColors.line),
                      )
                    : null,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        running
                            ? Icons.stop_rounded
                            : Icons.fiber_manual_record,
                        size: 18,
                      ),
                label: Text(
                  busy
                      ? 'Please wait…'
                      : running
                      ? 'End session'
                      : 'Start recording',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        InkWell(
          onTap: onOpenSettings,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, size: 20),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your recording setup',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        settings?.autoSchedule == true
                            ? 'Bedtime reminder on · Background settings'
                            : 'Sensitivity, schedule & background settings',
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 12,
              color: AppColors.textMuted,
            ),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'On your phone. Only shared by you.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Reading extends StatelessWidget {
  final String label;
  final String value;
  const _Reading({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionLabel(label),
      const SizedBox(height: 6),
      Text(
        value,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.6,
        ),
      ),
    ],
  );
}

/// Only actual microphone samples are shown. The idle state is a quiet baseline.
class SoundTracePainter extends CustomPainter {
  final List<double> levels;
  final bool active;
  const SoundTracePainter({required this.levels, required this.active});
  @override
  void paint(Canvas canvas, Size size) {
    final count = (size.width / 6).floor().clamp(1, 120);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    for (var i = 0; i < count; i++) {
      final sample = levels.length - count + i;
      final amplitude = active && sample >= 0 && sample < levels.length
          ? ((levels[sample] + 80) / 65).clamp(0.0, 1.0)
          : 0.0;
      final height = 2 + amplitude * (size.height - 6);
      paint.color = amplitude > 0.05 ? AppColors.primary : AppColors.line;
      final x = (i + 0.5) * size.width / count;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SoundTracePainter oldDelegate) => true;
}
