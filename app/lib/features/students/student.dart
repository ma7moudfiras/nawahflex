/// طالب — يقابل جدول public.students.
class Student {
  const Student({
    required this.id,
    required this.fullName,
    required this.isActive,
    required this.createdAt,
    this.birthDate,
    this.gender,
    this.guardianName,
    this.guardianPhone,
    this.guardianEmail,
    this.notes,
    this.photoUrl,
    this.programTitles = const [],
  });

  final String id;
  final String fullName;
  final DateTime? birthDate;
  final String? gender;             // 'm' | 'f' | null
  final String? guardianName;
  final String? guardianPhone;
  final String? guardianEmail;
  final String? notes;
  final String? photoUrl;
  final bool isActive;
  final DateTime createdAt;
  final List<String> programTitles;

  String get initial => fullName.trim().isEmpty ? '؟' : fullName.trim()[0];

  int? get age => ageFrom(birthDate);

  static int? ageFrom(DateTime? b) {
    if (b == null) return null;
    final now = DateTime.now();
    var a = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) a--;
    return a;
  }

  String get whatsappUrl {
    final raw = guardianPhone ?? '';
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = '970${digits.substring(1)}';
    return 'https://wa.me/$digits';
  }

  factory Student.fromMap(Map<String, dynamic> m) => Student(
        id: m['id'] as String,
        fullName: (m['full_name'] as String?) ?? '',
        birthDate: m['birth_date'] == null ? null : DateTime.parse(m['birth_date'] as String),
        gender: m['gender'] as String?,
        guardianName: m['guardian_name'] as String?,
        guardianPhone: m['guardian_phone'] as String?,
        guardianEmail: m['guardian_email'] as String?,
        notes: m['notes'] as String?,
        photoUrl: m['photo_url'] as String?,
        isActive: (m['is_active'] as bool?) ?? true,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        programTitles: ((m['student_programs'] as List?) ?? const [])
            .map((sp) => (sp as Map<String, dynamic>)['programs'] as Map<String, dynamic>?)
            .whereType<Map<String, dynamic>>()
            .map((p) => p['title'] as String)
            .toList(),
      );

  Map<String, dynamic> toInsertMap() => {
        'full_name': fullName,
        if (birthDate != null) 'birth_date': birthDate!.toIso8601String().split('T').first,
        if (gender != null) 'gender': gender,
        if (guardianName != null && guardianName!.isNotEmpty) 'guardian_name': guardianName,
        if (guardianPhone != null && guardianPhone!.isNotEmpty) 'guardian_phone': guardianPhone,
        if (guardianEmail != null && guardianEmail!.isNotEmpty) 'guardian_email': guardianEmail,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'is_active': isActive,
      };
}
