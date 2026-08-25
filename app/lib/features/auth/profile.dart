import 'package:characters/characters.dart';

/// ملف المستخدم وصلاحيته — يقابل جدول public.profiles حرفياً.
class Profile {
  const Profile({
    required this.id,
    required this.role,
    this.fullName,
  });

  final String id;
  final String? fullName;
  final String role;

  /// من يملك حق الكتابة في لوحة الإدارة.
  /// يطابق شرط private.is_admin() في قاعدة البيانات.
  bool get canManage => role == 'admin' || role == 'editor';
  bool get isAdmin => role == 'admin';
  bool get isTrainer => role == 'trainer';

  String get displayName =>
      (fullName == null || fullName!.trim().isEmpty) ? 'مستخدم' : fullName!.trim();

  /// أول حرف للصورة الرمزية.
  String get initial => displayName.characters.first;

  static const roleLabels = <String, String>{
    'admin': 'مدير',
    'editor': 'محرّر',
    'trainer': 'مدرّب',
    'viewer': 'مشاهد',
  };

  String get roleLabel => roleLabels[role] ?? role;

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        fullName: m['full_name'] as String?,
        role: (m['role'] as String?) ?? 'viewer',
      );
}
