import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_services.dart';
import '../models/recording.dart';
import '../services/audio_recorder_service.dart';
import '../utils/categories.dart';
import '../utils/theme.dart';
import '../widgets/brand.dart';
import 'night_detail_screen.dart';

class NightsScreen extends StatefulWidget {
  const NightsScreen({super.key, required this.onStart});
  final VoidCallback onStart;
  @override
  State<NightsScreen> createState() => _NightsScreenState();
}

class _NightsScreenState extends State<NightsScreen> {
  List<Recording> _all = const [];
  bool _loading = true;
  AudioRecorderService? _recorder;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
      _recorder = AppServices.of(context).recorder;
      _recorder!.addSegmentListener(_onNewClip);
    });
  }

  @override
  void dispose() {
    _recorder?.removeSegmentListener(_onNewClip);
    super.dispose();
  }

  void _onNewClip(Recording r) {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final all = await AppServices.of(context).storage.loadAll();
    if (mounted) {
      setState(() {
        _all = all;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final grouped = <DateTime, List<Recording>>{};
    for (final r in _all) {
      grouped.putIfAbsent(r.nightKey, () => []).add(r);
    }
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          ScreenHeading(
            title: 'Your nights.',
            subtitle: _all.isEmpty
                ? 'The sounds you slept through, all in one place.'
                : '${keys.length} ${keys.length == 1 ? 'night' : 'nights'} · ${_all.length} saved clips',
          ),
          if (_all.isEmpty) ...[
            const SizedBox(height: 40),
            const Center(child: SnorecMark(size: 80)),
            const SizedBox(height: 30),
            const Text(
              'Nothing recorded. Yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Start a session tonight. Your clips will be\nready to play here in the morning.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                onPressed: widget.onStart,
                label: const Text('Go to Tonight'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              ),
            ),
          ] else ...[
            const SectionLabel('Saved sessions'),
            const SizedBox(height: 12),
            const Divider(),
            for (final night in keys)
              _NightRow(
                night: night,
                recordings: grouped[night]!,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NightDetailScreen(
                        night: night,
                        recordings: grouped[night]!,
                      ),
                    ),
                  );
                  if (mounted) _load();
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _NightRow extends StatelessWidget {
  const _NightRow({
    required this.night,
    required this.recordings,
    required this.onTap,
  });
  final DateTime night;
  final List<Recording> recordings;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final counts = <DisplayCategory, int>{};
    for (final r in recordings) {
      for (final b in displayCategoriesFor(r.category, r.tags, [
        ...r.windowCategories,
        ...r.windowCategoriesSecondary,
      ])) {
        counts[b] = (counts[b] ?? 0) + 1;
      }
    }
    final duration = Duration(
      milliseconds: recordings.fold<int>(0, (n, r) => n + r.durationMs),
    );
    final length = duration.inMinutes > 0
        ? '${duration.inMinutes} min'
        : '${duration.inSeconds} sec';
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 57,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('dd').format(night),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -1.3,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SectionLabel(DateFormat('MMM').format(night)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE').format(night),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${recordings.length} clips · $length of sound',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 14,
                        runSpacing: 7,
                        children: [
                          for (final cat in DisplayCategory.values)
                            if ((counts[cat] ?? 0) > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: displayCategoryInfo[cat]!.color,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${displayCategoryInfo[cat]!.label} ${counts[cat]}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Icon(Icons.arrow_forward_rounded, size: 17),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }
}
