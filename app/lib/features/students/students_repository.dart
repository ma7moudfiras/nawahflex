import '../../core/supabase.dart';
import 'student.dart';

/// قراءة وكتابة الطلاب. كل استدعاء يمرّ عبر RLS — لا وصول عام إطلاقاً.
class StudentsRepository {
  const StudentsRepository();

  static const _cols = 'id, full_name, birth_date, gender, guardian_name, '
      'guardian_phone, guardian_email, notes, photo_url, is_active, created_at';

  Future<List<Student>> fetch({String query = '', bool activeOnly = false}) async {
    var q = Db.client.from('students').select(_cols);
    if (activeOnly) q = q.eq('is_active', true);
    if (query.trim().isNotEmpty) q = q.ilike('full_name', '%${query.trim()}%');
    final rows = await q.order('full_name').limit(500);
    return (rows as List).map((r) => Student.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> create(Student s) async {
    await Db.client.from('students').insert(s.toInsertMap());
  }

  Future<void> update(String id, Student s) async {
    await Db.client.from('students').update(s.toInsertMap()).eq('id', id);
  }

  Future<void> setActive(String id, bool active) async {
    await Db.client.from('students').update({'is_active': active}).eq('id', id);
  }
}
