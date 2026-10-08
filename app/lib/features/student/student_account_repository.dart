import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import '../../core/errors.dart';
import '../../core/supabase.dart';
import '../students/student.dart';

/// اسم المستخدم وكلمة المرور كما ترجعهما الدالة — مرة واحدة فقط.
class StudentCredentials {
  const StudentCredentials({required this.username, required this.password});
  final String username;
  final String password;
}

/// حساب دخول الطالب: قراءة لنفسه وللإدارة (RLS في 0014)، والإنشاء وإعادة
/// كلمة المرور عبر Edge Function «student-account».
class StudentAccountRepository {
  const StudentAccountRepository();

  /// الطالب المسجَّل دخوله — بأعمدة الهوية فقط (my_student).
  Future<Student?> fetchMe() async {
    final rows = (await Db.client.rpc('my_student') as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return null;
    final r = rows.first;
    return Student(
      id: r['id'] as String,
      fullName: r['full_name'] as String,
      birthDate: r['birth_date'] == null ? null : DateTime.parse(r['birth_date'] as String),
      gender: r['gender'] as String?,
      photoUrl: r['photo_url'] as String?,
      isActive: (r['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      programIds: ((r['program_ids'] as List?) ?? const []).cast<String>(),
      programTitles: ((r['program_titles'] as List?) ?? const []).cast<String>(),
    );
  }

  /// اسم مستخدم الطالب إن كان له حساب — للإدارة.
  Future<String?> fetchUsername(String studentId) async {
    final row = await Db.client
        .from('student_accounts')
        .select('username')
        .eq('student_id', studentId)
        .maybeSingle();
    return row?['username'] as String?;
  }

  Future<StudentCredentials> create(String studentId, String username) =>
      _call({'student_id': studentId, 'username': username.trim().toLowerCase()});

  Future<StudentCredentials> resetPassword(String studentId) =>
      _call({'student_id': studentId, 'reset': true});

  Future<StudentCredentials> _call(Map<String, dynamic> body) async {
    try {
      final res = await Db.client.functions.invoke('student-account', body: body);
      final d = res.data as Map<String, dynamic>;
      return StudentCredentials(username: d['username'] as String, password: d['password'] as String);
    } on FunctionException catch (e) {
      final code = e.details is Map ? (e.details as Map)['error'] : null;
      final msg = switch (code) {
        'username' => 'اسم المستخدم: ٣–٢٠ حرفاً إنجليزياً صغيراً أو أرقاماً أو نقطة.',
        'username_taken' => 'اسم المستخدم مأخوذ — اختر غيره.',
        'has_account' => 'لهذا الطالب حساب أصلاً.',
        'no_account' => 'لا حساب لهذا الطالب بعد.',
        'not_student_account' => 'الحساب المربوط ليس حساب طالب.',
        'forbidden' => 'حسابات الطلاب للإدارة فقط.',
        _ => null,
      };
      if (msg != null) throw UserFacingError(msg);
      rethrow;
    }
  }
}
