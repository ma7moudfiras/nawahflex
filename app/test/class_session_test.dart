import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawahflex_app/features/attendance/class_session.dart';

void main() {
  group('hours / duration', () {
    test('ساعة ونصف تُحسب 1.5', () {
      final s = ClassSession(
        id: 'x', cohortId: 'c', sessionDate: DateTime(2026),
        startsAt: const TimeOfDay(hour: 16, minute: 0),
        endsAt: const TimeOfDay(hour: 17, minute: 30),
      );
      expect(s.hours, 1.5);
    });

    test('بلا أحد الوقتين ترجع null', () {
      final s = ClassSession(id: 'x', cohortId: 'c', sessionDate: DateTime(2026), startsAt: const TimeOfDay(hour: 16, minute: 0));
      expect(s.hours, isNull);
    });

    test('نهاية قبل أو تساوي البداية ترجع null (بيانات غير منطقية)', () {
      final s = ClassSession(
        id: 'x', cohortId: 'c', sessionDate: DateTime(2026),
        startsAt: const TimeOfDay(hour: 17, minute: 0),
        endsAt: const TimeOfDay(hour: 16, minute: 0),
      );
      expect(s.hours, isNull);
    });
  });

  group('formatTime / fromMap', () {
    test('formatTime ينتج HH:MM:SS', () {
      expect(ClassSession.formatTime(const TimeOfDay(hour: 9, minute: 5)), '09:05:00');
    });

    test('formatTime لقيمة null يرجع null', () {
      expect(ClassSession.formatTime(null), isNull);
    });

    test('fromMap يقرأ الوقت من نص HH:MM:SS', () {
      final s = ClassSession.fromMap({
        'id': 's1',
        'cohort_id': 'c1',
        'session_date': '2026-01-01',
        'starts_at': '16:00:00',
        'ends_at': '17:30:00',
        'trainer_hourly_rate': 25,
      });
      expect(s.startsAt, const TimeOfDay(hour: 16, minute: 0));
      expect(s.endsAt, const TimeOfDay(hour: 17, minute: 30));
      expect(s.trainerHourlyRate, 25.0);
      expect(s.hours, 1.5);
    });
  });
}
