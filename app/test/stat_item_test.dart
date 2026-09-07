import 'package:flutter_test/flutter_test.dart';
import 'package:nawahflex_app/features/stats/stat_item.dart';

void main() {
  group('fromMap', () {
    test('يقرأ الأعمدة الصحيحة', () {
      final s = StatItem.fromMap({
        'id': 's1',
        'label': 'طالب وطالبة',
        'value': 1250,
        'suffix': '+',
        'icon': '🎓',
        'sort_order': 1,
        'is_published': true,
      });
      expect(s.label, 'طالب وطالبة');
      expect(s.value, 1250);
      expect(s.suffix, '+');
    });

    test('قيم افتراضية آمنة عند غياب الحقول الاختيارية', () {
      final s = StatItem.fromMap({'id': 's1', 'label': 'x', 'value': 5});
      expect(s.suffix, '');
      expect(s.sortOrder, 0);
      expect(s.isPublished, isTrue);
    });
  });

  group('toInsertMap', () {
    test('يحذف الأيقونة الفارغة فقط، ويُبقي باقي الحقول دائماً', () {
      final m = const StatItem(id: 'x', label: 'طالب', value: 10, isPublished: true).toInsertMap();
      expect(m.containsKey('icon'), isFalse);
      expect(m['label'], 'طالب');
      expect(m['value'], 10);
      expect(m['suffix'], '');
      expect(m['sort_order'], 0);
    });
  });
}
