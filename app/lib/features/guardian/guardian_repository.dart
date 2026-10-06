import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import '../../core/errors.dart';
import '../../core/supabase.dart';
import '../students/student.dart';

/// شهر مستحقات كما يراه ولي الأمر: المطلوب والمدفوع.
class ChildDue {
  const ChildDue({required this.month, required this.due, required this.paid});
  final DateTime month;
  final num due;
  final num paid;
  num get remaining => (due - paid) < 0 ? 0 : due - paid;
  bool get settled => remaining == 0;

  factory ChildDue.fromMap(Map<String, dynamic> m) => ChildDue(
        month: DateTime.parse(m['period_month'] as String),
        due: m['amount_due'] as num,
        paid: m['amount_paid'] as num,
      );
}

/// ولي أمر مربوط بطالب — للإدارة.
class LinkedGuardian {
  const LinkedGuardian({required this.id, required this.name, this.relationship});
  final String id;
  final String name;
  final String? relationship;
}

/// نتيجة الدعوة: الرابط الذي ترسله الإدارة لولي الأمر.
class GuardianLink {
  const GuardianLink({required this.link, required this.existing});
  final String link;

  /// الحساب كان موجوداً (ولي أمر لطالب آخر) — الرابط رابط دخول لا دعوة.
  final bool existing;
}

/// رفض الدالة طلباً لسبب يفهمه المستخدم — رسالته عربية جاهزة للعرض.
class InviteRefused extends UserFacingError {
  const InviteRefused(super.message);
}

/// بوابة ولي الأمر. القراءة عبر دوال 0013 التي ترجع أعمدة مقصودة فقط وتُسقط
/// كل طالب ليس السائل وليّه؛ الدعوة عبر Edge Function «invite-guardian».
class GuardianRepository {
  const GuardianRepository();

  // ---------- ولي الأمر ----------

  Future<List<Student>> fetchChildren() async {
    final rows = await Db.client.rpc('my_children');
    return [
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        Student(
          id: r['id'] as String,
          fullName: r['full_name'] as String,
          birthDate: r['birth_date'] == null ? null : DateTime.parse(r['birth_date'] as String),
          gender: r['gender'] as String?,
          photoUrl: r['photo_url'] as String?,
          isActive: (r['is_active'] as bool?) ?? true,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          programIds: ((r['program_ids'] as List?) ?? const []).cast<String>(),
          programTitles: ((r['program_titles'] as List?) ?? const []).cast<String>(),
        ),
    ];
  }

  Future<Student?> fetchChild(String id) async =>
      (await fetchChildren()).where((s) => s.id == id).firstOrNull;

  /// الحضور: الحالة ← العدد، بنفس شكل AttendanceRepository.
  Future<Map<String, int>> fetchAttendanceCounts(String studentId) async {
    final rows = await Db.client.rpc('child_attendance', params: {'p_student_id': studentId});
    final counts = <String, int>{};
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      final s = r['status'] as String;
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts;
  }

  Future<List<ChildDue>> fetchDues(String studentId) async {
    final rows = await Db.client.rpc('child_dues', params: {'p_student_id': studentId});
    return (rows as List).map((r) => ChildDue.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// آخر ملاحظة «للأهل» لكل ابن — RLS ترجع لولي الأمر المعلَّمة له فقط.
  Future<Map<String, String>> fetchLatestNotes(List<String> studentIds) async {
    if (studentIds.isEmpty) return const {};
    final rows = await Db.client
        .from('student_notes')
        .select('student_id, body, created_at')
        .inFilter('student_id', studentIds)
        .eq('visible_to_guardian', true)
        .order('created_at', ascending: false)
        .limit(50);
    final out = <String, String>{};
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      out.putIfAbsent(r['student_id'] as String, () => r['body'] as String);
    }
    return out;
  }

  // ---------- الإدارة ----------

  Future<List<LinkedGuardian>> fetchGuardians(String studentId) async {
    final rows = await Db.client
        .from('guardian_students')
        .select('guardian_id, relationship, profiles(full_name)')
        .eq('student_id', studentId)
        .order('created_at', ascending: true);
    return [
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        LinkedGuardian(
          id: r['guardian_id'] as String,
          name: ((r['profiles'] as Map<String, dynamic>?)?['full_name'] as String?) ?? 'ولي أمر',
          relationship: r['relationship'] as String?,
        ),
    ];
  }

  Future<GuardianLink> invite({
    required String studentId,
    required String email,
    String? fullName,
    String? relationship,
  }) =>
      _call({
        'student_id': studentId,
        'email': email.trim(),
        if (fullName != null && fullName.trim().isNotEmpty) 'full_name': fullName.trim(),
        if (relationship != null && relationship.trim().isNotEmpty) 'relationship': relationship.trim(),
      });

  /// رابط دخول جديد لولي أمر مربوط (الرابط يُستعمل مرة واحدة ولمدة محدودة).
  Future<GuardianLink> loginLink({required String studentId, required String guardianId}) =>
      _call({'student_id': studentId, 'guardian_id': guardianId});

  Future<GuardianLink> _call(Map<String, dynamic> body) async {
    try {
      final res = await Db.client.functions.invoke('invite-guardian', body: body);
      final data = res.data as Map<String, dynamic>;
      return GuardianLink(link: data['link'] as String, existing: (data['existing'] as bool?) ?? false);
    } on FunctionException catch (e) {
      final code = e.details is Map ? (e.details as Map)['error'] : null;
      final msg = switch (code) {
        'staff_account' => 'هذا البريد لحساب موظّف في الأكاديمية — لا يُدعى وليّ أمر.',
        'email' => 'البريد الإلكتروني غير صالح.',
        'forbidden' => 'دعوة أولياء الأمور للإدارة فقط.',
        'not_linked' => 'ولي الأمر هذا لم يعد مربوطاً بالطالب.',
        'no_email' => 'لا بريد لهذا الحساب.',
        _ => null,
      };
      if (msg != null) throw InviteRefused(msg);
      rethrow;
    }
  }

  Future<void> unlink({required String studentId, required String guardianId}) async {
    expectRows(await Db.client
        .from('guardian_students')
        .delete()
        .eq('student_id', studentId)
        .eq('guardian_id', guardianId)
        .select('guardian_id'));
  }
}
