/// برنامج — يقابل جدول public.programs (يُستعمل هنا للتشغيل الإداري، لا
/// لنصوص الموقع التعريفي التي تبقى في site/js/content.js).
class Program {
  const Program({
    required this.id,
    required this.title,
    required this.description,
    required this.isPublished,
    required this.createdAt,
    this.ageMin,
    this.ageMax,
    this.price = 0,
    this.siblingPrice,
  });

  final String id;
  final String title;
  final String description;
  final int? ageMin;
  final int? ageMax;
  final bool isPublished;
  final DateTime createdAt;

  /// السعر الشهري العادي، وسعره بخصم الإخوة إن وُجد (يجب ألا يتجاوز
  /// السعر العادي — القاعدة تفرض هذا بقيد CHECK أيضاً).
  final int price;
  final int? siblingPrice;

  String get ageRangeLabel {
    if (ageMin != null && ageMax != null) return '$ageMin–$ageMax سنة';
    if (ageMin != null) return 'من $ageMin سنة';
    if (ageMax != null) return 'حتى $ageMax سنة';
    return '';
  }

  /// هل عمر معيَّن يقع ضمن نطاق البرنامج؟ يُستعمل كتلميح غير مانع عند
  /// اختيار برامج لطالب، لا كقيد صارم — قد يُسجَّل طالب خارج النطاق عمداً.
  bool fitsAge(int age) {
    if (ageMin != null && age < ageMin!) return false;
    if (ageMax != null && age > ageMax!) return false;
    return true;
  }

  factory Program.fromMap(Map<String, dynamic> m) => Program(
        id: m['id'] as String,
        title: (m['title'] as String?) ?? '',
        description: (m['text'] as String?) ?? '',
        ageMin: (m['age_min'] as num?)?.toInt(),
        ageMax: (m['age_max'] as num?)?.toInt(),
        isPublished: (m['is_published'] as bool?) ?? true,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        price: (m['price'] as num?)?.toInt() ?? 0,
        siblingPrice: (m['sibling_price'] as num?)?.toInt(),
      );

  Map<String, dynamic> toInsertMap() => {
        'title': title,
        'text': description,
        if (ageMin != null) 'age_min': ageMin,
        if (ageMax != null) 'age_max': ageMax,
        'is_published': isPublished,
        'price': price,
        if (siblingPrice != null) 'sibling_price': siblingPrice,
      };
}
