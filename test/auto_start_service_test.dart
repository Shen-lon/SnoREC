import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snorec/services/auto_start_service.dart';
import 'package:snorec/models/app_settings.dart';

void main() {
  group('pending bedtime reminder', () {
    const settings = AppSettings(autoSchedule: true);
    final fired = DateTime(2026, 11, 26, 22, 30);

    test('late evening launch keeps the original morning stop time', () {
      expect(
        AutoStartService.pendingSessionEnd(
          settings,
          fired,
          now: DateTime(2026, 11, 27, 1),
        ),
        DateTime(2026, 11, 27, 7),
      );
    });
    test(
      'opening after the morning stop does not start a daytime recording',
      () {
        expect(
          AutoStartService.pendingSessionEnd(
            settings,
            fired,
            now: DateTime(2026, 11, 27, 8),
          ),
          isNull,
        );
      },
    );
    test('exact end, disabled schedule, and future flags are ignored', () {
      expect(
        AutoStartService.pendingSessionEnd(
          settings,
          fired,
          now: DateTime(2026, 11, 27, 7),
        ),
        isNull,
      );
      expect(
        AutoStartService.pendingSessionEnd(
          const AppSettings(),
          fired,
          now: DateTime(2026, 11, 26, 23),
        ),
        isNull,
      );
      expect(
        AutoStartService.pendingSessionEnd(
          settings,
          fired,
          now: DateTime(2026, 11, 26, 21),
        ),
        isNull,
      );
    });
  });
  group('AutoStartService.nextOccurrence', () {
    test('future time today fires today', () {
      final from = DateTime(2026, 5, 8, 21, 0); // 9 PM
      final at = AutoStartService.nextOccurrence(
        const TimeOfDay(hour: 23, minute: 0),
        from: from,
      );
      expect(at, DateTime(2026, 5, 8, 23, 0));
    });

    test('past time today rolls to tomorrow', () {
      final from = DateTime(2026, 5, 8, 23, 30); // 11:30 PM
      final at = AutoStartService.nextOccurrence(
        const TimeOfDay(hour: 22, minute: 0),
        from: from,
      );
      expect(at, DateTime(2026, 5, 9, 22, 0));
    });

    test('exact match rolls to tomorrow', () {
      // !isAfter -> roll. We want a strict-future fire so that
      // re-arming at the moment of fire doesn't immediately re-fire.
      final from = DateTime(2026, 5, 8, 23, 0);
      final at = AutoStartService.nextOccurrence(
        const TimeOfDay(hour: 23, minute: 0),
        from: from,
      );
      expect(at, DateTime(2026, 5, 9, 23, 0));
    });
  });

  group('AutoStartService.resolveEnd', () {
    test('end after now stays today', () {
      final from = DateTime(2026, 5, 8, 22, 0); // 10 PM
      final end = AutoStartService.resolveEnd(
        const TimeOfDay(hour: 23, minute: 30),
        from: from,
      );
      expect(end, DateTime(2026, 5, 8, 23, 30));
    });

    test(
      'end before now (typical 7 AM after 11 PM start) goes to next day',
      () {
        final from = DateTime(2026, 5, 8, 23, 0);
        final end = AutoStartService.resolveEnd(
          const TimeOfDay(hour: 7, minute: 0),
          from: from,
        );
        expect(end, DateTime(2026, 5, 9, 7, 0));
      },
    );
  });
}
