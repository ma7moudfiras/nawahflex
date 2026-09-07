/// بطاقة إحصاء بالهيرو — تقابل جدول public.stats. نفس الحقول المستعملة
/// حرفياً في site/js/content.js (stats[]) لتبقى القاعدة والموقع متطابقين.
class StatItem {
  const StatItem({
    required this.id,
    required this.label,
    required this.value,
    required this.isPublished,
    this.suffix = '',
    this.icon,
    this.sortOrder = 0,
  });

  final String id;
  final String label;
  final int value;
  final String suffix;
  final String? icon;
  final int sortOrder;
  final bool isPublished;

  factory StatItem.fromMap(Map<String, dynamic> m) => StatItem(
        id: m['id'] as String,
        label: (m['label'] as String?) ?? '',
        value: (m['value'] as num?)?.toInt() ?? 0,
        suffix: (m['suffix'] as String?) ?? '',
        icon: m['icon'] as String?,
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
        isPublished: (m['is_published'] as bool?) ?? true,
      );

  Map<String, dynamic> toInsertMap() => {
        'label': label,
        'value': value,
        'suffix': suffix,
        if (icon != null && icon!.isNotEmpty) 'icon': icon,
        'sort_order': sortOrder,
        'is_published': isPublished,
      };
}
