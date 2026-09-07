import 'package:flutter/material.dart' show TimeOfDay;

import '../../core/supabase.dart';
import 'class_session.dart';

/// اسم وطالب مسجَّل بفوج — عرض خفيف لا يحتاج نموذج Student الكامل.
class RosterEntry {
  const RosterEntry({required this.studentId, required this.fullName});
  final String studentId;
  final String fullName;
}

/// مدرّب مساعد بلقاء معيّن — اسمه وسعر ساعته الملتقَط وقت إضافته.
class SessionCoTrainer {
  const SessionCoTrainer({required this.trainerId, required this.fullName});
  final String trainerId;
  final String fullName;
}

/// تسجيل الحضور. RLS تُقيّد الفوج ذاته (fetch على cohorts، لا هنا) —
/// وتمنع المدرّب من تسجيل حضور لطالب غير مسجَّل بفوجه فعلياً (WITH CHECK
/// في 0004_cohorts_enrollments_attendance.sql).
class AttendanceRepository {
  const AttendanceRepository();

  Future<ClassSession?> fetchSession(String cohortId, DateTime date) async {
    final row = await Db.client
        .from('class_sessions')
        .select(
          'id, cohort_id, session_date, starts_at, ends_at, notes, trainer_hourly_rate',
        )
        .eq('cohort_id', cohortId)
        .eq('session_date', _dateOnly(date))
        .maybeSingle();
    return row == null ? null : ClassSession.fromMap(row);
  }

  /// ينشئ الحصة أو يحدّث وقتها/ملاحظاتها. سعر ساعة المدرّب يُلتقَط مرّة
  /// واحدة فقط عند أول إنشاء لهذه الحصة (لقطة)، ولا يُعاد التقاطه عند
  /// تعديلها لاحقاً — حتى لو تغيّر سعر المدرّب بين الحفظتين.
  Future<String> saveSession({
    required String cohortId,
    required DateTime date,
    TimeOfDay? startsAt,
    TimeOfDay? endsAt,
    String? notes,
  }) async {
    final existing = await fetchSession(cohortId, date);
    var rate = existing?.trainerHourlyRate;

    if (existing == null) {
      final cohort = await Db.client
          .from('cohorts')
          .select('trainer_id')
          .eq('id', cohortId)
          .maybeSingle();
      final trainerId = cohort?['trainer_id'] as String?;
      if (trainerId != null) {
        final rateRow = await Db.client
            .from('trainer_rate_history')
            .select('hourly_rate')
            .eq('profile_id', trainerId)
            .order('changed_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (rateRow != null) rate = (rateRow['hourly_rate'] as num).toDouble();
      }
    }

    final row = await Db.client
        .from('class_sessions')
        .upsert({
          'cohort_id': cohortId,
          'session_date': _dateOnly(date),
          'starts_at': ClassSession.formatTime(startsAt),
          'ends_at': ClassSession.formatTime(endsAt),
          'notes': notes,
          'trainer_hourly_rate': rate,
          if (existing == null) 'created_by': Db.user?.id,
        }, onConflict: 'cohort_id,session_date')
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// اللقاءات الماضية لفوج معيّن، الأحدث أولاً — لقائمة السجلّ.
  Future<List<ClassSession>> fetchPastSessions(String cohortId) async {
    final rows = await Db.client
        .from('class_sessions')
        .select(
          'id, cohort_id, session_date, starts_at, ends_at, notes, trainer_hourly_rate',
        )
        .eq('cohort_id', cohortId)
        .order('session_date', ascending: false);
    return (rows as List)
        .map((r) => ClassSession.fromMap(r as Map<String, dynamic>))
        .toList();
  }

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

  Future<Map<String, String>> fetchStatuses(
    String cohortId,
    DateTime date,
  ) async {
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
    String? sessionId,
  }) async {
    await Db.client.from('attendance').upsert({
      'cohort_id': cohortId,
      'student_id': studentId,
      'session_date': _dateOnly(date),
      'status': status,
      'marked_by': Db.user?.id,
      'session_id': ?sessionId,
    }, onConflict: 'cohort_id,student_id,session_date');
  }

  /// المدرّبون المساعدون بلقاء معيّن — لعرضهم وتعديلهم بنموذج اللقاء.
  Future<List<SessionCoTrainer>> fetchCoTrainers(String sessionId) async {
    final rows = await Db.client
        .from('class_session_trainers')
        .select('trainer_id, profiles(full_name)')
        .eq('session_id', sessionId);
    return (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      final profile = m['profiles'] as Map<String, dynamic>?;
      return SessionCoTrainer(
        trainerId: m['trainer_id'] as String,
        fullName: (profile?['full_name'] as String?) ?? '',
      );
    }).toList();
  }

  /// يستبدل قائمة المدرّبين المساعدين كاملة — حذف من لم يعد مختاراً، وإضافة
  /// الجدد فقط (سعر كل جديد يُلتقَط تلقائياً بمُشغِّل قاعدة البيانات، لأن
  /// من يسجّل اللقاء لا يملك أصلاً صلاحية قراءة سعر مدرّب آخر مباشرة).
  /// من يبقى مختاراً لا يُعاد إدراجه — سعره الملتقَط سابقاً لا يتغيّر.
  Future<void> setCoTrainers(String sessionId, List<String> trainerIds) async {
    final existing = (await fetchCoTrainers(sessionId))
        .map((t) => t.trainerId)
        .toList();
    final toRemove = existing.where((id) => !trainerIds.contains(id)).toList();
    final toAdd = trainerIds.where((id) => !existing.contains(id)).toList();
    if (toRemove.isNotEmpty) {
      await Db.client
          .from('class_session_trainers')
          .delete()
          .eq('session_id', sessionId)
          .inFilter('trainer_id', toRemove);
    }
    if (toAdd.isNotEmpty) {
      await Db.client
          .from('class_session_trainers')
          .insert(
            toAdd
                .map((id) => {'session_id': sessionId, 'trainer_id': id})
                .toList(),
          );
    }
  }

  /// طلاب مؤهَّلون للإضافة لهذا الفوج (نقل من فوج آخر) — أي طالب نشط
  /// ظاهر أصلاً لهذا المستخدم (RLS تحصر الظهور: الإدارة كل الطلاب، المدرّب
  /// طلاب أفواجه فقط) وغير مسجَّل بهذا الفوج تحديداً.
  Future<List<RosterEntry>> fetchAddableStudents(String cohortId) async {
    final enrolled = await Db.client
        .from('enrollments')
        .select('student_id')
        .eq('cohort_id', cohortId);
    final enrolledIds = (enrolled as List)
        .map((r) => (r as Map<String, dynamic>)['student_id'] as String)
        .toSet();
    final rows = await Db.client
        .from('students')
        .select('id, full_name')
        .eq('is_active', true)
        .order('full_name');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .where((r) => !enrolledIds.contains(r['id']))
        .map(
          (r) => RosterEntry(
            studentId: r['id'] as String,
            fullName: (r['full_name'] as String?) ?? '',
          ),
        )
        .toList();
  }

  /// يضيف طالباً موجوداً أصلاً لفوج آخر إلى هذا الفوج — RLS تمنع المدرّب من
  /// جلب طالب لا علاقة له به إطلاقاً (0009_multi_trainer_sessions.sql).
  Future<void> addStudentToCohort(String cohortId, String studentId) async {
    await Db.client.from('enrollments').insert({
      'cohort_id': cohortId,
      'student_id': studentId,
    });
  }

  static String _dateOnly(DateTime d) => d.toIso8601String().split('T').first;

  /// عدّاد كل حالة حضور لطالب معيّن عبر كل حصصه — لحساب نسبة الالتزام
  /// بتفاصيله (شاشة الطلاب).
  Future<Map<String, int>> fetchStudentAttendanceCounts(
    String studentId,
  ) async {
    final rows = await Db.client
        .from('attendance')
        .select('status')
        .eq('student_id', studentId);
    final counts = <String, int>{};
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      final status = r['status'] as String;
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }
}
