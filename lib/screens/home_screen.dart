import 'dart:async';

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../services/auto_start_service.dart';
import '../services/fgs_bridge.dart';
import '../utils/theme.dart';
import '../widgets/brand.dart';
import 'nights_screen.dart';
import 'settings_screen.dart';
import 'tonight_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _index = 0;
  bool _checkingSchedule = false;
  StreamSubscription<String>? _events;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _events = FgsBridge.events.listen((event) {
      if (event == 'autoStartDue') unawaited(_checkSchedule());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSchedule());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_checkSchedule());
  }

  Future<void> _checkSchedule() async {
    if (!mounted ||
        _checkingSchedule ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _checkingSchedule = true;
    try {
      final services = AppServices.of(context);
      await AutoStartService().handleColdLaunch(
        settingsService: services.settings,
        recorder: services.recorder,
      );
    } finally {
      _checkingSchedule = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _events?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final body = IndexedStack(
      index: _index,
      children: [
        TickerMode(
          enabled: _index == 0,
          child: TonightScreen(
            active: _index == 0,
            onOpenSettings: () => setState(() => _index = 2),
          ),
        ),
        NightsScreen(onStart: () => setState(() => _index = 0)),
        const SettingsScreen(),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const BrandWordmark(),
        actions: [
          if (MediaQuery.sizeOf(context).width >= 360 &&
              MediaQuery.textScalerOf(context).scale(1) < 1.4)
            const Padding(
              padding: EdgeInsets.only(right: 24),
              child: SectionLabel('Sleep recorder'),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            if (wide) ...[
              NavigationRail(
                backgroundColor: AppColors.background,
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                indicatorColor: AppColors.surfaceAlt,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.mic_none_rounded),
                    label: Text('Tonight'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.graphic_eq_rounded),
                    label: Text('Library'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.tune_rounded),
                    label: Text('Settings'),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
            ],
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: body,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.line, width: 0.7),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.mic_none_rounded),
                    label: 'Tonight',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.graphic_eq_rounded),
                    label: 'Library',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.tune_rounded),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
    );
  }
}
