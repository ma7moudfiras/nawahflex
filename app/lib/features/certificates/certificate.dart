/// شهادة صادرة عن الأكاديمية (جدول certificates — 0016).
class Certificate {
  const Certificate({
    required this.id,
    required this.code,
    required this.studentId,
    required this.kind,
    required this.title,
    required this.issuedAt,
    this.programId,
    this.level,
    this.revokedAt,
  });

  final String id;

  /// `NW-XXXX-XXXX` — يولّده الخادم عشوائياً؛ لا يُكتب من التطبيق.
  final String code;
  final String studentId;

  /// program | level | other
  final String kind;
  final String title;
  final String? programId;
  final int? level;
  final DateTime issuedAt;
  final DateTime? revokedAt;

  bool get isRevoked => revokedAt != null;

  static final codePattern = RegExp(r'^NW-[A-Z0-9]{4}-[A-Z0-9]{4}$');

  /// الرابط المطبوع في رمز QR على الشهادة — صفحة site/verify.html.
  static String verifyUrl(String code) => 'https://www.nawahflex.org/verify?c=$code';

  /// لاتيني خالص: كروميوم يرفض اسم ملف يخلط العربي باللاتيني (حماية من
  /// انتحال الامتداد) فيحفظه باسم «download» بلا امتداد.
  String get fileName => 'nawah-certificate-$code.pdf';

  static const kinds = <String, String>{
    'program': 'إتمام برنامج',
    'level': 'بلوغ مستوى',
    'other': 'أخرى',
  };

  factory Certificate.fromMap(Map<String, dynamic> m) => Certificate(
        id: m['id'] as String,
        code: m['code'] as String,
        studentId: m['student_id'] as String,
        kind: m['kind'] as String,
        title: m['title'] as String,
        programId: m['program_id'] as String?,
        level: (m['level'] as num?)?.toInt(),
        issuedAt: DateTime.parse(m['issued_at'] as String).toLocal(),
        revokedAt: m['revoked_at'] == null ? null : DateTime.parse(m['revoked_at'] as String).toLocal(),
      );
}
