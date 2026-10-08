import '../../core/errors.dart';
import '../../core/supabase.dart';
import 'certificate.dart';

class CertificatesRepository {
  const CertificatesRepository();

  static const _cols = 'id, code, student_id, kind, title, program_id, level, issued_at, revoked_at';

  /// RLS: من يدرّس الطالب، وليّه، والطالب نفسه.
  Future<List<Certificate>> fetchFor(String studentId) async {
    final rows = await Db.client
        .from('certificates')
        .select(_cols)
        .eq('student_id', studentId)
        .order('issued_at', ascending: false);
    return (rows as List).map((r) => Certificate.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// الإدارة وحدها (السياسة ترفض غيرها). الرقم والتاريخ من الخادم.
  Future<Certificate> issue({
    required String studentId,
    required String kind,
    required String title,
    String? programId,
    int? level,
  }) async {
    final row = await Db.client
        .from('certificates')
        .insert({
          'student_id': studentId,
          'kind': kind,
          'title': title.trim(),
          'program_id': ?programId,
          'level': ?level,
          'issued_by': Db.user?.id,
        })
        .select(_cols)
        .single();
    return Certificate.fromMap(row);
  }

  /// إلغاء لا حذف: تبقى في صفحة التحقّق «ملغاة».
  Future<void> revoke(String id) async {
    expectRows(await Db.client
        .from('certificates')
        .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select('id'));
  }
}
