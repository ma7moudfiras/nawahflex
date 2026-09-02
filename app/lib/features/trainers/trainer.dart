/// مدرّب — يقابل جدول public.trainers (سيرة تُعرض بالموقع: اسم، لقب، نبذة).
/// profileId رابط اختياري بحساب دخول فعلي للوحة (public.profiles) —
/// بلا حساب مرتبط، السيرة مجرّد محتوى تعريفي لا يملك أي صلاحية دخول.
class Trainer {
  const Trainer({
    required this.id,
    required this.fullName,
    required this.isPublished,
    required this.createdAt,
    this.profileId,
    this.title,
    this.bio,
  });

  final String id;
  final String fullName;
  final String? profileId;
  final String? title;
  final String? bio;
  final bool isPublished;
  final DateTime createdAt;

  bool get hasAccount => profileId != null;

  factory Trainer.fromMap(Map<String, dynamic> m) => Trainer(
        id: m['id'] as String,
        fullName: (m['full_name'] as String?) ?? '',
        profileId: m['profile_id'] as String?,
        title: m['title'] as String?,
        bio: m['bio'] as String?,
        isPublished: (m['is_published'] as bool?) ?? true,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );

  Map<String, dynamic> toInsertMap() => {
        'full_name': fullName,
        if (profileId != null) 'profile_id': profileId,
        if (title != null && title!.isNotEmpty) 'title': title,
        if (bio != null && bio!.isNotEmpty) 'bio': bio,
        'is_published': isPublished,
      };
}
