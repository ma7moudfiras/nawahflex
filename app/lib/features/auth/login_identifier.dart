/// نطاق حسابات الطلاب الداخلي — يطابق STUDENT_DOMAIN في
/// supabase/functions/student-account. الطالب يكتب اسم مستخدمه وحده.
const studentEmailDomain = 'students.nawahflex.org';

final _username = RegExp(r'^[a-z0-9._]{3,20}$');
final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// ما كتبه المستخدم في حقل الدخول ← البريد الذي تعرفه Supabase.
/// بريد كامل يمرّ كما هو؛ اسم مستخدم طالب يُلحَق به النطاق الداخلي.
/// يرجع null إن لم يكن هذا ولا ذاك.
String? loginEmailFor(String input) {
  final s = input.trim().toLowerCase();
  if (s.contains('@')) return _email.hasMatch(s) ? s : null;
  return _username.hasMatch(s) ? '$s@$studentEmailDomain' : null;
}
