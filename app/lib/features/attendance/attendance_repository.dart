import '../../core/supabase.dart';

/// اسم وطالب مسجَّل بفوج — عرض خفيف لا يحتاج نموذج Student الكامل.
class RosterEntry {
  const RosterEntry({required this.studentId, required this.fullName});
  final String studentId;
  final String fullName;
}

/// تسجيل الحضور. RLS تُقيّد الفوج ذاته (fetch على cohorts، لا هنا) —
/// وتمنع المدرّب من تسجيل حضور لطالب غير مسجَّل بفوجه فعلياً (WITH CHECK
/// في 0004_cohorts_enrollments_attendance.sql).
class AttendanceRepository {
  const AttendanceRepository();

  Future<List<RosterEntry>> fetchRoster(String cohortId) async {
    final rows = await Db.client
        .from('enrollments')
        .select('student_id, students(full_name)')
        .eq('cohort_id', cohortId);
    final list = (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      final student = m['students'] as Map<String, dynamic>?;
      return RosterEntry(
        studentId: m['student_id'] as String,
        fullName: (student?['full_name'] as String?) ?? '',
      );
    }).toList();
    list.sort((a, b) => a.fullName.compareTo(b.fullName));
    return list;
  }

  Future<Map<String, String>> fetchStatuses(String cohortId, DateTime date) async {
    final rows = await Db.client
        .from('attendance')
        .select('student_id, status')
        .eq('cohort_id', cohortId)
        .eq('session_date', _dateOnly(date));
    return {
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        r['student_id'] as String: r['status'] as String,
    };
  }

  Future<void> mark({
    required String cohortId,
    required String studentId,
    required DateTime date,
    required String status,
  }) async {
    await Db.client.from('attendance').upsert(
      {
        'cohort_id': cohortId,
        'student_id': studentId,
        'session_date': _dateOnly(date),
        'status': status,
        'marked_by': Db.user?.id,
      },
      onConflict: 'cohort_id,student_id,session_date',
    );
  }

  static String _dateOnly(DateTime d) => d.toIso8601String().split('T').first;
}
