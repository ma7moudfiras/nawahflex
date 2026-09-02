import 'package:flutter_test/flutter_test.dart';
import 'package:nawahflex_app/features/cohorts/cohort.dart';

void main() {
  group('fromMap', () {
    test('يقرأ الأعمدة المضمَّنة (اسم البرنامج والمدرّب)', () {
      final c = Cohort.fromMap({
        'id': 'c1',
        'name': 'فوج الثلاثاء',
        'program_id': 'p1',
        'trainer_id': 't1',
        'schedule_label': 'ثلاثاء ٤–٦م',
        'starts_at': '2026-01-01',
        'ends_at': '2026-06-01',
        'capacity': 12,
        'is_active': true,
        'created_at': DateTime(2026).toIso8601String(),
        'programs': {'title': 'الروبوتات'},
        'profiles': {'full_name': 'أحمد المدرّب'},
      });
      expect(c.programTitle, 'الروبوتات');
      expect(c.trainerName, 'أحمد المدرّب');
      expect(c.capacity, 12);
      expect(c.startsAt, DateTime.parse('2026-01-01'));
    });

    test('بلا برنامج أو مدرّب مضمَّن يرجع null بلا خطأ', () {
      final c = Cohort.fromMap({
        'id': 'c1',
        'name': 'فوج',
        'is_active': true,
        'created_at': DateTime(2026).toIso8601String(),
      });
      expect(c.programTitle, isNull);
      expect(c.trainerName, isNull);
    });
  });

  group('toInsertMap', () {
    test('يحذف الحقول الاختيارية الفارغة', () {
      final m = Cohort(id: 'x', name: 'فوج', isActive: true, createdAt: DateTime(2026))
          .toInsertMap();
      expect(m.containsKey('program_id'), isFalse);
      expect(m.containsKey('trainer_id'), isFalse);
      expect(m.containsKey('capacity'), isFalse);
      expect(m['name'], 'فوج');
    });
  });
}
