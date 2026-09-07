import 'package:flutter/material.dart' show TimeOfDay;

/// حصة فعلية لفوج بتاريخ معيّن — وقتها، ملاحظات المدرّب عنها، ولقطة سعر
/// ساعته وقت أول تسجيل لها (لا تتغيّر بتعديل السعر لاحقاً ولا بتعديل
/// الحصة نفسها بعد إنشائها).
class ClassSession {
  const ClassSession({
    required this.id,
    required this.cohortId,
    required this.sessionDate,
    this.startsAt,
    this.endsAt,
    this.notes,
    this.trainerHourlyRate,
  });

  final String id;
  final String cohortId;
  final DateTime sessionDate;
  final TimeOfDay? startsAt;
  final TimeOfDay? endsAt;
  final String? notes;
  final double? trainerHourlyRate;

  Duration? get duration {
    final s = startsAt, e = endsAt;
    if (s == null || e == null) return null;
    final startMin = s.hour * 60 + s.minute;
    final endMin = e.hour * 60 + e.minute;
    if (endMin <= startMin) return null;
    return Duration(minutes: endMin - startMin);
  }

  /// المدّة كساعات عشرية (مثلاً ساعة ونصف = 1.5) — تُستعمل مباشرة في
  /// حساب مستحقات المدرّب (ساعات × سعر الساعة الملتقَط بهذه الحصة).
  double? get hours {
    final d = duration;
    return d == null ? null : d.inMinutes / 60;
  }

  factory ClassSession.fromMap(Map<String, dynamic> m) => ClassSession(
        id: m['id'] as String,
        cohortId: m['cohort_id'] as String,
        sessionDate: DateTime.parse(m['session_date'] as String),
        startsAt: _parseTime(m['starts_at'] as String?),
        endsAt: _parseTime(m['ends_at'] as String?),
        notes: m['notes'] as String?,
        trainerHourlyRate: (m['trainer_hourly_rate'] as num?)?.toDouble(),
      );

  static TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String? formatTime(TimeOfDay? t) =>
      t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
}
