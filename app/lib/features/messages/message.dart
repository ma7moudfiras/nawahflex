/// رسالة واردة من نموذج التواصل في الموقع — تقابل جدول public.messages.
class Message {
  const Message({
    required this.id,
    required this.name,
    required this.phone,
    required this.body,
    required this.status,
    required this.createdAt,
    this.email,
    this.interest,
    this.notes,
    this.source = 'website',
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? interest;
  final String body;
  final String source;
  final String status;
  final String? notes;
  final DateTime createdAt;

  static const statusLabels = <String, String>{
    'new': 'جديدة',
    'in_progress': 'قيد المتابعة',
    'done': 'مكتملة',
    'spam': 'مزعجة',
  };

  String get statusLabel => statusLabels[status] ?? status;
  bool get isNew => status == 'new';

  /// رابط واتساب جاهز للردّ — أسرع وسيلة للتواصل مع ولي الأمر.
  /// أرقام فلسطين المحلية تبدأ بـ 0 وتُستبدل بمفتاح الدولة.
  String get whatsappUrl {
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = '970${digits.substring(1)}';
    return 'https://wa.me/$digits';
  }

  String get telUrl => 'tel:${phone.replaceAll(RegExp(r'\s'), '')}';

  factory Message.fromMap(Map<String, dynamic> m) => Message(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        email: m['email'] as String?,
        interest: m['interest'] as String?,
        body: (m['message'] as String?) ?? '',
        source: (m['source'] as String?) ?? 'website',
        status: (m['status'] as String?) ?? 'new',
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}
