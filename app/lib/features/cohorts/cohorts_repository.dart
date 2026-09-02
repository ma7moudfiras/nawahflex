import '../../core/supabase.dart';
import '../auth/profile.dart';
import 'cohort.dart';

/// قراءة وكتابة الأفواج، وربط الطلاب بها عبر enrollments. RLS تُقيّد ما
/// يظهر تلقائياً: الإدارة ترى الكل، والمدرّب يرى فوجه فقط.
class CohortsRepository {
  const CohortsRepository();

  static const _cols = 'id, name, program_id, trainer_id, schedule_label, starts_at, ends_at, '
      'capacity, is_active, created_at, programs(title), profiles(full_name)';

  Future<List<Cohort>> fetch() async {
    final rows = await Db.client.from('cohorts').select(_cols).order('name');
    return (rows as List).map((r) => Cohort.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<String> create(Cohort c) async {
    final row = await Db.client.from('cohorts').insert(c.toInsertMap()).select('id').single();
    return row['id'] as String;
  }

  Future<void> update(String id, Cohort c) async {
    await Db.client.from('cohorts').update(c.toInsertMap()).eq('id', id);
  }

  /// حسابات المدرّبين — لقائمة اختيار مدرّب الفوج عند الإنشاء/التعديل.
  Future<List<Profile>> fetchTrainers() async {
    final rows = await Db.client.from('profiles').select('id, full_name, role').eq('role', 'trainer').order('full_name');
    return (rows as List).map((r) => Profile.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<String>> fetchEnrolledStudentIds(String cohortId) async {
    final rows = await Db.client.from('enrollments').select('student_id').eq('cohort_id', cohortId);
    return (rows as List).map((r) => r['student_id'] as String).toList();
  }

  /// يستبدل قائمة طلاب الفوج كاملة — حذف ثم إدراج، بنفس نمط
  /// StudentsRepository.setPrograms (حجم استعمال مماثل: إدارة يدوية، لا تكرار عالٍ).
  Future<void> setEnrolledStudents(String cohortId, List<String> studentIds) async {
    await Db.client.from('enrollments').delete().eq('cohort_id', cohortId);
    if (studentIds.isEmpty) return;
    await Db.client.from('enrollments').insert(
          studentIds.map((id) => {'cohort_id': cohortId, 'student_id': id}).toList(),
        );
  }
}
